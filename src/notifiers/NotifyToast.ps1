#Requires -Version 5.1

function Test-ToastSupported {
    <#
    .SYNOPSIS
    Check if Windows 10+ with Toast support is available.

    .OUTPUTS
    Boolean - $true if Toast API available, $false otherwise
    #>
    try {
        $osVersion = [System.Environment]::OSVersion.Version
        if ($osVersion.Major -lt 10) {
            Write-Log -Level WARN -Message "Toast not supported on Windows < 10" `
                -Context @{ version = "$($osVersion.Major).$($osVersion.Minor)" }
            return $false
        }

        [void] [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
        return $true
    }
    catch {
        Write-Log -Level WARN -Message "Toast API not available" `
            -Context @{ error = $_.Exception.Message }
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
            foreach ($group in $groupedAlerts) {
                try {
                    $title = _NewToastTitle -AlertGroup $group
                    $body = _NewToastBody -AlertGroup $group -MaxCourses $Config.max_courses_per_group

                    Write-Log -Level INFO -Message "Toast notification" `
                        -Context @{
                            alert_type = $group.AlertType
                            count = $group.Count
                            title = $title
                            body = $body
                        }

                    $toastCount++
                }
                catch {
                    Write-Log -Level WARN -Message "Failed to create Toast for $($group.AlertType)" `
                        -Context @{ count = $group.Count } -Exception $_
                }
            }

            Write-Log -Level INFO -Message "Toast notifications sent" `
                -Context @{ total_alerts = $Alerts.Count; groups = $groupedAlerts.Count; toasts_sent = $toastCount }
        }
        catch {
            Write-Log -Level ERROR -Message "Toast notification failed" `
                -Context @{ alert_count = $Alerts.Count } -Exception $_
        }
    }
}
