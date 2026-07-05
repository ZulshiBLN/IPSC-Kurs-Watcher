#Requires -Version 5.1
#Requires -Modules Pester

BeforeAll {
    $corePath = Join-Path $PSScriptRoot '../../../src/core'
    . (Join-Path $corePath 'Logging.ps1')
    . (Join-Path $corePath 'Config.ps1')

    Mock Write-Log { $null }
}

Describe "Get-Config" {
    Context "File Loading" {
        It "loads config.json successfully" {
            $config = Get-Config -ConfigPath "config/config.json"
            $config | Should -Not -BeNullOrEmpty
            $config.version | Should -Be 1
        }

        It "throws error if file doesn't exist" {
            { Get-Config -ConfigPath "nonexistent/config.json" } | Should -Throw
        }
    }

    Context "Default Parameters" {
        It "uses default config path 'config/config.json'" {
            $config = Get-Config
            $config | Should -Not -BeNullOrEmpty
        }
    }

    Context "Config Structure" {
        It "returns config with monitors section" {
            $config = Get-Config
            $config.monitors | Should -Not -BeNullOrEmpty
        }

        It "returns config with filters section" {
            $config = Get-Config
            $config.filters | Should -Not -BeNullOrEmpty
        }

        It "returns config with notifiers section" {
            $config = Get-Config
            $config.notifiers | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Test-MonitorConfig" {
    Context "Validation" {
        It "accepts valid monitor config" {
            $monitor = @{ id = 'test'; provider = 'shooting-store'; url = 'https://example.com' }
            { Test-MonitorConfig -MonitorConfig $monitor } | Should -Not -Throw
        }

        It "returns true for valid config" {
            $monitor = @{ id = 'test'; provider = 'shooting-store'; url = 'https://example.com' }
            $result = Test-MonitorConfig -MonitorConfig $monitor
            $result | Should -Be $true
        }

        It "throws error if id is missing" {
            $monitor = @{ provider = 'shooting-store'; url = 'https://example.com' }
            { Test-MonitorConfig -MonitorConfig $monitor } | Should -Throw
        }

        It "throws error if provider is missing" {
            $monitor = @{ id = 'test'; url = 'https://example.com' }
            { Test-MonitorConfig -MonitorConfig $monitor } | Should -Throw
        }

        It "throws error if url is missing" {
            $monitor = @{ id = 'test'; provider = 'shooting-store' }
            { Test-MonitorConfig -MonitorConfig $monitor } | Should -Throw
        }
    }

    Context "Edge Cases" {
        It "rejects null id" {
            $monitor = @{ id = $null; provider = 'shooting-store'; url = 'https://example.com' }
            { Test-MonitorConfig -MonitorConfig $monitor } | Should -Throw
        }

        It "rejects empty string id" {
            $monitor = @{ id = ''; provider = 'shooting-store'; url = 'https://example.com' }
            { Test-MonitorConfig -MonitorConfig $monitor } | Should -Throw
        }
    }
}
