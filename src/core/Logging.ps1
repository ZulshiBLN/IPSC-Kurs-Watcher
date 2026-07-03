#Requires -Version 5.1

function Initialize-Logging {
    param([string]$LogDir = 'data/logs', [string]$LogLevel = 'INFO', [string]$Format = 'json', [int]$RetentionDays = 30)
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
}

function Write-Log {
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')][string]$Level = 'INFO',
        [string]$Message,
        [hashtable]$Context,
        [object]$Exception
    )

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
}
