#Requires -Version 5.1

<#
.SYNOPSIS
Remove Azure OAuth2 credentials and encryption keys.

.DESCRIPTION
Deletes Azure AD Client Secret from encrypted storage
and removes related environment variables.

.EXAMPLE
.\Remove-AzureCredentials.ps1
#>

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
    $response = Read-Host "$Message (yes/no)"
    return $response -eq 'yes'
}

Write-Header "Azure AD OAuth2 Credentials Removal"

Write-Warning-Custom "This will:"
Write-Host "  1. Delete Client Secret from encrypted storage" -ForegroundColor Yellow
Write-Host "  2. Remove Azure environment variables" -ForegroundColor Yellow
Write-Host ""

if (-not (Confirm-Action "Are you sure you want to proceed?")) {
    Write-Host "Cancelled." -ForegroundColor Gray
    exit 0
}

Write-Host "`n=== Removing Encrypted Credentials ===" -ForegroundColor Green

$CredentialStorePath = "$env:APPDATA\IPSC-Kurs-Watcher\credentials"
$credentialFile = Join-Path $CredentialStorePath "IPSC-Kurs-Watcher-Secret.bin"

try {
    if (Test-Path $credentialFile) {
        Remove-Item -Path $credentialFile -Force
        Write-Success "Credential file deleted: $credentialFile"
    }
    else {
        Write-Warning-Custom "Credential file not found (already removed?)"
    }
}
catch {
    Write-Error-Custom "Failed to delete credential file: $_"
    exit 1
}

Write-Host "`n=== Removing Environment Variables ===" -ForegroundColor Green

$variables = @(
    "IPSC_AZURE_TENANT_ID",
    "IPSC_AZURE_CLIENT_ID",
    "IPSC_CREDENTIAL_STORE_PATH"
)

try {
    foreach ($var in $variables) {
        $value = [System.Environment]::GetEnvironmentVariable($var, [System.EnvironmentVariableTarget]::User)
        if ($value) {
            [System.Environment]::SetEnvironmentVariable($var, $null, [System.EnvironmentVariableTarget]::User)
            Write-Success "$var removed"
        }
    }
}
catch {
    Write-Error-Custom "Failed to remove environment variables: $_"
    exit 1
}

Write-Header "Removal Completed"

Write-Success "All Azure credentials have been removed."
Write-Host "Email notifications are now disabled." -ForegroundColor Yellow

exit 0
