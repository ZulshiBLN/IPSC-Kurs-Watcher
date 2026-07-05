#Requires -Version 5.1

<#
.SYNOPSIS
Publish IPSC Kurs Watcher module to PowerShell Gallery

.DESCRIPTION
Publishes the module to PowerShell Gallery (PSGallery) for distribution.
This script is called by GitHub Actions during release automation.

.PARAMETER NuGetApiKey
PowerShell Gallery API key (from secrets)

.PARAMETER ModulePath
Path to module root directory (default: current directory)

.PARAMETER Repository
Target repository (default: PSGallery)

.EXAMPLE
.\Publish-ToGallery.ps1 -NuGetApiKey $apiKey -ModulePath "."

.NOTES
Called by: .github/workflows/release.yml
Policy: Only stable releases are published (pre-releases excluded)
#>

param(
    [ValidateNotNullOrEmpty()][string]$NuGetApiKey,
    [ValidateNotNullOrEmpty()][string]$ModulePath = ".",
    [string]$Repository = "PSGallery"
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "PowerShell Gallery Publishing Script"
Write-Host "=========================================="
Write-Host ""

# Validate NuGet API key is not empty
if ([string]::IsNullOrEmpty($NuGetApiKey)) {
    Write-Error "NuGetApiKey is required for publishing"
    exit 1
}

# Find module manifest (.psd1)
$manifestPath = Get-ChildItem -Path $ModulePath -Filter "*.psd1" -Depth 1 | Select-Object -ExpandProperty FullName

if (-not $manifestPath) {
    Write-Error "No PowerShell module manifest (.psd1) found in $ModulePath"
    exit 1
}

Write-Host "Found manifest: $manifestPath"

# Parse manifest to get module version
try {
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    $moduleVersion = $manifest.Version
    $moduleName = $manifest.Name

    Write-Host "Module: $moduleName"
    Write-Host "Version: $moduleVersion"
} catch {
    Write-Error "Failed to validate module manifest: $_"
    exit 1
}

# Check if module already exists in PSGallery with this version
Write-Host ""
Write-Host "Checking existing versions on PowerShell Gallery..."
try {
    $existingModule = Find-Module -Name $moduleName -RequiredVersion $moduleVersion -Repository $Repository -ErrorAction SilentlyContinue

    if ($existingModule) {
        Write-Warning "Module version $moduleVersion already exists on PowerShell Gallery!"
        Write-Host "Skipping publish (version already published)"
        Write-Host ""
        Write-Host "To publish a new version:"
        Write-Host "1. Update version in $manifestPath"
        Write-Host "2. Create new git tag: git tag v<version>"
        Write-Host "3. Push tag: git push origin v<version>"
        exit 0
    } else {
        Write-Host "✓ Version $moduleVersion is new (not yet on PSGallery)"
    }
} catch {
    Write-Warning "Unable to check existing versions (may be network issue): $_"
    Write-Host "Proceeding with publish attempt..."
}

# Publish module to PSGallery
Write-Host ""
Write-Host "Publishing module to PowerShell Gallery..."
Write-Host "Repository: $Repository"
Write-Host ""

try {
    Publish-Module -Path $ModulePath `
        -NuGetApiKey $NuGetApiKey `
        -Repository $Repository `
        -Force `
        -ErrorAction Stop

    Write-Host "✓ Successfully published to PowerShell Gallery!"
    Write-Host ""
    Write-Host "Module available at:"
    Write-Host "  https://www.powershellgallery.com/packages/$moduleName/$moduleVersion"
    Write-Host ""
    Write-Host "Installation command:"
    Write-Host "  Install-Module -Name $moduleName -RequiredVersion $moduleVersion"

} catch {
    Write-Error "Failed to publish module: $_"
    Write-Host ""
    Write-Host "Troubleshooting:"
    Write-Host "1. Verify NuGetApiKey is correct (from https://www.powershellgallery.com/account/Edit)"
    Write-Host "2. Verify module manifest is valid: Test-ModuleManifest -Path '$manifestPath'"
    Write-Host "3. Check PSGallery status: https://www.powershellgallery.com/"
    exit 1
}

exit 0
