#Requires -Version 5.1

function Get-Config {
    <#
    .SYNOPSIS
    Loads and validates the configuration file.

    .DESCRIPTION
    Reads config.json, parses it as JSON, and returns the configuration object.
    Logs load success/failure for troubleshooting. Throws on file not found or parse error.

    .PARAMETER ConfigPath
    Path to the config.json file. Defaults to 'config/config.json' in the current directory.

    .OUTPUTS
    PSCustomObject containing monitors, filters, notifiers, state, logging, and error_handling sections.

    .EXAMPLE
    $config = Get-Config -ConfigPath 'config/config.json'

    .EXAMPLE
    $config = Get-Config
    # Uses default 'config/config.json'

    .NOTES
    File encoding must be UTF-8. Invalid JSON or missing file will throw an error.
    #>
    param([string]$ConfigPath = 'config/config.json')
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

function Test-MonitorConfig {
    <#
    .SYNOPSIS
    Validates monitor configuration object structure.

    .DESCRIPTION
    Verifies that a monitor configuration contains all required fields (id, provider, url).
    Returns $true if valid; throws an error if validation fails.

    .PARAMETER MonitorConfig
    Hashtable or PSCustomObject with monitor configuration fields.
    Required fields: id (string), provider (string), url (string).

    .OUTPUTS
    Boolean - $true if configuration is valid.

    .EXAMPLE
    $monitor = @{ id = 'shooting-store'; provider = 'web-scraper'; url = 'https://example.com' }
    Test-MonitorConfig -MonitorConfig $monitor
    # Returns: $true

    .NOTES
    Throws an error if any required field is missing. Called during config validation.
    #>
    param([hashtable]$MonitorConfig)
    if (-not $MonitorConfig.id) { throw "Monitor must have 'id'" }
    if (-not $MonitorConfig.provider) { throw "Monitor must have 'provider'" }
    if (-not $MonitorConfig.url) { throw "Monitor must have 'url'" }
    return $true
}
