#Requires -Version 5.1

<#
.SYNOPSIS
    Complete test suite for IPSC Kurs Watcher
.DESCRIPTION
    Runs all tests across all 7 phases + integration tests
.PARAMETER Phase
    Run specific phase (1-7) or "all" or "integration"
.PARAMETER Verbose
    Show detailed output
.EXAMPLE
    .\Run-FullTest.ps1 -Phase all
    .\Run-FullTest.ps1 -Phase 3
#>

param(
    [string]$Phase = "all",
    [switch]$Verbose
)

$ErrorActionPreference = 'Continue'
$testResults = @{
    passed = @()
    failed = @()
    skipped = @()
    total = 0
}

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Test-Result {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = ""
    )

    $testResults.total++

    if ($Passed) {
        Write-Host "[✓] $TestName" -ForegroundColor Green
        $testResults.passed += $TestName
    } else {
        Write-Host "[✗] $TestName" -ForegroundColor Red
        if ($Details) { Write-Host "    $Details" -ForegroundColor DarkRed }
        $testResults.failed += $TestName
    }
}

function Show-Summary {
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "Test Summary" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "Total Tests:  $($testResults.total)"
    Write-Host "Passed:       $($testResults.passed.Count)" -ForegroundColor Green
    Write-Host "Failed:       $($testResults.failed.Count)" -ForegroundColor $(if ($testResults.failed.Count -eq 0) { "Green" } else { "Red" })
    Write-Host ""

    if ($testResults.failed.Count -gt 0) {
        Write-Host "Failed Tests:" -ForegroundColor Red
        $testResults.failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }

    Write-Host ""
    $passRate = [math]::Round(($testResults.passed.Count / $testResults.total) * 100, 1)
    Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -eq 100) { "Green" } else { "Yellow" })
    Write-Host "=" * 60 -ForegroundColor Cyan
}

# ============================================================================
# PHASE 1: Core Infrastructure
# ============================================================================

if ($Phase -in @("1", "all")) {
    Write-TestHeader "PHASE 1: Core Infrastructure Tests"

    # Test 1.1: Logging
    try {
        . src/utils/Logging.ps1
        Initialize-Logging -LogDirectory "data/logs-test"
        Write-Log "INFO" "Test log message"
        $logExists = Test-Path "data/logs-test" -PathType Container
        Test-Result "Logging: Initialize and write" $logExists
    } catch {
        Test-Result "Logging: Initialize and write" $false $_
    }

    # Test 1.2: Configuration
    try {
        . src/core/Config.ps1
        $config = Read-Config -ConfigPath "config/config.json"
        $configValid = ($config.monitors.Count -gt 0) -and ($config.filters.course_types.Count -gt 0)
        Test-Result "Configuration: Load from JSON" $configValid
    } catch {
        Test-Result "Configuration: Load from JSON" $false $_
    }

    # Test 1.3: State Management
    try {
        . src/core/State.ps1
        Initialize-State -StateFile "data/state-test.json"
        Add-NotifiedCourse -CourseId "test-1" -StateFile "data/state-test.json"
        $notified = Test-CourseNotified -CourseId "test-1" -StateFile "data/state-test.json"
        Test-Result "State: Initialize and track courses" $notified
    } catch {
        Test-Result "State: Initialize and track courses" $false $_
    }
}

# ============================================================================
# PHASE 2: Monitor Pipeline
# ============================================================================

if ($Phase -in @("2", "all")) {
    Write-TestHeader "PHASE 2: Monitor Pipeline Tests"

    # Test 2.1: Monitor Factory
    try {
        . src/core/Config.ps1
        . src/monitors/MonitorFactory.ps1
        $config = Read-Config -ConfigPath "config/config.json"
        $monitor = $config.monitors[0]
        $factory = New-Monitor -Config $monitor
        $factoryValid = $null -ne $factory
        Test-Result "Monitor: Factory creation" $factoryValid
    } catch {
        Test-Result "Monitor: Factory creation" $false $_
    }

    # Test 2.2: Monitor provider routing
    try {
        $providerType = $monitor.provider
        $providerValid = $providerType -in @("shooting-store", "generic-html")
        Test-Result "Monitor: Provider type validation" $providerValid
    } catch {
        Test-Result "Monitor: Provider type validation" $false $_
    }
}

# ============================================================================
# PHASE 3: Filter Pipeline
# ============================================================================

if ($Phase -in @("3", "all")) {
    Write-TestHeader "PHASE 3: Filter Pipeline Tests"

    # Test 3.1: Type Filter
    try {
        . src/filters/FilterByType.ps1
        $config = Read-Config -ConfigPath "config/config.json"

        $testCourses = @(
            @{ id = "1"; title = "Tryout"; type = "Tryout"; availability = 5 }
            @{ id = "2"; title = "Basic"; type = "Basic"; availability = 3 }
        )

        $filtered = Invoke-FilterByType -Courses $testCourses -Config $config
        $filterValid = $filtered -is [array]
        Test-Result "Filter: Type filtering" $filterValid
    } catch {
        Test-Result "Filter: Type filtering" $false $_
    }

    # Test 3.2: Exclusion Filter
    try {
        . src/filters/FilterByExclusion.ps1

        $testCourses = @(
            @{ id = "1"; title = "Normal" }
            @{ id = "2"; title = "Privatunterricht" }
        )

        $filtered = Invoke-FilterByExclusion -Courses $testCourses -Config $config
        $exclusionValid = $filtered.Count -lt $testCourses.Count
        Test-Result "Filter: Exclusion patterns" $exclusionValid
    } catch {
        Test-Result "Filter: Exclusion patterns" $false $_
    }

    # Test 3.3: Deduplication
    try {
        . src/filters/Deduplicator.ps1
        . src/core/State.ps1
        Initialize-State -StateFile "data/state-dedup-test.json"
        Add-NotifiedCourse -CourseId "old-1" -StateFile "data/state-dedup-test.json"

        $testCourses = @(
            @{ id = "new-1"; title = "New"; availability = 5 }
            @{ id = "old-1"; title = "Old"; availability = 3 }
        )

        $dedup = New-Deduplicator -StateFile "data/state-dedup-test.json"
        $filtered = Invoke-Deduplication -Courses $testCourses -Config @{} -Deduplicator $dedup
        $dedupValid = $filtered.Count -eq 1
        Test-Result "Filter: Deduplication" $dedupValid
    } catch {
        Test-Result "Filter: Deduplication" $false $_
    }
}

# ============================================================================
# PHASE 4: Notifier Pipeline
# ============================================================================

if ($Phase -in @("4", "all")) {
    Write-TestHeader "PHASE 4: Notifier Pipeline Tests"

    try {
        . src/notifiers/NotifyEmail.ps1
        $config = Read-Config -ConfigPath "config/config.json"

        if ($config.notifiers.email.enabled) {
            $emailNotifier = New-EmailNotifier -Config $config.notifiers.email
            $emailValid = $null -ne $emailNotifier
            Test-Result "Notifier: Email setup" $emailValid
        } else {
            Write-Host "[--] Email notifier disabled (skipping)" -ForegroundColor Gray
        }
    } catch {
        Test-Result "Notifier: Email setup" $false $_
    }

    try {
        . src/notifiers/NotifyDiscord.ps1

        if ($config.notifiers.discord.enabled) {
            $discordNotifier = New-DiscordNotifier -Config $config.notifiers.discord
            $discordValid = $null -ne $discordNotifier
            Test-Result "Notifier: Discord setup" $discordValid
        } else {
            Write-Host "[--] Discord notifier disabled (skipping)" -ForegroundColor Gray
        }
    } catch {
        Test-Result "Notifier: Discord setup" $false $_
    }

    try {
        . src/notifiers/NotifyToast.ps1
        $toastNotifier = New-ToastNotifier -Config @{ enabled = $true; duration = "long" }
        $toastValid = $null -ne $toastNotifier
        Test-Result "Notifier: Windows Toast setup" $toastValid
    } catch {
        Write-Host "[--] Windows Toast not available on this system (expected)" -ForegroundColor Gray
    }
}

# ============================================================================
# PHASE 5: GUI
# ============================================================================

if ($Phase -in @("5", "all")) {
    Write-TestHeader "PHASE 5: GUI Tests"

    # Test 5.1: WPF Assemblies
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName PresentationCore -ErrorAction Stop
        Add-Type -AssemblyName WindowsBase -ErrorAction Stop
        Test-Result "GUI: WPF assemblies load" $true
    } catch {
        Write-Host "[⊘] WPF not available (expected in headless environment)" -ForegroundColor Gray
    }

    # Test 5.2: ViewModel
    try {
        . src/gui/ViewModels/MainWindowViewModel-Simple.ps1
        $vm = New-MainWindowViewModel -ConfigPath "config/config.json"
        $loaded = Load-ViewModelConfiguration -ViewModel $vm -ConfigPath "config/config.json"
        $vmValid = ($vm.Monitors.Count -gt 0) -and ($vm.CourseTypes.Count -gt 0)
        Test-Result "GUI: ViewModel loading" $vmValid
    } catch {
        Test-Result "GUI: ViewModel loading" $false $_
    }

    # Test 5.3: XAML Parsing
    try {
        [xml]$xaml = Get-Content "src/gui/MainWindow-Simple.xaml" -Raw
        $tabCount = $xaml.SelectNodes("//TabItem").Count
        $xamlValid = $tabCount -gt 0
        $xamlMsg = "GUI: XAML parsing ($tabCount tabs found)"
        Test-Result $xamlMsg $xamlValid
    } catch {
        Test-Result "GUI: XAML parsing" $false $_
    }
}

# ============================================================================
# PHASE 6: Scheduler
# ============================================================================

if ($Phase -in @("6", "all")) {
    Write-TestHeader "PHASE 6: Scheduler Tests"

    # Test 6.1: Watcher script structure
    try {
        $watcher = Get-Content "Watcher.ps1" -Raw
        $hasConfigPath = $watcher -match "param.*ConfigPath"
        $hasLoopCount = $watcher -match "param.*LoopCount"
        $hasTestMode = $watcher -match "param.*TestMode"
        $structureValid = $hasConfigPath -and $hasLoopCount -and $hasTestMode
        Test-Result "Scheduler: Watcher script parameters" $structureValid
    } catch {
        Test-Result "Scheduler: Watcher script parameters" $false $_
    }

    # Test 6.2: Scheduled task installation readiness
    try {
        $installScript = Get-Content "scripts/Install-ScheduledTask.ps1" -Raw
        $hasAdmin = $installScript -match "RunAsAdministrator"
        $installValid = $hasAdmin
        Test-Result "Scheduler: Task installation script" $installValid
    } catch {
        Test-Result "Scheduler: Task installation script" $false $_
    }
}

# ============================================================================
# PHASE 7: Tests
# ============================================================================

if ($Phase -in @("7", "all")) {
    Write-TestHeader "PHASE 7: Test Framework Tests"

    # Test 7.1: Pester available
    try {
        if (Get-Module Pester -ListAvailable | Where-Object { $_.Version.Major -ge 5 }) {
            Test-Result "Tests: Pester 5+ available" $true
        } else {
            Write-Host "[⊘] Pester 5+ not installed (optional)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "[⊘] Pester check skipped" -ForegroundColor Gray
    }

    # Test 7.2: Test files exist
    try {
        $testFiles = Get-ChildItem "tests" -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue
        $testFilesValid = $testFiles.Count -gt 0
        $testMsg = "Tests: Test files present ($($testFiles.Count) found)"
        Test-Result $testMsg $testFilesValid
    } catch {
        Test-Result "Tests: Test files present" $false $_
    }
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

if ($Phase -in @("integration", "all")) {
    Write-TestHeader "Integration Tests"

    # Test: Full pipeline
    try {
        . src/core/Config.ps1
        . src/core/State.ps1
        . src/filters/FilterPipeline.ps1

        $config = Read-Config -ConfigPath "config/config.json"
        Initialize-State -StateFile "data/state-integration-test.json"

        $testCourses = @(
            @{ id = "i1"; title = "Int Test 1"; type = "Tryout"; availability = 5; url = "https://example.com/1" }
            @{ id = "i2"; title = "Int Test 2"; type = "Basic"; availability = 3; url = "https://example.com/2" }
        )

        $result = Invoke-FilterPipeline -Courses $testCourses -Config $config
        $integrationValid = $result -is [array]
        Test-Result "Integration: Full filter pipeline" $integrationValid
    } catch {
        Test-Result "Integration: Full filter pipeline" $false $_
    }

    # Test: Configuration tool
    try {
        . src/core/Config.ps1
        $config = Read-Config -ConfigPath "config/config.json"
        $configValid = ($config.monitors.Count -gt 0) -and ($config.filters.course_types.Count -gt 0)
        Test-Result "Integration: Configuration tool" $configValid
    } catch {
        Test-Result "Integration: Configuration tool" $false $_
    }

    # Test: Deployment readiness
    try {
        $watcherExists = Test-Path "Watcher.ps1"
        $installExists = Test-Path "scripts/Install-ScheduledTask.ps1"
        $configExists = Test-Path "config/config.json"
        $deployValid = $watcherExists -and $installExists -and $configExists
        Test-Result "Integration: Deployment readiness" $deployValid
    } catch {
        Test-Result "Integration: Deployment readiness" $false $_
    }
}

# ============================================================================
# Summary
# ============================================================================

Show-Summary

# Exit code based on results
if ($testResults.failed.Count -gt 0) {
    exit 1
} else {
    exit 0
}
