#Requires -Version 5.1

<#
.SYNOPSIS
    Run all Pester tests for IPSC Kurs Watcher
.DESCRIPTION
    Executes unit and integration tests, generates reports
.PARAMETER Path
    Path to test files (default: current directory)
.PARAMETER Tag
    Run tests with specific tags (Unit, Integration, etc.)
.PARAMETER ExcludeTag
    Exclude tests with specific tags
.PARAMETER OutputFormat
    Output format: JSON, NUnitXml, or Table (default: Table)
.PARAMETER OutputPath
    Path to save test results
.EXAMPLE
    .\Run-Tests.ps1
    .\Run-Tests.ps1 -Tag Unit
    .\Run-Tests.ps1 -OutputFormat NUnitXml -OutputPath results.xml
.NOTES
    Requires Pester module v5+
#>

param(
    [string]$Path = $PSScriptRoot,
    [string]$Tag = "",
    [string]$ExcludeTag = "",
    [ValidateSet("Table", "JSON", "NUnitXml")]
    [string]$OutputFormat = "Table",
    [string]$OutputPath = ""
)

$ErrorActionPreference = 'Stop'

function Test-PesterInstalled {
    try {
        $pester = Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version.Major -ge 5 }
        if (-not $pester) {
            Write-Host "Pester 5+ is required. Installing..." -ForegroundColor Yellow
            Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
        }
        Import-Module Pester -MinimumVersion 5.0
        return $true
    } catch {
        Write-Host "Failed to load Pester module: $_" -ForegroundColor Red
        return $false
    }
}

function Invoke-PesterTests {
    param(
        [string]$TestPath,
        [string]$TagFilter = "",
        [string]$ExcludeTagFilter = "",
        [string]$OutFormat = "Table",
        [string]$OutPath = ""
    )

    Write-Host "Running tests from: $TestPath" -ForegroundColor Cyan

    $pesterParams = @{
        Path = $TestPath
        PassThru = $true
        Show = "All"
    }

    if ($TagFilter) {
        $pesterParams.Tag = $TagFilter.Split(",").Trim()
    }

    if ($ExcludeTagFilter) {
        $pesterParams.ExcludeTag = $ExcludeTagFilter.Split(",").Trim()
    }

    if ($OutPath) {
        $pesterParams.OutputPath = $OutPath
        $pesterParams.OutputFormat = $OutFormat
    }

    try {
        $results = Invoke-Pester @pesterParams
        return $results
    } catch {
        Write-Host "Test execution failed: $_" -ForegroundColor Red
        throw
    }
}

function Show-TestSummary {
    param([object]$Results)

    Write-Host ""
    Write-Host "=== Test Summary ===" -ForegroundColor Cyan
    Write-Host "Total Tests:  $($Results.Tests.Count)"
    Write-Host "Passed:       $($Results.Passed.Count)" -ForegroundColor Green
    Write-Host "Failed:       $($Results.Failed.Count)" -ForegroundColor $(if ($Results.Failed.Count -gt 0) { "Red" } else { "Green" })
    Write-Host "Skipped:      $($Results.Skipped.Count)"
    Write-Host "Duration:     $($Results.Duration.TotalSeconds)s"

    if ($Results.Failed.Count -gt 0) {
        Write-Host ""
        Write-Host "Failed Tests:" -ForegroundColor Red
        foreach ($failure in $Results.Failed) {
            Write-Host "  - $($failure.Name)" -ForegroundColor Red
            Write-Host "    $($failure.FailureMessage)" -ForegroundColor DarkRed
        }
    }

    Write-Host ""
    return $Results.FailedCount -eq 0
}

function Generate-TestReport {
    param(
        [object]$Results,
        [string]$Format = "Table",
        [string]$OutputFile = ""
    )

    if ($OutputFile -and (Test-Path (Split-Path $OutputFile))) {
        Write-Host "Test report saved to: $OutputFile" -ForegroundColor Green
        return
    }

    switch ($Format) {
        "Table" {
            Write-Host ""
            Write-Host "Detailed Results:" -ForegroundColor Cyan
            $Results.Tests | Format-Table -Property Name, Result, Duration
        }
        "JSON" {
            if ($OutputFile) {
                $Results | ConvertTo-Json -Depth 10 | Set-Content $OutputFile
            } else {
                $Results | ConvertTo-Json -Depth 10 | Write-Output
            }
        }
    }
}

# Main execution
Write-Host "IPSC Kurs Watcher - Test Suite" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-PesterInstalled)) {
    exit 1
}

# Find test files
$testFiles = Get-ChildItem -Path $Path -Filter "*.Tests.ps1" -Recurse
if ($testFiles.Count -eq 0) {
    Write-Host "No test files found in: $Path" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found $($testFiles.Count) test file(s)" -ForegroundColor Gray
Write-Host ""

# Run tests
try {
    $results = Invoke-PesterTests -TestPath $Path `
                                  -TagFilter $Tag `
                                  -ExcludeTagFilter $ExcludeTag `
                                  -OutFormat $OutputFormat `
                                  -OutPath $OutputPath

    # Show summary
    $allPassed = Show-TestSummary -Results $results

    # Generate report
    if ($OutputPath) {
        Generate-TestReport -Results $results -Format $OutputFormat -OutputFile $OutputPath
    } else {
        Generate-TestReport -Results $results -Format $OutputFormat
    }

    # Exit with appropriate code
    exit $(if ($allPassed) { 0 } else { 1 })

} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
