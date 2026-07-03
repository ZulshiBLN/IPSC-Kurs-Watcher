#Requires -Version 5.1

<#
.SYNOPSIS
    Pester tests for State management module
.DESCRIPTION
    Tests state persistence and course notification tracking
#>

BeforeAll {
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    . "$ModuleRoot/src/core/State.ps1"

    $stateFile = Join-Path $PSScriptRoot "test-state.json"
}

AfterAll {
    if (Test-Path $stateFile) {
        Remove-Item $stateFile -Force
    }
}

Describe "Initialize-State" {
    It "Should create state file if not exists" {
        Remove-Item $stateFile -Force -ErrorAction SilentlyContinue
        Initialize-State -StateFile $stateFile
        Test-Path $stateFile | Should -Be $true
    }

    It "Should create valid JSON structure" {
        Remove-Item $stateFile -Force -ErrorAction SilentlyContinue
        Initialize-State -StateFile $stateFile
        $content = Get-Content $stateFile | ConvertFrom-Json
        $content.notified_courses | Should -Not -BeNullOrEmpty
    }

    It "Should preserve existing state" {
        # Create initial state with a course
        Remove-Item $stateFile -Force -ErrorAction SilentlyContinue
        Initialize-State -StateFile $stateFile
        Add-NotifiedCourse -CourseId "test-1" -StateFile $stateFile | Out-Null

        # Re-initialize
        Initialize-State -StateFile $stateFile

        # Verify course still exists
        $state = Read-State -StateFile $stateFile
        $state.notified_courses."test-1" | Should -Not -BeNullOrEmpty
    }
}

Describe "Read-State" {
    It "Should read state from file" {
        Initialize-State -StateFile $stateFile
        $state = Read-State -StateFile $stateFile
        $state | Should -Not -BeNullOrEmpty
        $state | Should -HaveKey "notified_courses"
    }

    It "Should return hashtable" {
        Initialize-State -StateFile $stateFile
        $state = Read-State -StateFile $stateFile
        $state | Should -BeOfType [hashtable]
    }

    It "Should throw if file not found" {
        { Read-State -StateFile "nonexistent.json" } | Should -Throw
    }
}

Describe "Save-State" {
    It "Should write state to file" {
        Initialize-State -StateFile $stateFile
        $state = @{
            notified_courses = @{
                "test-1" = @{ timestamp = (Get-Date -Format 'o'); hash = "abc123" }
            }
        }
        Save-State -State $state -StateFile $stateFile

        $loaded = Read-State -StateFile $stateFile
        $loaded.notified_courses."test-1" | Should -Not -BeNullOrEmpty
    }

    It "Should preserve data types" {
        Initialize-State -StateFile $stateFile
        $timestamp = Get-Date
        $state = @{
            notified_courses = @{
                "test-1" = @{
                    timestamp = $timestamp.ToString('o')
                    hash = "xyz789"
                }
            }
        }
        Save-State -State $state -StateFile $stateFile

        $loaded = Read-State -StateFile $stateFile
        $loaded.notified_courses."test-1".hash | Should -Be "xyz789"
    }
}

Describe "Add-NotifiedCourse" {
    It "Should add course to state" {
        Initialize-State -StateFile $stateFile
        Add-NotifiedCourse -CourseId "new-course" -StateFile $stateFile | Out-Null

        $state = Read-State -StateFile $stateFile
        $state.notified_courses."new-course" | Should -Not -BeNullOrEmpty
    }

    It "Should set timestamp" {
        Initialize-State -StateFile $stateFile
        $before = Get-Date
        Add-NotifiedCourse -CourseId "timed-course" -StateFile $stateFile | Out-Null
        $after = Get-Date

        $state = Read-State -StateFile $stateFile
        $timestamp = [DateTime]::Parse($state.notified_courses."timed-course".timestamp)
        $timestamp | Should -BeGreaterThan $before
        $timestamp | Should -BeLessThan $after.AddSeconds(1)
    }

    It "Should handle duplicate adds (update)" {
        Initialize-State -StateFile $stateFile
        Add-NotifiedCourse -CourseId "dup-course" -StateFile $stateFile | Out-Null
        Start-Sleep -Milliseconds 100
        Add-NotifiedCourse -CourseId "dup-course" -StateFile $stateFile | Out-Null

        $state = Read-State -StateFile $stateFile
        $state.notified_courses."dup-course" | Should -Not -BeNullOrEmpty
        # Should only have one entry
        $count = @($state.notified_courses.Keys).Where({ $_ -eq "dup-course" }).Count
        $count | Should -Be 1
    }
}

Describe "Test-CourseNotified" {
    It "Should return true for notified courses" {
        Initialize-State -StateFile $stateFile
        Add-NotifiedCourse -CourseId "notified-course" -StateFile $stateFile | Out-Null

        $result = Test-CourseNotified -CourseId "notified-course" -StateFile $stateFile
        $result | Should -Be $true
    }

    It "Should return false for non-notified courses" {
        Initialize-State -StateFile $stateFile
        $result = Test-CourseNotified -CourseId "unknown-course" -StateFile $stateFile
        $result | Should -Be $false
    }

    It "Should be case-sensitive for course IDs" {
        Initialize-State -StateFile $stateFile
        Add-NotifiedCourse -CourseId "TestCourse" -StateFile $stateFile | Out-Null

        $result1 = Test-CourseNotified -CourseId "TestCourse" -StateFile $stateFile
        $result2 = Test-CourseNotified -CourseId "testcourse" -StateFile $stateFile

        $result1 | Should -Be $true
        $result2 | Should -Be $false
    }
}

Describe "Clear-OldStateEntries" {
    It "Should remove entries older than threshold" {
        Initialize-State -StateFile $stateFile

        # Add old entry (9 days old)
        $state = Read-State -StateFile $stateFile
        $oldDate = (Get-Date).AddDays(-9).ToString('o')
        $state.notified_courses."old-course" = @{
            timestamp = $oldDate
            hash = "old"
        }
        Save-State -State $state -StateFile $stateFile

        # Add new entry (1 day old)
        $newDate = (Get-Date).AddDays(-1).ToString('o')
        $state.notified_courses."new-course" = @{
            timestamp = $newDate
            hash = "new"
        }
        Save-State -State $state -StateFile $stateFile

        # Clear entries older than 7 days
        Clear-OldStateEntries -DaysToKeep 7 -StateFile $stateFile

        $final = Read-State -StateFile $stateFile
        $final.notified_courses."old-course" | Should -BeNullOrEmpty
        $final.notified_courses."new-course" | Should -Not -BeNullOrEmpty
    }

    It "Should keep entries within threshold" {
        Initialize-State -StateFile $stateFile

        # Add entry 2 days old
        $state = Read-State -StateFile $stateFile
        $recentDate = (Get-Date).AddDays(-2).ToString('o')
        $state.notified_courses."recent-course" = @{
            timestamp = $recentDate
            hash = "recent"
        }
        Save-State -State $state -StateFile $stateFile

        Clear-OldStateEntries -DaysToKeep 7 -StateFile $stateFile

        $final = Read-State -StateFile $stateFile
        $final.notified_courses."recent-course" | Should -Not -BeNullOrEmpty
    }

    It "Should handle empty state file" {
        Initialize-State -StateFile $stateFile
        $state = @{ notified_courses = @{} }
        Save-State -State $state -StateFile $stateFile

        { Clear-OldStateEntries -DaysToKeep 7 -StateFile $stateFile } | Should -Not -Throw
    }
}
