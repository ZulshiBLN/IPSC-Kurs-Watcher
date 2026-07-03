#Requires -Version 5.1

<#
.SYNOPSIS
Modular IPSC Kurs Watcher scheduler and orchestrator.

.DESCRIPTION
Coordinates all monitoring, filtering, deduplication, and notification tasks.
Loads configuration and modules, then orchestrates the monitoring cycle.

.PARAMETER ConfigPath
Path to config.json (default: config/config.json)

.PARAMETER RunOnce
Run single monitoring cycle and exit (for testing)

.PARAMETER CheckInterval
Polling interval in minutes (overrides config value)

.EXAMPLE
.\Scheduler.ps1 -RunOnce
.\Scheduler.ps1 -CheckInterval 15
#>

param(
    [string]$ConfigPath = 'config/config.json',
    [switch]$RunOnce,
    [int]$CheckInterval = 0
)

$ErrorActionPreference = 'Continue'

# ============================================================================
# MODULE LOADING (strict order, no circular deps)
# ============================================================================

$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Loading modules..."

try {
    # Core modules (no dependencies)
    . (Join-Path $ScriptRoot 'src/core/Helpers.ps1')
    . (Join-Path $ScriptRoot 'src/core/Logging.ps1')
    . (Join-Path $ScriptRoot 'src/core/Config.ps1')
    . (Join-Path $ScriptRoot 'src/core/State.ps1')

    # Initialize logging
    Initialize-Logging -LogDir 'data/logs' -LogLevel 'INFO' -Format 'json' -RetentionDays 30

    Write-Log -Level INFO -Message "Core modules loaded"

    # Monitor modules
    . (Join-Path $ScriptRoot 'src/monitors/MonitorBase.ps1')
    . (Join-Path $ScriptRoot 'src/monitors/CourseMonitor.ps1')
    . (Join-Path $ScriptRoot 'src/monitors/MonitorFactory.ps1')

    Write-Log -Level INFO -Message "Monitor modules loaded"

    # Filter modules
    . (Join-Path $ScriptRoot 'src/filters/FilterByType.ps1')
    . (Join-Path $ScriptRoot 'src/filters/FilterByExclusion.ps1')
    . (Join-Path $ScriptRoot 'src/filters/FilterPipeline.ps1')

    Write-Log -Level INFO -Message "Filter modules loaded"

    # Notifier modules
    . (Join-Path $ScriptRoot 'src/notifiers/NotifyEmail.ps1')
    . (Join-Path $ScriptRoot 'src/notifiers/NotifyDiscord.ps1')
    . (Join-Path $ScriptRoot 'src/notifiers/NotifyToast.ps1')

    Write-Log -Level INFO -Message "Notifier modules loaded"
}
catch {
    Write-Host "[ERROR] Module loading failed: $_" -ForegroundColor Red
    exit 1
}

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

$config = $null
$state = $null

try {
    # Resolve config path
    if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
        $ConfigPath = Join-Path $ScriptRoot $ConfigPath
    }

    $config = Get-Config -ConfigPath $ConfigPath
    Write-Log -Level INFO -Message "Configuration loaded" `
        -Context @{ monitors = $config.monitors.Count }

    # Load state
    $stateFile = if ([System.IO.Path]::IsPathRooted($config.state.file_path)) {
        $config.state.file_path
    }
    else {
        Join-Path $ScriptRoot $config.state.file_path
    }

    $state = Get-State -StateFile $stateFile
    Write-Log -Level INFO -Message "State loaded" `
        -Context @{ known_courses = $state.last_notified.Count }
}
catch {
    Write-Log -Level ERROR -Message "Configuration or state loading failed" -Exception $_
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================================
# MONITORING CYCLE FUNCTION
# ============================================================================

function Invoke-MonitoringCycle {
    <#
    .SYNOPSIS
    Execute one complete monitoring cycle.
    #>

    $cycleStart = Get-Date

    Write-Log -Level INFO -Message "Monitoring cycle starting" `
        -Context @{ monitors = $config.monitors.Count }

    $cycleAlerts = @{ new = @(); reduced = @(); sold_out = @() }

    foreach ($monitorConfig in $config.monitors) {
        if (-not $monitorConfig.enabled) {
            Write-Log -Level DEBUG -Message "Monitor disabled, skipping" `
                -Context @{ id = $monitorConfig.id }
            continue
        }

        try {
            Write-Log -Level INFO -Message "Monitor executing" `
                -Context @{ id = $monitorConfig.id; provider = $monitorConfig.provider }

            # Create and invoke monitor
            $monitor = Get-Monitor -Config $monitorConfig
            if ($null -eq $monitor) { throw "Monitor factory returned null" }
            $currentCourses = $monitor.Invoke()

            if ($currentCourses.Count -eq 0) {
                Write-Log -Level WARN -Message "Monitor returned no courses" `
                    -Context @{ id = $monitorConfig.id }
                continue
            }

            Write-Log -Level INFO -Message "Courses fetched" `
                -Context @{ monitor = $monitorConfig.id; count = $currentCourses.Count }

            # Merge current courses with state (detects changes)
            $mergeResult = Update-StateWithCourses -State $state -CurrentCourses $currentCourses
            $state = $mergeResult.state
            $alerts = $mergeResult.alerts

            # Log alerts by type
            if ($alerts.new.Count -gt 0) {
                Write-Log -Level INFO -Message "New courses detected" `
                    -Context @{ monitor = $monitorConfig.id; count = $alerts.new.Count }
                $cycleAlerts.new += $alerts.new
            }

            if ($alerts.reduced.Count -gt 0) {
                Write-Log -Level INFO -Message "Availability reduced" `
                    -Context @{ monitor = $monitorConfig.id; count = $alerts.reduced.Count }
                $cycleAlerts.reduced += $alerts.reduced
            }

            if ($alerts.sold_out.Count -gt 0) {
                $disappearedCount = @($alerts.sold_out | Where-Object { $_.disappeared }).Count
                Write-Log -Level INFO -Message "Courses sold out or disappeared" `
                    -Context @{ monitor = $monitorConfig.id; sold_out = $alerts.sold_out.Count; disappeared = $disappearedCount }
                $cycleAlerts.sold_out += $alerts.sold_out
            }
        }
        catch {
            $err = $_
            Write-Host "[ERROR] Monitor execution failed: $($err.Exception.Message)" -ForegroundColor Red
            if ($err.InvocationInfo) { Write-Host "  at $($err.InvocationInfo.ScriptName):$($err.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red }
        }
    }

    # Notify about alerts (all types)
    $totalAlerts = $cycleAlerts.new.Count + $cycleAlerts.reduced.Count + $cycleAlerts.sold_out.Count

    if ($totalAlerts -gt 0) {
        Write-Log -Level INFO -Message "Sending notifications" `
            -Context @{ new = $cycleAlerts.new.Count; reduced = $cycleAlerts.reduced.Count; sold_out = $cycleAlerts.sold_out.Count }

        # v0.1: Call notifier stubs with alert types
        if ($cycleAlerts.new.Count -gt 0) {
            Send-EmailNotification -Alerts $cycleAlerts.new -Config $config.notifiers.email
        }
        if ($cycleAlerts.reduced.Count -gt 0) {
            Send-EmailNotification -Alerts $cycleAlerts.reduced -Config $config.notifiers.email
        }
        if ($cycleAlerts.sold_out.Count -gt 0) {
            Send-EmailNotification -Alerts $cycleAlerts.sold_out -Config $config.notifiers.email
        }

        # Same for Discord and Toast
        if ($cycleAlerts.new.Count -gt 0) {
            Send-DiscordNotification -Alerts $cycleAlerts.new -Config $config.notifiers.discord
        }
        if ($cycleAlerts.reduced.Count -gt 0) {
            Send-DiscordNotification -Alerts $cycleAlerts.reduced -Config $config.notifiers.discord
        }
        if ($cycleAlerts.sold_out.Count -gt 0) {
            Send-DiscordNotification -Alerts $cycleAlerts.sold_out -Config $config.notifiers.discord
        }

        if ($cycleAlerts.new.Count -gt 0) {
            Send-ToastNotification -Alerts $cycleAlerts.new -Config $config.notifiers.windows_toast
        }
        if ($cycleAlerts.reduced.Count -gt 0) {
            Send-ToastNotification -Alerts $cycleAlerts.reduced -Config $config.notifiers.windows_toast
        }
        if ($cycleAlerts.sold_out.Count -gt 0) {
            Send-ToastNotification -Alerts $cycleAlerts.sold_out -Config $config.notifiers.windows_toast
        }
    }
    else {
        Write-Log -Level INFO -Message "No alerts to notify" `
            -Context @{ total_tracked = $state.last_notified.Count }
    }

    # Save updated state
    try {
        Save-State -State $state -StateFile $stateFile
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to save state" -Exception $_
    }

    $cycleDuration = ((Get-Date) - $cycleStart).TotalMilliseconds

    Write-Log -Level INFO -Message "Monitoring cycle completed" `
        -Context @{
            total_tracked = $state.last_notified.Count
            new = $cycleAlerts.new.Count
            reduced = $cycleAlerts.reduced.Count
            sold_out = $cycleAlerts.sold_out.Count
            duration_ms = $cycleDuration
        }

    return @{
        timestamp = $cycleStart.ToString('o')
        new = $cycleAlerts.new.Count
        reduced = $cycleAlerts.reduced.Count
        sold_out = $cycleAlerts.sold_out.Count
        total_tracked = $state.last_notified.Count
        duration_ms = $cycleDuration
    }
}

# ============================================================================
# MAIN LOOP
# ============================================================================

Write-Log -Level INFO -Message "Scheduler started" `
    -Context @{ mode = if ($RunOnce) { 'RunOnce' } else { 'Continuous' } }

if ($RunOnce) {
    # Single run mode (for testing)
    Invoke-MonitoringCycle | Out-Null
    Write-Log -Level INFO -Message "Single run completed, exiting"
    exit 0
}
else {
    # Continuous mode (production)
    if ($CheckInterval -gt 0) {
        $interval = $CheckInterval
    }
    elseif ($config.monitors[0].poll_interval_minutes) {
        $interval = $config.monitors[0].poll_interval_minutes
    }
    else {
        $interval = 30
    }

    Write-Log -Level INFO -Message "Continuous monitoring started" `
        -Context @{ interval_minutes = $interval }

    while ($true) {
        try {
            Invoke-MonitoringCycle | Out-Null
        }
        catch {
            Write-Log -Level ERROR -Message "Monitoring cycle failed" -Exception $_
        }

        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Sleeping for $interval minutes..."
        Start-Sleep -Seconds ($interval * 60)
    }
}
