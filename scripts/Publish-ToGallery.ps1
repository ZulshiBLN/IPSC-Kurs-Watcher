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
        Write-Host "[OK] Version $moduleVersion is new (not yet on PSGallery)"
    }
} catch {
    Write-Warning "Unable to check existing versions (may be network issue): $_"
    Write-Host "Proceeding with publish attempt..."
}

# Create temporary staging directory for publishing (cross-platform)
$tempDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
$tempStaging = Join-Path $tempDir "PSGallery-$moduleName-$(Get-Random)"
$moduleDir = Join-Path $tempStaging $moduleName

try {
    Write-Host ""
    Write-Host "Creating staging directory for publishing..."
    New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
    Write-Host "Staging directory: $moduleDir"

    # Copy manifest
    $destManifest = Join-Path $moduleDir "$moduleName.psd1"
    Copy-Item $manifestPath -Destination $destManifest -Force
    Write-Host "[OK] Copied manifest to $destManifest"

    # Copy PSM1 module
    $psmPath = Join-Path $ModulePath "$moduleName.psm1"
    if (Test-Path $psmPath) {
        $destPsm = Join-Path $moduleDir "$moduleName.psm1"
        Copy-Item $psmPath -Destination $destPsm -Force
        Write-Host "[OK] Copied PSM1 module to $destPsm"
    } else {
        Write-Host "[WARN] PSM1 module not found at $psmPath"
    }

    # Copy source files
    $srcPath = Join-Path $ModulePath "src"
    if (Test-Path $srcPath) {
        $destSrc = Join-Path $moduleDir "src"
        Copy-Item $srcPath -Destination $destSrc -Recurse -Force
        Write-Host "[OK] Copied source files to $destSrc"
    } else {
        Write-Host "[WARN] Source directory not found at $srcPath"
    }

    # Copy documentation
    $docsPath = Join-Path $ModulePath "docs"
    if (Test-Path $docsPath) {
        $destDocs = Join-Path $moduleDir "docs"
        Copy-Item $docsPath -Destination $destDocs -Recurse -Force
        Write-Host "[OK] Copied documentation to $destDocs"
    } else {
        Write-Host "[WARN] Documentation directory not found at $docsPath"
    }

    # Validate the staged module
    Write-Host ""
    Write-Host "Validating staged module manifest..."
    $stagedManifest = Test-ModuleManifest -Path $destManifest -ErrorAction Stop
    Write-Host "[OK] Staged manifest is valid"
    Write-Host "  Module: $($stagedManifest.Name)"
    Write-Host "  Version: $($stagedManifest.Version)"

    # Publish module to PSGallery
    Write-Host ""
    Write-Host "Publishing module to PowerShell Gallery..."
    Write-Host "Repository: $Repository"
    Write-Host "Module path: $moduleDir"
    Write-Host ""

    # Use verbose output to capture more details
    $publishParams = @{
        Path = $moduleDir
        NuGetApiKey = $NuGetApiKey
        Repository = $Repository
        Force = $true
        ErrorAction = "Stop"
        Verbose = $true
    }

    Publish-Module @publishParams

    Write-Host ""
    Write-Host "=========================================="
    Write-Host "[OK] Successfully published to PowerShell Gallery!"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Module available at:"
    Write-Host "  https://www.powershellgallery.com/packages/$moduleName/$moduleVersion"
    Write-Host ""
    Write-Host "Installation command:"
    Write-Host "  Install-Module -Name $moduleName -RequiredVersion $moduleVersion"

} catch {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "ERROR: Failed to publish module"
    Write-Host "=========================================="
    Write-Host ""
    Write-Error $_.Exception.Message
    Write-Host ""
    Write-Host "Full Error Details:"
    Write-Host $_.Exception.ToString()
    Write-Host ""
    Write-Host "Troubleshooting:"
    Write-Host "1. Verify NuGetApiKey is correct (from https://www.powershellgallery.com/account/Edit)"
    Write-Host "2. Verify staged manifest is valid: Test-ModuleManifest -Path '$destManifest'"
    Write-Host "3. Check staging directory contents: ls -la '$moduleDir'"
    Write-Host "4. Check PSGallery status: https://www.powershellgallery.com/"
    exit 1
} finally {
    # Cleanup staging directory
    Write-Host ""
    Write-Host "Cleaning up staging directory..."
    if (Test-Path $tempStaging) {
        Remove-Item $tempStaging -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Staging directory cleaned up"
    }
}

exit 0
