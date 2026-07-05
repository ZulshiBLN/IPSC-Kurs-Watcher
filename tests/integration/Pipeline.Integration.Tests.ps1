#Requires -Version 5.1
#Requires -Modules Pester

BeforeAll {
    # Load all modules using absolute path
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $modulePaths = @(
        "$repoRoot/src/core/Helpers.ps1"
        "$repoRoot/src/core/Logging.ps1"
        "$repoRoot/src/core/Config.ps1"
        "$repoRoot/src/core/State.ps1"
        "$repoRoot/src/monitors/MonitorBase.ps1"
        "$repoRoot/src/monitors/CourseMonitor.ps1"
        "$repoRoot/src/monitors/MonitorFactory.ps1"
        "$repoRoot/src/filters/FilterByType.ps1"
        "$repoRoot/src/filters/FilterByExclusion.ps1"
        "$repoRoot/src/filters/FilterPipeline.ps1"
    )

    foreach ($path in $modulePaths) {
        if (Test-Path $path) {
            . $path
        } else {
            Write-Warning "Module not found: $path"
        }
    }

    # Set up test fixtures directory
    $script:fixturesDir = Join-Path $PSScriptRoot '../fixtures'
    $script:htmlFixture = Join-Path $script:fixturesDir 'html/shooting-store-sample.html'
    $script:coursesFixture = Join-Path $script:fixturesDir 'data/test-courses.json'
    $script:stateFixture = Join-Path $script:fixturesDir 'data/state-example.json'
    $script:configFixture = Join-Path $script:fixturesDir 'configs/test-config.json'
    $script:testStateFile = Join-Path $script:fixturesDir 'data/test-state.json'

    # Initialize logging for tests
    $logDir = Join-Path $script:fixturesDir 'logs'
    Initialize-Logging -LogDir $logDir -LogLevel 'WARN'
}

Describe "IPSC Kurs Watcher Integration Pipeline" {
    Context "Complete Monitoring Cycle" {
        It "should load config and parse test HTML" {
            # Load config
            $config = Get-Config -ConfigPath $script:configFixture

            $config | Should -Not -BeNullOrEmpty
            $config.version | Should -Be 1
            $config.monitors | Should -Not -BeNullOrEmpty
            $config.monitors[0].id | Should -Be 'shooting-store'
        }

        It "should load test courses from fixture JSON" {
            $coursesJson = Get-Content $script:coursesFixture -Raw | ConvertFrom-Json

            $coursesJson | Should -Not -BeNullOrEmpty
            $coursesJson.Count | Should -Be 8
            $coursesJson[0].name | Should -Match 'IPSC'
            $coursesJson[0].availability | Should -BeGreaterThan 0
        }

        It "should apply filter pipeline and reduce courses" {
            # Load courses
            $courses = Get-Content $script:coursesFixture -Raw | ConvertFrom-Json

            # Load config
            $config = Get-Config -ConfigPath $script:configFixture

            # Apply filters (should keep only Basic and Stages, exclude Privatunterricht)
            $filtered = Invoke-FilterPipeline -Courses $courses -FilterConfig $config.filters

            # Should have fewer courses after filtering
            $filtered.Count | Should -BeLessThan $courses.Count

            # Should only have Basic or Stages courses
            foreach ($course in $filtered) {
                ($course.name -match 'Basic' -or $course.name -match 'Stages') | Should -Be $true
            }
        }

        It "should detect new courses in run 1" {
            # Load fresh state (empty)
            $state = @{
                version = 1
                last_poll = $null
                last_notified = @()
            }

            # Load current courses
            $currentCourses = Get-Content $script:coursesFixture -Raw | ConvertFrom-Json

            # Load config for filtering
            $config = Get-Config -ConfigPath $script:configFixture
            $filtered = Invoke-FilterPipeline -Courses $currentCourses -FilterConfig $config.filters

            # Update state (all should be NEW)
            $result = Update-StateWithCourse -State $state -CurrentCourses $filtered

            # Verify new courses detected
            $result.alerts.new.Count | Should -BeGreaterThan 0
            $result.alerts.reduced.Count | Should -Be 0
            $result.alerts.sold_out.Count | Should -Be 0

            # Verify state updated
            $result.state.last_notified.Count | Should -Be $filtered.Count
        }

        It "should detect no new courses in run 2 (same state)" {
            # Load example state from fixture
            $state = Get-Content $script:stateFixture -Raw | ConvertFrom-Json
            $state = @{
                version = $state.version
                last_poll = $state.last_poll
                last_notified = @($state.last_notified)
            }

            # Load same courses
            $currentCourses = Get-Content $script:coursesFixture -Raw | ConvertFrom-Json

            # Load config for filtering
            $config = Get-Config -ConfigPath $script:configFixture
            $filtered = Invoke-FilterPipeline -Courses $currentCourses -FilterConfig $config.filters

            # Update state (should detect no changes)
            $result = Update-StateWithCourse -State $state -CurrentCourses $filtered

            # Verify no new courses (they were already in state)
            $result.alerts.new.Count | Should -Be 0
        }

        It "should detect availability reduction" {
            # Create initial state with course at 5 availability
            $course1 = @{
                id = 'IPSC Stages|12.07.2026|08:00-11:00'
                name = 'IPSC Stages'
                date = '12.07.2026'
                time = '08:00-11:00'
                availability = 5
                price = 'CHF 260.00'
                url = 'https://example.com'
                monitor_id = 'shooting-store'
                notified_at = [datetime]::UtcNow.ToString('o')
            }

            $state = @{
                version = 1
                last_poll = [datetime]::UtcNow.ToString('o')
                last_notified = @($course1)
            }

            # Current course same ID but reduced availability
            $course2 = @{
                id = 'IPSC Stages|12.07.2026|08:00-11:00'
                name = 'IPSC Stages'
                date = '12.07.2026'
                time = '08:00-11:00'
                availability = 2
                price = 'CHF 260.00'
                url = 'https://example.com'
                monitor_id = 'shooting-store'
            }

            $result = Update-StateWithCourse -State $state -CurrentCourses @($course2)

            # Should detect availability reduction
            $result.alerts.reduced.Count | Should -Be 1
            $result.alerts.reduced[0].availability | Should -Be 2
        }

        It "should detect sold out courses" {
            # Create state with available course
            $course1 = @{
                id = 'IPSC Course|01.08.2026|09:00-12:00'
                name = 'IPSC Course'
                date = '01.08.2026'
                time = '09:00-12:00'
                availability = 3
                price = 'CHF 250.00'
                url = 'https://example.com'
                monitor_id = 'shooting-store'
                notified_at = [datetime]::UtcNow.ToString('o')
            }

            $state = @{
                version = 1
                last_poll = [datetime]::UtcNow.ToString('o')
                last_notified = @($course1)
            }

            # Course no longer available (not in current list)
            $result = Update-StateWithCourse -State $state -CurrentCourses @()

            # Should detect sold out
            $result.alerts.sold_out.Count | Should -Be 1
            $result.state.last_notified.Count | Should -Be 0
        }
    }

    Context "State Persistence" {
        It "should save and load state from JSON" {
            # Create test state
            $originalState = @{
                version = 1
                last_poll = [datetime]::UtcNow.ToString('o')
                last_notified = @(
                    @{
                        id = 'test|01.08.2026|09:00'
                        name = 'Test Course'
                        date = '01.08.2026'
                        time = '09:00-12:00'
                        availability = 3
                        price = 'CHF 250.00'
                        url = 'https://example.com'
                        monitor_id = 'test'
                        notified_at = [datetime]::UtcNow.ToString('o')
                    }
                )
            }

            # Save state
            Save-State -State $originalState -StateFile $script:testStateFile

            # Load state
            $loadedState = Get-State -StateFile $script:testStateFile

            # Verify persistence
            $loadedState.version | Should -Be $originalState.version
            $loadedState.last_notified.Count | Should -Be $originalState.last_notified.Count
            $loadedState.last_notified[0].id | Should -Be $originalState.last_notified[0].id
        }

        AfterEach {
            # Clean up test state file
            if (Test-Path $script:testStateFile) {
                Remove-Item $script:testStateFile -Force
            }
        }
    }

    Context "Filter Pipeline Combinations" {
        It "should apply type filter only" {
            $courses = Get-Content $script:coursesFixture -Raw | ConvertFrom-Json

            $filterConfig = @{
                course_types = @(
                    @{ id = 'basic'; name = 'Basic'; patterns = @('Basic'); enabled = $true }
                )
                exclude_patterns = @()
                min_availability = 0
            }

            $filtered = Invoke-FilterPipeline -Courses $courses -FilterConfig $filterConfig

            # Should have only Basic courses
            foreach ($course in $filtered) {
                $course.name | Should -Match 'Basic'
            }
        }

        It "should apply exclusion filter only" {
            $courses = Get-Content $script:coursesFixture -Raw | ConvertFrom-Json

            $filterConfig = @{
                course_types = @()
                exclude_patterns = @('Stages')
                min_availability = 0
            }

            $filtered = Invoke-FilterPipeline -Courses $courses -FilterConfig $filterConfig

            # Should exclude all Stages courses
            foreach ($course in $filtered) {
                $course.name | Should -Not -Match 'Stages'
            }
        }

        It "should apply min_availability filter" {
            $courses = Get-Content $script:coursesFixture -Raw | ConvertFrom-Json

            $filterConfig = @{
                course_types = @()
                exclude_patterns = @()
                min_availability = 5
            }

            $filtered = Invoke-FilterPipeline -Courses $courses -FilterConfig $filterConfig

            # Should have only courses with 5+ availability
            foreach ($course in $filtered) {
                $course.availability | Should -BeGreaterOrEqual 5
            }
        }
    }
}
