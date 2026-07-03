#Requires -Version 5.1

# Global logging configuration
$script:LoggingConfig = @{
    LogDir = 'data/logs'
    LogLevel = 'INFO'
    Format = 'json'
    RetentionDays = 30
}

function Initialize-Logging {
    <#
    .SYNOPSIS
    Configures and initializes the global logging system.

    .DESCRIPTION
    Sets up logging configuration (directory, level, format), creates log directory if missing,
    and removes old log files exceeding retention period.

    .PARAMETER LogDir
    Directory where log files are stored. Defaults to 'data/logs'.

    .PARAMETER LogLevel
    Minimum log level (DEBUG, INFO, WARN, ERROR). Defaults to 'INFO'.

    .PARAMETER Format
    Log file format. Currently 'json' for structured logging. Defaults to 'json'.

    .PARAMETER RetentionDays
    Number of days to retain log files. Older files are deleted. Defaults to 30.

    .EXAMPLE
    Initialize-Logging -LogDir 'data/logs' -LogLevel 'INFO' -RetentionDays 30

    .NOTES
    Call this once at script startup before using Write-Log.
    #>
    param(
        [string]$LogDir = 'data/logs',
        [string]$LogLevel = 'INFO',
        [string]$Format = 'json',
        [int]$RetentionDays = 30
    )

    $script:LoggingConfig.LogDir = $LogDir
    $script:LoggingConfig.LogLevel = $LogLevel
    $script:LoggingConfig.Format = $Format
    $script:LoggingConfig.RetentionDays = $RetentionDays

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    Remove-OldLog -LogDir $LogDir -RetentionDays $RetentionDays
}

function Write-Log {
    <#
    .SYNOPSIS
    Logs a message to console and file with optional context and exception details.

    .DESCRIPTION
    Writes structured log entries to both console and persistent JSON log file.
    Console output is colored based on level (ERROR=red, WARN=yellow).
    Context hashtable and Exception object are included in file output for debugging.

    .PARAMETER Level
    Log level (DEBUG, INFO, WARN, ERROR). Defaults to 'INFO'.

    .PARAMETER Message
    The main log message.

    .PARAMETER Context
    Optional hashtable with structured context (e.g., @{ monitor_id = 'abc'; attempt = 3 }).

    .PARAMETER Exception
    Optional exception object to include stack trace and line number.

    .EXAMPLE
    Write-Log -Level INFO -Message "Monitor started" -Context @{ monitor = 'shooting-store' }

    .EXAMPLE
    Write-Log -Level ERROR -Message "Failed to fetch courses" -Exception $_

    .NOTES
    Requires Initialize-Logging to be called first.
    #>
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')][string]$Level = 'INFO',
        [string]$Message,
        [hashtable]$Context,
        [object]$Exception
    )

    # Format console output
    $color = $null
    if ($Level -eq 'ERROR') { $color = 'Red' }
    elseif ($Level -eq 'WARN') { $color = 'Yellow' }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMsg = "[$timestamp] $Level`: $Message"

    if ($Exception) {
        $logMsg += " | Exception: $($Exception.Message)"
        if ($Exception.InvocationInfo) { $logMsg += " (Line: $($Exception.InvocationInfo.ScriptLineNumber))" }
    }

    if ($color) { Write-Information $logMsg -InformationAction Continue }
    else { Write-Output $logMsg }

    # Write to file
    if ($script:LoggingConfig.Format -eq 'json') {
        Write-LogToFile-JSON -Level $Level -Message $Message -Context $Context -Exception $Exception
    }
}

function Write-LogToFile-JSON {
    param(
        [string]$Level,
        [string]$Message,
        [hashtable]$Context,
        [object]$Exception
    )

    $logDir = $script:LoggingConfig.LogDir
    $logFile = Join-Path $logDir "watcher-$(Get-Date -Format 'yyyy-MM-dd').log"

    $logEntry = @{
        timestamp = [datetime]::UtcNow.ToString('o')
        level = $Level
        message = $Message
    }

    if ($Context) { $logEntry.context = $Context }

    if ($Exception) {
        $logEntry.exception = @{
            message = $Exception.Message
            type = $Exception.GetType().FullName
            line = if ($Exception.InvocationInfo) { $Exception.InvocationInfo.ScriptLineNumber } else { $null }
        }
    }

    try {
        $json = $logEntry | ConvertTo-Json -Compress -Depth 5
        Add-Content -Path $logFile -Value $json -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to write log: $_"
    }
}

function Remove-OldLog {
    <#
    .SYNOPSIS
    Deletes log files older than retention period.

    .DESCRIPTION
    Removes watcher-*.log files from LogDir that exceed the RetentionDays threshold.
    Respects -WhatIf and -Confirm for safe operation.

    .PARAMETER LogDir
    Directory containing log files to clean.

    .PARAMETER RetentionDays
    Number of days to retain. Files older than this are deleted.

    .EXAMPLE
    Remove-OldLog -LogDir 'data/logs' -RetentionDays 30

    .EXAMPLE
    Remove-OldLog -LogDir 'data/logs' -RetentionDays 30 -WhatIf
    # Shows what would be deleted without deleting

    .NOTES
    Supports -WhatIf and -Confirm for safety. Silently continues on file access errors.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$LogDir,
        [int]$RetentionDays
    )

    if (-not (Test-Path $LogDir)) { return }

    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    Get-ChildItem $LogDir -Filter "watcher-*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force -ErrorAction SilentlyContinue -WhatIf:$WhatIfPreference -Confirm:$ConfirmPreference
}
