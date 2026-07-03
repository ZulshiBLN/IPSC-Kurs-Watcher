#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build script for IPSC Kurs Watcher - Validates code quality and structure
.DESCRIPTION
    Runs PSScriptAnalyzer for linting, validates config schema, checks folder structure
.PARAMETER Validate
    Run validation checks (PSScriptAnalyzer, config schema, etc.)
.PARAMETER Clean
    Remove build artifacts (logs, temp files)
.EXAMPLE
    .\build.ps1 -Validate
#>
[CmdletBinding()]
param(
    [switch]$Validate,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Title {
    param([string]$Text)
    Write-Host "`n========== $Text ==========" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Error {
    param([string]$Text)
    Write-Host "[ERROR] $Text" -ForegroundColor Red
}

# Install PSScriptAnalyzer if missing
Write-Title "Checking Prerequisites"
try {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Write-Success "PSScriptAnalyzer installed"
} catch {
    Write-Host "Installing PSScriptAnalyzer..." -ForegroundColor Yellow
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
    Import-Module PSScriptAnalyzer
}

if ($Validate) {
    Write-Title "Running PSScriptAnalyzer"
    $psFilesPath = Join-Path $script:ScriptPath "src"
    $analyzeParams = @{
        Path = $psFilesPath
        Settings = (Join-Path $script:ScriptPath "PSScriptAnalyzerSettings.psd1")
        Recurse = $true
    }

    $results = Invoke-ScriptAnalyzer @analyzeParams

    if ($results) {
        Write-Error "PSScriptAnalyzer found issues:"
        $results | Format-Table -AutoSize
        exit 1
    } else {
        Write-Success "No PSScriptAnalyzer issues found"
    }

    Write-Title "Validating Config Schema"
    $configPath = Join-Path $script:ScriptPath "config/config.example.json"
    $schemaPath = Join-Path $script:ScriptPath "config/config.schema.json"

    if (Test-Path $configPath -PathType Leaf) {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            Write-Success "config.example.json is valid JSON"
        } catch {
            Write-Error "config.example.json is invalid JSON: $_"
            exit 1
        }
    }

    Write-Title "Validating Folder Structure"
    $requiredFolders = @("src/core", "src/monitors", "src/filters", "src/notifiers", "src/utils", "config", "data/logs", "tests")
    foreach ($folder in $requiredFolders) {
        $folderPath = Join-Path $script:ScriptPath $folder
        if (Test-Path $folderPath -PathType Container) {
            Write-Success "Folder exists: $folder"
        } else {
            Write-Error "Missing folder: $folder"
            exit 1
        }
    }

    Write-Title "Build Validation Complete"
    Write-Success "All checks passed!"
}

if ($Clean) {
    Write-Title "Cleaning Build Artifacts"
    $itemsToClean = @(
        "build/*",
        "data/logs/*",
        ".PSScriptAnalyzerCache"
    )

    foreach ($item in $itemsToClean) {
        $itemPath = Join-Path $script:ScriptPath $item
        if (Test-Path $itemPath) {
            Remove-Item $itemPath -Recurse -Force
            Write-Success "Removed: $item"
        }
    }
}

if (-not $Validate -and -not $Clean) {
    Write-Title "IPSC Kurs Watcher - Build Script"
    Write-Host @"
Usage:
  .\build.ps1 -Validate      Run validation checks (PSScriptAnalyzer, config, folders)
  .\build.ps1 -Clean         Remove build artifacts and temp files

Default: Show this help message
"@
}
