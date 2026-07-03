#Requires -Version 5.1

<#
.SYNOPSIS
    IPSC Kurs Watcher - Main orchestration script
.DESCRIPTION
    Central monitoring loop that orchestrates monitors, filters, and notifiers
.PARAMETER ConfigPath
    Path to configuration file (default: config/config.json)
.PARAMETER LoopCount
    Number of monitoring cycles to run (default: infinite loop)
.PARAMETER TestMode
    Run single cycle and exit (for testing)
.EXAMPLE
    .\Watcher.ps1 -ConfigPath "config/config.json"
    .\Watcher.ps1 -TestMode
.NOTES
    Runs as background service, handles graceful shutdown via SIGTERM
#>

param(
    [string]$ConfigPath = "config/config.json",
    [int]$LoopCount = 0,
    [switch]$TestMode
)

$ErrorActionPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'

# Global state
$script:Running = $true
$script:CycleCount = 0

# Setup graceful shutdown
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Write-Log "INFO" "Watcher received shutdown signal, cleaning up..."
    $script:Running = $false
}

# Import all modules
$ModuleRoot = Split-Path $MyInvocation.MyCommand.Path
$CorePath = Join-Path $ModuleRoot "src/core"
$MonitorsPath = Join-Path $ModuleRoot "src/monitors"
$FiltersPath = Join-Path $ModuleRoot "src/filters"
$NotifiersPath = Join-Path $ModuleRoot "src/notifiers"
$UtilsPath = Join-Path $ModuleRoot "src/utils"

. "$UtilsPath/Logging.ps1"
. "$CorePath/Config.ps1"
. "$CorePath/ConfigValidator.ps1"
. "$CorePath/State.ps1"
. "$MonitorsPath/MonitorFactory.ps1"
. "$FiltersPath/FilterPipeline.ps1"
. "$NotifiersPath/NotificationPipeline.ps1"

function Initialize-Watcher {
    <#
    .SYNOPSIS
        Initialize watcher environment
    .DESCRIPTION
        Setup logging, load config, initialize state
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath
    )

    Write-Host "IPSC Kurs Watcher - Initializing..."

    # Initialize logging
    Initialize-Logging -LogDirectory "data/logs"
    Write-Log "INFO" "Watcher started (PID: $PID)"

    # Load and validate configuration
    try {
        $config = Read-Config -Path $ConfigPath
        Write-Log "INFO" "Configuration loaded from: $ConfigPath"
    } catch {
        Write-Log "ERROR" "Failed to load configuration: $_"
        throw
    }

    # Validate configuration
    try {
        Test-Configuration -Config $config | Out-Null
        Write-Log "INFO" "Configuration validation passed"
    } catch {
        Write-Log "ERROR" "Configuration validation failed: $_"
        throw
    }

    # Initialize state
    try {
        Initialize-State -StateFile "data/state.json"
        Write-Log "INFO" "State initialized"
    } catch {
        Write-Log "ERROR" "Failed to initialize state: $_"
        throw
    }

    return $config
}

function Invoke-MonitoringCycle {
    <#
    .SYNOPSIS
        Execute single monitoring cycle
    .DESCRIPTION
        Fetch courses from all monitors, filter, and notify
    .RETURNS
        Hashtable with cycle statistics
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $cycleStats = @{
        timestamp = Get-Date -Format 'o'
        monitors_executed = 0
        courses_found = 0
        courses_filtered = 0
        courses_notified = 0
        notifiers_succeeded = @()
        notifiers_failed = @()
        duration_ms = 0
        success = $true
    }

    $cycleStart = [DateTime]::UtcNow

    try {
        # Get enabled monitors
        $enabledMonitors = @(Get-EnabledMonitors -Config $Config)
        Write-Log "INFO" "Monitoring cycle started - $($enabledMonitors.Count) monitor(s) enabled"

        $allCourses = @()

        # Execute each monitor
        foreach ($monitor in $enabledMonitors) {
            try {
                Write-Log "INFO" "Executing monitor: $($monitor.name)"

                $monitorFactory = New-Monitor -Config $monitor
                $courses = & $monitorFactory

                if ($courses -is [array]) {
                    $allCourses += $courses
                    $cycleStats.monitors_executed++
                    $cycleStats.courses_found += $courses.Count

                    Write-Log "INFO" "Monitor '$($monitor.name)' found $($courses.Count) course(s)"
                } else {
                    Write-Log "WARN" "Monitor '$($monitor.name)' returned unexpected data type"
                }

            } catch {
                Write-Log "ERROR" "Monitor '$($monitor.name)' failed: $_"
                $cycleStats.success = $false
            }
        }

        Write-Log "INFO" "Total courses from all monitors: $($allCourses.Count)"

        # Apply filter pipeline
        if ($allCourses.Count -gt 0) {
            try {
                $pipelineStats = Invoke-FilterPipeline -Courses $allCourses -Config $Config
                $filteredCourses = $pipelineStats.courses
                $cycleStats.courses_filtered = $filteredCourses.Count

                Write-Log "INFO" "Filter pipeline: $($allCourses.Count) → $($filteredCourses.Count) course(s)"
                Write-Log "DEBUG" "Pipeline stats: $($pipelineStats | ConvertTo-Json -Compress)"

            } catch {
                Write-Log "ERROR" "Filter pipeline failed: $_"
                $cycleStats.success = $false
                $filteredCourses = @()
            }

            # Send notifications
            if ($filteredCourses.Count -gt 0) {
                try {
                    $notifStats = Invoke-NotificationPipeline -Courses $filteredCourses -Config $Config

                    $cycleStats.courses_notified = $filteredCourses.Count
                    $cycleStats.notifiers_succeeded = $notifStats.enabled_channels

                    Write-Log "INFO" "Notifications sent: $($notifStats.enabled_channels -join ', ')"
                    Write-Log "DEBUG" "Notification stats: $($notifStats | ConvertTo-Json -Compress)"

                    if (-not $notifStats.success) {
                        $cycleStats.success = $false
                    }

                } catch {
                    Write-Log "ERROR" "Notification pipeline failed: $_"
                    $cycleStats.success = $false
                }
            } else {
                Write-Log "INFO" "No courses after filtering, skipping notifications"
            }
        } else {
            Write-Log "INFO" "No courses found from any monitor"
        }

    } catch {
        Write-Log "ERROR" "Monitoring cycle error: $_"
        $cycleStats.success = $false
    } finally {
        $cycleEnd = [DateTime]::UtcNow
        $cycleStats.duration_ms = [int]($cycleEnd - $cycleStart).TotalMilliseconds

        Write-Log "INFO" "Cycle complete: $($cycleStats.courses_found) found, $($cycleStats.courses_filtered) filtered, $($cycleStats.courses_notified) notified [$($cycleStats.duration_ms)ms]"
    }

    return $cycleStats
}

function Get-NextRunTime {
    <#
    .SYNOPSIS
        Calculate next monitoring cycle run time
    .DESCRIPTION
        Returns the next scheduled run based on monitor poll intervals
    .RETURNS
        DateTime of next run
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $enabledMonitors = @(Get-EnabledMonitors -Config $Config)

    if ($enabledMonitors.Count -eq 0) {
        return (Get-Date).AddMinutes(5)
    }

    $minInterval = ($enabledMonitors | Measure-Object -Property poll_interval_minutes -Minimum).Minimum
    $intervalSeconds = [Math]::Max($minInterval * 60, 60)

    return (Get-Date).AddSeconds($intervalSeconds)
}

function Wait-UntilNextRun {
    <#
    .SYNOPSIS
        Wait until next monitoring cycle
    .DESCRIPTION
        Sleeps while respecting shutdown signal
    .PARAMETER Duration
        Seconds to wait
    #>
    [CmdletBinding()]
    param(
        [int]$Duration = 300
    )

    $startTime = [DateTime]::UtcNow
    $endTime = $startTime.AddSeconds($Duration)

    while ($script:Running -and ([DateTime]::UtcNow -lt $endTime)) {
        Start-Sleep -Seconds 1
    }

    $elapsed = [int](([DateTime]::UtcNow - $startTime).TotalSeconds)
    return $elapsed
}

function Invoke-WatcherLoop {
    <#
    .SYNOPSIS
        Main watcher event loop
    .DESCRIPTION
        Continuously executes monitoring cycles at configured intervals
    .PARAMETER Config
        Configuration object
    .PARAMETER LoopCount
        Number of cycles to run (0 = infinite)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [int]$LoopCount = 0
    )

    Write-Log "INFO" "Watcher loop started (LoopCount: $(if ($LoopCount -eq 0) { 'infinite' } else { $LoopCount }))"

    $script:CycleCount = 0
    $lastCleanupTime = [DateTime]::UtcNow

    while ($script:Running -and ($LoopCount -eq 0 -or $script:CycleCount -lt $LoopCount)) {
        $script:CycleCount++

        Write-Log "INFO" "=== Cycle $($script:CycleCount) Start ==="

        # Execute monitoring cycle
        $cycleStats = Invoke-MonitoringCycle -Config $Config

        # Cleanup old state entries (every hour)
        $now = [DateTime]::UtcNow
        if (($now - $lastCleanupTime).TotalSeconds -gt 3600) {
            try {
                Clear-OldStateEntries -DaysToKeep 7
                Write-Log "DEBUG" "State cleanup completed"
                $lastCleanupTime = $now
            } catch {
                Write-Log "WARN" "State cleanup failed: $_"
            }
        }

        if (-not $script:Running) {
            Write-Log "INFO" "Shutdown signal received"
            break
        }

        # Calculate next run time
        $nextRunTime = Get-NextRunTime -Config $Config
        $waitDuration = [int](($nextRunTime - [DateTime]::UtcNow).TotalSeconds)

        if ($waitDuration -gt 0) {
            Write-Log "INFO" "Waiting $waitDuration seconds until next cycle"
            $waitDuration = Wait-UntilNextRun -Duration $waitDuration
            Write-Log "DEBUG" "Actually waited $waitDuration seconds"
        }

        Write-Log "INFO" "=== Cycle $($script:CycleCount) End ==="
        Write-Log "INFO" ""
    }

    Write-Log "INFO" "Watcher loop finished ($($script:CycleCount) cycles executed)"
}

# Main execution
try {
    # Initialize
    $config = Initialize-Watcher -ConfigPath $ConfigPath

    # Run monitoring loop
    if ($TestMode) {
        Write-Log "INFO" "Test mode: executing single cycle"
        Invoke-MonitoringCycle -Config $config | ConvertTo-Json | Write-Output
        Write-Log "INFO" "Test mode complete"
    } else {
        Invoke-WatcherLoop -Config $config -LoopCount $LoopCount
    }

    Write-Log "INFO" "Watcher shutdown complete"
    exit 0

} catch {
    Write-Log "ERROR" "Fatal error: $_`n$($_.ScriptStackTrace)"
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
