#Requires -Version 5.1

<#
.SYNOPSIS
Discord webhook notifications for course alerts via embeds.

.DESCRIPTION
Sends course alerts to Discord via webhook with rich embeds.
Webhooks from IPSC_DISCORD_WEBHOOKS environment variable (comma-separated).
Supports retry logic, parallel posting, and error recovery.
#>

# ============================================================================
# CONSTANTS
# ============================================================================

$DISCORD_WEBHOOK_TIMEOUT = 30
$DISCORD_MAX_RETRIES = 3
$DISCORD_EMBED_COLOR_NEW = 3066993          # Green #10b981
$DISCORD_EMBED_COLOR_REDUCED = 16243689     # Orange #f59e0b
$DISCORD_EMBED_COLOR_SOLD_OUT = 15671588    # Red #ef4444
$DISCORD_EMBED_COLOR_DEFAULT = 3947580      # Blue #3b82f6

# ============================================================================
# PRIVATE FUNCTIONS (Helpers)
# ============================================================================

function _GetAlertEmoji {
    param([string]$AlertReason)

    switch ($AlertReason) {
        'NEW' { return '[NEW]' }
        'AVAILABILITY_REDUCED' { return '[REDUCED]' }
        'SOLD_OUT' { return '[SOLD_OUT]' }
        default { return '[ALERT]' }
    }
}

function _GetAlertColor {
    param([string]$AlertReason)

    switch ($AlertReason) {
        'NEW' { return $DISCORD_EMBED_COLOR_NEW }
        'AVAILABILITY_REDUCED' { return $DISCORD_EMBED_COLOR_REDUCED }
        'SOLD_OUT' { return $DISCORD_EMBED_COLOR_SOLD_OUT }
        default { return $DISCORD_EMBED_COLOR_DEFAULT }
    }
}

function _ValidateDiscordConfig {
    <# .SYNOPSIS Validate Discord configuration #>
    param([object]$Config)

    if (-not $Config) {
        Write-Log -Level WARN -Message "Discord config missing"
        return $false
    }

    if (-not $Config.enabled) {
        return $false
    }

    return $true
}

function _GetDiscordWebhookUrls {
    <# .SYNOPSIS Get Discord webhook URLs from env var or config #>
    param([object]$Config)

    # Try environment variable first (highest priority)
    $webhookUrlsEnv = $env:IPSC_DISCORD_WEBHOOKS
    if ($webhookUrlsEnv) {
        $urls = @($webhookUrlsEnv -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($urls -and $urls.Count -gt 0) {
            Write-Log -Level DEBUG -Message "Discord webhooks from environment variable" `
                -Context @{ count = $urls.Count } | Out-Null
            return $urls
        }
    }

    # Fallback to config.json (backward compatibility)
    if ($Config.webhook_urls) {
        $urls = @($Config.webhook_urls | Where-Object { $_ })
        if ($urls -and $urls.Count -gt 0) {
            Write-Log -Level DEBUG -Message "Discord webhooks from config" `
                -Context @{ count = $urls.Count } | Out-Null
            return $urls
        }
    }

    Write-Log -Level WARN -Message "Discord notifier disabled: no webhook URLs configured" | Out-Null
    return @()
}

function _GroupAlertsByReason {
    <# .SYNOPSIS Group alerts by alert_reason (NEW, REDUCED, SOLD_OUT) #>
    param([object[]]$Alerts)

    if (-not $Alerts -or $Alerts.Count -eq 0) {
        return @{}
    }

    $grouped = @{}
    foreach ($alert in $Alerts) {
        $reason = $alert.alert_reason
        if (-not $reason) { $reason = 'OTHER' }

        if (-not $grouped[$reason]) {
            $grouped[$reason] = @()
        }
        $grouped[$reason] += $alert
    }

    return $grouped
}

function _BuildDiscordEmbeds {
    <# .SYNOPSIS Build Discord embed messages grouped by alert reason #>
    param([hashtable]$GroupedAlerts)

    [array]$embeds = @()
    $reasonOrder = @('NEW', 'AVAILABILITY_REDUCED', 'SOLD_OUT', 'OTHER')

    foreach ($reason in $reasonOrder) {
        if (-not $GroupedAlerts[$reason] -or $GroupedAlerts[$reason].Count -eq 0) {
            continue
        }

        $alerts = $GroupedAlerts[$reason]
        $emoji = _GetAlertEmoji -AlertReason $reason
        $color = _GetAlertColor -AlertReason $reason
        $count = $alerts.Count

        $title = switch ($reason) {
            'NEW' { "$emoji NEW Courses ($count available)" }
            'AVAILABILITY_REDUCED' { "$emoji Availability Reduced ($count courses)" }
            'SOLD_OUT' { "$emoji Sold Out ($count courses)" }
            default { "$emoji Course Alerts ($count)" }
        }

        $description = switch ($reason) {
            'NEW' { "New IPSC courses available on shooting-store.ch" }
            'AVAILABILITY_REDUCED' { "Available slots decreased for these courses" }
            'SOLD_OUT' { "These courses are no longer available" }
            default { "Course status updates" }
        }

        # Build fields (one per course)
        $fields = @()
        foreach ($alert in $alerts) {
            $value = "[$($alert.name)]($($alert.url)) | $($alert.price)`n$($alert.date) | $($alert.time) | **$($alert.availability) Slots**"

            $fields += @{
                name = " "
                value = $value
                inline = $false
            }
        }

        # Create embed
        $embed = @{
            title = $title
            description = $description
            color = $color
            fields = $fields
            footer = @{
                text = "IPSC Kurs Watcher"
            }
            timestamp = ([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))
        }

        $embeds += $embed
    }

    return ,$embeds
}

function _PostToWebhook {
    <# .SYNOPSIS Post message to single Discord webhook with retry logic #>
    param(
        [string]$WebhookUrl,
        [array]$Embeds,
        [int]$TimeoutSeconds,
        [int]$MaxRetries
    )

    # Apply defaults if not provided
    if (-not $TimeoutSeconds -or $TimeoutSeconds -le 0) { $TimeoutSeconds = 30 }
    if (-not $MaxRetries -or $MaxRetries -le 0) { $MaxRetries = 3 }

    if (-not $WebhookUrl -or -not $Embeds -or $Embeds.Count -eq 0) {
        return @{ success = $false; error = "Invalid webhook URL or embeds" }
    }

    $payload = @{ embeds = @($Embeds) }
    $jsonPayload = $payload | ConvertTo-Json -Depth 10 -Compress

    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        $attempt++
        try {
            $params = @{
                Uri = $WebhookUrl
                Method = 'POST'
                Headers = @{ 'Content-Type' = 'application/json' }
                Body = $jsonPayload
                TimeoutSeconds = $TimeoutSeconds
            }

            Invoke-SecureWebRequest @params | Out-Null
            Write-Log -Level DEBUG -Message "Discord webhook POST successful" `
                -Context @{ attempt = $attempt; webhook = $WebhookUrl } | Out-Null

            return @{ success = $true; status = 'sent' }
        }
        catch {
            if ($attempt -lt $MaxRetries) {
                $waitSeconds = [Math]::Pow(2, $attempt - 1)
                Write-Log -Level WARN -Message "Discord webhook retry attempt $attempt/$MaxRetries" `
                    -Context @{ webhook = $WebhookUrl; wait_seconds = $waitSeconds; error = $_.Exception.Message } | Out-Null
                Start-Sleep -Seconds $waitSeconds
            }
            else {
                Write-Log -Level ERROR -Message "Discord webhook failed after $MaxRetries attempts" `
                    -Context @{ webhook = $WebhookUrl; error = $_.Exception.Message } | Out-Null
                return @{ success = $false; error = $_.Exception.Message }
            }
        }
    }

    return @{ success = $false; error = "Unknown error" }
}

function _SendDiscordWebhooks {
    <# .SYNOPSIS Send Discord embeds to all webhooks #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification='Parameters used in job scriptblock with Using: scope')]
    param(
        [string[]]$WebhookUrls,
        [array]$Embeds,
        [int]$TimeoutSeconds = 30,
        [int]$MaxRetries = 3
    )

    if (-not $WebhookUrls -or $WebhookUrls.Count -eq 0) {
        return @{ sent = 0; failed = 0; results = @() }
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $results = @()
    $successCount = 0
    $failureCount = 0

    # Send to all webhooks (serial to avoid job startup overhead for small batches)
    $results = @()
    foreach ($url in $WebhookUrls) {
        $result = _PostToWebhook -WebhookUrl $url -Embeds $Embeds `
            -TimeoutSeconds $TimeoutSeconds -MaxRetries $MaxRetries
        $results += $result

        if ($result.success) {
            $successCount++
        }
        else {
            $failureCount++
        }
    }

    $stopwatch.Stop()

    Write-Log -Level INFO -Message "Discord notifications sent" `
        -Context @{
            webhook_count = $WebhookUrls.Count
            embeds_sent = $Embeds.Count
            success = $successCount
            failed = $failureCount
            duration_ms = $stopwatch.ElapsedMilliseconds
        } | Out-Null

    return @{ sent = $successCount; failed = $failureCount; results = $results }
}

# ============================================================================
# PUBLIC FUNCTIONS (Exported API)
# ============================================================================

function Send-DiscordNotification {
    <#
    .SYNOPSIS
    Send Discord webhook notifications for course alerts.

    .DESCRIPTION
    Sends course alerts to Discord via webhook with rich embeds.
    Webhooks from IPSC_DISCORD_WEBHOOKS environment variable or config.json.
    Supports retry logic, parallel posting, and graceful error handling.

    .PARAMETER Alerts
    Array of alert objects (from pipeline, containing alert_reason, name, date, time, availability, price, url)

    .PARAMETER Config
    Discord configuration from config.json (enabled, retry_attempts, timeout_seconds)

    .EXAMPLE
    $alerts = @(...course alerts...)
    Send-DiscordNotification -Alerts $alerts -Config $config.notifiers.discord
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateNotNull()][object[]]$Alerts,
        [ValidateNotNull()][object]$Config
    )

    # Validation
    if (-not (_ValidateDiscordConfig -Config $Config)) {
        return
    }

    if (-not $Alerts -or $Alerts.Count -eq 0) {
        Write-Log -Level DEBUG -Message "Discord: no alerts to send" | Out-Null
        return
    }

    if (-not $PSCmdlet.ShouldProcess("Discord webhooks", "Send $($Alerts.Count) course alerts")) {
        return
    }

    # Get webhook URLs
    $webhookUrls = _GetDiscordWebhookUrls -Config $Config
    if (-not $webhookUrls -or $webhookUrls.Count -eq 0) {
        return
    }

    # Group alerts by reason and build embeds
    $grouped = _GroupAlertsByReason -Alerts $Alerts
    $embeds = _BuildDiscordEmbeds -GroupedAlerts $grouped

    if (-not $embeds -or $embeds.Count -eq 0) {
        Write-Log -Level WARN -Message "Discord: no embeds to send" | Out-Null
        return
    }

    # Send to all webhooks
    $timeoutSeconds = $Config.timeout_seconds -as [int]
    if (-not $timeoutSeconds -or $timeoutSeconds -le 0) { $timeoutSeconds = $DISCORD_WEBHOOK_TIMEOUT }

    $maxRetries = $Config.retry_attempts -as [int]
    if (-not $maxRetries -or $maxRetries -le 0) { $maxRetries = $DISCORD_MAX_RETRIES }

    _SendDiscordWebhooks -WebhookUrls $webhookUrls -Embeds $embeds `
        -TimeoutSeconds $timeoutSeconds -MaxRetries $maxRetries
}


