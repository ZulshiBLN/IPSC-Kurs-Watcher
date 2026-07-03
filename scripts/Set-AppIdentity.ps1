#Requires -Version 5.1

<#
.SYNOPSIS
Register IPSC Kurs Monitor as a Windows app for Toast notifications.

.DESCRIPTION
Creates registry entries to display "IPSC Kurs Monitor" as the app name
in Toast notifications instead of "Microsoft.PowerShell...".

Needs to run once per user. No administrator privileges required.

.EXAMPLE
.\Set-AppIdentity.ps1
#>

$appName = "IPSC Kurs Monitor"
$appDescription = "IPSC Course Monitoring and Notifications"

# Registry path for app registration
$regPath = "HKCU:\Software\Classes\CLSID\{12345678-1234-1234-1234-123456789012}"
$appUserModelId = "IPSC.KursMonitor"

Write-Host "Registering '$appName' for Toast notifications..."

try {
    # Create registry entry for app
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    # Set app properties
    Set-ItemProperty -Path $regPath -Name "(Default)" -Value $appName -Force
    Set-ItemProperty -Path $regPath -Name "AppUserModelID" -Value $appUserModelId -Force

    # Create LocalizedString entry (display name)
    $localizedPath = "$regPath\LocalizedString"
    if (-not (Test-Path $localizedPath)) {
        New-Item -Path $localizedPath -Force | Out-Null
    }
    Set-ItemProperty -Path $localizedPath -Name "(Default)" -Value $appName -Force

    # Create DefaultIcon entry (optional, PowerShell icon)
    $iconPath = "$regPath\DefaultIcon"
    if (-not (Test-Path $iconPath)) {
        New-Item -Path $iconPath -Force | Out-Null
    }
    $powershellExe = (Get-Command powershell.exe).Source
    Set-ItemProperty -Path $iconPath -Name "(Default)" -Value $powershellExe -Force

    Write-Host "[OK] '$appName' registered successfully" -ForegroundColor Green
    Write-Host "App User Model ID: $appUserModelId" -ForegroundColor Cyan
}
catch {
    Write-Host "[ERROR] Failed to register app: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Setup complete. Toast notifications will now show '$appName' as the app name." -ForegroundColor Green
