#Requires -Version 5.1

<#
.SYNOPSIS
Unregister IPSC Kurs Monitor app identity from Windows.

.DESCRIPTION
Removes registry entries created by Install-AppIdentity.ps1.
Restores Toast notifications to display default PowerShell app name.

No administrator privileges required.

.EXAMPLE
.\Uninstall-AppIdentity.ps1
#>

$appName = "IPSC Kurs Monitor"
$regPath = "HKCU:\Software\Classes\CLSID\{12345678-1234-1234-1234-123456789012}"

Write-Host "Unregistering '$appName' app identity..."

try {
    # Check if registry entry exists
    if (Test-Path $regPath) {
        # Remove registry entry
        Remove-Item -Path $regPath -Recurse -Force
        Write-Host "[OK] '$appName' unregistered successfully" -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] App identity not found in registry (already removed)" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "[ERROR] Failed to unregister app: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Uninstall complete. Toast notifications will revert to default PowerShell app name." -ForegroundColor Green
