#Requires -Version 5.1

<#
.SYNOPSIS
    Simple Basic Course Watcher - Monitor for new Basic courses on Shooting-Store.ch
.DESCRIPTION
    Periodically checks https://www.shooting-store.ch/de/kategorie/kurse1 for new Basic courses
    and sends notifications when found.
.PARAMETER ConfigPath
    Path to configuration file (default: config/config.json)
.PARAMETER CheckInterval
    Check interval in minutes (default: 30)
.PARAMETER RunOnce
    Run single check and exit (for testing)
.EXAMPLE
    .\BasicCourseWatcher.ps1
    .\BasicCourseWatcher.ps1 -CheckInterval 15 -RunOnce
.NOTES
    State file: data/notified-basic-courses.json
    Logs: data/logs/basic-course-watcher-*.log
#>

param(
    [string]$ConfigPath = "config/config.json",
    [int]$CheckInterval = 30,
    [switch]$RunOnce
)

$ErrorActionPreference = 'Continue'

# Setup paths
$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path
$MonitorPath = Join-Path $ScriptRoot "src/monitors/BasicCourseMonitor.ps1"
$StateFile = Join-Path $ScriptRoot "data/notified-basic-courses.json"
$LogDir = Join-Path $ScriptRoot "data/logs"

# Create log directory if not exists
if (-not (Test-Path $LogDir)) {
    mkdir $LogDir -Force | Out-Null
}

# Logging function
function Write-LogEntry {
    param(
        [string]$Level,
        [string]$Message
    )

    $timestamp = ([datetime]::UtcNow).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$timestamp] [$Level] $Message"

    Write-Host $logLine

    # Log to file
    $logFile = Join-Path $LogDir "basic-course-watcher-$(Get-Date -Format 'yyyy-MM-dd').log"
    Add-Content -Path $logFile -Value $logLine -Encoding UTF8
}

# Load monitor module
try {
    . $MonitorPath
    Write-LogEntry "INFO" "Loaded BasicCourseMonitor module"
} catch {
    Write-LogEntry "ERROR" "Failed to load monitor module: $_"
    exit 1
}

# Load config if it exists (optional - can run without it for basic notifications)
$config = @{
    notifiers = @{
        email = @{ enabled = $false }
        discord = @{ enabled = $false }
        windows_toast = @{ enabled = $false }
    }
}

if (Test-Path $ConfigPath) {
    try {
        $configJson = Get-Content $ConfigPath -Encoding UTF8 | ConvertFrom-Json
        $config = @{
            notifiers = @{
                email = @{
                    enabled = $configJson.notifiers.email.enabled
                    smtp_host = $configJson.notifiers.email.smtp_host
                    smtp_port = $configJson.notifiers.email.smtp_port
                    recipients = @($configJson.notifiers.email.recipients)
                }
                discord = @{
                    enabled = $configJson.notifiers.discord.enabled
                    webhook_url = $configJson.notifiers.discord.webhook_url
                }
                windows_toast = @{
                    enabled = $configJson.notifiers.windows_toast.enabled
                }
            }
        }
        Write-LogEntry "INFO" "Loaded configuration from $ConfigPath"
    } catch {
        Write-LogEntry "WARN" "Could not load config file, using defaults: $_"
    }
}

# Main monitoring loop
function Invoke-MonitoringLoop {
    Write-LogEntry "INFO" "==== Basic Course Watcher Started ===="
    Write-LogEntry "INFO" "Check interval: $CheckInterval minutes"
    Write-LogEntry "INFO" "State file: $StateFile"

    $cycleCount = 0

    while ($true) {
        $cycleCount++
        Write-LogEntry "INFO" "--- Cycle #$cycleCount ---"

        try {
            # Run the monitor
            $result = Invoke-BasicCourseMonitor -Config $config -StateFile $StateFile

            # Log results
            Write-LogEntry "INFO" "Total Basic courses: $($result.total_current)"
            Write-LogEntry "INFO" "New courses found: $($result.newly_found)"

            if ($result.newly_found -gt 0) {
                Write-LogEntry "WARN" "NEW COURSES DETECTED - Notifications should be sent"
                foreach ($course in $result.courses) {
                    Write-LogEntry "WARN" "  - $($course.name)"
                }
            }

        } catch {
            Write-LogEntry "ERROR" "Monitor execution failed: $_"
        }

        # Exit if single run mode
        if ($RunOnce) {
            Write-LogEntry "INFO" "Single run mode - exiting"
            break
        }

        # Wait before next check
        Write-LogEntry "INFO" "Next check in $CheckInterval minutes..."
        Start-Sleep -Seconds ($CheckInterval * 60)
    }

    Write-LogEntry "INFO" "==== Basic Course Watcher Stopped ===="
}

# Start monitoring
Invoke-MonitoringLoop
