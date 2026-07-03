#Requires -Version 5.1

<#
.SYNOPSIS
    Windows Toast notification module
.DESCRIPTION
    Sends course notifications as Windows Toast notifications (native Windows notifications)
.NOTES
    Requires Windows 10+ and uses WinRT APIs
#>

function New-ToastNotifier {
    <#
    .SYNOPSIS
        Create Toast notifier instance
    .PARAMETER Config
        Toast configuration from config.json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $Config.app_id = $Config.app_id ?? "IPSC.Kurs.Watcher"
    $Config.sound = $Config.sound ?? "Notification.Default"
    $Config.duration = $Config.duration ?? "long"

    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        throw "Windows Toast notifications require Windows 10 or later"
    }

    return $Config
}

function Send-ToastNotification {
    <#
    .SYNOPSIS
        Send Windows Toast notification
    .PARAMETER Courses
        Array of courses to notify about
    .PARAMETER Notifier
        Toast notifier configuration
    .PARAMETER MonitorName
        Name of the monitor source
    .EXAMPLE
        Send-ToastNotification -Courses $newCourses -Notifier $config.notifiers.windows_toast -MonitorName "shooting-store"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Courses,

        [Parameter(Mandatory)]
        [hashtable]$Notifier,

        [string]$MonitorName = "IPSC Kurs Watcher"
    )

    if ($Courses.Count -eq 0) {
        Write-Verbose "No courses to notify via Toast"
        return $true
    }

    if (-not $Notifier.enabled) {
        Write-Verbose "Toast notifier is disabled"
        return $true
    }

    try {
        # Load WinRT assemblies
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        # Build toast XML
        $toastXml = Build-ToastXml -Courses $Courses -MonitorName $MonitorName -Notifier $Notifier

        # Create and send toast
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($toastXml)

        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($Notifier.app_id).Show($toast)

        Write-Verbose "Toast notification sent successfully"
        return $true
    } catch {
        Write-Error "Failed to send Toast notification: $_"
        return $false
    }
}

function Build-ToastXml {
    <#
    .SYNOPSIS
        Build Toast XML payload
    .PARAMETER Courses
        Courses to include
    .PARAMETER MonitorName
        Monitor name
    .PARAMETER Notifier
        Notifier config (for sound, duration)
    #>
    [CmdletBinding()]
    param(
        [array]$Courses,
        [string]$MonitorName,
        [hashtable]$Notifier
    )

    # Build course summary (first 3 courses, then count if more)
    $courseSummary = @()
    for ($i = 0; $i -lt [Math]::Min(3, $Courses.Count); $i++) {
        $course = $Courses[$i]
        $courseSummary += "$($course.title) ($($course.type ?? 'N/A'))"
    }

    if ($Courses.Count -gt 3) {
        $courseSummary += "+$($Courses.Count - 3) weitere..."
    }

    $courseText = $courseSummary -join "`n"

    # Build XML
    $xml = @"
<toast duration="$($Notifier.duration)">
    <visual>
        <binding template="ToastText01">
            <text id="1">$($Courses.Count) neue Kurs(e) von $MonitorName</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Notification.Looping.Alarm" silent="false"/>
</toast>
"@

    return $xml
}
