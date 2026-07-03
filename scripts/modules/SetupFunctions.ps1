#Requires -Version 5.1

<#
.SYNOPSIS
IPSC Kurs Watcher setup and teardown functions.

.DESCRIPTION
Reusable functions for setting up and removing IPSC Kurs Watcher components.
Used by Setup.ps1, Uninstall.ps1, and individual Set-/Remove-* scripts.
#>

# ============================================================================
# APP IDENTITY FUNCTIONS
# ============================================================================

function Invoke-SetAppIdentity {
    [CmdletBinding()]
    param()

    $appName = "IPSC Kurs Monitor"
    $regPath = "HKCU:\Software\Classes\CLSID\{12345678-1234-1234-1234-123456789012}"
    $appUserModelId = "IPSC.KursMonitor"

    Write-Host "Registering '$appName' for Toast notifications..."

    try {
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }

        Set-ItemProperty -Path $regPath -Name "(Default)" -Value $appName -Force
        Set-ItemProperty -Path $regPath -Name "AppUserModelID" -Value $appUserModelId -Force

        $localizedPath = "$regPath\LocalizedString"
        if (-not (Test-Path $localizedPath)) {
            New-Item -Path $localizedPath -Force | Out-Null
        }
        Set-ItemProperty -Path $localizedPath -Name "(Default)" -Value $appName -Force

        $iconPath = "$regPath\DefaultIcon"
        if (-not (Test-Path $iconPath)) {
            New-Item -Path $iconPath -Force | Out-Null
        }
        $powershellExe = (Get-Command powershell.exe).Source
        Set-ItemProperty -Path $iconPath -Name "(Default)" -Value $powershellExe -Force

        Write-Host "[OK] '$appName' registered successfully" -ForegroundColor Green
        Write-Host "App User Model ID: $appUserModelId" -ForegroundColor Cyan
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to register app: $_" -ForegroundColor Red
        return $false
    }
}

function Invoke-RemoveAppIdentity {
    [CmdletBinding()]
    param()

    $appName = "IPSC Kurs Monitor"
    $regPath = "HKCU:\Software\Classes\CLSID\{12345678-1234-1234-1234-123456789012}"

    Write-Host "Removing '$appName' app identity..."

    try {
        if (Test-Path $regPath) {
            Remove-Item -Path $regPath -Recurse -Force
            Write-Host "[OK] '$appName' app identity removed successfully" -ForegroundColor Green
        }
        else {
            Write-Host "[INFO] App identity not found in registry (already removed)" -ForegroundColor Cyan
        }
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to remove app identity: $_" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# ENVIRONMENT VARIABLES FUNCTIONS
# ============================================================================

function Invoke-SetEnvironmentVariables {
    [CmdletBinding()]
    param()

    Write-Host "Setting environment variables..."

    # Use Tenant ID from Step 2 if already verified, otherwise ask
    if ($env:IPSC_AZURE_TENANT_ID) {
        $tenantId = $env:IPSC_AZURE_TENANT_ID
    }
    else {
        $tenantId = Read-Host "Azure Tenant ID (Directory ID)"
        if (-not $tenantId) {
            Write-Host "[ERROR] Tenant ID is required" -ForegroundColor Red
            return $false
        }
    }

    # Use Client ID from Step 2 if already verified, otherwise ask
    if ($env:IPSC_AZURE_CLIENT_ID) {
        $clientId = $env:IPSC_AZURE_CLIENT_ID
    }
    else {
        $clientId = Read-Host "Azure Client ID (Application ID)"
        if (-not $clientId) {
            Write-Host "[ERROR] Client ID is required" -ForegroundColor Red
            return $false
        }
    }

    # Sender Email (singular) - the mailbox that sends notifications
    $senderEmail = Read-Host "Email Sender Address (mailbox for sending notifications)"
    if (-not $senderEmail) {
        Write-Host "[ERROR] Sender email is required" -ForegroundColor Red
        return $false
    }

    $emailPattern = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if ($senderEmail -notmatch $emailPattern) {
        Write-Host "[ERROR] Invalid sender email format: $senderEmail" -ForegroundColor Red
        return $false
    }

    # Recipient Emails (comma-separated) - who receives the notifications
    $recipientEmails = Read-Host "Email Recipient Addresses (comma-separated: user1@example.com,user2@example.com)"
    if (-not $recipientEmails) {
        Write-Host "[ERROR] At least one recipient email is required" -ForegroundColor Red
        return $false
    }

    $recipients = @($recipientEmails -split ',').Trim() | Where-Object { $_ }
    if ($recipients.Count -eq 0) {
        Write-Host "[ERROR] At least one valid recipient email is required" -ForegroundColor Red
        return $false
    }

    foreach ($email in $recipients) {
        if ($email -notmatch $emailPattern) {
            Write-Host "[ERROR] Invalid recipient email format: $email" -ForegroundColor Red
            return $false
        }
    }

    $recipientEmails = $recipients -join ','

    $credStorePath = Read-Host "Credential Store Path (press Enter for default)"
    if (-not $credStorePath) {
        $credStorePath = "$env:APPDATA\IPSC-Kurs-Watcher\credentials"
        Write-Host "Using default: $credStorePath" -ForegroundColor Gray
    }

    $discordWebhooks = Read-Host "Discord Webhook URLs (press Enter to skip)"

    try {
        [System.Environment]::SetEnvironmentVariable("IPSC_AZURE_TENANT_ID", $tenantId, [System.EnvironmentVariableTarget]::User)
        Write-Host "[OK] IPSC_AZURE_TENANT_ID set" -ForegroundColor Green

        [System.Environment]::SetEnvironmentVariable("IPSC_AZURE_CLIENT_ID", $clientId, [System.EnvironmentVariableTarget]::User)
        Write-Host "[OK] IPSC_AZURE_CLIENT_ID set" -ForegroundColor Green

        [System.Environment]::SetEnvironmentVariable("IPSC_EMAIL_SENDER", $senderEmail, [System.EnvironmentVariableTarget]::User)
        Write-Host "[OK] IPSC_EMAIL_SENDER set" -ForegroundColor Green

        [System.Environment]::SetEnvironmentVariable("IPSC_EMAIL_RECIPIENTS", $recipientEmails, [System.EnvironmentVariableTarget]::User)
        Write-Host "[OK] IPSC_EMAIL_RECIPIENTS set" -ForegroundColor Green

        [System.Environment]::SetEnvironmentVariable("IPSC_CREDENTIAL_STORE_PATH", $credStorePath, [System.EnvironmentVariableTarget]::User)
        Write-Host "[OK] IPSC_CREDENTIAL_STORE_PATH set" -ForegroundColor Green

        if ($discordWebhooks) {
            [System.Environment]::SetEnvironmentVariable("IPSC_DISCORD_WEBHOOKS", $discordWebhooks, [System.EnvironmentVariableTarget]::User)
            Write-Host "[OK] IPSC_DISCORD_WEBHOOKS set" -ForegroundColor Green
        }
        else {
            Write-Host "[INFO] IPSC_DISCORD_WEBHOOKS skipped" -ForegroundColor Gray
        }

        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to set environment variables: $_" -ForegroundColor Red
        return $false
    }
}

function Invoke-RemoveEnvironmentVariables {
    [CmdletBinding()]
    param()

    Write-Host "Removing environment variables..."

    $variables = @(
        "IPSC_AZURE_TENANT_ID",
        "IPSC_AZURE_CLIENT_ID",
        "IPSC_EMAIL_SENDER",
        "IPSC_EMAIL_RECIPIENTS",
        "IPSC_CREDENTIAL_STORE_PATH",
        "IPSC_DISCORD_WEBHOOKS"
    )

    try {
        foreach ($var in $variables) {
            $value = [System.Environment]::GetEnvironmentVariable($var, [System.EnvironmentVariableTarget]::User)
            if ($value) {
                [System.Environment]::SetEnvironmentVariable($var, $null, [System.EnvironmentVariableTarget]::User)
                Write-Host "[OK] $var removed" -ForegroundColor Green
            }
            else {
                Write-Host "[INFO] $var not set (skipped)" -ForegroundColor Gray
            }
        }
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to remove environment variables: $_" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# SCHEDULED TASK FUNCTIONS
# ============================================================================

function Invoke-SetScheduledTask {
    [CmdletBinding()]
    param()

    $isAdmin = [Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains `
        [Security.Principal.SecurityIdentifier]"S-1-5-32-544"

    if (-not $isAdmin) {
        Write-Host "[ERROR] This operation requires Administrator privileges" -ForegroundColor Red
        return $false
    }

    $taskName = "IPSC-Kurs-Watcher"
    $taskDescription = "Automated IPSC course monitoring and notifications"
    $scriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $schedulerScript = Join-Path $scriptRoot "Scheduler.ps1"

    if (-not (Test-Path $schedulerScript)) {
        Write-Host "[ERROR] Scheduler.ps1 not found at: $schedulerScript" -ForegroundColor Red
        return $false
    }

    Write-Host "Configuring monitoring schedule..."
    Write-Host "Select trigger type:"
    Write-Host "  1. Daily at specific time" -ForegroundColor Cyan
    Write-Host "  2. Every N minutes" -ForegroundColor Cyan
    Write-Host "  3. At system startup" -ForegroundColor Cyan

    $choice = Read-Host "Enter choice (1-3)"

    try {
        switch ($choice) {
            "1" {
                $time = Read-Host "Enter time for daily run (e.g., 06:00, 14:30)"
                $trigger = New-ScheduledTaskTrigger -Daily -At $time
                Write-Host "[OK] Daily trigger set to: $time" -ForegroundColor Green
            }
            "2" {
                $minutes = Read-Host "Enter interval in minutes (e.g., 30, 60)"
                if (-not ($minutes -match '^\d+$')) {
                    Write-Host "[ERROR] Please enter a valid number" -ForegroundColor Red
                    return $false
                }
                $timespan = New-TimeSpan -Minutes $minutes
                # RepetitionDuration set to 1 year (365 days) for practical unlimited repetition
                $duration = New-TimeSpan -Days 365
                $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval $timespan -RepetitionDuration $duration
                Write-Host "[OK] Repeating trigger set to: Every $minutes minutes" -ForegroundColor Green
            }
            "3" {
                $trigger = New-ScheduledTaskTrigger -AtStartup
                Write-Host "[OK] Startup trigger configured" -ForegroundColor Green
            }
            default {
                Write-Host "[ERROR] Invalid choice" -ForegroundColor Red
                return $false
            }
        }

        $action = New-ScheduledTaskAction `
            -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$schedulerScript`""

        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -MultipleInstances IgnoreNew

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
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to create scheduled task: $_" -ForegroundColor Red
        return $false
    }
}

function Invoke-RemoveScheduledTask {
    [CmdletBinding()]
    param()

    $isAdmin = [Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains `
        [Security.Principal.SecurityIdentifier]"S-1-5-32-544"

    if (-not $isAdmin) {
        Write-Host "[ERROR] This operation requires Administrator privileges" -ForegroundColor Red
        return $false
    }

    $taskName = "IPSC-Kurs-Watcher"

    Write-Host "Checking for scheduled task: '$taskName'..." -ForegroundColor Green

    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    if (-not $task) {
        Write-Host "[INFO] Scheduled task '$taskName' not found (already removed)" -ForegroundColor Gray
        return $true
    }

    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "[OK] Scheduled task '$taskName' removed successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to remove scheduled task: $_" -ForegroundColor Red
        return $false
    }
}
