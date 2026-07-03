#Requires -Version 5.1

function Test-ToastSupported {
    <#
    .SYNOPSIS
    Check if Windows 10+ with Toast support is available.

    .OUTPUTS
    Boolean - $true if Toast API available, $false otherwise
    #>
    [CmdletBinding()]
    param()

    if ([System.Environment]::OSVersion.Version.Major -lt 10) {
        return $false
    }

    try {
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        return $true
    }
    catch {
        return $false
    }
}

function _GetAlertEmoji {
    param([string]$AlertReason)

    switch ($AlertReason) {
        'NEW' { return '[NEW]' }
        'AVAILABILITY_REDUCED' { return '[REDUCED]' }
        'SOLD_OUT' { return '[SOLD_OUT]' }
        default { return '[ALERT]' }
    }
}

function _NewToastXML {
    <#
    .SYNOPSIS
    Build Windows Toast XML with title, body, sound, and action buttons.

    .PARAMETER Title
    Toast title text

    .PARAMETER Body
    Toast body text (with course details)

    .PARAMETER ActionUrl
    URL to display in body (included as text)

    .PARAMETER SoundEnabled
    Whether to play notification sound

    .OUTPUTS
    String - XML template for Toast notification
    #>
    param(
        [string]$Title,
        [string]$Body,
        [string]$ActionUrl,
        [bool]$SoundEnabled = $true
    )

    $escapedTitle = [System.Security.SecurityElement]::Escape($Title)
    $escapedUrl = [System.Security.SecurityElement]::Escape($ActionUrl)
    $bodyWithUrl = [System.Security.SecurityElement]::Escape("$Body`n`n$ActionUrl")

    $audio = if ($SoundEnabled) {
        '<audio src="ms-winsoundevent:Notification.Default"/>'
    } else {
        '<audio silent="true"/>'
    }

    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<toast>
  <visual>
    <binding template="ToastText02">
      <text id="1">$escapedTitle</text>
      <text id="2">$bodyWithUrl</text>
    </binding>
  </visual>
  $audio
  <actions>
    <action activationType="protocol" arguments="$escapedUrl" content="View Course"/>
    <action activationType="system" arguments="dismiss" content="Dismiss"/>
  </actions>
</toast>
"@

    return $xml
}


function _SendToastViaWinRT {
    <#
    .SYNOPSIS
    Send Toast via Windows.UI.Notifications WinRT API.

    .PARAMETER ToastXml
    XML template for Toast

    .OUTPUTS
    Boolean - $true if successful, $false if failed
    #>
    param([string]$ToastXml)

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($ToastXml)

        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml

        $appId = 'IPSC.KursMonitor'

        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)

        return $true
    }
    catch {
        Write-Log -Level WARN -Message "Failed to display Toast via WinRT" `
            -Context @{ error = $_.Exception.Message } -Exception $_
        return $false
    }
}

function Send-ToastNotification {
    <#
    .SYNOPSIS
    Send Windows Toast notifications for course alerts (one Toast per course).

    .DESCRIPTION
    Each alert (course) gets its own Toast notification with course-specific URL.
    Toast title includes alert emoji and course name. Body shows time, availability, price.

    .PARAMETER Alerts
    Array of alert objects with alert_reason, name, time, availability, price, url properties

    .PARAMETER Config
    Toast notification configuration object with properties:
      - enabled: Boolean
      - sound_enabled: Boolean
      - auto_dismiss_seconds: Integer

    .EXAMPLE
    $alerts = @(
        @{ alert_reason = 'NEW_COURSE'; name = 'Basic 2.0'; time = '09:30-13:00'; availability = 2; price = 'CHF 280.00'; url = 'https://...' }
    )
    $config = @{ enabled = $true; sound_enabled = $true }
    Send-ToastNotification -Alerts $alerts -Config $config
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][ValidateNotNull()][object[]]$Alerts,
        [Parameter(Mandatory)][ValidateNotNull()][object]$Config
    )

    if (-not $Config.enabled) { return }
    if (-not $Alerts -or $Alerts.Count -eq 0) { return }

    if (-not (Test-ToastSupported)) {
        Write-Log -Level WARN -Message "Toast notifications skipped (not supported)" `
            -Context @{ os = [System.Environment]::OSVersion.VersionString }
        return
    }

    if ($PSCmdlet.ShouldProcess("Toast notifications", "Send $($Alerts.Count) alerts")) {
        try {
            $toastCount = 0
            $failureCount = 0

            foreach ($alert in $Alerts) {
                try {
                    $emoji = _GetAlertEmoji -AlertReason $alert.alert_reason
                    $title = "$emoji $($alert.name) | $($alert.availability) Slots"
                    $body = "$($alert.date) | $($alert.time) | $($alert.price)"

                    $toastXml = _NewToastXML -Title $title `
                                           -Body $body `
                                           -ActionUrl $alert.url `
                                           -SoundEnabled $Config.sound_enabled

                    $sendSuccess = _SendToastViaWinRT -ToastXml $toastXml

                    if ($sendSuccess) {
                        Write-Log -Level INFO -Message "Toast notification sent" `
                            -Context @{
                                alert_type = $alert.alert_reason
                                course_name = $alert.name
                                title = $title
                            }
                        $toastCount++
                    }
                    else {
                        $failureCount++
                    }
                }
                catch {
                    Write-Log -Level WARN -Message "Failed to create Toast for $($alert.name)" `
                        -Context @{ alert_type = $alert.alert_reason } -Exception $_
                    $failureCount++
                }
            }

            Write-Log -Level INFO -Message "Toast notifications completed" `
                -Context @{
                    total_alerts = $Alerts.Count
                    sent = $toastCount
                    failed = $failureCount
                }
        }
        catch {
            Write-Log -Level ERROR -Message "Toast notification pipeline failed" `
                -Context @{ alert_count = $Alerts.Count } -Exception $_
        }
    }
}
