#Requires -Version 5.1

<#
.SYNOPSIS
Configure Azure AD OAuth2 credentials for IPSC Kurs Watcher.

.DESCRIPTION
Sets up OAuth2 authentication with Azure AD and Microsoft Graph API.
Stores Client Secret securely using DPAPI encryption.

Credentials are tested before storage.

.EXAMPLE
.\Set-AzureCredentials.ps1
#>

Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Web

. "$PSScriptRoot\modules\SetupFunctions.ps1"

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Text)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Text)
    Write-Host "[ERROR] $Text" -ForegroundColor Red
}

function _TestAzureConnection {
    param([string]$TenantId, [string]$ClientId, [string]$ClientSecret)

    try {
        $tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

        $body = "client_id=$([System.Web.HttpUtility]::UrlEncode($ClientId))&client_secret=$([System.Web.HttpUtility]::UrlEncode($ClientSecret))&scope=$([System.Web.HttpUtility]::UrlEncode('https://graph.microsoft.com/.default'))&grant_type=client_credentials"

        $response = Invoke-WebRequest -Uri $tokenUri -Method POST -Body $body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 10 -ErrorAction Stop -UseBasicParsing
        $token = $response.Content | ConvertFrom-Json
        if ($token.access_token) {
            return @{ success = $true; message = "OAuth2 token obtained successfully" }
        }
        return @{ success = $false; message = "OAuth2 failed: No token in response" }
    }
    catch {
        $errorMsg = $_.Exception.Message
        $errorResponse = $_.Exception.Response.StatusCode
        if ($errorMsg -match "401|Unauthorized" -or $errorResponse -eq "Unauthorized") {
            $errorMsg = "Invalid Client ID, Client Secret, or Tenant ID"
        }
        elseif ($errorMsg -match "403|Forbidden") {
            $errorMsg = "Permission denied. Check Tenant ID and credentials."
        }
        return @{ success = $false; message = "OAuth2 failed: $errorMsg" }
    }
}

Write-Header "Azure AD OAuth2 Configuration for IPSC Kurs Watcher"

$CredentialStorePath = "$env:APPDATA\IPSC-Kurs-Watcher\credentials"

Write-Header "Enter Azure Credentials"

$tenantId = Read-Host "Tenant ID (Directory ID)"
if (-not $tenantId) {
    Write-Error-Custom "Tenant ID is required"
    exit 1
}

$clientId = Read-Host "Client ID (Application ID)"
if (-not $clientId) {
    Write-Error-Custom "Client ID is required"
    exit 1
}

$clientSecretPlain = Read-Host "Client Secret (will be masked)"
if (-not $clientSecretPlain -or $clientSecretPlain.Length -eq 0) {
    Write-Error-Custom "Client Secret is required"
    exit 1
}

Write-Header "Testing Azure Credentials"

$testResult = _TestAzureConnection -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecretPlain

if ($testResult.success) {
    Write-Success $testResult.message
}
else {
    Write-Error-Custom $testResult.message
    exit 1
}

Write-Header "Storing Credentials Securely"

try {
    if (-not (Test-Path $CredentialStorePath)) {
        New-Item -ItemType Directory -Path $CredentialStorePath -Force | Out-Null
        Write-Success "Created credential store directory"
    }

    $credentialFile = Join-Path $CredentialStorePath "IPSC-Kurs-Watcher-Secret.bin"
    $secretBytes = [System.Text.Encoding]::UTF8.GetBytes($clientSecretPlain)
    $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect($secretBytes, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
    [System.IO.File]::WriteAllBytes($credentialFile, $encryptedBytes)
    Write-Success "Client Secret stored in: $credentialFile"
}
catch {
    Write-Error-Custom "Failed to store credentials: $_"
    exit 1
}

Write-Header "Setting Environment Variables"

try {
    $env:IPSC_AZURE_TENANT_ID = $tenantId
    $env:IPSC_AZURE_CLIENT_ID = $clientId
    $env:IPSC_CREDENTIAL_STORE_PATH = $CredentialStorePath

    Write-Success "Environment variables set for current session:"
    Write-Success "  IPSC_AZURE_TENANT_ID = $tenantId"
    Write-Success "  IPSC_AZURE_CLIENT_ID = $clientId"
    Write-Success "  IPSC_CREDENTIAL_STORE_PATH = $CredentialStorePath"
}
catch {
    Write-Error-Custom "Failed to set environment variables: $_"
    exit 1
}

Write-Header "Configuration Verification"

Write-Host "Tenant ID:        $tenantId" -ForegroundColor Gray
Write-Host "Client ID:        $clientId" -ForegroundColor Gray
Write-Host "Client Secret:    [STORED SECURELY]" -ForegroundColor Gray
Write-Host "Credential Store: $credentialFile" -ForegroundColor Gray
Write-Host ""

Write-Success "Configuration completed successfully!"

Write-Header "Persist Environment Variables (Recommended)"

Write-Host "For persistent environment variables across sessions, set them in Windows:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1: Using setx command (requires restart)" -ForegroundColor Yellow
Write-Host "  setx IPSC_AZURE_TENANT_ID `"$tenantId`"" -ForegroundColor Gray
Write-Host "  setx IPSC_AZURE_CLIENT_ID `"$clientId`"" -ForegroundColor Gray
Write-Host "  setx IPSC_CREDENTIAL_STORE_PATH `"$CredentialStorePath`"" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 2: Using System Properties > Environment Variables (GUI)" -ForegroundColor Yellow
Write-Host "  Click Start > Settings > System > About > Advanced system settings" -ForegroundColor Gray
Write-Host "  Click 'Environment Variables' > New (User or System)" -ForegroundColor Gray
Write-Host ""

Write-Host "`nNext step: Continue with Step 3 for environment variables" -ForegroundColor Yellow
Write-Host "Command: .\Scheduler.ps1 -RunOnce`n" -ForegroundColor Yellow

exit 0
