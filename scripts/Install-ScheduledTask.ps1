#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Install IPSC Kurs Watcher as Windows Scheduled Task
.DESCRIPTION
    Registers the watcher to run at system startup with highest privileges
.PARAMETER WatcherPath
    Path to Watcher.ps1 script
.PARAMETER ConfigPath
    Path to configuration file (default: config/config.json relative to script)
.PARAMETER TaskName
    Name of scheduled task (default: IPSC-Kurs-Watcher)
.PARAMETER RunAsUser
    User account to run task under (default: SYSTEM)
.EXAMPLE
    .\Install-ScheduledTask.ps1 -WatcherPath "C:\IPSC\Watcher.ps1"
.NOTES
    Requires administrator privileges
#>

param(
    [Parameter(Mandatory)]
    [string]$WatcherPath,

    [string]$ConfigPath = "config/config.json",

    [string]$TaskName = "IPSC-Kurs-Watcher",

    [string]$RunAsUser = "SYSTEM"
)

$ErrorActionPreference = 'Stop'

function Test-AdminPrivileges {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Register-WatcherTask {
    param(
        [string]$WatcherPath,
        [string]$ConfigPath,
        [string]$TaskName,
        [string]$RunAsUser
    )

    Write-Host "Registering scheduled task: $TaskName"

    if (-not (Test-Path $WatcherPath)) {
        throw "Watcher script not found: $WatcherPath"
    }

    $WatcherPath = (Resolve-Path $WatcherPath).Path
    Write-Host "Watcher script: $WatcherPath"

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Warning: Config file not found: $ConfigPath" -ForegroundColor Yellow
    } else {
        $ConfigPath = (Resolve-Path $ConfigPath).Path
    }

    Write-Host "Config file: $ConfigPath"

    # Create task action
    $taskAction = New-ScheduledTaskAction `
        -Execute "PowerShell.exe" `
        -Argument "-NoProfile -ExecutionPolicy RemoteSigned -File `"$WatcherPath`" -ConfigPath `"$ConfigPath`"" `
        -WorkingDirectory (Split-Path $WatcherPath)

    # Create task trigger (run at system startup)
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup

    # Create task settings
    $taskSettings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -RunOnlyIfNetworkAvailable

    # Create task principal (run as SYSTEM with highest privileges)
    $taskPrincipal = New-ScheduledTaskPrincipal `
        -UserId $RunAsUser `
        -LogonType ServiceAccount `
        -RunLevel Highest

    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($existingTask) {
        Write-Host "Task already exists, updating..."
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Start-Sleep -Milliseconds 500
    }

    # Register the task
    $task = Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $taskAction `
        -Trigger $taskTrigger `
        -Settings $taskSettings `
        -Principal $taskPrincipal `
        -Description "IPSC Kurs Watcher - Automated course monitoring and notifications"

    Write-Host "Scheduled task registered successfully: $($task.TaskName)" -ForegroundColor Green

    return $task
}

function Show-TaskInfo {
    param([object]$Task)

    Write-Host ""
    Write-Host "Task Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($Task.TaskName)"
    Write-Host "  State: $($Task.State)"
    Write-Host "  Trigger: AtStartup"
    Write-Host "  Run Level: Highest"
    Write-Host "  Principal: SYSTEM"
    Write-Host ""
}

function Test-TaskExecution {
    param([string]$TaskName)

    Write-Host "Testing task execution..."
    Start-ScheduledTask -TaskName $TaskName

    Start-Sleep -Seconds 2

    $lastRun = Get-ScheduledTaskInfo -TaskName $TaskName
    Write-Host "Last run result: $($lastRun.LastTaskResult)"
    Write-Host "Last run time: $($lastRun.LastRunTime)"

    if ($lastRun.LastTaskResult -eq 0) {
        Write-Host "Task executed successfully" -ForegroundColor Green
    } else {
        Write-Host "Task execution failed with code: $($lastRun.LastTaskResult)" -ForegroundColor Yellow
    }
}

# Main execution
try {
    if (-not (Test-AdminPrivileges)) {
        throw "This script requires administrator privileges. Please run as administrator."
    }

    $task = Register-WatcherTask -WatcherPath $WatcherPath `
                                 -ConfigPath $ConfigPath `
                                 -TaskName $TaskName `
                                 -RunAsUser $RunAsUser

    Show-TaskInfo -Task $task

    Write-Host "Attempting test execution..." -ForegroundColor Cyan
    Test-TaskExecution -TaskName $TaskName

    Write-Host ""
    Write-Host "Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Manage task with:"
    Write-Host "  Start:   Start-ScheduledTask -TaskName '$TaskName'"
    Write-Host "  Stop:    Stop-ScheduledTask -TaskName '$TaskName'"
    Write-Host "  View:    Get-ScheduledTask -TaskName '$TaskName'"
    Write-Host "  Remove:  Unregister-ScheduledTask -TaskName '$TaskName'"

} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
