#Requires -Version 5.1

<#
.SYNOPSIS
Remove IPSC Kurs Watcher Scheduled Task from Windows.

.DESCRIPTION
Removes the IPSC Kurs Watcher scheduled task created by Set-ScheduledTask.ps1.
The task will no longer run automatically.

Requires administrator privileges.

.EXAMPLE
.\Remove-ScheduledTask.ps1
#>

. "$PSScriptRoot\modules\SetupFunctions.ps1"

$ErrorActionPreference = "Stop"

# Validate administrator privileges
$isAdmin = [Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains `
    [Security.Principal.SecurityIdentifier]"S-1-5-32-544"

if (-not $isAdmin) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Remove Scheduled Task" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Host "[ERROR] This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Remove Scheduled Task" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "This will remove the IPSC-Kurs-Watcher scheduled task." -ForegroundColor Yellow
$confirm = Read-Host "Are you sure you want to proceed? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "[INFO] Operation cancelled" -ForegroundColor Gray
    exit 0
}

$success = Invoke-RemoveScheduledTask

Write-Host ""
if ($success) {
    Write-Host "Note: IPSC Kurs Watcher will no longer run automatically." -ForegroundColor Yellow
    Write-Host "To run monitoring manually, use:" -ForegroundColor Yellow
    Write-Host "  .\Scheduler.ps1`n" -ForegroundColor Gray
    exit 0
}
else {
    exit 1
}
