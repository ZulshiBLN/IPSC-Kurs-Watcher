#Requires -Version 5.1

<#
.SYNOPSIS
Email notifications via Microsoft Graph API (OAuth2).

.DESCRIPTION
Sends course alerts via email using Azure AD OAuth2 + Microsoft Graph /me/sendMail endpoint.
Includes token caching, auto-refresh, and retry logic.
#>

# ============================================================================
# CONSTANTS
# ============================================================================

$OAUTH_TOKEN_ENDPOINT = "https://login.microsoftonline.com/{0}/oauth2/v2.0/token"
$GRAPH_API_SCOPE = "https://graph.microsoft.com/.default"

# Load System.Web for HttpUtility
if (-not ([System.Management.Automation.PSTypeName]'System.Web.HttpUtility').Type) {
    Add-Type -AssemblyName System.Web | Out-Null
}

# Load System.Security for ProtectedData
if (-not ([System.Management.Automation.PSTypeName]'System.Security.Cryptography.ProtectedData').Type) {
    Add-Type -AssemblyName System.Security | Out-Null
}

# ============================================================================
# PRIVATE FUNCTIONS (Helpers)
# ============================================================================

function _GetCredentialFromStore {
    <# .SYNOPSIS Load Client Secret from encrypted credential store #>
    param([string]$StorePath)

    try {
        $credentialFile = Join-Path $StorePath "IPSC-Kurs-Watcher-Secret.bin"

        if (-not (Test-Path $credentialFile)) {
            Write-Log -Level ERROR -Message "Credential file not found" `
                -Context @{ path = $credentialFile }
            return $null
        }

        $encryptedBytes = [System.IO.File]::ReadAllBytes($credentialFile)
        $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encryptedBytes,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::LocalMachine
        )

        $secret = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
        return $secret
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to load credential from store" -Exception $_
        return $null
    }
}

function _LoadTokenCache {
    <# .SYNOPSIS Load cached OAuth2 token from encrypted file #>
    param([string]$CachePath)

    try {
        if (-not (Test-Path $CachePath)) {
            return $null
        }

        $encryptedBytes = [System.IO.File]::ReadAllBytes($CachePath)

        $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encryptedBytes,
            [System.Text.Encoding]::UTF8.GetBytes("IPSC-Token-Cache-v1"),
            [System.Security.Cryptography.DataProtectionScope]::LocalMachine
        )

        $tokenJson = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
        $cached = $tokenJson | ConvertFrom-Json
        return $cached
    }
    catch {
        Write-Log -Level WARN -Message "Failed to load token cache" -Exception $_
        return $null
    }
}

function _SaveTokenCache {
    <# .SYNOPSIS Save OAuth2 token to encrypted cache file #>
    param([object]$Token, [string]$CachePath)

    try {
        $cacheDir = Split-Path -Path $CachePath -Parent
        if (-not (Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        }

        $tokenJson = $Token | ConvertTo-Json
        $tokenBytes = [System.Text.Encoding]::UTF8.GetBytes($tokenJson)

        $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
            $tokenBytes,
            [System.Text.Encoding]::UTF8.GetBytes("IPSC-Token-Cache-v1"),
            [System.Security.Cryptography.DataProtectionScope]::LocalMachine
        )

        [System.IO.File]::WriteAllBytes($CachePath, $encryptedBytes)
    }
    catch {
        Write-Log -Level WARN -Message "Failed to save token cache" -Exception $_
    }
}

function _IsTokenExpired {
    <# .SYNOPSIS Check if OAuth2 token is expired or expiring soon #>
    param([object]$Token)

    if (-not $Token -or -not $Token.expires_on) {
        return $true
    }

    try {
        $unixEpoch = [DateTime]'1970-01-01'
        $expiresOn = $unixEpoch.AddSeconds([int]$Token.expires_on)
        $bufferSeconds = 60
        $expiryThreshold = $expiresOn.AddSeconds(-$bufferSeconds)

        return (Get-Date) -gt $expiryThreshold
    }
    catch {
        return $true
    }
}

function _RefreshOAuthToken {
    <# .SYNOPSIS Request new OAuth2 token from Azure AD #>
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret,
        [int]$TimeoutSeconds = 30,
        [int]$MaxRetries = 3
    )

    $attempt = 0

    while ($attempt -lt $MaxRetries) {
        $attempt++
        try {
            $tokenUri = $OAUTH_TOKEN_ENDPOINT -f $TenantId

            $body = @{
                client_id     = $ClientId
                client_secret = $ClientSecret
                scope         = $GRAPH_API_SCOPE
                grant_type    = "client_credentials"
            }

            $response = Invoke-SecureWebRequest -Uri $tokenUri -Method POST -Body $body `
                -Headers @{ "Content-Type" = "application/x-www-form-urlencoded" } `
                -TimeoutSeconds $TimeoutSeconds

            $token = $response.Content | ConvertFrom-Json
            $unixEpoch = [DateTime]'1970-01-01'
            $expiresOn = [int]([DateTime]::UtcNow - $unixEpoch).TotalSeconds + $token.expires_in
            $token | Add-Member -NotePropertyName expires_on -NotePropertyValue $expiresOn -Force

            return $token
        }
        catch {
            $waitSeconds = [Math]::Pow(2, $attempt - 1)
            $errorMsg = $_.Exception.Message
            $sanitizedError = Protect-OAuthError -ErrorMessage $errorMsg

            if ($attempt -lt $MaxRetries) {
                Write-Log -Level WARN -Message "OAuth2 token refresh failed, retrying" `
                    -Context @{ attempt = $attempt; max_retries = $MaxRetries; wait_seconds = $waitSeconds; error = $sanitizedError }
                Start-Sleep -Seconds $waitSeconds
            }
            else {
                Write-Log -Level ERROR -Message "OAuth2 token refresh failed on last attempt" `
                    -Context @{ attempt = $attempt; error = $sanitizedError }
            }
        }
    }

    Write-Log -Level ERROR -Message "OAuth2 token refresh failed after all retries" `
        -Context @{ max_retries = $MaxRetries }
    return $null
}

function _GetAlertEmoji {
    <# .SYNOPSIS Get emoji for alert type #>
    param([string]$AlertReason)

    switch ($AlertReason) {
        'NEW' { return '[NEW]' }
        'AVAILABILITY_REDUCED' { return '[REDUCED]' }
        'SOLD_OUT' { return '[SOLD_OUT]' }
        default { return '[ALERT]' }
    }
}

function _GetAlertColor {
    <# .SYNOPSIS Get color hex for alert type #>
    param([string]$AlertReason)

    switch ($AlertReason) {
        'NEW' { return '#10b981' }
        'AVAILABILITY_REDUCED' { return '#f59e0b' }
        'SOLD_OUT' { return '#ef4444' }
        default { return '#3b82f6' }
    }
}

function _BuildEmailBody {
    <# .SYNOPSIS Build HTML email body from alerts #>
    param([object[]]$Alerts)

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #1a1a1a; line-height: 1.6; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .header p { margin: 10px 0 0 0; opacity: 0.9; font-size: 14px; }
        .alert-group { background: #f9fafb; border-left: 4px solid; margin: 20px 0; padding: 15px; border-radius: 4px; }
        .alert-group.new { border-left-color: #10b981; background: #f0fdf4; }
        .alert-group.reduced { border-left-color: #f59e0b; background: #fffbeb; }
        .alert-group.sold_out { border-left-color: #ef4444; background: #fef2f2; }
        .alert-group-title { font-weight: 600; margin-bottom: 12px; font-size: 14px; }
        .alert-group.new .alert-group-title { color: #10b981; }
        .alert-group.reduced .alert-group-title { color: #f59e0b; }
        .alert-group.sold_out .alert-group-title { color: #ef4444; }
        .course { background: white; padding: 12px; margin: 8px 0; border-radius: 4px; border: 1px solid #e5e7eb; }
        .course-name { font-weight: 600; color: #1a1a1a; margin: 0 0 6px 0; }
        .course-detail { font-size: 13px; color: #666; margin: 4px 0; }
        .course-link { display: inline-block; margin-top: 8px; padding: 8px 16px; background: #3b82f6; color: white; text-decoration: none; border-radius: 4px; font-size: 13px; }
        .course-link:hover { background: #2563eb; }
        .footer { text-align: center; color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>IPSC Kurs Watcher</h1>
            <p>Neue Kurse und Verf&uuml;gbarkeits&auml;nderungen</p>
        </div>
"@

    # Group alerts by reason
    $grouped = $Alerts | Group-Object -Property alert_reason

    foreach ($group in $grouped) {
        $reason = $group.Name
        $cssClass = switch ($reason) {
            'NEW' { 'new' }
            'AVAILABILITY_REDUCED' { 'reduced' }
            'SOLD_OUT' { 'sold_out' }
            default { 'new' }
        }

        $title = switch ($reason) {
            'NEW' { 'Neue Kurse' }
            'AVAILABILITY_REDUCED' { 'Verf&uuml;gbarkeit reduziert' }
            'SOLD_OUT' { 'Ausgebucht' }
            default { 'Kurse' }
        }

        $html += @"
        <div class="alert-group $cssClass">
            <div class="alert-group-title">$title ($($group.Count))</div>
"@

        foreach ($alert in $group.Group) {
            $html += @"
            <div class="course">
                <div class="course-name">$([System.Web.HttpUtility]::HtmlEncode($alert.name))</div>
                <div class="course-detail">Datum: $([System.Web.HttpUtility]::HtmlEncode($alert.date)) | Zeit: $([System.Web.HttpUtility]::HtmlEncode($alert.time))</div>
                <div class="course-detail">Verf&uuml;gbarkeit: $($alert.availability) Pl&auml;tze | Preis: $([System.Web.HttpUtility]::HtmlEncode($alert.price))</div>
                <a href="$([System.Web.HttpUtility]::HtmlEncode($alert.url))" class="course-link">Kurs anschauen</a>
            </div>
"@
        }

        $html += @"
        </div>
"@
    }

    $html += @"
        <div class="footer">
            <p>IPSC Kurs Watcher | shooting-store.ch</p>
            <p>Diese Benachrichtigung wurde automatisch generiert.</p>
        </div>
    </div>
</body>
</html>
"@

    return $html
}

function _SendMailViaGraph {
    <# .SYNOPSIS Send email via Microsoft Graph API #>
    param(
        [string]$AccessToken,
        [string]$UserId,
        [string[]]$Recipients,
        [string]$Subject,
        [string]$HtmlBody,
        [int]$TimeoutSeconds = 30,
        [int]$MaxRetries = 3
    )

    $attempt = 0

    while ($attempt -lt $MaxRetries) {
        try {
            $attempt++

            $recipientList = @()
            foreach ($recipient in $Recipients) {
                $recipientList += @{
                    emailAddress = @{ address = $recipient }
                }
            }

            $payload = @{
                message = @{
                    subject      = $Subject
                    body         = @{
                        contentType = "HTML"
                        content     = $HtmlBody
                    }
                    toRecipients = $recipientList
                }
            }

            $headers = @{
                Authorization  = "Bearer $AccessToken"
                "Content-Type"  = "application/json; charset=utf-8"
            }

            $jsonBody = $payload | ConvertTo-Json -Depth 10
            $jsonBodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)

            $sendMailUri = "https://graph.microsoft.com/v1.0/users/$UserId/sendMail"

            if (-not (Test-ValidUrl -Url $sendMailUri)) {
                Write-Log -Level ERROR -Message "Invalid sendMail URI detected" -Context @{ uri = $sendMailUri }
                return $false
            }

            Invoke-SecureWebRequest -Uri $sendMailUri -Method POST `
                -Headers $headers -Body $jsonBodyBytes `
                -TimeoutSeconds $TimeoutSeconds | Out-Null

            Write-Log -Level INFO -Message "Email sent successfully" `
                -Context @{ recipients = $Recipients.Count }
            return $true
        }
        catch {
            $waitSeconds = [Math]::Pow(2, $attempt - 1)

            if ($attempt -lt $MaxRetries) {
                Write-Log -Level WARN -Message "Email send failed, retrying" `
                    -Context @{ attempt = $attempt; max_retries = $MaxRetries; wait_seconds = $waitSeconds; error = $_.Exception.Message }
                Start-Sleep -Seconds $waitSeconds
            }
            else {
                Write-Log -Level ERROR -Message "Email send failed after all retries" `
                    -Context @{ max_retries = $MaxRetries; error = $_.Exception.Message }
            }
        }
    }

    return $false
}

# ============================================================================
# PUBLIC FUNCTIONS
# ============================================================================

function Get-AzureOAuthToken {
    <#
    .SYNOPSIS
    Get valid OAuth2 token for Microsoft Graph API.

    .DESCRIPTION
    Returns cached token if valid, otherwise refreshes from Azure AD.
    Implements automatic refresh, caching, and retry logic.

    .PARAMETER TenantId
    Azure AD Tenant ID

    .PARAMETER ClientId
    Azure AD Application (Client) ID

    .PARAMETER ClientSecret
    Azure AD Client Secret (from Credential Store)

    .PARAMETER CachePath
    Path to token cache file (default: data/.token_cache.json)

    .PARAMETER TimeoutSeconds
    Request timeout in seconds (default: 30)

    .EXAMPLE
    $token = Get-AzureOAuthToken -TenantId "..." -ClientId "..." -ClientSecret "..."
    if ($token) {
        $authHeader = @{ Authorization = "Bearer $($token.access_token)" }
    }

    .OUTPUTS
    PSObject with access_token, expires_on, or $null on failure
    #>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()][string]$TenantId,
        [ValidateNotNullOrEmpty()][string]$ClientId,
        [ValidateNotNullOrEmpty()][string]$ClientSecret,
        [ValidateNotNullOrEmpty()][string]$CachePath = "data/.token_cache.json",
        [ValidateRange(1, 600)][int]$TimeoutSeconds = 30
    )

    try {
        # Try to load cached token
        $cached = _LoadTokenCache -CachePath $CachePath

        if ($cached -and -not (_IsTokenExpired -Token $cached)) {
            Write-Log -Level DEBUG -Message "Using cached OAuth2 token"
            return $cached
        }

        # Refresh token
        Write-Log -Level INFO -Message "Refreshing OAuth2 token"
        $newToken = _RefreshOAuthToken -TenantId $TenantId -ClientId $ClientId `
            -ClientSecret $ClientSecret -TimeoutSeconds $TimeoutSeconds

        if ($newToken) {
            _SaveTokenCache -Token $newToken -CachePath $CachePath
            return $newToken
        }

        return $null
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to get OAuth2 token" -Exception $_
        throw
    }
}

function Send-EmailNotification {
    <#
    .SYNOPSIS
    Send email notifications for course alerts via Microsoft Graph API.

    .PARAMETER Alerts
    Array of alert objects with alert_reason (NEW, AVAILABILITY_REDUCED, SOLD_OUT)

    .PARAMETER Config
    Email configuration from config.json

    .EXAMPLE
    Send-EmailNotification -Alerts $alerts -Config $config.notifiers.email

    .OUTPUTS
    None
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([ValidateNotNull()][object[]]$Alerts, [ValidateNotNull()][object]$Config)

    if (-not $Config.enabled) {
        return
    }

    if (-not $Alerts -or $Alerts.Count -eq 0) {
        return
    }

    if (-not $PSCmdlet.ShouldProcess("email recipients", "Send $($Alerts.Count) course alerts")) {
        return
    }

    try {
        # Get Azure credentials from environment variables
        $tenantId = $env:IPSC_AZURE_TENANT_ID
        $clientId = $env:IPSC_AZURE_CLIENT_ID
        $senderEmail = $env:IPSC_EMAIL_SENDER
        $recipientEmailsStr = $env:IPSC_EMAIL_RECIPIENTS
        $credStorePath = $env:IPSC_CREDENTIAL_STORE_PATH

        # Validate required environment variables
        if (-not $tenantId -or -not $clientId) {
            Write-Log -Level WARN -Message "Email notifier disabled: missing IPSC_AZURE_TENANT_ID or IPSC_AZURE_CLIENT_ID environment variables"
            return
        }

        if (-not $senderEmail) {
            Write-Log -Level WARN -Message "Email notifier disabled: missing IPSC_EMAIL_SENDER environment variable"
            return
        }

        if (-not $recipientEmailsStr) {
            Write-Log -Level WARN -Message "Email notifier disabled: missing IPSC_EMAIL_RECIPIENTS environment variable"
            return
        }

        # Get credentials from encrypted credential store
        if (-not $credStorePath) {
            $credStorePath = "$env:APPDATA\IPSC-Kurs-Watcher\credentials"
        }

        $clientSecret = _GetCredentialFromStore -StorePath $credStorePath
        if (-not $clientSecret) {
            Write-Log -Level ERROR -Message "Email notifier failed: could not load Client Secret from credential store at $credStorePath"
            return
        }

        # Get OAuth2 token
        $cacheDir = if ([System.IO.Path]::IsPathRooted($Config.token_cache_path)) {
            $Config.token_cache_path
        }
        else {
            Join-Path (Get-Location) $Config.token_cache_path
        }

        $token = Get-AzureOAuthToken -TenantId $tenantId -ClientId $clientId `
            -ClientSecret $clientSecret -CachePath $cacheDir -TimeoutSeconds $Config.timeout_seconds

        if (-not $token -or -not $token.access_token) {
            Write-Log -Level ERROR -Message "Email notifier failed: could not obtain OAuth2 token"
            return
        }

        # Build email
        $htmlBody = _BuildEmailBody -Alerts $Alerts

        # Create subject with proper UTF-8 encoding for special characters (ü=252, ä=228)
        $subject = "IPSC Kurs Watcher - Neue Kurse und Verf" + [char]252 + "gbarkeits" + [char]228 + "nderungen"

        # Parse recipient emails (comma-separated list supported)
        $recipients = @($recipientEmailsStr -split ',').Trim() | Where-Object { $_ }

        # Send email with retry logic (senderEmail is the mailbox account for sendMail)
        $sent = _SendMailViaGraph -AccessToken $token.access_token -UserId $senderEmail `
            -Recipients $recipients -Subject $subject -HtmlBody $htmlBody `
            -TimeoutSeconds $Config.timeout_seconds -MaxRetries $Config.retry_attempts

        if ($sent) {
            Write-Log -Level INFO -Message "Email notification sent" `
                -Context @{ alert_count = $Alerts.Count; recipient_count = $recipients.Count; recipients = ($recipients -join ';') }
        }
    }
    catch {
        Write-Log -Level WARN -Message "Email notification failed" -Exception $_
    }
}

