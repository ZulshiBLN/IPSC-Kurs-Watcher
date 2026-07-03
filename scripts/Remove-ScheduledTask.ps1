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

$ErrorActionPreference = "Stop"

# Validate administrator privileges
$isAdmin = [Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains `
    [Security.Principal.SecurityIdentifier]"S-1-5-32-544"

if (-not $isAdmin) {
    Write-Host "[ERROR] This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Remove Scheduled Task" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$taskName = "IPSC-Kurs-Watcher"

# Check if task exists
Write-Host "Checking for scheduled task: '$taskName'..." -ForegroundColor Green

$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if (-not $task) {
    Write-Host "[INFO] Scheduled task '$taskName' not found (already removed)" -ForegroundColor Gray
    exit 0
}

# Show task info
Write-Host "Found task:" -ForegroundColor Cyan
Write-Host "  Name:    $($task.TaskName)" -ForegroundColor Gray
Write-Host "  Status:  $($task.State)" -ForegroundColor Gray
Write-Host "  Path:    $($task.TaskPath)" -ForegroundColor Gray

# Confirmation
Write-Host ""
$confirm = Read-Host "Are you sure you want to remove this task? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "[INFO] Operation cancelled" -ForegroundColor Gray
    exit 0
}

# Remove task
Write-Host "`n=== Removing Scheduled Task ===" -ForegroundColor Green

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "[OK] Scheduled task '$taskName' removed successfully" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to remove scheduled task: $_" -ForegroundColor Red
    exit 1
}

# Verify removal
Write-Host "`n=== Verification ===" -ForegroundColor Green
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($taskExists) {
    Write-Host "[ERROR] Task still exists" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "[OK] Task successfully removed" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "[OK] Scheduled Task removal completed!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Note: IPSC Kurs Watcher will no longer run automatically." -ForegroundColor Yellow
Write-Host "To run monitoring manually, use:" -ForegroundColor Yellow
Write-Host "  .\Scheduler.ps1`n" -ForegroundColor Gray

exit 0
