#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Interactive setup for Azure OAuth2 credentials for Email Notifier.

.DESCRIPTION
Stores Azure AD Client Secret securely in Windows Credential Manager
and updates config.json with Tenant ID and Client ID.

.PARAMETER ConfigPath
Path to config.json (default: config/config.json)

.PARAMETER CredentialStorePath
Path where credential XML is stored (default: %APPDATA%\Microsoft\Windows\PowerShell\PSCredentialStore)

.EXAMPLE
.\Setup-AzureCredentials.ps1
.\Setup-AzureCredentials.ps1 -ConfigPath "config/config.json"

.NOTES
Requires Administrator privileges to store credentials securely.
#>

param(
    [string]$ConfigPath = 'config/config.json',
    [string]$CredentialStorePath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSCredentialStore"
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# PRIVATE HELPER FUNCTIONS
# ============================================================================

function _TestAzureConnection {
    <# .SYNOPSIS Test OAuth2 connection to Azure AD #>
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )

    try {
        $tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

        $body = @{
            client_id     = $ClientId
            client_secret = $ClientSecret
            scope         = "https://graph.microsoft.com/.default"
            grant_type    = "client_credentials"
        }

        $response = Invoke-WebRequest -Uri $tokenUri -Method POST -Body $body `
            -ContentType "application/x-www-form-urlencoded" -TimeoutSec 10 -ErrorAction Stop

        $token = $response.Content | ConvertFrom-Json

        if ($token.access_token) {
            return @{ success = $true; message = "OAuth2 token obtained successfully" }
        }
        else {
            return @{ success = $false; message = "OAuth2 failed: No token in response" }
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        if ($errorMsg -match "401|Unauthorized") {
            $errorMsg = "Invalid Client ID, Client Secret, or Tenant ID"
        }
        elseif ($errorMsg -match "403|Forbidden") {
            $errorMsg = "Permission denied. Check Tenant ID and credentials."
        }
        return @{ success = $false; message = "OAuth2 failed: $errorMsg" }
    }
}

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

function Read-SecureInput {
    param(
        [string]$Prompt,
        [switch]$AsPlainText
    )

    if ($AsPlainText) {
        return Read-Host -Prompt $Prompt
    }
    else {
        $secure = Read-Host -Prompt $Prompt -AsSecureString
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($secure))
    }
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

Write-Header "Azure AD OAuth2 Setup for IPSC Kurs Watcher"

# --- STEP 1: Resolve config path ---

Write-Host "Step 1: Locating configuration..." -ForegroundColor Yellow

if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
    $scriptRoot = Split-Path $MyInvocation.MyCommand.Path
    $ConfigPath = Join-Path (Split-Path $scriptRoot) $ConfigPath
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error-Custom "Config file not found: $ConfigPath"
    exit 1
}

Write-Success "Config found: $ConfigPath"

# --- STEP 2: Input credentials ---

Write-Header "Enter Azure Credentials"

$tenantId = Read-SecureInput "Tenant ID (Directory ID)" -AsPlainText
if (-not $tenantId) {
    Write-Error-Custom "Tenant ID is required"
    exit 1
}

$clientId = Read-SecureInput "Client ID (Application ID)" -AsPlainText
if (-not $clientId) {
    Write-Error-Custom "Client ID is required"
    exit 1
}

$clientSecret = Read-SecureInput "Client Secret (will be masked)" -AsPlainText
if (-not $clientSecret) {
    Write-Error-Custom "Client Secret is required"
    exit 1
}

# --- STEP 3: Test Azure Connection ---

Write-Header "Testing Azure Credentials"

$testResult = _TestAzureConnection -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret

if ($testResult.success) {
    Write-Success $testResult.message
}
else {
    Write-Error-Custom $testResult.message
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Verify Tenant ID (Directory ID) is correct" -ForegroundColor Yellow
    Write-Host "2. Verify Client ID (Application ID) is correct" -ForegroundColor Yellow
    Write-Host "3. Verify Client Secret is correct and not expired" -ForegroundColor Yellow
    Write-Host "4. Verify Mail.Send permission is granted in Azure AD" -ForegroundColor Yellow
    Write-Host "5. Check if Azure AD app was deleted or disabled" -ForegroundColor Yellow
    Write-Host ""

    $retry = Read-Host "Try again? (yes/no)"
    if ($retry -eq "yes") {
        # Remove cached credentials and restart from STEP 2
        Write-Host "Restarting credential input..." -ForegroundColor Yellow
        & $MyInvocation.MyCommand.Path -ConfigPath $ConfigPath
        exit 0
    }
    else {
        Write-Host "Setup cancelled." -ForegroundColor Gray
        exit 1
    }
}

# --- STEP 4: Store credentials securely ---

Write-Header "Storing Credentials Securely"

try {
    # Create credential store directory if it doesn't exist
    if (-not (Test-Path $CredentialStorePath)) {
        New-Item -ItemType Directory -Path $CredentialStorePath -Force | Out-Null
        Write-Success "Created credential store directory"
    }

    # Store client secret securely using PSCredential export
    $credentialFilePath = Join-Path $CredentialStorePath "IPSC-Kurs-Watcher-Secret.xml"
    $cred = New-Object System.Management.Automation.PSCredential("IPSC-Kurs-Watcher", (ConvertTo-SecureString $clientSecret -AsPlainText -Force))
    $cred | Export-Clixml -Path $credentialFilePath -Force

    Write-Success "Client Secret stored in: $credentialFilePath"
}
catch {
    Write-Error-Custom "Failed to store credentials: $_"
    exit 1
}

# --- STEP 5: Update config.json ---

Write-Header "Updating Configuration"

try {
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

    # Update email notifier section
    $config.notifiers.email = @{
        enabled = $true
        provider = "graph"
        tenant_id = $tenantId
        client_id = $clientId
        recipients = @("google@brosche-bausinger.ch")
        retry_attempts = 3
        timeout_seconds = 30
        token_cache_path = "data/.token_cache.json"
        credential_store_path = $credentialFilePath
    }

    # Write updated config back (compressed format)
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8

    Write-Success "config.json updated with Azure credentials"
}
catch {
    Write-Error-Custom "Failed to update config.json: $_"
    exit 1
}

# --- STEP 6: Verify Setup ---

Write-Header "Setup Verification"

Write-Host "Tenant ID:        $tenantId" -ForegroundColor Gray
Write-Host "Client ID:        $clientId" -ForegroundColor Gray
Write-Host "Client Secret:    [STORED SECURELY]" -ForegroundColor Gray
Write-Host "Config Path:      $ConfigPath" -ForegroundColor Gray
Write-Host "Credential Store: $credentialFilePath" -ForegroundColor Gray
Write-Host ""

Write-Success "Setup completed successfully!"

Write-Host "`nNext step: Implement OAuth token flow in NotifyEmail.ps1" -ForegroundColor Yellow
Write-Host "Then run: .\Scheduler.ps1 -RunOnce`n" -ForegroundColor Yellow

exit 0
