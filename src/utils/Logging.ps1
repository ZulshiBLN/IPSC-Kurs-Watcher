#Requires -Version 5.1

<#
.SYNOPSIS
    Structured logging module for IPSC Kurs Watcher
.DESCRIPTION
    Provides JSON-structured logging with file rotation and log levels
.NOTES
    Used throughout the application for consistent logging
#>

$script:LogConfig = @{
    LogDir = "data/logs"
    MaxLogSizeMB = 10
    RetentionDays = 30
    LogLevel = "INFO"
    LogLevels = @{
        ERROR = 0
        WARN = 1
        INFO = 2
        DEBUG = 3
        TRACE = 4
    }
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initialize logging system
    .PARAMETER LogDir
        Directory for log files
    .PARAMETER LogLevel
        Minimum log level (ERROR, WARN, INFO, DEBUG, TRACE)
    #>
    [CmdletBinding()]
    param(
        [string]$LogDir = "data/logs",
        [string]$LogLevel = "INFO"
    )

    $script:LogConfig.LogDir = $LogDir
    $script:LogConfig.LogLevel = $LogLevel

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    Write-Log "Logging initialized (Level: $LogLevel)" -Level INFO
}

function Write-Log {
    <#
    .SYNOPSIS
        Write structured log entry
    .PARAMETER Message
        Log message
    .PARAMETER Level
        Log level (ERROR, WARN, INFO, DEBUG, TRACE)
    .PARAMETER Monitor
        Monitor identifier (optional)
    .PARAMETER Context
        Additional context data as hashtable (optional)
    .EXAMPLE
        Write-Log "Course found" -Level INFO -Monitor "shooting-store" -Context @{ Count = 5 }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [string]$Level = "INFO",
        [string]$Monitor = "",
        [hashtable]$Context
    )

    $levelValue = $script:LogConfig.LogLevels[$Level]
    $currentLevelValue = $script:LogConfig.LogLevels[$script:LogConfig.LogLevel]

    if ($levelValue -gt $currentLevelValue) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    $logFile = Join-Path $script:LogConfig.LogDir "ipsc-watcher-$(Get-Date -Format 'yyyy-MM-dd').log"

    $logEntry = @{
        timestamp = $timestamp
        level = $Level
        message = $Message
    }

    if ($Monitor) {
        $logEntry.monitor = $Monitor
    }

    if ($Context) {
        $logEntry.context = $Context
    }

    $jsonLog = $logEntry | ConvertTo-Json -Compress

    try {
        Add-Content -Path $logFile -Value $jsonLog -Encoding UTF8 -ErrorAction Stop

        if ((Get-Item $logFile).Length / 1MB -gt $script:LogConfig.MaxLogSizeMB) {
            Compress-LogFile -LogFile $logFile
        }
    } catch {
        Write-Error "Failed to write log: $_" -ErrorAction Continue
    }

    $plainText = "[$timestamp] [$Level]" + $(if ($Monitor) { " [$Monitor]" }) + " $Message"
    Write-Host $plainText -ForegroundColor $(Get-LogLevelColor -Level $Level)
}

function Get-LogLevelColor {
    [CmdletBinding()]
    param([string]$Level)

    switch ($Level) {
        "ERROR" { return "Red" }
        "WARN" { return "Yellow" }
        "INFO" { return "Green" }
        "DEBUG" { return "Cyan" }
        "TRACE" { return "Gray" }
        default { return "White" }
    }
}

function Compress-LogFile {
    [CmdletBinding()]
    param([string]$LogFile)

    $zipPath = "$LogFile.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath
    }

    Compress-Archive -Path $LogFile -DestinationPath $zipPath
    Clear-Content -Path $LogFile
}

function Clean-OldLogs {
    <#
    .SYNOPSIS
        Remove log files older than retention period
    #>
    [CmdletBinding()]
    param()

    $cutoffDate = (Get-Date).AddDays(-$script:LogConfig.RetentionDays)

    Get-ChildItem -Path $script:LogConfig.LogDir -Filter "*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force
}

Export-ModuleMember -Function @(
    'Initialize-Logging',
    'Write-Log',
    'Clean-OldLogs'
)
