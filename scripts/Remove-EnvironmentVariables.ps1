#Requires -Version 5.1

<#
.SYNOPSIS
Remove IPSC Kurs Watcher environment variables from Windows.

.DESCRIPTION
Removes environment variables set by Set-EnvironmentVariables.ps1:
- IPSC_AZURE_TENANT_ID
- IPSC_AZURE_CLIENT_ID
- IPSC_AZURE_USER_ID
- IPSC_CREDENTIAL_STORE_PATH
- IPSC_DISCORD_WEBHOOKS

Variables are removed from User level environment only.

.EXAMPLE
.\Remove-EnvironmentVariables.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Remove Environment Variables" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "This script removes IPSC Kurs Watcher environment variables." -ForegroundColor Yellow
Write-Host "Your stored credentials will NOT be affected.`n" -ForegroundColor Yellow

# Confirm before removing
$confirm = Read-Host "Are you sure you want to remove environment variables? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "[INFO] Operation cancelled" -ForegroundColor Gray
    exit 0
}

Write-Host "`n=== Removing Environment Variables ===" -ForegroundColor Green

$variables = @(
    "IPSC_AZURE_TENANT_ID",
    "IPSC_AZURE_CLIENT_ID",
    "IPSC_AZURE_USER_ID",
    "IPSC_CREDENTIAL_STORE_PATH",
    "IPSC_DISCORD_WEBHOOKS"
)

try {
    foreach ($var in $variables) {
        $value = [System.Environment]::GetEnvironmentVariable($var, [System.EnvironmentVariableTarget]::User)
        if ($value) {
            [System.Environment]::SetEnvironmentVariable($var, $null, [System.EnvironmentVariableTarget]::User)
            Write-Host "[OK] $var removed" -ForegroundColor Green
        }
        else {
            Write-Host "[INFO] $var not set (skipped)" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host "[ERROR] Failed to remove environment variables: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "[OK] Environment variables removed successfully!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Note: You may need to restart PowerShell for changes to take effect." -ForegroundColor Yellow
Write-Host "Your encrypted credentials are still stored at: " -ForegroundColor Yellow
Write-Host "`$env:APPDATA\IPSC-Kurs-Watcher\credentials\IPSC-Kurs-Watcher-Secret.bin`n" -ForegroundColor Gray

exit 0
