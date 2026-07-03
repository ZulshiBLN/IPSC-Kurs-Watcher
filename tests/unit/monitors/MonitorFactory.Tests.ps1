#Requires -Version 5.1
#Requires -Modules Pester

BeforeAll {
    $monitorsPath = Join-Path $PSScriptRoot '../../../src/monitors'
    $corePath = Join-Path $PSScriptRoot '../../../src/core'

    . (Join-Path $corePath 'Logging.ps1')
    . (Join-Path $monitorsPath 'MonitorBase.ps1')
    . (Join-Path $monitorsPath 'CourseMonitor.ps1')
    . (Join-Path $monitorsPath 'MonitorFactory.ps1')

    Mock Write-Log { $null }
    Mock Invoke-WebRequest { @{ Content = "<html></html>" } }
}

Describe "Get-Monitor" {
    Context "Monitor Creation" {
        It "creates CourseMonitor for shooting-store provider" {
            $config = @{
                provider = 'shooting-store'
                id = 'test'
                url = 'https://example.com'
                base_url = 'https://example.com'
                enabled = $true
            }

            $monitor = Get-Monitor -Config $config

            $monitor | Should -Not -BeNullOrEmpty
            $monitor.GetType().Name | Should -Be 'CourseMonitor'
        }

        It "throws for unknown provider" {
            $config = @{
                provider = 'unknown-provider'
                id = 'test'
                url = 'https://example.com'
                base_url = 'https://example.com'
            }

            { Get-Monitor -Config $config } | Should -Throw
        }
    }

    Context "Configuration Passing" {
        It "passes config to monitor" {
            $config = @{
                provider = 'shooting-store'
                id = 'my-monitor'
                url = 'https://example.com'
                base_url = 'https://example.com'
                enabled = $true
            }

            $monitor = Get-Monitor -Config $config

            $monitor.Id | Should -Be 'my-monitor'
            $monitor.Provider | Should -Be 'shooting-store'
        }
    }
}

Describe "CourseMonitor" {
    Context "Initialization" {
        It "creates monitor with valid config" {
            $config = @{
                provider = 'shooting-store'
                id = 'test'
                url = 'https://shooting-store.ch'
                base_url = 'https://shooting-store.ch'
                enabled = $true
                timeout_seconds = 30
                retry_attempts = 3
            }

            $monitor = [CourseMonitor]::new($config)

            $monitor | Should -Not -BeNullOrEmpty
            $monitor.Id | Should -Be 'test'
        }

        It "throws if URL is missing" {
            $config = @{
                provider = 'shooting-store'
                id = 'test'
                base_url = 'https://example.com'
            }

            { [CourseMonitor]::new($config) } | Should -Throw
        }

        It "throws if base_url is missing" {
            $config = @{
                provider = 'shooting-store'
                id = 'test'
                url = 'https://example.com'
            }

            { [CourseMonitor]::new($config) } | Should -Throw
        }
    }

    Context "Default Values" {
        It "uses default timeout if not provided" {
            $config = @{
                provider = 'shooting-store'
                id = 'test'
                url = 'https://example.com'
                base_url = 'https://example.com'
            }

            $monitor = [CourseMonitor]::new($config)

            $monitor.TimeoutSeconds | Should -Be 30
        }

        It "uses default retry attempts if not provided" {
            $config = @{
                provider = 'shooting-store'
                id = 'test'
                url = 'https://example.com'
                base_url = 'https://example.com'
            }

            $monitor = [CourseMonitor]::new($config)

            $monitor.RetryAttempts | Should -Be 3
        }
    }
}

Describe "MonitorBase Class" {
    Context "Abstract Methods" {
        It "throws for unimplemented Invoke method" {
            $config = @{
                provider = 'unknown'
                id = 'test'
                url = 'https://example.com'
                base_url = 'https://example.com'
            }

            $monitor = [MonitorBase]::new($config)

            { $monitor.Invoke() } | Should -Throw
        }
    }
}
