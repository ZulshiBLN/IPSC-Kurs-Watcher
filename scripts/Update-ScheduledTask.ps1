#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Updates the existing IPSC-Kurs-Watcher Scheduled Task with hidden window and RunOnce mode.

.DESCRIPTION
Re-registers the scheduled task with the correct parameters to run hidden and in RunOnce mode
(so it doesn't loop for 30 minutes).

.EXAMPLE
.\Update-ScheduledTask.ps1
#>

$taskName = "IPSC-Kurs-Watcher"
$schedulerScript = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "Scheduler.ps1"

Write-Host "Updating Scheduled Task: $taskName" -ForegroundColor Cyan
Write-Host "Script: $schedulerScript`n" -ForegroundColor Gray

$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Host "[ERROR] Scheduled Task '$taskName' not found" -ForegroundColor Red
    Write-Host "Please run .\Set-ScheduledTask.ps1 first to create the task" -ForegroundColor Yellow
    exit 1
}

try {
    Write-Host "Removing old task configuration..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false

    Write-Host "Creating new task with correct parameters..." -ForegroundColor Yellow

    # Get the old trigger to reuse it
    $oldTriggers = $task.Triggers
    if (-not $oldTriggers -or $oldTriggers.Count -eq 0) {
        Write-Host "[WARN] No triggers found, using default (30 minute interval)" -ForegroundColor Yellow
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 365)
    }
    else {
        $trigger = $oldTriggers
    }

    # Create new action with hidden window and RunOnce
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$schedulerScript`" -RunOnce"

    # Preserve old settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew

    # Register updated task
    Register-ScheduledTask `
        -TaskName $taskName `
        -Description $task.Description `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -RunLevel Limited `
        -User $env:USERNAME

    Write-Host "[OK] Scheduled Task updated successfully" -ForegroundColor Green
    Write-Host "`nChanges made:" -ForegroundColor Cyan
    Write-Host "  - PowerShell window now runs hidden (-WindowStyle Hidden)" -ForegroundColor Green
    Write-Host "  - Script runs once and exits (-RunOnce)" -ForegroundColor Green
    Write-Host "  - Task will repeat at configured interval" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to update scheduled task: $_" -ForegroundColor Red
    exit 1
}
