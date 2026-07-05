#Requires -Version 5.1
#Requires -Modules Pester

BeforeAll {
    # Load core modules using absolute path
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $modulePaths = @(
        "$repoRoot/src/core/Helpers.ps1"
        "$repoRoot/src/core/Logging.ps1"
        "$repoRoot/src/core/State.ps1"
    )

    foreach ($path in $modulePaths) {
        if (Test-Path $path) {
            . $path
        } else {
            Write-Warning "Module not found: $path"
        }
    }

    $script:fixturesDir = Join-Path $PSScriptRoot '../fixtures'
    $script:testStateFile = Join-Path $script:fixturesDir 'data/test-state-sm.json'

    Initialize-Logging -LogDir (Join-Path $script:fixturesDir 'logs') -LogLevel 'WARN'
}

Describe "State Management Integration" {
    Context "New Courses Detection" {
        It "should detect all courses as new in first run" {
            $state = @{
                version = 1
                last_poll = $null
                last_notified = @()
            }

            $courses = @(
                @{ id = 'c1'; name = 'Course 1'; availability = 3; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test' }
                @{ id = 'c2'; name = 'Course 2'; availability = 2; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-02'; time = '10:00'; monitor_id = 'test' }
                @{ id = 'c3'; name = 'Course 3'; availability = 1; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-03'; time = '11:00'; monitor_id = 'test' }
            )

            $result = Update-StateWithCourse -State $state -CurrentCourses $courses

            $result.alerts.new.Count | Should -Be 3
            $result.alerts.reduced.Count | Should -Be 0
            $result.alerts.sold_out.Count | Should -Be 0
            $result.state.last_notified.Count | Should -Be 3
        }

        It "should detect no new courses on second run (identical state)" {
            $state = @{
                version = 1
                last_poll = [datetime]::UtcNow.ToString('o')
                last_notified = @(
                    @{ id = 'c1'; name = 'Course 1'; availability = 3; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                    @{ id = 'c2'; name = 'Course 2'; availability = 2; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-02'; time = '10:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                )
            }

            $courses = @(
                @{ id = 'c1'; name = 'Course 1'; availability = 3; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test' }
                @{ id = 'c2'; name = 'Course 2'; availability = 2; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-02'; time = '10:00'; monitor_id = 'test' }
            )

            $result = Update-StateWithCourse -State $state -CurrentCourses $courses

            $result.alerts.new.Count | Should -Be 0
            $result.alerts.reduced.Count | Should -Be 0
            $result.alerts.sold_out.Count | Should -Be 0
        }
    }

    Context "Availability Reduction Detection" {
        It "should detect when availability decreases" {
            $state = @{
                version = 1
                last_poll = [datetime]::UtcNow.ToString('o')
                last_notified = @(
                    @{ id = 'c1'; name = 'Course 1'; availability = 5; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                )
            }

            $courses = @(
                @{ id = 'c1'; name = 'Course 1'; availability = 2; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test' }
            )

            $result = Update-StateWithCourse -State $state -CurrentCourses $courses

            $result.alerts.reduced.Count | Should -Be 1
            $result.alerts.reduced[0].availability | Should -Be 2
            $result.alerts.new.Count | Should -Be 0
        }

        It "should not alert on availability increase" {
            $state = @{
                version = 1
                last_poll = [datetime]::UtcNow.ToString('o')
                last_notified = @(
                    @{ id = 'c1'; name = 'Course 1'; availability = 2; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                )
            }

            $courses = @(
                @{ id = 'c1'; name = 'Course 1'; availability = 5; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test' }
            )

            $result = Update-StateWithCourse -State $state -CurrentCourses $courses

            $result.alerts.reduced.Count | Should -Be 0
            $result.alerts.new.Count | Should -Be 0
        }

        It "should detect multiple availability reductions" {
            $state = @{
                version = 1
                last_poll = [datetime]::UtcNow.ToString('o')
                last_notified = @(
                    @{ id = 'c1'; name = 'Course 1'; availability = 5; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                    @{ id = 'c2'; name = 'Course 2'; availability = 4; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-02'; time = '10:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                )
            }

            $courses = @(
                @{ id = 'c1'; name = 'Course 1'; availability = 3; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test' }
                @{ id = 'c2'; name = 'Course 2'; availability = 1; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-02'; time = '10:00'; monitor_id = 'test' }
            )

            $result = Update-StateWithCourse -State $state -CurrentCourses $courses

            $result.alerts.reduced.Count | Should -Be 2
            $result.state.last_notified.Count | Should -Be 2
        }
    }

    Context "Sold Out Detection" {
        It "should detect course with 0 availability as sold out" {
            $state = @{
                version = 1
                last_poll = [datetime]::UtcNow.ToString('o')
                last_notified = @(
                    @{ id = 'c1'; name = 'Course 1'; availability = 3; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                )
            }

            $courses = @(
                @{ id = 'c1'; name = 'Course 1'; availability = 0; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test' }
            )

            $result = Update-StateWithCourse -State $state -CurrentCourses $courses

            $result.alerts.sold_out.Count | Should -Be 1
            $result.state.last_notified.Count | Should -Be 0
        }

        It "should detect disappeared course as sold out" {
            $state = @{
                version = 1
                last_poll = [datetime]::UtcNow.ToString('o')
                last_notified = @(
                    @{ id = 'c1'; name = 'Course 1'; availability = 3; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                    @{ id = 'c2'; name = 'Course 2'; availability = 2; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-02'; time = '10:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                )
            }

            $courses = @(
                @{ id = 'c1'; name = 'Course 1'; availability = 3; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test' }
            )

            $result = Update-StateWithCourse -State $state -CurrentCourses $courses

            $result.alerts.sold_out.Count | Should -Be 1
            $result.alerts.sold_out[0].id | Should -Be 'c2'
            $result.state.last_notified.Count | Should -Be 1
        }
    }

    Context "Complex Scenarios" {
        It "should handle mixed alerts (new, reduced, sold_out)" {
            $state = @{
                version = 1
                last_poll = [datetime]::UtcNow.ToString('o')
                last_notified = @(
                    @{ id = 'c1'; name = 'Course 1'; availability = 5; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                    @{ id = 'c2'; name = 'Course 2'; availability = 4; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-02'; time = '10:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                    @{ id = 'c3'; name = 'Course 3'; availability = 3; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-03'; time = '11:00'; monitor_id = 'test'; notified_at = [datetime]::UtcNow.ToString('o') }
                )
            }

            $courses = @(
                @{ id = 'c1'; name = 'Course 1'; availability = 3; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-01'; time = '09:00'; monitor_id = 'test' }  # REDUCED
                @{ id = 'c2'; name = 'Course 2'; availability = 0; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-02'; time = '10:00'; monitor_id = 'test' }  # SOLD OUT
                @{ id = 'c4'; name = 'Course 4'; availability = 2; price = 'CHF 100'; url = 'http://example.com'; date = '2026-08-04'; time = '12:00'; monitor_id = 'test' }  # NEW
            )

            $result = Update-StateWithCourse -State $state -CurrentCourses $courses

            $result.alerts.new.Count | Should -Be 1
            $result.alerts.reduced.Count | Should -Be 1
            $result.alerts.sold_out.Count | Should -Be 2  # c2 and c3 (disappeared)
            $result.state.last_notified.Count | Should -Be 2  # c1 and c4
        }
    }

    AfterEach {
        if (Test-Path $script:testStateFile) {
            Remove-Item $script:testStateFile -Force
        }
    }
}
