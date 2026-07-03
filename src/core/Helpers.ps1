#Requires -Version 5.1

<#
.SYNOPSIS
Common helper utilities for IPSC Kurs Watcher.
#>

function ConvertTo-SafeJson {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][object]$InputObject, [int]$Depth = 10)
    process {
        try { $InputObject | ConvertTo-Json -Depth $Depth -ErrorAction Stop }
        catch { Write-Error "JSON conversion failed: $_"; $null }
    }
}

function ConvertFrom-SafeJson {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][string]$JsonString)
    process {
        try { $JsonString | ConvertFrom-Json -ErrorAction Stop }
        catch { Write-Error "JSON parse error: $_"; $null }
    }
}

function Test-FilePath { [CmdletBinding()] param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    if (!(Get-Item $Path).PSIsContainer) { return $true }
    return $false
}

function Get-FileDirectory { [CmdletBinding()] param([string]$Path)
    if (-not (Test-Path $Path)) { try { New-Item -ItemType Directory -Path $Path -Force | Out-Null } catch { Write-Error "Failed to create directory $Path : $_"; return $null } }
    return $Path
}

function Invoke-WithRetry { [CmdletBinding()] param([scriptblock]$ScriptBlock, [int]$MaxAttempts = 3, [int]$BaseDelaySeconds = 1)
    $attempt = 0; $lastError = $null
    while ($attempt -lt $MaxAttempts) { try { return & $ScriptBlock } catch { $attempt++; $lastError = $_; if ($attempt -lt $MaxAttempts) { $delay = [Math]::Pow(2, $attempt - 1) * $BaseDelaySeconds; Start-Sleep -Seconds $delay } } }
    throw $lastError
}

function Protect-SensitiveData { [CmdletBinding()] param([string]$InputString)
    if (-not $InputString) { return $InputString }
    $masked = $InputString
    $masked = $masked -replace '(password[^=]*=")[^"]*"', '$1***MASKED***"'
    $masked = $masked -replace '(api_key=")[^"]*"', '$1***MASKED***"'
    $masked = $masked -replace '(webhook_url=")[^"]*"', '$1***MASKED***"'
    $masked = $masked -replace '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '***@***.***'
    return $masked
}

function Get-UtcTimestamp { [datetime]::UtcNow.ToString('o') }

function ConvertTo-UnixTimestamp { [CmdletBinding()] param([datetime]$DateTime)
    [int64][double]::Parse((Get-Date $DateTime -UFormat %s))
}
