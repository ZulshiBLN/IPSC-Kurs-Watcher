#Requires -Version 5.1

<#
.SYNOPSIS
    Notification pipeline orchestrator
.DESCRIPTION
    Orchestrates sending notifications through enabled channels (Email, Discord, Toast)
.NOTES
    Handles parallel notification sending with error isolation
#>

. "$PSScriptRoot/NotifyEmail.ps1"
. "$PSScriptRoot/NotifyDiscord.ps1"
. "$PSScriptRoot/NotifyToast.ps1"

function Invoke-NotificationPipeline {
    <#
    .SYNOPSIS
        Send notifications through all enabled channels
    .PARAMETER Courses
        Array of courses to notify about
    .PARAMETER Config
        Configuration object with notifiers section
    .PARAMETER MonitorName
        Name of the monitor source
    .EXAMPLE
        $results = Invoke-NotificationPipeline -Courses $courses -Config $config -MonitorName "shooting-store"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Courses,

        [Parameter(Mandatory)]
        [hashtable]$Config,

        [string]$MonitorName = "IPSC Kurs Watcher"
    )

    if ($Courses.Count -eq 0) {
        Write-Verbose "No courses to notify"
        return @{
            total_courses = 0
            email = "skipped"
            discord = "skipped"
            toast = "skipped"
            success = $true
        }
    }

    Write-Verbose "Starting notification pipeline for $($Courses.Count) course(s)"

    $results = @{
        total_courses = $Courses.Count
        email = "disabled"
        discord = "disabled"
        toast = "disabled"
        success = $true
        enabled_channels = @()
    }

    # Email Notification
    if ($Config.notifiers.email.enabled) {
        try {
            $emailNotifier = New-EmailNotifier -Config $Config.notifiers.email
            $emailResult = Send-EmailNotification -Courses $Courses -Notifier $emailNotifier -MonitorName $MonitorName

            $results.email = if ($emailResult) { "sent" } else { "failed" }
            if (-not $emailResult) {
                $results.success = $false
            }
            $results.enabled_channels += "email"

            Write-Verbose "Email notification: $($results.email)"
        } catch {
            Write-Error "Email notifier error: $_"
            $results.email = "error"
            $results.success = $false
        }
    }

    # Discord Notification
    if ($Config.notifiers.discord.enabled) {
        try {
            $discordNotifier = New-DiscordNotifier -Config $Config.notifiers.discord
            $discordResult = Send-DiscordNotification -Courses $Courses -Notifier $discordNotifier -MonitorName $MonitorName

            $results.discord = if ($discordResult) { "sent" } else { "failed" }
            if (-not $discordResult) {
                $results.success = $false
            }
            $results.enabled_channels += "discord"

            Write-Verbose "Discord notification: $($results.discord)"
        } catch {
            Write-Error "Discord notifier error: $_"
            $results.discord = "error"
            $results.success = $false
        }
    }

    # Toast Notification
    if ($Config.notifiers.windows_toast.enabled) {
        try {
            $toastNotifier = New-ToastNotifier -Config $Config.notifiers.windows_toast
            $toastResult = Send-ToastNotification -Courses $Courses -Notifier $toastNotifier -MonitorName $MonitorName

            $results.toast = if ($toastResult) { "sent" } else { "failed" }
            if (-not $toastResult) {
                $results.success = $false
            }
            $results.enabled_channels += "toast"

            Write-Verbose "Toast notification: $($results.toast)"
        } catch {
            Write-Error "Toast notifier error: $_"
            $results.toast = "error"
            $results.success = $false
        }
    }

    Write-Verbose "Notification pipeline complete - Channels: $($results.enabled_channels -join ', ')"

    return $results
}

function Test-AllNotifiers {
    <#
    .SYNOPSIS
        Test all enabled notifiers
    .PARAMETER Config
        Configuration object with notifiers section
    .RETURNS
        Hashtable with test results for each notifier
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $testResults = @{
        email = "disabled"
        discord = "disabled"
        toast = "disabled"
        all_ok = $true
    }

    # Test Email
    if ($Config.notifiers.email.enabled) {
        try {
            $emailNotifier = New-EmailNotifier -Config $Config.notifiers.email
            $testResults.email = if (Test-EmailConnection -Notifier $emailNotifier) { "ok" } else { "failed" }
            if ($testResults.email -eq "failed") {
                $testResults.all_ok = $false
            }
        } catch {
            Write-Error "Email test failed: $_"
            $testResults.email = "error"
            $testResults.all_ok = $false
        }
    }

    # Test Discord
    if ($Config.notifiers.discord.enabled) {
        try {
            $discordNotifier = New-DiscordNotifier -Config $Config.notifiers.discord
            $testResults.discord = if (Test-DiscordConnection -Notifier $discordNotifier) { "ok" } else { "failed" }
            if ($testResults.discord -eq "failed") {
                $testResults.all_ok = $false
            }
        } catch {
            Write-Error "Discord test failed: $_"
            $testResults.discord = "error"
            $testResults.all_ok = $false
        }
    }

    # Toast doesn't need testing (WinRT check done in New-ToastNotifier)
    if ($Config.notifiers.windows_toast.enabled) {
        try {
            New-ToastNotifier -Config $Config.notifiers.windows_toast | Out-Null
            $testResults.toast = "ok"
        } catch {
            Write-Error "Toast setup failed: $_"
            $testResults.toast = "error"
            $testResults.all_ok = $false
        }
    }

    return $testResults
}
