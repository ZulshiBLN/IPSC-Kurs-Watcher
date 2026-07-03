#Requires -Version 5.1

<#
.SYNOPSIS
Remove IPSC Kurs Monitor app identity from Windows registry.

.DESCRIPTION
Removes the registry entries created by Set-AppIdentity.ps1.
Toast notifications will revert to showing "Microsoft.PowerShell..." as the app name.

No administrator privileges required.

.EXAMPLE
.\Remove-AppIdentity.ps1
#>

. "$PSScriptRoot\modules\SetupFunctions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "IPSC Kurs Monitor - App Identity Removal" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$success = Invoke-RemoveAppIdentity

Write-Host ""
if ($success) {
    Write-Host "Removal complete. Toast notifications will revert to default app name." -ForegroundColor Green
    exit 0
}
else {
    exit 1
}
