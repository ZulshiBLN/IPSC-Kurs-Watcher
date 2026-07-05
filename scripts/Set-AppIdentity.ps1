#Requires -Version 5.1

<#
.SYNOPSIS
Register IPSC Kurs Monitor as a Windows app for Toast notifications.

.DESCRIPTION
Creates registry entries to display "IPSC Kurs Monitor" as the app name
in Toast notifications instead of "Microsoft.PowerShell...".

Needs to run once per user. No administrator privileges required.

.EXAMPLE
.\Set-AppIdentity.ps1
#>

. "$PSScriptRoot\modules\SetupFunctions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "IPSC Kurs Monitor - App Identity Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$success = Invoke-SetAppIdentity

Write-Host ""
if ($success) {
    Write-Host "Setup complete. Toast notifications will now show 'IPSC Kurs Monitor' as the app name." -ForegroundColor Green
    exit 0
}
else {
    exit 1
}
