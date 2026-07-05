#Requires -Version 5.1
#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../../src/core/Logging.ps1'
    . $modulePath

    $testLogDir = "test_logs"
}

AfterAll {
    if (Test-Path $testLogDir) {
        Remove-Item -Path $testLogDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Initialize-Logging" {
    Context "Setup" {
        It "creates log directory if missing" {
            $testDir = "test_temp_logs"
            Initialize-Logging -LogDir $testDir

            Test-Path $testDir | Should -Be $true
            Remove-Item $testDir -Force -ErrorAction SilentlyContinue
        }

        It "sets logging config" {
            Initialize-Logging -LogDir $testLogDir -LogLevel 'INFO' -Format 'json'

            $script:LoggingConfig.LogDir | Should -Be $testLogDir
            $script:LoggingConfig.LogLevel | Should -Be 'INFO'
            $script:LoggingConfig.Format | Should -Be 'json'
        }

        It "accepts custom retention days" {
            Initialize-Logging -LogDir $testLogDir -RetentionDays 14

            $script:LoggingConfig.RetentionDays | Should -Be 14
        }
    }
}

Describe "Write-Log" {
    BeforeEach {
        Initialize-Logging -LogDir $testLogDir -LogLevel 'DEBUG'
    }

    Context "Log Levels" {
        It "accepts DEBUG level" {
            { Write-Log -Level DEBUG -Message "Test" } | Should -Not -Throw
        }

        It "accepts INFO level" {
            { Write-Log -Level INFO -Message "Test" } | Should -Not -Throw
        }

        It "accepts WARN level" {
            { Write-Log -Level WARN -Message "Test" } | Should -Not -Throw
        }

        It "accepts ERROR level" {
            { Write-Log -Level ERROR -Message "Test" } | Should -Not -Throw
        }
    }

    Context "Message Logging" {
        It "logs message to file" {
            Write-Log -Level INFO -Message "Test message"

            $logFile = Get-ChildItem $testLogDir -Filter "watcher-*.log" | Select-Object -First 1
            $logFile | Should -Not -BeNullOrEmpty
        }

        It "includes message in log file" {
            Write-Log -Level INFO -Message "Test message"

            $logFile = Get-ChildItem $testLogDir -Filter "watcher-*.log" | Select-Object -First 1
            $content = Get-Content $logFile.FullName | Out-String
            $content -match "Test message" | Should -Be $true
        }
    }

    Context "Context Data" {
        It "accepts context hashtable" {
            $ctx = @{ monitor = 'test'; count = 5 }
            { Write-Log -Level INFO -Message "Test" -Context $ctx } | Should -Not -Throw
        }

        It "includes context in log file" {
            $ctx = @{ monitor = 'test'; count = 5 }
            Write-Log -Level INFO -Message "Test" -Context $ctx

            $logFile = Get-ChildItem $testLogDir -Filter "watcher-*.log" | Select-Object -First 1
            $content = Get-Content $logFile.FullName | Out-String
            $content -match "monitor" | Should -Be $true
        }
    }

    Context "Exception Handling" {
        It "accepts exception object" {
            try { 1/0 } catch { $e = $_ }
            { Write-Log -Level ERROR -Message "Error" -Exception $e } | Should -Not -Throw
        }

        It "includes exception in log file" {
            try { 1/0 } catch { $e = $_ }
            Write-Log -Level ERROR -Message "Division by zero" -Exception $e

            $logFile = Get-ChildItem $testLogDir -Filter "watcher-*.log" | Select-Object -First 1
            $content = Get-Content $logFile.FullName | Out-String
            $content -match "exception" | Should -Be $true
        }
    }
}

Describe "Remove-OldLog" {
    Context "Log Directory Handling" {
        It "handles missing log directory silently" {
            { Remove-OldLog -LogDir "nonexistent_dir" -RetentionDays 30 } | Should -Not -Throw
        }
    }

    Context "Cmdlet Binding" {
        It "implements SupportsShouldProcess" {
            $cmdletName = 'Remove-OldLog'
            $cmdletInfo = Get-Command $cmdletName

            $cmdletInfo | Should -Not -BeNullOrEmpty
            $cmdletInfo.ScriptBlock.ToString() | Should -Match 'ShouldProcess'
        }
    }
}
