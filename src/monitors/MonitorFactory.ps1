#Requires -Version 5.1

<#
.SYNOPSIS
    Factory for creating monitor instances based on provider type
.DESCRIPTION
    Routes monitor configuration to correct provider implementation
.NOTES
    Factory pattern allows easy addition of new providers
#>

. "$PSScriptRoot/MonitorBase.ps1"
. "$PSScriptRoot/MonitorShootingStore.ps1"
. "$PSScriptRoot/MonitorGenericHtml.ps1"

function New-Monitor {
    <#
    .SYNOPSIS
        Create new monitor instance
    .PARAMETER Config
        Monitor configuration object
    .EXAMPLE
        $config = @{
            id = "shooting-store-main"
            provider = "shooting-store"
            url = "https://example.com/kurse"
            ...
        }
        $monitor = New-Monitor -Config $config
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    if ([string]::IsNullOrWhiteSpace($Config.provider)) {
        throw "Monitor configuration must include 'provider' field"
    }

    $provider = $Config.provider.ToLower()

    switch ($provider) {
        "shooting-store" {
            $monitor = [MonitorShootingStore]::new($Config)
        }
        "generic-html" {
            $monitor = [MonitorGenericHtml]::new($Config)
        }
        default {
            throw "Unknown monitor provider: $provider"
        }
    }

    try {
        $monitor.ValidateConfig()
    } catch {
        throw "Monitor configuration validation failed: $_"
    }

    Write-Verbose "Created monitor: $($monitor.Name) (provider: $provider)"

    return $monitor
}

function Test-MonitorConnection {
    <#
    .SYNOPSIS
        Test if monitor can connect to source
    .PARAMETER Monitor
        Monitor instance to test
    .EXAMPLE
        $result = Test-MonitorConnection -Monitor $monitor
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [MonitorBase]$Monitor
    )

    Write-Verbose "Testing connection for monitor: $($Monitor.Name)"

    $result = $Monitor.TestConnection()
    return $result -eq "OK"
}
