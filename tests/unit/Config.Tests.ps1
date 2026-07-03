#Requires -Version 5.1

<#
.SYNOPSIS
    Pester tests for Config module
.DESCRIPTION
    Tests configuration loading, saving, validation
#>

BeforeAll {
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    . "$ModuleRoot/src/core/Config.ps1"

    $testConfigPath = Join-Path $PSScriptRoot "test-config.json"
    $testConfig = @{
        monitors = @(
            @{
                name = "test-monitor"
                provider = "shooting-store"
                enabled = $true
                poll_interval_minutes = 5
                url = "https://example.com"
            }
        )
        filters = @{
            course_types = @(
                @{
                    id = "service-pistol"
                    name = "Service Pistol"
                    patterns = @("Service Pistol", "SP")
                    enabled = $true
                }
            )
            exclusions = @()
        }
        notifiers = @{
            email = @{
                enabled = $true
                smtp_server = "smtp.example.com"
                port = 587
                from_address = "noreply@example.com"
                recipients = @("user@example.com")
            }
            discord = @{
                enabled = $false
                webhook_url = ""
            }
            windows_toast = @{
                enabled = $true
            }
        }
    }

    $testConfig | ConvertTo-Json -Depth 10 | Set-Content $testConfigPath
}

AfterAll {
    if (Test-Path $testConfigPath) {
        Remove-Item $testConfigPath -Force
    }
}

Describe "Read-Config" {
    It "Should load configuration from JSON file" {
        $config = Read-Config -ConfigPath $testConfigPath
        $config | Should -Not -BeNullOrEmpty
        $config.monitors | Should -Not -BeNullOrEmpty
    }

    It "Should return hashtable with required keys" {
        $config = Read-Config -ConfigPath $testConfigPath
        $config | Should -BeOfType [PSCustomObject]
    }

    It "Should throw on missing file" {
        { Read-Config -ConfigPath "nonexistent.json" } | Should -Throw
    }

    It "Should throw on invalid JSON" {
        $invalidPath = Join-Path $PSScriptRoot "invalid.json"
        "{ invalid json" | Set-Content $invalidPath
        try {
            { Read-Config -ConfigPath $invalidPath } | Should -Throw
        } finally {
            Remove-Item $invalidPath -Force
        }
    }
}

Describe "Save-Config" {
    It "Should save configuration to JSON file" {
        $savePath = Join-Path $PSScriptRoot "save-test.json"
        try {
            Save-Config -Config $testConfig -Path $savePath
            Test-Path $savePath | Should -Be $true
        } finally {
            if (Test-Path $savePath) { Remove-Item $savePath -Force }
        }
    }

    It "Should preserve all configuration data" {
        $savePath = Join-Path $PSScriptRoot "preserve-test.json"
        try {
            Save-Config -Config $testConfig -Path $savePath
            $loaded = Read-Config -Path $savePath
            $loaded.monitors[0].name | Should -Be "test-monitor"
            $loaded.notifiers.email.smtp_server | Should -Be "smtp.example.com"
        } finally {
            if (Test-Path $savePath) { Remove-Item $savePath -Force }
        }
    }

    It "Should create directory if it does not exist" {
        $newDir = Join-Path $PSScriptRoot "config-test"
        $savePath = Join-Path $newDir "config.json"
        try {
            Save-Config -Config $testConfig -Path $savePath
            Test-Path $newDir | Should -Be $true
            Test-Path $savePath | Should -Be $true
        } finally {
            if (Test-Path $newDir) { Remove-Item $newDir -Recurse -Force }
        }
    }
}

Describe "Get-ConfigMonitor" {
    It "Should return monitor by name" {
        $config = Read-Config -Path $testConfigPath
        $monitor = Get-ConfigMonitor -Config $config -Name "test-monitor"
        $monitor | Should -Not -BeNullOrEmpty
        $monitor.name | Should -Be "test-monitor"
    }

    It "Should return null for non-existent monitor" {
        $config = Read-Config -Path $testConfigPath
        $monitor = Get-ConfigMonitor -Config $config -Name "nonexistent"
        $monitor | Should -BeNullOrEmpty
    }
}

Describe "Get-EnabledMonitors" {
    It "Should return only enabled monitors" {
        $config = Read-Config -Path $testConfigPath
        $enabled = @(Get-EnabledMonitors -Config $config)
        $enabled.Count | Should -BeGreaterThan 0
        $enabled[0].enabled | Should -Be $true
    }

    It "Should exclude disabled monitors" {
        $testConfig.monitors += @{
            name = "disabled-monitor"
            provider = "test"
            enabled = $false
            poll_interval_minutes = 5
        }

        $savePath = Join-Path $PSScriptRoot "mixed-config.json"
        try {
            Save-Config -Config $testConfig -Path $savePath
            $config = Read-Config -Path $savePath
            $enabled = @(Get-EnabledMonitors -Config $config)
            $enabled.Count | Should -Be 1
            $enabled[0].name | Should -Be "test-monitor"
        } finally {
            if (Test-Path $savePath) { Remove-Item $savePath -Force }
        }
    }
}

Describe "Get-EnabledCourseTypes" {
    It "Should return only enabled course types" {
        $config = Read-Config -Path $testConfigPath
        $enabled = @(Get-EnabledCourseTypes -Config $config)
        $enabled.Count | Should -Be 1
        $enabled[0].enabled | Should -Be $true
    }

    It "Should exclude disabled types" {
        $testConfig.filters.course_types += @{
            id = "standard-pistol"
            name = "Standard Pistol"
            patterns = @("Standard")
            enabled = $false
        }

        $savePath = Join-Path $PSScriptRoot "mixed-types.json"
        try {
            Save-Config -Config $testConfig -Path $savePath
            $config = Read-Config -Path $savePath
            $enabled = @(Get-EnabledCourseTypes -Config $config)
            $enabled.Count | Should -Be 1
        } finally {
            if (Test-Path $savePath) { Remove-Item $savePath -Force }
        }
    }
}
