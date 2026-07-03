#Requires -Version 5.1

function Send-DiscordNotification {
    <#
    .SYNOPSIS
    Send Discord webhook notifications for course alerts (v0.1 stub).

    .DESCRIPTION
    Sends course alerts via Discord webhooks. Webhooks are read from the
    IPSC_DISCORD_WEBHOOKS environment variable (comma-separated list).
    Falls back to config.json webhooks for backward compatibility.

    .PARAMETER Alerts
    Array of alert objects with alert_reason (NEW_COURSE, AVAILABILITY_REDUCED, SOLD_OUT)

    .PARAMETER Config
    Discord configuration from config.json
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([object[]]$Alerts, [object]$Config)

    if (-not $Config.enabled) { return }
    if (-not $Alerts -or $Alerts.Count -eq 0) { return }

    if (-not $PSCmdlet.ShouldProcess("Discord webhooks", "Send $($Alerts.Count) course alerts")) {
        return
    }

    # Try environment variable first, then fall back to config
    $webhookUrlsEnv = $env:IPSC_DISCORD_WEBHOOKS
    $webhookUrls = if ($webhookUrlsEnv) {
        @($webhookUrlsEnv -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
    else {
        $Config.webhook_urls
    }

    if (-not $webhookUrls -or $webhookUrls.Count -eq 0) {
        Write-Log -Level WARN -Message "Discord notifier disabled: no webhook URLs configured"
        return
    }

    # v0.1: Stub - log alerts by type
    $byReason = $Alerts | Group-Object -Property alert_reason

    foreach ($group in $byReason) {
        Write-Log -Level INFO -Message "Discord notification ($($group.Name) stub)" `
            -Context @{
                count = $group.Count
                webhook_count = $webhookUrls.Count
                status = 'STUB_v0.1_not_sent'
                source = if ($webhookUrlsEnv) { 'environment_variable' } else { 'config' }
            }
    }
}

