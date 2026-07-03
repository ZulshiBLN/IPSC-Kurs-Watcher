#Requires -Version 5.1

<#
.SYNOPSIS
    Service for managing the watcher background job
.DESCRIPTION
    Handles starting, stopping, and monitoring the main watcher job
#>

class WatcherService {
    [System.Diagnostics.Process]$WatcherProcess
    [string]$WatcherScriptPath
    [string]$ConfigPath
    [hashtable]$Status

    WatcherService([string]$watcherPath, [string]$configPath) {
        $this.WatcherScriptPath = $watcherPath
        $this.ConfigPath = $configPath
        $this.Status = @{
            running = $false
            lastRun = $null
            nextRun = $null
            cycleCount = 0
        }
    }

    [bool] StartWatcher() {
        if ($this.Status.running) {
            Write-Verbose "Watcher is already running"
            return $false
        }

        try {
            $scriptPath = if (Test-Path $this.WatcherScriptPath) {
                $this.WatcherScriptPath
            } else {
                Join-Path (Split-Path (Split-Path $PSScriptRoot)) "Watcher.ps1"
            }

            if (-not (Test-Path $scriptPath)) {
                throw "Watcher script not found: $scriptPath"
            }

            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "powershell.exe"
            $pinfo.Arguments = "-NoProfile -ExecutionPolicy RemoteSigned -File `"$scriptPath`" -ConfigPath `"$($this.ConfigPath)`""
            $pinfo.RedirectStandardOutput = $true
            $pinfo.RedirectStandardError = $true
            $pinfo.UseShellExecute = $false
            $pinfo.CreateNoWindow = $true

            $this.WatcherProcess = [System.Diagnostics.Process]::Start($pinfo)
            $this.Status.running = $true
            $this.Status.lastRun = Get-Date

            Write-Verbose "Watcher started with PID: $($this.WatcherProcess.Id)"
            return $true
        } catch {
            Write-Error "Failed to start watcher: $_"
            return $false
        }
    }

    [bool] StopWatcher() {
        if (-not $this.Status.running) {
            Write-Verbose "Watcher is not running"
            return $false
        }

        try {
            if ($null -ne $this.WatcherProcess -and -not $this.WatcherProcess.HasExited) {
                $this.WatcherProcess.Kill()
                $this.WatcherProcess.WaitForExit(5000)
                $this.Status.running = $false

                Write-Verbose "Watcher stopped"
                return $true
            }
        } catch {
            Write-Error "Failed to stop watcher: $_"
        }

        $this.Status.running = $false
        return $false
    }

    [bool] IsRunning() {
        if ($null -eq $this.WatcherProcess) {
            return $false
        }

        if ($this.WatcherProcess.HasExited) {
            $this.Status.running = $false
            return $false
        }

        return $this.Status.running
    }

    [hashtable] GetStatus() {
        return $this.Status
    }

    [string[]] GetRecentLogs([int]$lineCount = 20) {
        $logPath = Join-Path (Split-Path (Split-Path $PSScriptRoot)) "data/logs"

        if (-not (Test-Path $logPath)) {
            return @("No logs directory found")
        }

        $logFiles = Get-ChildItem $logPath -Filter "*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($logFiles.Count -eq 0) {
            return @("No log files found")
        }

        try {
            $logs = Get-Content $logFiles[0].FullName -Tail $lineCount -ErrorAction Stop
            return if ($logs -is [array]) { $logs } else { @($logs) }
        } catch {
            return @("Failed to read logs: $_")
        }
    }
}

function New-WatcherService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WatcherPath,

        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    return [WatcherService]::new($WatcherPath, $ConfigPath)
}
