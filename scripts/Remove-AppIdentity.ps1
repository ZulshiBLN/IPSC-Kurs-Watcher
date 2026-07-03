#Requires -Version 5.1

<#
.SYNOPSIS
Remove IPSC Kurs Monitor app identity from Windows registry.

.DESCRIPTION
Removes registry entries created by Set-AppIdentity.ps1.
Restores Toast notifications to display default PowerShell app name.

No administrator privileges required.

.EXAMPLE
.\Remove-AppIdentity.ps1
#>

$appName = "IPSC Kurs Monitor"
$regPath = "HKCU:\Software\Classes\CLSID\{12345678-1234-1234-1234-123456789012}"

Write-Host "Removing '$appName' app identity..."

try {
    # Check if registry entry exists
    if (Test-Path $regPath) {
        # Remove registry entry
        Remove-Item -Path $regPath -Recurse -Force
        Write-Host "[OK] '$appName' app identity removed successfully" -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] App identity not found in registry (already removed)" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "[ERROR] Failed to remove app identity: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Removal complete. Toast notifications will revert to default PowerShell app name." -ForegroundColor Green
