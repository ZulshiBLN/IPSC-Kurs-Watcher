#Requires -Version 5.1
<#
.SYNOPSIS
Build and validation script for IPSC Kurs Watcher.
.DESCRIPTION
Runs PSScriptAnalyzer, syntax checks, and JSON validation.
.PARAMETER Validate
Run validation checks
.EXAMPLE
.\build.ps1 -Validate
#>
param([switch]$Validate, [switch]$Test, [switch]$All)

$ErrorActionPreference = 'Continue'
$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent

# Determine what to run
if (-not $Validate -and -not $Test -and -not $All) { $Validate = $true }
if ($All) { $Validate = $true; $Test = $true }

$totalFailed = 0
$totalPassed = 0

# ============================================================================
# PSScriptAnalyzer Validation
# ============================================================================

if ($Validate) {
    Write-Host "`n=== PSScriptAnalyzer Linting ===" -ForegroundColor Cyan

    if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable)) {
        Write-Host "[WARN] PSScriptAnalyzer not installed, installing..." -ForegroundColor Yellow
        Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser | Out-Null
    }

    $srcPath = Join-Path $ScriptRoot 'src'
    $psFiles = Get-ChildItem -Path $srcPath -Filter '*.ps1' -Recurse

    foreach ($file in $psFiles) {
        $analysis = Invoke-ScriptAnalyzer -Path $file.FullName -Severity Error, Warning -ErrorAction SilentlyContinue

        if ($analysis) {
            Write-Host "[FAIL] $($file.Name)" -ForegroundColor Red
            $analysis | ForEach-Object {
                Write-Host "  Line $($_.Line): $($_.Message)" -ForegroundColor Red
            }
            $totalFailed++
        }
        else {
            Write-Host "[OK] $($file.Name)" -ForegroundColor Green
            $totalPassed++
        }
    }
}

# ============================================================================
# Syntax Validation
# ============================================================================

if ($Validate) {
    Write-Host "`n=== Syntax Validation ===" -ForegroundColor Cyan

    $srcPath = Join-Path $ScriptRoot 'src'
    $psFiles = Get-ChildItem -Path $srcPath -Filter '*.ps1' -Recurse

    foreach ($file in $psFiles) {
        $tokens = @()
        $parseErrors = @()

        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $file.FullName -Raw),
            [ref]$tokens,
            [ref]$parseErrors
        )

        if ($parseErrors.Count -gt 0) {
            Write-Host "[FAIL] $($file.Name)" -ForegroundColor Red
            $parseErrors | ForEach-Object {
                Write-Host "  Line $($_.Token.StartLine): $($_.Message)" -ForegroundColor Red
            }
            $totalFailed++
        }
        else {
            Write-Host "[OK] $($file.Name)" -ForegroundColor Green
            $totalPassed++
        }
    }
}

# ============================================================================
# JSON Validation
# ============================================================================

if ($Validate) {
    Write-Host "`n=== JSON Validation ===" -ForegroundColor Cyan

    $configPath = Join-Path $ScriptRoot 'config/config.json'
    if (Test-Path $configPath) {
        try {
            $null = Get-Content $configPath | ConvertFrom-Json
            Write-Host "[OK] config.json" -ForegroundColor Green
            $totalPassed++
        }
        catch {
            Write-Host "[FAIL] config.json - $_" -ForegroundColor Red
            $totalFailed++
        }
    }
}

# ============================================================================
# Summary
# ============================================================================

Write-Host "`n=== BUILD SUMMARY ===" -ForegroundColor Cyan
Write-Host "Passed: $totalPassed" -ForegroundColor Green
Write-Host "Failed: $totalFailed" -ForegroundColor $(if ($totalFailed -eq 0) { 'Green' } else { 'Red' })

if ($totalFailed -eq 0) {
    Write-Host "`n[OK] All checks passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`n[ERROR] Build validation failed!" -ForegroundColor Red
    exit 1
}
