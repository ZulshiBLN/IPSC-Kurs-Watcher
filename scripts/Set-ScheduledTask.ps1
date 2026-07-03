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
Write-Host "IPSC Kurs Watcher - Scheduled Task Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Fixed parameters
$taskName = "IPSC-Kurs-Watcher"
$taskDescription = "Automated IPSC course monitoring and notifications"

# Find script path
$scriptRoot = Split-Path -Parent $PSScriptRoot
$schedulerScript = Join-Path $scriptRoot "Scheduler.ps1"

if (-not (Test-Path $schedulerScript)) {
    Write-Host "[ERROR] Scheduler.ps1 not found at: $schedulerScript" -ForegroundColor Red
    exit 1
}

Write-Host "Script path: $schedulerScript`n" -ForegroundColor Gray

# Configure trigger timing
Write-Host "=== Configure Monitoring Schedule ===" -ForegroundColor Green

$options = @(
    "Daily at specific time",
    "Every N minutes",
    "At system startup"
)

Write-Host "Select trigger type:"
for ($i = 0; $i -lt $options.Count; $i++) {
    Write-Host "  $($i + 1). $($options[$i])" -ForegroundColor Cyan
}

$choice = Read-Host "Enter choice (1-3)"

switch ($choice) {
    "1" {
        # Daily trigger
        $time = Read-Host "Enter time for daily run (e.g., 06:00, 14:30)"
        try {
            $trigger = New-ScheduledTaskTrigger -Daily -At $time
            Write-Host "[OK] Daily trigger set to: $time" -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Invalid time format: $_" -ForegroundColor Red
            exit 1
        }
    }
    "2" {
        # Repeat trigger
        $minutes = Read-Host "Enter interval in minutes (e.g., 30, 60)"
        if (-not ($minutes -match '^\d+$')) {
            Write-Host "[ERROR] Please enter a valid number" -ForegroundColor Red
            exit 1
        }
        $timespan = New-TimeSpan -Minutes $minutes
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval $timespan -RepetitionDuration ([timespan]::MaxValue)
        Write-Host "[OK] Repeating trigger set to: Every $minutes minutes" -ForegroundColor Green
    }
    "3" {
        # Startup trigger
        $trigger = New-ScheduledTaskTrigger -AtStartup
        Write-Host "[OK] Startup trigger configured" -ForegroundColor Green
    }
    default {
        Write-Host "[ERROR] Invalid choice" -ForegroundColor Red
        exit 1
    }
}

# Create action
Write-Host "`n=== Configuring Task Action ===" -ForegroundColor Green

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$schedulerScript`""

Write-Host "[OK] Task action configured" -ForegroundColor Green

# Create task settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

Write-Host "[OK] Task settings configured" -ForegroundColor Green

# Register task
Write-Host "`n=== Creating Scheduled Task ===" -ForegroundColor Green

try {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Write-Host "[INFO] Task '$taskName' already exists, updating..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }

    Register-ScheduledTask `
        -TaskName $taskName `
        -Description $taskDescription `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -RunLevel Limited `
        -User $env:USERNAME

    Write-Host "[OK] Scheduled Task '$taskName' created successfully" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to create scheduled task: $_" -ForegroundColor Red
    exit 1
}

# Verify
Write-Host "`n=== Verification ===" -ForegroundColor Green
$task = Get-ScheduledTask -TaskName $taskName
Write-Host "Task Name:   $($task.TaskName)" -ForegroundColor Cyan
Write-Host "Status:      $($task.State)" -ForegroundColor Cyan
Write-Host "Run Level:   Limited (non-admin)" -ForegroundColor Cyan
Write-Host "User:        $env:USERNAME" -ForegroundColor Cyan

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "[OK] Scheduled Task setup completed!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  - Run once to verify: powershell -NoProfile -ExecutionPolicy Bypass -File `"$schedulerScript`"" -ForegroundColor Gray
Write-Host "  - Check Windows Task Scheduler: taskschd.msc" -ForegroundColor Gray
Write-Host "  - View task logs in Event Viewer`n" -ForegroundColor Gray

exit 0
