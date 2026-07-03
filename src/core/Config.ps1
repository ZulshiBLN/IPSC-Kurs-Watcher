#Requires -Version 5.1

function Get-Config { param([string]$ConfigPath = 'config/config.json', [string]$SchemaPath = 'config/config.schema.json')
    if (-not (Test-Path $ConfigPath)) { throw "Config file not found: $ConfigPath" }
    try {
        $configJson = Get-Content $ConfigPath -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
        Write-Log -Level INFO -Message "Config loaded successfully" -Context @{ path = $ConfigPath; monitors = $configJson.monitors.Count }
        return $configJson
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to load config" -Context @{ path = $ConfigPath } -Exception $_
        throw "Config loading failed: $_"
    }
}

function Validate-MonitorConfig { param([hashtable]$MonitorConfig)
    if (-not $MonitorConfig.id) { throw "Monitor must have 'id'" }
    if (-not $MonitorConfig.provider) { throw "Monitor must have 'provider'" }
    if (-not $MonitorConfig.url) { throw "Monitor must have 'url'" }
    return $true
}
