#Requires -Version 5.1

<#
.SYNOPSIS
Remove IPSC Kurs Watcher environment variables.

.DESCRIPTION
Removes environment variables configured by Set-EnvironmentVariables.ps1:
- IPSC_AZURE_TENANT_ID
- IPSC_AZURE_CLIENT_ID
- IPSC_AZURE_USER_ID
- IPSC_CREDENTIAL_STORE_PATH
- IPSC_DISCORD_WEBHOOKS

Stored credentials are NOT affected.

.EXAMPLE
.\Remove-EnvironmentVariables.ps1
#>

. "$PSScriptRoot\modules\SetupFunctions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Remove Environment Variables" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "This script removes IPSC Kurs Watcher environment variables." -ForegroundColor Yellow
Write-Host "Your stored credentials will NOT be affected.`n" -ForegroundColor Yellow

$confirm = Read-Host "Are you sure you want to remove environment variables? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "[INFO] Operation cancelled" -ForegroundColor Gray
    exit 0
}

$success = Invoke-RemoveEnvironmentVariables

Write-Host ""
if ($success) {
    Write-Host "Note: You may need to restart PowerShell for changes to take effect." -ForegroundColor Yellow
    Write-Host "Your encrypted credentials are still stored at:" -ForegroundColor Yellow
    Write-Host "`$env:APPDATA\IPSC-Kurs-Watcher\credentials\IPSC-Kurs-Watcher-Secret.bin`n" -ForegroundColor Gray
    exit 0
}
else {
    exit 1
}
