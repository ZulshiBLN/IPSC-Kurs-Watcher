#Requires -Version 5.1

<#
.SYNOPSIS
    Integration tests for Watcher orchestration
.DESCRIPTION
    Tests end-to-end monitoring cycles with mock data
#>

BeforeAll {
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent

    # Import modules
    . "$ModuleRoot/src/utils/Logging.ps1"
    . "$ModuleRoot/src/core/Config.ps1"
    . "$ModuleRoot/src/core/State.ps1"
    . "$ModuleRoot/src/filters/FilterPipeline.ps1"

    $testConfigPath = Join-Path $PSScriptRoot "test-config.json"
    $testStatePath = Join-Path $PSScriptRoot "test-state.json"

    # Create test config
    $testConfig = @{
        monitors = @(
            @{
                name = "test-monitor"
                provider = "test"
                enabled = $true
                poll_interval_minutes = 5
            }
        )
        filters = @{
            course_types = @(
                @{
                    id = "sp"
                    name = "Service Pistol"
                    patterns = @("Service Pistol")
                    enabled = $true
                }
            )
            exclusions = @()
        }
        notifiers = @{
            email = @{ enabled = $false }
            discord = @{ enabled = $false }
            windows_toast = @{ enabled = $false }
        }
    }

    $testConfig | ConvertTo-Json -Depth 10 | Set-Content $testConfigPath
}

AfterAll {
    if (Test-Path $testConfigPath) { Remove-Item $testConfigPath -Force }
    if (Test-Path $testStatePath) { Remove-Item $testStatePath -Force }
}

Describe "Watcher Integration" -Tag Integration {
    It "Should load and validate configuration" {
        $config = Read-Config -Path $testConfigPath
        $config | Should -Not -BeNullOrEmpty
        $config.monitors.Count | Should -Be 1
    }

    It "Should initialize state" {
        Initialize-State -StateFile $testStatePath
        Test-Path $testStatePath | Should -Be $true

        $state = Read-State -StateFile $testStatePath
        $state.notified_courses | Should -BeOfType [hashtable]
    }

    It "Should track and filter courses through full cycle" {
        # Setup
        Initialize-State -StateFile $testStatePath
        $config = Read-Config -Path $testConfigPath

        # Mock courses
        $courses = @(
            @{
                id = "course-1"
                title = "Service Pistol - Level 1"
                type = "Service Pistol"
                availability = 5
            }
            @{
                id = "course-2"
                title = "Standard Rifle - Level 1"
                type = "Standard Rifle"
                availability = 3
            }
        )

        # Apply filter pipeline
        $filtered = Invoke-FilterPipeline -Courses $courses -Config $config

        # Verify filtering
        $filtered.Count | Should -Be 1
        $filtered[0].type | Should -Be "Service Pistol"
    }

    It "Should detect and skip duplicate notifications" {
        # Setup
        Initialize-State -StateFile $testStatePath
        $config = Read-Config -Path $testConfigPath

        $course = @{
            id = "dup-course"
            title = "Test Course"
            type = "Service Pistol"
            availability = 5
        }

        # Mark as notified
        Add-NotifiedCourse -CourseId $course.id -StateFile $testStatePath | Out-Null

        # Verify it's tracked
        $notified = Test-CourseNotified -CourseId $course.id -StateFile $testStatePath
        $notified | Should -Be $true
    }

    It "Should cleanup old state entries" {
        # Setup
        Initialize-State -StateFile $testStatePath

        # Add old entry
        $state = Read-State -StateFile $testStatePath
        $oldDate = (Get-Date).AddDays(-10).ToString('o')
        $state.notified_courses."old-course" = @{
            timestamp = $oldDate
            hash = "old"
        }
        Save-State -State $state -StateFile $testStatePath

        # Add new entry
        Add-NotifiedCourse -CourseId "new-course" -StateFile $testStatePath | Out-Null

        # Cleanup
        Clear-OldStateEntries -DaysToKeep 7 -StateFile $testStatePath

        # Verify
        $final = Read-State -StateFile $testStatePath
        $final.notified_courses."old-course" | Should -BeNullOrEmpty
        $final.notified_courses."new-course" | Should -Not -BeNullOrEmpty
    }
}

Describe "Error Handling" -Tag Integration {
    It "Should handle missing configuration gracefully" {
        { Read-Config -Path "nonexistent.json" } | Should -Throw
    }

    It "Should handle invalid state file gracefully" {
        $invalidPath = Join-Path $PSScriptRoot "invalid-state.json"
        "{ invalid" | Set-Content $invalidPath
        try {
            { Read-State -StateFile $invalidPath } | Should -Throw
        } finally {
            Remove-Item $invalidPath -Force
        }
    }

    It "Should recover from corrupted state" {
        $recoveryPath = Join-Path $PSScriptRoot "recovery-state.json"
        "{}" | Set-Content $recoveryPath
        try {
            Initialize-State -StateFile $recoveryPath
            Test-Path $recoveryPath | Should -Be $true

            $state = Read-State -StateFile $recoveryPath
            $state.notified_courses | Should -Not -BeNullOrEmpty
        } finally {
            Remove-Item $recoveryPath -Force
        }
    }
}
