#Requires -Version 5.1

function Test-ToastSupported {
    <#
    .SYNOPSIS
    Check if Windows 10+ with Toast support is available.

    .OUTPUTS
    Boolean - $true if Toast API available, $false otherwise
    #>
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

function Group-AlertsByType {
    <#
    .SYNOPSIS
    Group alerts by alert_reason and add metadata (icon, color, description).

    .PARAMETER Alerts
    Array of alert objects with alert_reason property

    .OUTPUTS
    Array of grouped alert objects with properties:
      - AlertType: Enum value (NEW_COURSE, AVAILABILITY_REDUCED, SOLD_OUT)
      - Emoji: Visual emoji (🟢, 🟡, 🔴)
      - Color: Hex color code
      - Count: Number of alerts in group
      - Alerts: Array of alert objects in group
    #>
    param([object[]]$Alerts)

    $alertTypeMap = @{
        'NEW_COURSE' = @{
            Emoji = '🟢'
            Color = '0x00FF00'
            Description = 'NEW COURSES'
        }
        'AVAILABILITY_REDUCED' = @{
            Emoji = '🟡'
            Color = '0xFFFF00'
            Description = 'AVAILABILITY REDUCED'
        }
        'SOLD_OUT' = @{
            Emoji = '🔴'
            Color = '0xFF0000'
            Description = 'SOLD OUT'
        }
    }

    $groups = $Alerts | Group-Object -Property alert_reason

    $result = @()
    foreach ($group in $groups) {
        $metadata = $alertTypeMap[$group.Name]
        if ($metadata) {
            $result += @{
                AlertType = $group.Name
                Emoji = $metadata.Emoji
                Color = $metadata.Color
                Description = $metadata.Description
                Count = $group.Count
                Alerts = @($group.Group)
            }
        }
    }

    return $result
}

function _NewToastTitle {
    param([object]$AlertGroup)

    return "$($AlertGroup.Emoji) $($AlertGroup.Description) ($($AlertGroup.Count))"
}

function _NewToastBody {
    param([object]$AlertGroup, [int]$MaxCourses = 5)

    $courses = @($AlertGroup.Alerts | Select-Object -First $MaxCourses)
    $lines = @()

    foreach ($course in $courses) {
        $line = "$($course.name) ($($course.time), $($course.availability) spots)"
        $lines += $line
    }

    if ($AlertGroup.Alerts.Count -gt $MaxCourses) {
        $lines += "+$($AlertGroup.Alerts.Count - $MaxCourses) more..."
    }

    return $lines -join ' | '
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
    $bodyWithUrl = [System.Security.SecurityElement]::Escape("$Body`n`nURL: $ActionUrl")

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

function _InvokeToastAction {
    <#
    .SYNOPSIS
    Open URL in default browser (handles Toast click action).

    .PARAMETER MainPageUrl
    URL to open in browser
    #>
    param([string]$MainPageUrl)

    try {
        if ([string]::IsNullOrWhiteSpace($MainPageUrl)) {
            return
        }

        Start-Process $MainPageUrl -ErrorAction Stop
    }
    catch {
        Write-Log -Level WARN -Message "Failed to open Toast action URL" `
            -Context @{ url = $MainPageUrl } -Exception $_
    }
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

        $appId = 'Microsoft.PowerShell_31bf3856ad364e35_15.1.0.0_x64__8wekyb3d8bbwe'

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
    Send Windows Toast notifications for course alerts.

    .DESCRIPTION
    Groups alerts by type (NEW, REDUCED, SOLD_OUT) and sends Windows Toast notification.
    Groups are displayed as separate Toasts. Clicking opens main course page.

    .PARAMETER Alerts
    Array of alert objects with alert_reason, name, time, availability properties

    .PARAMETER Config
    Toast notification configuration object with properties:
      - enabled: Boolean
      - sound_enabled: Boolean
      - group_by_type: Boolean
      - max_courses_per_group: Integer
      - auto_dismiss_seconds: Integer
      - main_page_url: String (URL to open on click)

    .EXAMPLE
    $alerts = @(
        @{ alert_reason = 'NEW_COURSE'; name = 'Basic 2.0'; time = '19:00'; availability = 3 }
    )
    $config = @{ enabled = $true; sound_enabled = $true; ... }
    Send-ToastNotification -Alerts $alerts -Config $config
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][object[]]$Alerts,
        [Parameter(Mandatory)][object]$Config
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
            $groupedAlerts = Group-AlertsByType -Alerts $Alerts
            $toastCount = 0
            $failureCount = 0

            foreach ($group in $groupedAlerts) {
                try {
                    $title = _NewToastTitle -AlertGroup $group
                    $body = _NewToastBody -AlertGroup $group -MaxCourses $Config.max_courses_per_group

                    $toastXml = _NewToastXML -Title $title `
                                           -Body $body `
                                           -ActionUrl $Config.main_page_url `
                                           -SoundEnabled $Config.sound_enabled

                    $sendSuccess = _SendToastViaWinRT -ToastXml $toastXml

                    if ($sendSuccess) {
                        Write-Log -Level INFO -Message "Toast notification sent" `
                            -Context @{
                                alert_type = $group.AlertType
                                count = $group.Count
                                title = $title
                            }
                        $toastCount++
                    }
                    else {
                        $failureCount++
                    }
                }
                catch {
                    Write-Log -Level WARN -Message "Failed to create Toast for $($group.AlertType)" `
                        -Context @{ count = $group.Count } -Exception $_
                    $failureCount++
                }
            }

            Write-Log -Level INFO -Message "Toast notifications completed" `
                -Context @{
                    total_alerts = $Alerts.Count
                    groups = $groupedAlerts.Count
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
