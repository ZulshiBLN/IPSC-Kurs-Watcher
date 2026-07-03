#Requires -Version 5.1

<#
.SYNOPSIS
Set IPSC Kurs Watcher environment variables persistently.

.DESCRIPTION
Sets environment variables required for IPSC Kurs Watcher:
- IPSC_AZURE_TENANT_ID (Azure AD Tenant ID)
- IPSC_AZURE_CLIENT_ID (Azure AD Application ID)
- IPSC_AZURE_USER_ID (Recipient email address)
- IPSC_CREDENTIAL_STORE_PATH (Optional - encrypted credential storage)
- IPSC_DISCORD_WEBHOOKS (Optional - Discord webhook URLs)

Variables are stored at User level and persist across PowerShell sessions.

.EXAMPLE
.\Set-EnvironmentVariables.ps1
#>

. "$PSScriptRoot\modules\SetupFunctions.ps1"

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "IPSC Kurs Watcher Environment Variables" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "This script sets environment variables needed for IPSC Kurs Watcher." -ForegroundColor Yellow
Write-Host "Variables will be stored persistently in Windows environment.`n" -ForegroundColor Yellow

$success = Invoke-SetEnvironmentVariables

Write-Host ""
if ($success) {
    Write-Host "Environment variables set successfully!" -ForegroundColor Green
    Write-Host "Note: You may need to restart PowerShell for changes to take effect." -ForegroundColor Yellow
    Write-Host "Or run: `$env:IPSC_AZURE_TENANT_ID = `"<value>`"" -ForegroundColor Gray
    Write-Host "        (for each variable in current session)`n" -ForegroundColor Gray
    exit 0
}
else {
    exit 1
}
