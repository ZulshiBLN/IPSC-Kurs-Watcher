#Requires -Version 5.1
#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../../src/core/State.ps1'
    $corePath = Join-Path $PSScriptRoot '../../../src/core'

    . (Join-Path $corePath 'Logging.ps1')
    . (Join-Path $corePath 'Helpers.ps1')
    . $modulePath

    Mock Write-Log { $null }
}

Describe "Get-State" {
    Context "Initialization" {
        It "returns initialized state when file missing" {
            $state = Get-State -StateFile 'nonexistent/state.json'
            $state | Should -Not -BeNullOrEmpty
            $state.version | Should -Be 1
        }

        It "returns version property" {
            $state = Get-State -StateFile 'nonexistent/state.json'
            $state.version | Should -Be 1
        }

        It "returns last_poll property" {
            $state = Get-State -StateFile 'nonexistent/state.json'
            $state.last_poll | Should -Not -BeNullOrEmpty
        }

        It "returns last_notified property" {
            $state = Get-State -StateFile 'nonexistent/state.json'
            $state | Should -Not -BeNullOrEmpty
            $state.Keys | Should -Contain 'last_notified'
        }

        It "returns empty last_notified for new state" {
            $state = Get-State -StateFile 'nonexistent/state.json'
            $state.last_notified | Should -Be @()
        }
    }

    Context "File Handling" {
        It "uses default state path 'data/state.json'" {
            $state = Get-State
            $state | Should -Not -BeNullOrEmpty
        }

        It "creates directory if missing" {
            $testPath = "test_temp/state.json"
            $state = Get-State -StateFile $testPath
            $state | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Merge-CourseState" {
    Context "NEW Course Detection" {
        It "detects brand new courses" {
            $current = @(
                @{ name = 'Basic 1'; date = '2026-07-15'; time = '10:00'; availability = 5; price = 'CHF 100'; url = 'https://example.com'; monitor_id = 'test' }
            )
            $tracked = @()

            $result = Merge-CourseState -CurrentCourses $current -TrackedCourses $tracked

            $result.alerts.new.Count | Should -Be 1
            $result.alerts.new[0].alert_reason | Should -Be 'NEW'
        }
    }

    Context "AVAILABILITY_REDUCED Detection" {
        It "detects reduced availability" {
            $current = @(
                @{ name = 'Basic 1'; date = '2026-07-15'; time = '10:00'; availability = 2; price = 'CHF 100'; url = 'https://example.com'; monitor_id = 'test' }
            )
            $tracked = @(
                @{ id = 'Basic 1|2026-07-15|10:00'; name = 'Basic 1'; date = '2026-07-15'; time = '10:00'; availability = 5; notified_at = '2026-07-01T00:00:00Z' }
            )

            $result = Merge-CourseState -CurrentCourses $current -TrackedCourses $tracked

            $result.alerts.reduced.Count | Should -Be 1
            $result.alerts.reduced[0].alert_reason | Should -Be 'AVAILABILITY_REDUCED'
        }
    }

    Context "SOLD_OUT Detection" {
        It "detects sold out courses (availability=0)" {
            $current = @(
                @{ name = 'Basic 1'; date = '2026-07-15'; time = '10:00'; availability = 0; price = 'CHF 100'; url = 'https://example.com'; monitor_id = 'test' }
            )
            $tracked = @(
                @{ id = 'Basic 1|2026-07-15|10:00'; name = 'Basic 1'; date = '2026-07-15'; time = '10:00'; availability = 5; notified_at = '2026-07-01T00:00:00Z' }
            )

            $result = Merge-CourseState -CurrentCourses $current -TrackedCourses $tracked

            $result.alerts.sold_out.Count | Should -Be 1
            $result.alerts.sold_out[0].alert_reason | Should -Be 'SOLD_OUT'
        }

        It "detects disappeared courses" {
            $current = @()
            $tracked = @(
                @{ id = 'Basic 1|2026-07-15|10:00'; name = 'Basic 1'; date = '2026-07-15'; time = '10:00'; availability = 5; notified_at = '2026-07-01T00:00:00Z' }
            )

            $result = Merge-CourseState -CurrentCourses $current -TrackedCourses $tracked

            $result.alerts.sold_out.Count | Should -Be 1
            $result.alerts.sold_out[0].disappeared | Should -Be $true
        }
    }

    Context "State Updates" {
        It "adds new courses to updated_state" {
            $current = @(
                @{ name = 'Basic 1'; date = '2026-07-15'; time = '10:00'; availability = 5; price = 'CHF 100'; url = 'https://example.com'; monitor_id = 'test' }
            )
            $tracked = @()

            $result = Merge-CourseState -CurrentCourses $current -TrackedCourses $tracked

            $result.updated_state.Count | Should -Be 1
            $result.updated_state[0].id | Should -Be 'Basic 1|2026-07-15|10:00'
        }

        It "removes sold out courses from updated_state" {
            $current = @()
            $tracked = @(
                @{ id = 'course1|2026-07-15|10:00'; name = 'Basic 1'; availability = 5; notified_at = '2026-07-01T00:00:00Z' }
            )

            $result = Merge-CourseState -CurrentCourses $current -TrackedCourses $tracked

            $result.updated_state.Count | Should -Be 0
        }
    }

    Context "Edge Cases" {
        It "handles empty course lists" {
            $result = Merge-CourseState -CurrentCourses @() -TrackedCourses @()
            $result.alerts.new.Count | Should -Be 0
            $result.alerts.reduced.Count | Should -Be 0
            $result.alerts.sold_out.Count | Should -Be 0
        }

        It "handles null inputs" {
            $result = Merge-CourseState -CurrentCourses $null -TrackedCourses $null
            $result.updated_state | Should -Be @()
        }
    }
}

Describe "Update-StateWithCourse" {
    Context "State Updates" {
        It "updates state with merged courses" {
            $state = @{ version = 1; last_poll = (Get-Date).ToString('o'); last_notified = @() }
            $courses = @(
                @{ id = 'course1|2026-07-15|10:00'; name = 'Basic 1'; date = '2026-07-15'; time = '10:00'; availability = 5; price = 'CHF 100'; url = 'https://example.com'; monitor_id = 'test' }
            )

            $result = Update-StateWithCourse -State $state -CurrentCourses $courses

            $result.state | Should -Not -BeNullOrEmpty
            $result.alerts | Should -Not -BeNullOrEmpty
        }

        It "returns alerts" {
            $state = @{ version = 1; last_poll = (Get-Date).ToString('o'); last_notified = @() }
            $courses = @(
                @{ id = 'course1|2026-07-15|10:00'; name = 'Basic 1'; date = '2026-07-15'; time = '10:00'; availability = 5; price = 'CHF 100'; url = 'https://example.com'; monitor_id = 'test' }
            )

            $result = Update-StateWithCourse -State $state -CurrentCourses $courses

            $result.alerts.new.Count | Should -Be 1
        }
    }
}

Describe "Get-NewCourse" {
    Context "Deprecation" {
        It "is deprecated but still functional" {
            $cmdletName = 'Get-NewCourse'
            $cmdletInfo = Get-Command $cmdletName

            $cmdletInfo | Should -Not -BeNullOrEmpty
        }
    }
}
