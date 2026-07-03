#Requires -Version 5.1

<#
.SYNOPSIS
    Interactive configuration tool for IPSC Kurs Watcher
.DESCRIPTION
    Allows adding/editing monitors, course types, and notification settings
.EXAMPLE
    .\Configure-Watcher.ps1 -ConfigPath "config/config.json"
#>

param(
    [string]$ConfigPath = "config/config.json"
)

$ErrorActionPreference = 'Stop'

. (Join-Path (Split-Path $PSScriptRoot) "src/core/Config.ps1")

function Show-MainMenu {
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "IPSC Kurs Watcher - Configuration Manager" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1] View Monitors"
    Write-Host "[2] View Course Types"
    Write-Host "[3] View Notification Settings"
    Write-Host "[4] Add Monitor"
    Write-Host "[5] Add Course Type"
    Write-Host "[6] Edit Email Settings"
    Write-Host "[7] Save & Exit"
    Write-Host ""
}

function Show-Monitors {
    param([hashtable]$Config)

    Write-Host ""
    Write-Host "Monitors:" -ForegroundColor Cyan
    Write-Host "-" * 60

    foreach ($i = 0; $i -lt $Config.monitors.Count; $i++) {
        $m = $Config.monitors[$i]
        $status = if ($m.enabled) { "[ENABLED]" } else { "[DISABLED]" }
        Write-Host "$($i + 1). $($m.name) $status"
        Write-Host "   Provider: $($m.provider) | Poll: $($m.poll_interval_minutes)min"
    }
}

function Show-CourseTypes {
    param([hashtable]$Config)

    Write-Host ""
    Write-Host "Course Types:" -ForegroundColor Cyan
    Write-Host "-" * 60

    foreach ($i = 0; $i -lt $Config.filters.course_types.Count; $i++) {
        $ct = $Config.filters.course_types[$i]
        $status = if ($ct.enabled) { "[ENABLED]" } else { "[DISABLED]" }
        Write-Host "$($i + 1). $($ct.name) $status"
        Write-Host "   Patterns: $($ct.patterns -join ', ')"
    }
}

function Show-Notifiers {
    param([hashtable]$Config)

    Write-Host ""
    Write-Host "Notification Channels:" -ForegroundColor Cyan
    Write-Host "-" * 60

    # Email
    $emailStatus = if ($Config.notifiers.email.enabled) { "ENABLED" } else { "DISABLED" }
    Write-Host "Email: $emailStatus" -ForegroundColor $(if ($Config.notifiers.email.enabled) { "Green" } else { "Yellow" })
    Write-Host "  SMTP: $($Config.notifiers.email.smtp_server)"
    Write-Host "  From: $($Config.notifiers.email.from_address)"
    Write-Host "  Recipients: $($Config.notifiers.email.recipients -join ', ')"

    # Discord
    $discordStatus = if ($Config.notifiers.discord.enabled) { "ENABLED" } else { "DISABLED" }
    Write-Host ""
    Write-Host "Discord: $discordStatus" -ForegroundColor $(if ($Config.notifiers.discord.enabled) { "Green" } else { "Yellow" })
    Write-Host "  Webhook: $($Config.notifiers.discord.webhook_url)"

    # Toast
    $toastStatus = if ($Config.notifiers.windows_toast.enabled) { "ENABLED" } else { "DISABLED" }
    Write-Host ""
    Write-Host "Windows Toast: $toastStatus" -ForegroundColor $(if ($Config.notifiers.windows_toast.enabled) { "Green" } else { "Yellow" })
}

function Add-NewMonitor {
    param([hashtable]$Config)

    Write-Host ""
    Write-Host "Add New Monitor:" -ForegroundColor Cyan

    $name = Read-Host "Monitor name (e.g., 'shooting-store')"
    $provider = Read-Host "Provider type (e.g., 'shooting-store')"
    $url = Read-Host "URL"
    $interval = Read-Host "Poll interval in minutes (default: 15)" | ForEach-Object { if ($_) { [int]$_ } else { 15 } }

    $monitor = @{
        id = $name.ToLower().Replace(" ", "-")
        name = $name
        provider = $provider
        url = $url
        poll_interval_minutes = $interval
        enabled = $true
        request_timeout_seconds = 30
        retry_attempts = 3
    }

    $Config.monitors += $monitor

    Write-Host ""
    Write-Host "Monitor added! Current monitors: $($Config.monitors.Count)" -ForegroundColor Green

    return $Config
}

function Add-NewCourseType {
    param([hashtable]$Config)

    Write-Host ""
    Write-Host "Add New Course Type:" -ForegroundColor Cyan

    $name = Read-Host "Course type name"
    $patterns = Read-Host "Patterns (comma-separated, e.g., 'Service Pistol, SP')"

    $courseType = @{
        id = $name.ToLower().Replace(" ", "-")
        name = $name
        patterns = @($patterns -split ',' | ForEach-Object { $_.Trim() })
        enabled = $true
    }

    $Config.filters.course_types += $courseType

    Write-Host ""
    Write-Host "Course type added! Current types: $($Config.filters.course_types.Count)" -ForegroundColor Green

    return $Config
}

function Edit-EmailSettings {
    param([hashtable]$Config)

    Write-Host ""
    Write-Host "Email Configuration:" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Current Settings:"
    Show-Notifiers $Config

    Write-Host ""
    Write-Host "Edit Email Settings (leave blank to keep current):"

    $smtp = Read-Host "SMTP Server (current: $($Config.notifiers.email.smtp_server))"
    if ($smtp) { $Config.notifiers.email.smtp_server = $smtp }

    $port = Read-Host "SMTP Port (current: $($Config.notifiers.email.port))"
    if ($port) { $Config.notifiers.email.port = [int]$port }

    $from = Read-Host "From Address (current: $($Config.notifiers.email.from_address))"
    if ($from) { $Config.notifiers.email.from_address = $from }

    $recipients = Read-Host "Recipients (comma-separated, current: $($Config.notifiers.email.recipients -join ', '))"
    if ($recipients) { $Config.notifiers.email.recipients = @($recipients -split ',' | ForEach-Object { $_.Trim() }) }

    $enableEmail = Read-Host "Enable Email? (y/n, current: $(if ($Config.notifiers.email.enabled) { 'enabled' } else { 'disabled' }))"
    if ($enableEmail) { $Config.notifiers.email.enabled = $enableEmail -eq 'y' }

    Write-Host ""
    Write-Host "Email settings updated!" -ForegroundColor Green

    return $Config
}

# Main execution
Write-Host ""
Write-Host "Loading configuration..." -ForegroundColor Gray

if (-not (Test-Path $ConfigPath)) {
    Write-Host "Configuration not found at: $ConfigPath" -ForegroundColor Yellow
    $createNew = Read-Host "Create from template? (y/n)"
    if ($createNew -eq 'y') {
        Copy-Item "config/config.example.json" $ConfigPath
        Write-Host "Created new config!" -ForegroundColor Green
    } else {
        exit 1
    }
}

$config = Read-Config -ConfigPath $ConfigPath
Write-Host "Configuration loaded from: $ConfigPath" -ForegroundColor Green

# Main loop
$done = $false
while (-not $done) {
    Show-MainMenu
    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" { Show-Monitors $config }
        "2" { Show-CourseTypes $config }
        "3" { Show-Notifiers $config }
        "4" { $config = Add-NewMonitor $config }
        "5" { $config = Add-NewCourseType $config }
        "6" { $config = Edit-EmailSettings $config }
        "7" {
            Write-Host ""
            Write-Host "Saving configuration..." -ForegroundColor Cyan
            Save-Config -Config $config -ConfigPath $ConfigPath
            Write-Host "Configuration saved successfully!" -ForegroundColor Green
            $done = $true
        }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

Write-Host ""
Write-Host "Configuration complete!" -ForegroundColor Green
