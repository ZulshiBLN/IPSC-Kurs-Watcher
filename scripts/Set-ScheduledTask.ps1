#Requires -Version 5.1

<#
.SYNOPSIS
Create IPSC Kurs Watcher as a Windows Scheduled Task.

.DESCRIPTION
Sets up a Windows Scheduled Task to run IPSC Kurs Watcher automatically
at specified intervals. The task runs Scheduler.ps1 with monitoring enabled.

Requires administrator privileges.

.EXAMPLE
.\Set-ScheduledTask.ps1
#>

. "$PSScriptRoot\modules\SetupFunctions.ps1"

$ErrorActionPreference = "Stop"

# Validate administrator privileges
$isAdmin = [Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains `
    [Security.Principal.SecurityIdentifier]"S-1-5-32-544"

if (-not $isAdmin) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "IPSC Kurs Watcher - Scheduled Task Setup" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Host "[ERROR] This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "IPSC Kurs Watcher - Scheduled Task Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$success = Invoke-SetScheduledTask

Write-Host ""
if ($success) {
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  - Check Windows Task Scheduler: taskschd.msc" -ForegroundColor Gray
    Write-Host "  - View task logs in Event Viewer`n" -ForegroundColor Gray
    exit 0
}
else {
    exit 1
}
