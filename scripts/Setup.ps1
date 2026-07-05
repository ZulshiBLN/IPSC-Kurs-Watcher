#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Complete setup orchestrator for IPSC Kurs Watcher.

.DESCRIPTION
Guides through all setup steps in the correct order:
1. Register app identity for Toast notifications
2. Configure Azure AD OAuth2 credentials
3. Set environment variables
4. Create Windows Scheduled Task (optional, requires admin)

Each step can be skipped or run individually using the Set-* scripts.

.EXAMPLE
.\Setup.ps1
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

function Confirm-Step {
    param([string]$Message)
    $response = Read-Host "$Message (yes/no)"
    return $response -eq 'yes'
}

Write-Header "IPSC Kurs Watcher - Complete Setup"

Write-Host "This setup wizard will configure IPSC Kurs Watcher in the following order:" -ForegroundColor Yellow
Write-Host "  1. App Identity (Toast notifications)" -ForegroundColor Gray
Write-Host "  2. Azure AD OAuth2 credentials" -ForegroundColor Gray
Write-Host "  3. Environment variables" -ForegroundColor Gray
Write-Host "  4. Scheduled Task (optional, requires admin)" -ForegroundColor Gray
Write-Host ""


# ============================================================================
# STEP 1: APP IDENTITY
# ============================================================================

Write-Header "Step 1: Register App Identity for Toast Notifications"

Write-Host "This registers 'IPSC Kurs Monitor' as the app name in Windows Toast notifications." -ForegroundColor Gray
Write-Host ""

$result = Invoke-SetAppIdentity
if ($result) {
    Write-Success "Step 1 completed"
}
else {
    Write-Host "[WARN] Step 1 failed" -ForegroundColor Yellow
    Write-Host "You can retry later with: .\Set-AppIdentity.ps1" -ForegroundColor Gray
}

# ============================================================================
# STEP 2: AZURE CREDENTIALS
# ============================================================================

Write-Header "Step 2: Configure Azure AD OAuth2 Credentials"

Write-Host "This sets up authentication with Azure AD and Microsoft Graph API." -ForegroundColor Gray
Write-Host "You will need:" -ForegroundColor Gray
Write-Host "  - Azure Tenant ID (Directory ID)" -ForegroundColor Gray
Write-Host "  - Azure Client ID (Application ID)" -ForegroundColor Gray
Write-Host "  - Azure Client Secret" -ForegroundColor Gray
Write-Host ""

# Call the standalone Set-AzureCredentials script to handle all the logic
& "$PSScriptRoot\Set-AzureCredentials.ps1"

Write-Success "Step 2 completed"

# ============================================================================
# STEP 3: ENVIRONMENT VARIABLES
# ============================================================================

Write-Header "Step 3: Set Environment Variables"

Write-Host "This sets persistent environment variables needed for operation:" -ForegroundColor Gray
Write-Host "  - IPSC_AZURE_TENANT_ID" -ForegroundColor Gray
Write-Host "  - IPSC_AZURE_CLIENT_ID" -ForegroundColor Gray
Write-Host "  - IPSC_AZURE_USER_ID (recipient email)" -ForegroundColor Gray
Write-Host "  - IPSC_CREDENTIAL_STORE_PATH (optional)" -ForegroundColor Gray
Write-Host "  - IPSC_DISCORD_WEBHOOKS (optional)" -ForegroundColor Gray
Write-Host ""

$result = Invoke-SetEnvironmentVariables
if ($result) {
    Write-Success "Step 3 completed"
}
else {
    Write-Host "[WARN] Step 3 failed" -ForegroundColor Yellow
    Write-Host "You can retry later with: .\Set-EnvironmentVariables.ps1" -ForegroundColor Gray
}

# ============================================================================
# STEP 4: SCHEDULED TASK (OPTIONAL, REQUIRES ADMIN)
# ============================================================================

Write-Header "Step 4: Create Scheduled Task (Optional)"

Write-Host "This creates an automated task to run IPSC Kurs Watcher at regular intervals." -ForegroundColor Gray
Write-Host "(You can skip this and run monitoring manually with .\Scheduler.ps1)" -ForegroundColor Gray
Write-Host ""

if (Confirm-Step "Do you want to set up the Scheduled Task now?") {
    Write-Host ""
    $result = Invoke-SetScheduledTask
    if ($result) {
        Write-Success "Step 4 completed"
    }
    else {
        Write-Host "[WARN] Step 4 skipped or failed" -ForegroundColor Yellow
    }
}
else {
    Write-Host "[INFO] Step 4 skipped - you can run later with: .\Set-ScheduledTask.ps1" -ForegroundColor Gray
}

# ============================================================================
# COMPLETION
# ============================================================================

Write-Header "Setup Complete!"

Write-Host "Your IPSC Kurs Watcher is now configured." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test the monitoring: .\Scheduler.ps1 -RunOnce" -ForegroundColor Gray
Write-Host "  2. Check logs for any warnings" -ForegroundColor Gray
Write-Host "  3. Monitor will run automatically if Scheduled Task was set up" -ForegroundColor Gray
Write-Host ""

Write-Host "To remove/reconfigure:" -ForegroundColor Yellow
Write-Host "  1. Run .\Uninstall.ps1 to remove all components" -ForegroundColor Gray
Write-Host "  2. Or run individual Remove-* scripts" -ForegroundColor Gray
Write-Host ""

exit 0
