#Requires -Version 5.1
#Requires -Modules Pester

BeforeAll {
    $filtersPath = Join-Path $PSScriptRoot '../../../src/filters'

    . (Join-Path $filtersPath 'FilterByType.ps1')
    . (Join-Path $filtersPath 'FilterByExclusion.ps1')
    . (Join-Path $filtersPath 'FilterPipeline.ps1')
}

Describe "Invoke-FilterPipeline" {
    Context "Type Filtering" {
        It "filters by course type" {
            $courses = @(
                @{ id = '1'; name = 'Basic 1'; availability = 5 }
                @{ id = '2'; name = 'Advanced 1'; availability = 3 }
            )
            $config = @{
                course_types = @(
                    @{ enabled = $true; patterns = @('Basic') }
                )
            }

            $result = Invoke-FilterPipeline -Courses $courses -FilterConfig $config

            $result.Count | Should -Be 1
            $result[0].name | Should -Match 'Basic'
        }
    }

    Context "Exclusion Filtering" {
        It "excludes courses by pattern" {
            $courses = @(
                @{ id = '1'; name = 'Basic Course'; availability = 5 }
                @{ id = '2'; name = 'VIP Lesson'; availability = 3 }
            )
            $config = @{
                exclude_patterns = @('VIP')
            }

            $result = Invoke-FilterPipeline -Courses $courses -FilterConfig $config

            $result.Count | Should -Be 1
            $result[0].name | Should -Not -Match 'VIP'
        }
    }

    Context "Minimum Availability" {
        It "filters by minimum availability" {
            $courses = @(
                @{ id = '1'; name = 'Course 1'; availability = 5 }
                @{ id = '2'; name = 'Course 2'; availability = 0 }
                @{ id = '3'; name = 'Course 3'; availability = 1 }
            )
            $config = @{
                min_availability = 1
            }

            $result = Invoke-FilterPipeline -Courses $courses -FilterConfig $config

            $result.Count | Should -Be 2
        }
    }

    Context "Combined Filters" {
        It "applies all filters in sequence" {
            $courses = @(
                @{ id = '1'; name = 'Basic Course'; availability = 5 }
                @{ id = '2'; name = 'VIP Basic'; availability = 3 }
                @{ id = '3'; name = 'Advanced'; availability = 1 }
            )
            $config = @{
                course_types = @(
                    @{ enabled = $true; patterns = @('Basic') }
                )
                exclude_patterns = @('VIP')
                min_availability = 1
            }

            $result = Invoke-FilterPipeline -Courses $courses -FilterConfig $config

            $result.Count | Should -Be 1
            $result[0].name | Should -Be 'Basic Course'
        }
    }

    Context "Edge Cases" {
        It "returns empty array for null courses" {
            $config = @{}
            $result = Invoke-FilterPipeline -Courses $null -FilterConfig $config

            $result.Count | Should -Be 0
        }

        It "returns all courses if no filters configured" {
            $courses = @(
                @{ id = '1'; name = 'Course 1'; availability = 5 }
                @{ id = '2'; name = 'Course 2'; availability = 3 }
            )
            $config = @{}

            $result = Invoke-FilterPipeline -Courses $courses -FilterConfig $config

            $result.Count | Should -Be 2
        }

        It "handles zero min_availability" {
            $courses = @(
                @{ id = '1'; name = 'Course 1'; availability = 0 }
            )
            $config = @{ min_availability = 0 }

            $result = Invoke-FilterPipeline -Courses $courses -FilterConfig $config

            $result.Count | Should -Be 1
        }
    }
}

Describe "Get-FilteredCoursesByType" {
    Context "Type Matching" {
        It "filters by single pattern" {
            $courses = @(
                @{ name = 'Basic 1' }
                @{ name = 'Advanced 1' }
            )
            $filters = @(
                @{ enabled = $true; patterns = @('Basic') }
            )

            $result = Get-FilteredCoursesByType -Courses $courses -TypeFilters $filters

            $result.Count | Should -Be 1
        }

        It "filters by multiple patterns in one filter" {
            $courses = @(
                @{ name = 'Basic' }
                @{ name = 'Anfänger' }
                @{ name = 'Advanced' }
            )
            $filters = @(
                @{ enabled = $true; patterns = @('Basic', 'Anfänger') }
            )

            $result = Get-FilteredCoursesByType -Courses $courses -TypeFilters $filters

            $result.Count | Should -Be 2
        }

        It "respects enabled flag" {
            $courses = @(
                @{ name = 'Basic' }
                @{ name = 'Advanced' }
            )
            $filters = @(
                @{ enabled = $false; patterns = @('Basic') }
            )

            $result = Get-FilteredCoursesByType -Courses $courses -TypeFilters $filters

            $result.Count | Should -Be 2
        }
    }
}

Describe "Get-FilteredCoursesByExclusion" {
    Context "Exclusion" {
        It "removes matching courses" {
            $courses = @(
                @{ name = 'Basic' }
                @{ name = 'VIP Lesson' }
            )
            $patterns = @('VIP')

            $result = Get-FilteredCoursesByExclusion -Courses $courses -ExcludePatterns $patterns

            $result.Count | Should -Be 1
        }

        It "excludes multiple patterns" {
            $courses = @(
                @{ name = 'Basic' }
                @{ name = 'VIP' }
                @{ name = 'Private' }
            )
            $patterns = @('VIP', 'Private')

            $result = Get-FilteredCoursesByExclusion -Courses $courses -ExcludePatterns $patterns

            $result.Count | Should -Be 1
        }
    }
}

Describe "Test-CourseType" {
    Context "Pattern Matching" {
        It "matches exact pattern" {
            $result = Test-CourseType -CourseName "Basic" -Patterns @('Basic')

            $result | Should -Be $true
        }

        It "matches partial pattern" {
            $result = Test-CourseType -CourseName "Basic Level 1" -Patterns @('Basic')

            $result | Should -Be $true
        }

        It "returns false for no match" {
            $result = Test-CourseType -CourseName "Advanced" -Patterns @('Basic')

            $result | Should -Be $false
        }

        It "matches with multiple patterns" {
            $result = Test-CourseType -CourseName "Anfänger" -Patterns @('Basic', 'Anfänger')

            $result | Should -Be $true
        }
    }
}
