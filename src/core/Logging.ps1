#Requires -Version 5.1

# Global logging configuration
$script:LoggingConfig = @{
    LogDir = 'data/logs'
    LogLevel = 'INFO'
    Format = 'json'
    RetentionDays = 30
}

function Initialize-Logging {
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

    Remove-OldLogs -LogDir $LogDir -RetentionDays $RetentionDays
}

function Write-Log {
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

    if ($color) { Write-Host $logMsg -ForegroundColor $color }
    else { Write-Host $logMsg }

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
        Write-Host "Failed to write log: $_" -ForegroundColor Red
    }
}

function Remove-OldLogs {
    param(
        [string]$LogDir,
        [int]$RetentionDays
    )

    if (-not (Test-Path $LogDir)) { return }

    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    Get-ChildItem $LogDir -Filter "watcher-*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
