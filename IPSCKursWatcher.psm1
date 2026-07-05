#Requires -Version 5.1

# IPSC Kurs Watcher Module
# Entry point for PowerShell Gallery distribution

# Get the module root directory
$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load core helper scripts
$scriptFiles = @(
    'src/core/Helpers.ps1'
    'src/core/Logging.ps1'
    'src/core/Config.ps1'
    'src/core/State.ps1'
)

foreach ($script in $scriptFiles) {
    $scriptPath = Join-Path $moduleRoot $script
    if (Test-Path $scriptPath) {
        . $scriptPath
    }
}

# Load main scheduler (contains Invoke-MonitoringCycle)
$schedulerPath = Join-Path $moduleRoot 'Scheduler.ps1'
if (Test-Path $schedulerPath) {
    . $schedulerPath
}

# Export public function
Export-ModuleMember -Function @(
    'Invoke-MonitoringCycle'
) -Alias @() -Cmdlet @() -Variable @()
