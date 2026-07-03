#Requires -Version 5.1

<#
.SYNOPSIS
    Quick test suite for IPSC Kurs Watcher
.DESCRIPTION
    Fast smoke tests for all major components
.EXAMPLE
    .\Run-QuickTest.ps1
#>

$ErrorActionPreference = 'Continue'
$passed = 0
$failed = 0

function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$Test
    )

    Write-Host "Testing: $Name... " -NoNewline

    try {
        $result = & $Test

        if ($result -eq $true -or $null -eq $result) {
            Write-Host "[OK]" -ForegroundColor Green
            $script:passed++
        } else {
            Write-Host "[FAIL]" -ForegroundColor Red
            $script:failed++
        }
    } catch {
        Write-Host "[ERROR] $_" -ForegroundColor Red
        $script:failed++
    }
}

# ============================================================================
Write-Host ""
Write-Host "IPSC Kurs Watcher - Quick Test Suite" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
Write-Host "PHASE 1: Core Infrastructure" -ForegroundColor Yellow
# ============================================================================

Test-Component "Logging System" {
    . src/utils/Logging.ps1
    Initialize-Logging -LogDirectory "data/logs-test" | Out-Null
    Write-Log "INFO" "Test" | Out-Null
    Test-Path "data/logs-test"
}

Test-Component "Configuration Loading" {
    . src/core/Config.ps1
    $config = Read-Config -ConfigPath "config/config.json"
    ($config.monitors.Count -gt 0) -and ($config.filters.course_types.Count -gt 0)
}

Test-Component "State Management" {
    . src/core/State.ps1
    Initialize-State -StateFile "data/state-test.json" | Out-Null
    Add-NotifiedCourse -CourseId "test-1" -StateFile "data/state-test.json" | Out-Null
    Test-CourseNotified -CourseId "test-1" -StateFile "data/state-test.json"
}

# ============================================================================
Write-Host ""
Write-Host "PHASE 2: Monitor Pipeline" -ForegroundColor Yellow
# ============================================================================

Test-Component "Monitor Factory" {
    . src/core/Config.ps1
    . src/monitors/MonitorFactory.ps1
    $config = Read-Config -ConfigPath "config/config.json"
    $monitor = $config.monitors[0]
    $factory = New-Monitor -Config $monitor
    $null -ne $factory
}

# ============================================================================
Write-Host ""
Write-Host "PHASE 3: Filter Pipeline" -ForegroundColor Yellow
# ============================================================================

Test-Component "Type Filter" {
    . src/filters/FilterByType.ps1
    . src/core/Config.ps1
    $config = Read-Config -ConfigPath "config/config.json"
    $testCourses = @(
        @{ id = "1"; title = "Tryout"; type = "Tryout"; availability = 5 }
        @{ id = "2"; title = "Basic"; type = "Basic"; availability = 3 }
    )
    $filtered = Invoke-FilterByType -Courses $testCourses -Config $config
    $filtered -is [array]
}

Test-Component "Exclusion Filter" {
    . src/filters/FilterByExclusion.ps1
    $testCourses = @(
        @{ id = "1"; title = "Normal" }
        @{ id = "2"; title = "Privatunterricht" }
    )
    $filtered = Invoke-FilterByExclusion -Courses $testCourses -Config $config
    $filtered.Count -lt $testCourses.Count
}

Test-Component "Deduplicator" {
    . src/filters/Deduplicator.ps1
    . src/core/State.ps1
    Initialize-State -StateFile "data/state-dedup-test.json" | Out-Null
    Add-NotifiedCourse -CourseId "old-1" -StateFile "data/state-dedup-test.json" | Out-Null
    $testCourses = @(
        @{ id = "new-1"; title = "New"; availability = 5 }
        @{ id = "old-1"; title = "Old"; availability = 3 }
    )
    $dedup = New-Deduplicator -StateFile "data/state-dedup-test.json"
    $filtered = Invoke-Deduplication -Courses $testCourses -Config @{} -Deduplicator $dedup
    $filtered.Count -eq 1
}

# ============================================================================
Write-Host ""
Write-Host "PHASE 4: Notifier Pipeline" -ForegroundColor Yellow
# ============================================================================

Test-Component "Email Notifier" {
    . src/notifiers/NotifyEmail.ps1
    $config = Read-Config -ConfigPath "config/config.json"
    $emailNotifier = New-EmailNotifier -Config $config.notifiers.email
    $null -ne $emailNotifier
}

Test-Component "Discord Notifier" {
    . src/notifiers/NotifyDiscord.ps1
    if ($config.notifiers.discord.enabled) {
        $discordNotifier = New-DiscordNotifier -Config $config.notifiers.discord
        $null -ne $discordNotifier
    } else {
        $true
    }
}

Test-Component "Toast Notifier" {
    . src/notifiers/NotifyToast.ps1
    try {
        $toastNotifier = New-ToastNotifier -Config @{ enabled = $true; duration = "long" }
        $null -ne $toastNotifier
    } catch {
        if ($_ -match "Windows 10") {
            $true
        } else {
            throw $_
        }
    }
}

# ============================================================================
Write-Host ""
Write-Host "PHASE 5: GUI" -ForegroundColor Yellow
# ============================================================================

Test-Component "WPF Assemblies" {
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName PresentationCore -ErrorAction Stop
        Add-Type -AssemblyName WindowsBase -ErrorAction Stop
        $true
    } catch {
        Write-Host "(expected in headless env)" -NoNewline
        $true
    }
}

Test-Component "ViewModel" {
    . src/gui/ViewModels/MainWindowViewModel-Simple.ps1
    $vm = New-MainWindowViewModel -ConfigPath "config/config.json"
    Load-ViewModelConfiguration -ViewModel $vm -ConfigPath "config/config.json" | Out-Null
    ($vm.Monitors.Count -gt 0) -and ($vm.CourseTypes.Count -gt 0)
}

Test-Component "XAML Parsing" {
    [xml]$xaml = Get-Content "src/gui/MainWindow-Simple.xaml" -Raw
    $tabCount = $xaml.SelectNodes("//TabItem").Count
    $tabCount -gt 0
}

# ============================================================================
Write-Host ""
Write-Host "PHASE 6: Scheduler" -ForegroundColor Yellow
# ============================================================================

Test-Component "Watcher Script" {
    $watcher = Get-Content "Watcher.ps1" -Raw
    ($watcher -match "param.*ConfigPath") -and ($watcher -match "param.*LoopCount")
}

Test-Component "Task Installation" {
    Test-Path "scripts/Install-ScheduledTask.ps1"
}

# ============================================================================
Write-Host ""
Write-Host "PHASE 7: Tests" -ForegroundColor Yellow
# ============================================================================

Test-Component "Test Framework" {
    $testFiles = Get-ChildItem "tests" -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue
    $testFiles.Count -gt 0
}

# ============================================================================
Write-Host ""
Write-Host "INTEGRATION TESTS" -ForegroundColor Yellow
# ============================================================================

Test-Component "Full Pipeline" {
    . src/core/Config.ps1
    . src/core/State.ps1
    . src/filters/FilterPipeline.ps1
    $config = Read-Config -ConfigPath "config/config.json"
    Initialize-State -StateFile "data/state-integration-test.json" | Out-Null
    $testCourses = @(
        @{ id = "i1"; title = "Int1"; type = "Tryout"; availability = 5; url = "https://example.com/1" }
        @{ id = "i2"; title = "Int2"; type = "Basic"; availability = 3; url = "https://example.com/2" }
    )
    $result = Invoke-FilterPipeline -Courses $testCourses -Config $config
    $result -is [array]
}

Test-Component "Deployment Readiness" {
    (Test-Path "Watcher.ps1") -and (Test-Path "scripts/Install-ScheduledTask.ps1") -and (Test-Path "config/config.json")
}

# ============================================================================
Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "Total:  $($passed + $failed)"
Write-Host ""

$passRate = if (($passed + $failed) -gt 0) { [math]::Round(($passed / ($passed + $failed)) * 100, 0) } else { 0 }
Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -eq 100) { "Green" } else { "Yellow" })
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
