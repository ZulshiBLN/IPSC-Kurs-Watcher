#Requires -Version 5.1

function Get-Monitor {
    <#
    .SYNOPSIS
    Creates a monitor instance based on configured provider.

    .DESCRIPTION
    Factory function that instantiates the appropriate Monitor class
    based on the provider field in the configuration.
    Currently supports 'shooting-store' provider.

    .PARAMETER Config
    Configuration object with required fields:
      - provider: 'shooting-store' (currently only supported)
      - id, url, base_url, enabled, timeout_seconds, retry_attempts

    .OUTPUTS
    MonitorBase subclass instance (e.g., CourseMonitor).

    .EXAMPLE
    $monitorConfig = @{ provider = 'shooting-store'; url = 'https://...'; base_url = 'https://...' }
    $monitor = Get-Monitor -Config $monitorConfig
    $courses = $monitor.Invoke()

    .NOTES
    Throws error if provider is unknown.
    #>
    param([object]$Config)
    switch ($Config.provider) {
        'shooting-store' { return [CourseMonitor]::new($Config) }
        default { throw "Unknown provider: $($Config.provider)" }
    }
}
