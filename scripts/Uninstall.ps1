#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Complete uninstall orchestrator for IPSC Kurs Watcher.

.DESCRIPTION
Removes all IPSC Kurs Watcher components in reverse order:
1. Remove Windows Scheduled Task
2. Remove environment variables
3. Remove Azure AD credentials
4. Remove app identity

Each step requires confirmation before execution.

.EXAMPLE
.\Uninstall.ps1
#>

. "$PSScriptRoot\modules\SetupFunctions.ps1"

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Text)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-Warning-Custom {
    param([string]$Text)
    Write-Host "[WARN] $Text" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Confirm-Step {
    param([string]$Message)
    $response = Read-Host "$Message (yes/no)"
    return $response -eq 'yes'
}

Write-Header "IPSC Kurs Watcher - Complete Uninstall"

Write-Warning-Custom "This will remove ALL IPSC Kurs Watcher components:" -ForegroundColor Yellow
Write-Host "  1. Windows Scheduled Task" -ForegroundColor Yellow
Write-Host "  2. Environment variables" -ForegroundColor Yellow
Write-Host "  3. Azure AD credentials and encryption keys" -ForegroundColor Yellow
Write-Host "  4. App identity registry entries" -ForegroundColor Yellow
Write-Host ""

$final = Read-Host "Are you absolutely sure you want to uninstall everything? (yes/no)"
if ($final -ne 'yes') {
    Write-Host "[INFO] Uninstall cancelled" -ForegroundColor Gray
    exit 0
}

$stepsFailed = 0

# ============================================================================
# STEP 1: REMOVE SCHEDULED TASK (OPTIONAL - REQUIRES ADMIN)
# ============================================================================

Write-Header "Step 1: Remove Scheduled Task (Optional)"

$taskName = "IPSC-Kurs-Watcher"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($task) {
    Write-Host "Found Scheduled Task: '$taskName'" -ForegroundColor Cyan
    Write-Host ""

    if (Confirm-Step "Do you want to remove this Scheduled Task?") {
        $result = Invoke-RemoveScheduledTask
        if ($result) {
            Write-Success "Step 1 completed"
        }
        else {
            Write-Warning-Custom "Step 1 failed"
            $stepsFailed++
        }
    }
    else {
        Write-Host "[INFO] Step 1 skipped - Scheduled Task will remain" -ForegroundColor Gray
    }
}
else {
    Write-Host "No Scheduled Task found (was never set up)" -ForegroundColor Gray
    Write-Host "[INFO] Step 1 skipped" -ForegroundColor Gray
}

# ============================================================================
# STEP 2: REMOVE ENVIRONMENT VARIABLES
# ============================================================================

Write-Header "Step 2: Remove Environment Variables"

Write-Host "Removing Azure and Discord environment variables..." -ForegroundColor Gray
Write-Host ""

$result = Invoke-RemoveEnvironmentVariables
if ($result) {
    Write-Success "Step 2 completed"
}
else {
    Write-Warning-Custom "Step 2 failed or was skipped"
    $stepsFailed++
}

# ============================================================================
# STEP 3: REMOVE AZURE CREDENTIALS
# ============================================================================

Write-Header "Step 3: Remove Azure AD Credentials"

Write-Host "Removing encrypted Azure Client Secret..." -ForegroundColor Gray
Write-Host ""

if (Confirm-Step "Remove Azure credentials?") {
    $CredentialStorePath = "$env:APPDATA\IPSC-Kurs-Watcher\credentials"
    $credentialFile = Join-Path $CredentialStorePath "IPSC-Kurs-Watcher-Secret.bin"

    try {
        if (Test-Path $credentialFile) {
            Remove-Item -Path $credentialFile -Force
            Write-Success "Azure credentials removed"
        }
        else {
            Write-Host "[INFO] Credential file not found (already removed)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Warning-Custom "Failed to remove credential file: $_"
        $stepsFailed++
    }
}
else {
    Write-Host "[INFO] Step 3 skipped" -ForegroundColor Gray
}

# ============================================================================
# STEP 4: REMOVE APP IDENTITY
# ============================================================================

Write-Header "Step 4: Remove App Identity"

Write-Host "Removing Toast notification app identity from registry..." -ForegroundColor Gray
Write-Host ""

$result = Invoke-RemoveAppIdentity
if ($result) {
    Write-Success "Step 4 completed"
}
else {
    Write-Warning-Custom "Step 4 failed or was skipped"
    $stepsFailed++
}

# ============================================================================
# COMPLETION
# ============================================================================

Write-Header "Uninstall Complete"

if ($stepsFailed -eq 0) {
    Write-Success "All components have been removed successfully"
}
else {
    Write-Warning-Custom "$stepsFailed step(s) failed or were skipped"
    Write-Host "You can manually remove remaining components by running individual Remove-* scripts" -ForegroundColor Gray
}

Write-Host ""
Write-Host "To reinstall later, run: .\Setup.ps1`n" -ForegroundColor Gray

exit 0
