#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Remove Azure OAuth2 credentials and revert email configuration.

.DESCRIPTION
Deletes Azure AD Client Secret from Windows Credential Manager
and reverts config.json email section to default SMTP settings.

.PARAMETER ConfigPath
Path to config.json (default: config/config.json)

.PARAMETER CredentialStorePath
Path where credential XML is stored (default: %APPDATA%\Microsoft\Windows\PowerShell\PSCredentialStore)

.PARAMETER Force
Skip confirmation prompts

.EXAMPLE
.\Remove-AzureCredentials.ps1
.\Remove-AzureCredentials.ps1 -Force

.NOTES
Requires Administrator privileges.
#>

param(
    [string]$ConfigPath = 'config/config.json',
    [string]$CredentialStorePath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSCredentialStore",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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

function Write-Warning-Custom {
    param([string]$Text)
    Write-Host "[WARN] $Text" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Text)
    Write-Host "[ERROR] $Text" -ForegroundColor Red
}

function Confirm-Action {
    param([string]$Message)

    if ($Force) {
        return $true
    }

    $response = Read-Host "$Message (yes/no)"
    return $response -eq 'yes'
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

Write-Header "Azure AD OAuth2 Credentials Removal"

Write-Warning-Custom "This will:"
Write-Host "  1. Delete Client Secret from Credential Manager" -ForegroundColor Yellow
Write-Host "  2. Revert config.json email section to default SMTP" -ForegroundColor Yellow
Write-Host "  3. Disable email notifications" -ForegroundColor Yellow
Write-Host ""

if (-not (Confirm-Action "Are you sure you want to proceed?")) {
    Write-Host "Cancelled." -ForegroundColor Gray
    exit 0
}

# --- STEP 1: Resolve config path ---

Write-Host "`nStep 1: Locating configuration..." -ForegroundColor Yellow

if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
    $scriptRoot = Split-Path $MyInvocation.MyCommand.Path
    $ConfigPath = Join-Path (Split-Path $scriptRoot) $ConfigPath
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error-Custom "Config file not found: $ConfigPath"
    exit 1
}

Write-Success "Config found: $ConfigPath"

# --- STEP 2: Remove credentials from Credential Manager ---

Write-Host "`nStep 2: Removing credentials..." -ForegroundColor Yellow

$credentialFile = Join-Path $CredentialStorePath "IPSC-Kurs-Watcher-Secret.bin"

try {
    if (Test-Path $credentialFile) {
        Remove-Item -Path $credentialFile -Force
        Write-Success "Credential file deleted: $credentialFile"
    }
    else {
        Write-Warning-Custom "Credential file not found (already removed?): $credentialFile"
    }
}
catch {
    Write-Error-Custom "Failed to delete credential file: $_"
    exit 1
}

# --- STEP 3: Revert config.json ---

Write-Host "`nStep 3: Reverting configuration..." -ForegroundColor Yellow

try {
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

    # Reset email notifier to default SMTP settings
    $config.notifiers.email = @{
        enabled = $false
        smtp_host = "smtp.gmail.com"
        smtp_port = 587
        use_tls = $true
        from_address = "your-email@example.com"
        from_display_name = "IPSC Kurs Watcher"
        smtp_user = "your-email@gmail.com"
        smtp_password = "app-specific-password"
        recipients = @("user@example.com")
        retry_attempts = 3
        timeout_seconds = 30
        template_file = "templates/email.html"
    }

    # Write updated config back (compressed format)
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8

    Write-Success "config.json reverted to default SMTP settings"
}
catch {
    Write-Error-Custom "Failed to update config.json: $_"
    exit 1
}

# --- STEP 4: Summary ---

Write-Header "Removal Completed"

Write-Host "Removed:" -ForegroundColor Yellow
Write-Host "  - Client Secret from Credential Manager" -ForegroundColor Gray
Write-Host "  - Azure OAuth2 configuration from config.json" -ForegroundColor Gray
Write-Host "  - Email notifications (disabled)" -ForegroundColor Gray
Write-Host ""
Write-Host "Config Path: $ConfigPath" -ForegroundColor Gray
Write-Host ""

Write-Success "All Azure credentials have been removed."
Write-Host "Email notifications are now disabled." -ForegroundColor Yellow

exit 0
