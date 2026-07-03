#Requires -Version 5.1

<#
.SYNOPSIS
    Pester tests for Filter modules
.DESCRIPTION
    Tests course type filtering, exclusion, and deduplication
#>

BeforeAll {
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    . "$ModuleRoot/src/filters/FilterByType.ps1"
    . "$ModuleRoot/src/filters/FilterByExclusion.ps1"
    . "$ModuleRoot/src/filters/Deduplicator.ps1"
    . "$ModuleRoot/src/core/State.ps1"

    $testCourses = @(
        @{
            id = "course-1"
            title = "Service Pistol - Advanced"
            type = "Service Pistol"
            availability = 5
            url = "https://example.com/1"
        }
        @{
            id = "course-2"
            title = "Standard Pistol - Beginner"
            type = "Standard Pistol"
            availability = 3
            url = "https://example.com/2"
        }
        @{
            id = "course-3"
            title = "Service Rifle - Intermediate"
            type = "Service Rifle"
            availability = 2
            url = "https://example.com/3"
        }
    )

    $stateFile = Join-Path $PSScriptRoot "test-state.json"
}

AfterAll {
    if (Test-Path $stateFile) {
        Remove-Item $stateFile -Force
    }
}

Describe "New-CourseTypeFilter" {
    It "Should create filter from pattern array" {
        $patterns = @("Service Pistol", "SP")
        $filter = New-CourseTypeFilter -Patterns $patterns
        $filter | Should -Not -BeNullOrEmpty
        $filter.patterns | Should -Contain "Service Pistol"
    }
}

Describe "Test-CourseType" {
    It "Should match exact course type" {
        $filter = New-CourseTypeFilter -Patterns @("Service Pistol")
        $course = @{ type = "Service Pistol" }
        Test-CourseType -Course $course -Filter $filter | Should -Be $true
    }

    It "Should match partial pattern (case-insensitive)" {
        $filter = New-CourseTypeFilter -Patterns @("Service")
        $course = @{ type = "Service Pistol" }
        Test-CourseType -Course $course -Filter $filter | Should -Be $true
    }

    It "Should not match unrelated types" {
        $filter = New-CourseTypeFilter -Patterns @("Service Pistol")
        $course = @{ type = "Standard Rifle" }
        Test-CourseType -Course $course -Filter $filter | Should -Be $false
    }

    It "Should be case-insensitive" {
        $filter = New-CourseTypeFilter -Patterns @("SERVICE PISTOL")
        $course = @{ type = "service pistol" }
        Test-CourseType -Course $course -Filter $filter | Should -Be $true
    }
}

Describe "Invoke-FilterByType" {
    It "Should filter courses by type" {
        $config = @{
            filters = @{
                course_types = @(
                    @{
                        id = "sp"
                        name = "Service Pistol"
                        patterns = @("Service Pistol")
                        enabled = $true
                    }
                )
            }
        }

        $filtered = Invoke-FilterByType -Courses $testCourses -Config $config
        $filtered.Count | Should -Be 1
        $filtered[0].type | Should -Be "Service Pistol"
    }

    It "Should return empty array if no matches" {
        $config = @{
            filters = @{
                course_types = @(
                    @{
                        id = "unknown"
                        name = "Unknown Type"
                        patterns = @("Unknown")
                        enabled = $true
                    }
                )
            }
        }

        $filtered = Invoke-FilterByType -Courses $testCourses -Config $config
        $filtered.Count | Should -Be 0
    }

    It "Should respect disabled types" {
        $config = @{
            filters = @{
                course_types = @(
                    @{
                        id = "sp"
                        name = "Service Pistol"
                        patterns = @("Service Pistol")
                        enabled = $false
                    }
                )
            }
        }

        $filtered = Invoke-FilterByType -Courses $testCourses -Config $config
        $filtered.Count | Should -Be 0
    }
}

Describe "New-ExclusionFilter" {
    It "Should create regex filter from patterns" {
        $patterns = @("Beginner", "Basic")
        $filter = New-ExclusionFilter -Patterns $patterns
        $filter | Should -Not -BeNullOrEmpty
    }
}

Describe "Test-CourseExcluded" {
    It "Should exclude courses matching pattern" {
        $filter = New-ExclusionFilter -Patterns @("Beginner")
        $course = @{ title = "Standard Pistol - Beginner" }
        Test-CourseExcluded -Course $course -Filter $filter | Should -Be $true
    }

    It "Should not exclude non-matching courses" {
        $filter = New-ExclusionFilter -Patterns @("Beginner")
        $course = @{ title = "Service Pistol - Advanced" }
        Test-CourseExcluded -Course $course -Filter $filter | Should -Be $false
    }

    It "Should be case-insensitive" {
        $filter = New-ExclusionFilter -Patterns @("BEGINNER")
        $course = @{ title = "Standard Pistol - beginner" }
        Test-CourseExcluded -Course $course -Filter $filter | Should -Be $true
    }
}

Describe "Invoke-FilterByExclusion" {
    It "Should exclude matching courses" {
        $config = @{
            filters = @{
                exclusions = @("Beginner")
            }
        }

        $filtered = Invoke-FilterByExclusion -Courses $testCourses -Config $config
        $filtered.Count | Should -Be 2
        $filtered | Where-Object { $_.title -match "Beginner" } | Should -BeNullOrEmpty
    }

    It "Should return all if no exclusions" {
        $config = @{
            filters = @{
                exclusions = @()
            }
        }

        $filtered = Invoke-FilterByExclusion -Courses $testCourses -Config $config
        $filtered.Count | Should -Be $testCourses.Count
    }
}

Describe "New-Deduplicator" {
    It "Should create deduplicator instance" {
        $dedup = New-Deduplicator -StateFile $stateFile
        $dedup | Should -Not -BeNullOrEmpty
    }
}

Describe "Test-CourseDuplicate" {
    It "Should identify duplicate courses" {
        $dedup = New-Deduplicator -StateFile $stateFile
        $course = @{ id = "course-1"; title = "Test" }

        # First time - not duplicate
        $result1 = Test-CourseDuplicate -Course $course -Deduplicator $dedup
        $result1 | Should -Be $false

        # Mark as notified
        Add-NotifiedCourse -CourseId $course.id -StateFile $stateFile | Out-Null

        # Second time - should be duplicate
        $result2 = Test-CourseDuplicate -Course $course -Deduplicator $dedup
        $result2 | Should -Be $true
    }
}

Describe "Test-CourseAvailability" {
    It "Should detect available courses" {
        $dedup = New-Deduplicator -StateFile $stateFile
        $course = @{ availability = 5 }
        Test-CourseAvailability -Course $course -Deduplicator $dedup | Should -Be $true
    }

    It "Should exclude unavailable courses (0 seats)" {
        $dedup = New-Deduplicator -StateFile $stateFile
        $course = @{ availability = 0 }
        Test-CourseAvailability -Course $course -Deduplicator $dedup | Should -Be $false
    }

    It "Should exclude null/empty availability" {
        $dedup = New-Deduplicator -StateFile $stateFile
        $course = @{ availability = $null }
        Test-CourseAvailability -Course $course -Deduplicator $dedup | Should -Be $false
    }
}

Describe "Invoke-Deduplication" {
    It "Should remove duplicate courses" {
        # Add first course to state
        Initialize-State -StateFile $stateFile
        Add-NotifiedCourse -CourseId "course-1" -StateFile $stateFile | Out-Null

        $config = @{ }
        $dedup = New-Deduplicator -StateFile $stateFile
        $filtered = Invoke-Deduplication -Courses $testCourses -Config $config -Deduplicator $dedup

        # course-1 should be filtered out
        $filtered | Where-Object { $_.id -eq "course-1" } | Should -BeNullOrEmpty
    }

    It "Should remove unavailable courses" {
        $unavailableCourse = @{
            id = "course-unavail"
            title = "Full Course"
            availability = 0
        }

        $courses = $testCourses + $unavailableCourse
        $config = @{ }
        $dedup = New-Deduplicator -StateFile $stateFile
        $filtered = Invoke-Deduplication -Courses $courses -Config $config -Deduplicator $dedup

        $filtered | Where-Object { $_.id -eq "course-unavail" } | Should -BeNullOrEmpty
    }
}
