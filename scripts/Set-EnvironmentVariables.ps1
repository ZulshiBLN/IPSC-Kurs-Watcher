#Requires -Version 5.1

<#
.SYNOPSIS
Set IPSC Kurs Watcher environment variables persistently in Windows.

.DESCRIPTION
Sets environment variables required for IPSC Kurs Watcher to function:
- IPSC_AZURE_TENANT_ID (Azure AD Tenant ID)
- IPSC_AZURE_CLIENT_ID (Azure AD Application ID)
- IPSC_AZURE_USER_ID (Recipient email address)
- IPSC_CREDENTIAL_STORE_PATH (Optional - encrypted credential storage location)
- IPSC_DISCORD_WEBHOOKS (Optional - comma-separated Discord webhook URLs)

Variables are stored at User level and persist across PowerShell sessions.
Requires user to provide values interactively.

.EXAMPLE
.\Set-EnvironmentVariables.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "IPSC Kurs Watcher Environment Variables" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "This script sets environment variables needed for IPSC Kurs Watcher." -ForegroundColor Yellow
Write-Host "Variables will be stored persistently in Windows environment.`n" -ForegroundColor Yellow

# Required variables
Write-Host "=== Required Variables ===" -ForegroundColor Green

$tenantId = Read-Host "Azure Tenant ID (Directory ID)"
if (-not $tenantId) {
    Write-Host "[ERROR] Tenant ID is required" -ForegroundColor Red
    exit 1
}

$clientId = Read-Host "Azure Client ID (Application ID)"
if (-not $clientId) {
    Write-Host "[ERROR] Client ID is required" -ForegroundColor Red
    exit 1
}

$userId = Read-Host "Azure User ID (your email address)"
if (-not $userId) {
    Write-Host "[ERROR] User ID is required" -ForegroundColor Red
    exit 1
}

# Optional variables
Write-Host "`n=== Optional Variables ===" -ForegroundColor Green

$credStorePath = Read-Host "Credential Store Path (press Enter for default)"
if (-not $credStorePath) {
    $credStorePath = "$env:APPDATA\IPSC-Kurs-Watcher\credentials"
    Write-Host "Using default: $credStorePath" -ForegroundColor Gray
}

$discordWebhooks = Read-Host "Discord Webhook URLs (press Enter to skip)"

# Set variables
Write-Host "`n=== Setting Environment Variables ===" -ForegroundColor Green

try {
    [System.Environment]::SetEnvironmentVariable("IPSC_AZURE_TENANT_ID", $tenantId, [System.EnvironmentVariableTarget]::User)
    Write-Host "[OK] IPSC_AZURE_TENANT_ID set" -ForegroundColor Green

    [System.Environment]::SetEnvironmentVariable("IPSC_AZURE_CLIENT_ID", $clientId, [System.EnvironmentVariableTarget]::User)
    Write-Host "[OK] IPSC_AZURE_CLIENT_ID set" -ForegroundColor Green

    [System.Environment]::SetEnvironmentVariable("IPSC_AZURE_USER_ID", $userId, [System.EnvironmentVariableTarget]::User)
    Write-Host "[OK] IPSC_AZURE_USER_ID set" -ForegroundColor Green

    [System.Environment]::SetEnvironmentVariable("IPSC_CREDENTIAL_STORE_PATH", $credStorePath, [System.EnvironmentVariableTarget]::User)
    Write-Host "[OK] IPSC_CREDENTIAL_STORE_PATH set" -ForegroundColor Green

    if ($discordWebhooks) {
        [System.Environment]::SetEnvironmentVariable("IPSC_DISCORD_WEBHOOKS", $discordWebhooks, [System.EnvironmentVariableTarget]::User)
        Write-Host "[OK] IPSC_DISCORD_WEBHOOKS set" -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] IPSC_DISCORD_WEBHOOKS skipped" -ForegroundColor Gray
    }
}
catch {
    Write-Host "[ERROR] Failed to set environment variables: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Configuration Summary:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Tenant ID:          $tenantId" -ForegroundColor Cyan
Write-Host "Client ID:          $clientId" -ForegroundColor Cyan
Write-Host "User ID:            $userId" -ForegroundColor Cyan
Write-Host "Credential Store:   $credStorePath" -ForegroundColor Cyan
if ($discordWebhooks) {
    Write-Host "Discord Webhooks:   [SET]" -ForegroundColor Cyan
}
else {
    Write-Host "Discord Webhooks:   [NOT SET]" -ForegroundColor Gray
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "[OK] Environment variables set successfully!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Note: You may need to restart PowerShell for changes to take effect." -ForegroundColor Yellow
Write-Host "Or run: `$env:IPSC_AZURE_TENANT_ID = `"$tenantId`"" -ForegroundColor Gray
Write-Host "        (for each variable in current session)`n" -ForegroundColor Gray

exit 0
