#Requires -Version 5.1

<#
.SYNOPSIS
    Configuration management module for IPSC Kurs Watcher
.DESCRIPTION
    Loads, validates, and manages application configuration from JSON files
.NOTES
    Configuration is loaded at startup and validated against schema
#>

function Get-ConfigPath {
    <#
    .SYNOPSIS
        Get configuration file path
    .PARAMETER ConfigDir
        Configuration directory
    .PARAMETER ConfigFile
        Configuration filename (default: config.json)
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigDir = "config",
        [string]$ConfigFile = "config.json"
    )

    return Join-Path $ConfigDir $ConfigFile
}

function New-ConfigFromTemplate {
    <#
    .SYNOPSIS
        Create new configuration from template
    .PARAMETER TargetPath
        Path where to create the new config
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    $templatePath = Get-ConfigPath -ConfigFile "config.example.json"

    if (-not (Test-Path $templatePath)) {
        throw "Template config not found at: $templatePath"
    }

    Copy-Item -Path $templatePath -Destination $TargetPath
    Write-Verbose "Created new config from template: $TargetPath"
}

function Read-Config {
    <#
    .SYNOPSIS
        Read configuration from JSON file
    .PARAMETER ConfigPath
        Path to configuration file
    .PARAMETER CreateIfMissing
        Create config from template if file doesn't exist
    .EXAMPLE
        $config = Read-Config -ConfigPath "config/config.json"
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "config/config.json",
        [switch]$CreateIfMissing
    )

    if (-not (Test-Path $ConfigPath)) {
        if ($CreateIfMissing) {
            Write-Verbose "Config not found, creating from template"
            New-ConfigFromTemplate -TargetPath $ConfigPath
        } else {
            throw "Configuration file not found: $ConfigPath"
        }
    }

    try {
        $configContent = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $config = $configContent | ConvertFrom-Json

        Write-Verbose "Configuration loaded from: $ConfigPath"
        return $config
    } catch {
        throw "Failed to read configuration: $_"
    }
}

function Save-Config {
    <#
    .SYNOPSIS
        Save configuration to JSON file
    .PARAMETER Config
        Configuration object to save
    .PARAMETER ConfigPath
        Path where to save configuration
    .PARAMETER CreateBackup
        Create backup before saving (default: true)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Config,

        [string]$ConfigPath = "config/config.json",
        [switch]$CreateBackup = $true
    )

    if ($CreateBackup -and (Test-Path $ConfigPath)) {
        $backupPath = "$ConfigPath.backup.$(Get-Date -Format 'yyyyMMdd')"
        Copy-Item -Path $ConfigPath -Destination $backupPath
        Write-Verbose "Created backup: $backupPath"
    }

    try {
        $jsonConfig = $Config | ConvertTo-Json -Depth 10
        Set-Content -Path $ConfigPath -Value $jsonConfig -Encoding UTF8
        Write-Verbose "Configuration saved to: $ConfigPath"
    } catch {
        throw "Failed to save configuration: $_"
    }
}

function Get-ConfigMonitor {
    <#
    .SYNOPSIS
        Get specific monitor configuration
    .PARAMETER Config
        Configuration object
    .PARAMETER MonitorId
        Monitor identifier
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Config,

        [Parameter(Mandatory)]
        [string]$MonitorId
    )

    $monitor = $Config.monitors | Where-Object { $_.id -eq $MonitorId }

    if (-not $monitor) {
        throw "Monitor not found: $MonitorId"
    }

    return $monitor
}

function Get-EnabledMonitors {
    <#
    .SYNOPSIS
        Get all enabled monitors from configuration
    .PARAMETER Config
        Configuration object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Config
    )

    return $Config.monitors | Where-Object { $_.enabled -eq $true }
}

function Get-EnabledCourseTypes {
    <#
    .SYNOPSIS
        Get all enabled course types from configuration
    .PARAMETER Config
        Configuration object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Config
    )

    return $Config.filters.course_types | Where-Object { $_.enabled -eq $true }
}
