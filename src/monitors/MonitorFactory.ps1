#Requires -Version 5.1

function Get-Monitor { param([object]$Config)
    switch ($Config.provider) {
        'shooting-store' { return [CourseMonitor]::new($Config) }
        default { throw "Unknown provider: $($Config.provider)" }
    }
}
