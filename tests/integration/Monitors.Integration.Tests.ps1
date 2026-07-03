#Requires -Version 5.1
#Requires -Modules Pester

BeforeAll {
    # Load modules using absolute path
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $modulePaths = @(
        "$repoRoot/src/core/Helpers.ps1"
        "$repoRoot/src/core/Logging.ps1"
        "$repoRoot/src/core/Config.ps1"
        "$repoRoot/src/monitors/MonitorBase.ps1"
        "$repoRoot/src/monitors/CourseMonitor.ps1"
    )

    foreach ($path in $modulePaths) {
        if (Test-Path $path) {
            . $path
        } else {
            Write-Warning "Module not found: $path"
        }
    }

    $script:fixturesDir = Join-Path $PSScriptRoot '../fixtures'
    $script:htmlFixture = Join-Path $script:fixturesDir 'html/shooting-store-sample.html'
    $script:configFixture = Join-Path $script:fixturesDir 'configs/test-config.json'

    Initialize-Logging -LogDir (Join-Path $script:fixturesDir 'logs') -LogLevel 'WARN'
}

Describe "CourseMonitor Integration" {
    Context "HTML Parsing from Fixture" {
        It "should load and parse test HTML fixture" {
            $html = Get-Content $script:htmlFixture -Raw
            $html | Should -Not -BeNullOrEmpty
            $html | Should -Match 'IPSC'
        }

        It "should extract course count from fixture HTML" {
            # This would require CourseMonitor to be fully functional
            # For now, just verify the HTML has expected elements
            $html = Get-Content $script:htmlFixture -Raw

            # Should have 8 course-card divs
            $courseCards = [regex]::Matches($html, 'class="course-card"')
            $courseCards.Count | Should -Be 9  # 8 real courses + 1 Privatunterricht
        }

        It "should have courses with availability data" {
            $html = Get-Content $script:htmlFixture -Raw

            # Should have availability numbers
            $html | Should -Match 'Verfügbare Plätze:'
            $html | Should -Match '<strong>\d+</strong>'
        }

        It "should include course links and prices" {
            $html = Get-Content $script:htmlFixture -Raw

            # Should have course links
            $html | Should -Match '/de/produkt/'

            # Should have prices
            $html | Should -Match 'CHF \d+'
        }

        It "should have diverse course types" {
            $html = Get-Content $script:htmlFixture -Raw

            # Should have different course types
            $html | Should -Match 'IPSC Basic'
            $html | Should -Match 'IPSC Stages'
            $html | Should -Match 'IPSC Moving'
            $html | Should -Match 'IPSC Movement'
            $html | Should -Match 'IPSC Steel'
        }

        It "should have test course with no availability" {
            $html = Get-Content $script:htmlFixture -Raw

            # Should have Privatunterricht with 0 availability
            $html | Should -Match 'Privatunterricht'
            $html | Should -Match '<strong>0</strong>'
        }
    }

    Context "Monitor Configuration" {
        It "should load monitor configuration from fixture" {
            $config = Get-Config -ConfigPath $script:configFixture

            $config.monitors | Should -Not -BeNullOrEmpty
            $config.monitors[0].id | Should -Be 'shooting-store'
            $config.monitors[0].provider | Should -Be 'shooting-store'
            $config.monitors[0].enabled | Should -Be $true
        }

        It "should have valid configuration URLs" {
            $config = Get-Config -ConfigPath $script:configFixture

            $url = $config.monitors[0].url
            $url | Should -Match '^https?://'
            $url | Should -Not -BeNullOrEmpty
        }

        It "should have reasonable timeout values" {
            $config = Get-Config -ConfigPath $script:configFixture

            $config.monitors[0].timeout_seconds | Should -BeGreaterThan 0
            $config.monitors[0].timeout_seconds | Should -BeLessThanOrEqual 300
        }
    }

    Context "Test Fixture Completeness" {
        It "should have all required fixture files" {
            Test-Path $script:htmlFixture | Should -Be $true
            Test-Path $script:configFixture | Should -Be $true
        }

        It "should have valid JSON in test courses" {
            $coursesFile = Join-Path $script:fixturesDir 'data/test-courses.json'
            $json = Get-Content $coursesFile -Raw | ConvertFrom-Json

            $json | Should -Not -BeNullOrEmpty
            $json.Count | Should -Be 8
            $json[0].id | Should -Not -BeNullOrEmpty
            $json[0].name | Should -Not -BeNullOrEmpty
        }

        It "should have valid JSON in example state" {
            $stateFile = Join-Path $script:fixturesDir 'data/state-example.json'
            $json = Get-Content $stateFile -Raw | ConvertFrom-Json

            $json.version | Should -Be 1
            $json.last_notified | Should -Not -BeNullOrEmpty
            $json.last_notified.Count | Should -Be 5
        }
    }
}
