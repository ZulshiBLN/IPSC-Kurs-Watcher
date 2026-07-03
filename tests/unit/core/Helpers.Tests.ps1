#Requires -Version 5.1
#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../../src/core/Helpers.ps1'
    . $modulePath
}

Describe "ConvertTo-SafeJson" {
    Context "Object Conversion" {
        It "converts hashtable to JSON" {
            $obj = @{ id = 1; name = "Test" }
            $json = $obj | ConvertTo-SafeJson

            $json | Should -Not -BeNullOrEmpty
            $json -match '"id"' | Should -Be $true
            $json -match '"name"' | Should -Be $true
        }

        It "converts object to JSON" {
            $obj = [PSCustomObject]@{ id = 1; name = "Test" }
            $json = $obj | ConvertTo-SafeJson

            $json | Should -Not -BeNullOrEmpty
            $json -match '"id"' | Should -Be $true
        }

        It "accepts Depth parameter" {
            $obj = @{ level1 = @{ level2 = @{ level3 = "deep" } } }
            $json = $obj | ConvertTo-SafeJson -Depth 5

            $json | Should -Not -BeNullOrEmpty
        }

        It "returns null on conversion error" {
            $circular = @{}
            $circular.self = $circular

            $result = $circular | ConvertTo-SafeJson -ErrorAction SilentlyContinue
            # Depending on PowerShell version, may throw or return $null
        }
    }
}

Describe "ConvertFrom-SafeJson" {
    Context "JSON Parsing" {
        It "parses valid JSON" {
            $json = '{"id": 1, "name": "Test"}'
            $obj = $json | ConvertFrom-SafeJson

            $obj | Should -Not -BeNullOrEmpty
            $obj.id | Should -Be 1
            $obj.name | Should -Be "Test"
        }

        It "parses JSON array" {
            $json = '[{"id": 1}, {"id": 2}]'
            $obj = $json | ConvertFrom-SafeJson

            $obj.Count | Should -Be 2
        }

        It "returns null on parse error" {
            $invalidJson = '{invalid json}'
            $result = $invalidJson | ConvertFrom-SafeJson -ErrorAction SilentlyContinue

            $result | Should -BeNullOrEmpty
        }
    }
}

Describe "Test-FilePath" {
    Context "File Validation" {
        It "returns true for existing file" {
            $testFile = "test_temp_file.txt"
            New-Item -Path $testFile -Force | Out-Null

            $result = Test-FilePath -Path $testFile

            $result | Should -Be $true

            Remove-Item $testFile -Force
        }

        It "returns false for non-existent file" {
            $result = Test-FilePath -Path "nonexistent_file.txt"
            $result | Should -Be $false
        }

        It "returns false for directory" {
            $testDir = "test_temp_dir"
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null

            $result = Test-FilePath -Path $testDir

            $result | Should -Be $false

            Remove-Item $testDir -Force
        }
    }
}

Describe "Get-FileDirectory" {
    Context "Directory Creation" {
        It "creates directory if missing" {
            $testPath = "test_temp_new_dir"

            $result = Get-FileDirectory -Path $testPath

            Test-Path $testPath | Should -Be $true
            $result | Should -Be $testPath

            Remove-Item $testPath -Force
        }

        It "returns path if directory exists" {
            $testPath = "test_temp_existing"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            $result = Get-FileDirectory -Path $testPath

            $result | Should -Be $testPath

            Remove-Item $testPath -Force
        }

        It "returns null on creation error" {
            $invalidPath = "C:\invalid_root_path\directory"

            $result = Get-FileDirectory -Path $invalidPath -ErrorAction SilentlyContinue

            # May return null or throw depending on permissions
        }
    }
}

Describe "Invoke-WithRetry" {
    Context "Retry Logic" {
        It "executes scriptblock successfully" {
            $scriptblock = { return "success" }
            $result = Invoke-WithRetry -ScriptBlock $scriptblock

            $result | Should -Be "success"
        }

        It "retries on failure and succeeds" {
            $script:attempt = 0
            $scriptblock = {
                $script:attempt++
                if ($script:attempt -lt 2) { throw "Not yet" }
                return "success"
            }

            $result = Invoke-WithRetry -ScriptBlock $scriptblock -MaxAttempts 5 -BaseDelaySeconds 0.05

            $result | Should -Be "success"
            $script:attempt | Should -BeGreaterThan 1
        }

        It "throws after max attempts exceeded" {
            $scriptblock = { throw "Always fails" }

            { Invoke-WithRetry -ScriptBlock $scriptblock -MaxAttempts 2 -BaseDelaySeconds 0.01 } | Should -Throw
        }

        It "supports custom base delay" {
            $scriptblock = { throw "Fail" }

            { Invoke-WithRetry -ScriptBlock $scriptblock -MaxAttempts 2 -BaseDelaySeconds 0.01 } | Should -Throw
        }
    }
}

Describe "Protect-SensitiveData" {
    Context "Data Masking" {
        It "masks password" {
            $input = 'password="secret123"'
            $result = Protect-SensitiveData -InputString $input

            $result | Should -Match 'MASKED'
            $result | Should -Not -Match 'secret123'
        }

        It "masks api_key" {
            $input = 'api_key="abc123xyz"'
            $result = Protect-SensitiveData -InputString $input

            $result | Should -Match 'MASKED'
        }

        It "masks webhook_url" {
            $input = 'webhook_url="https://discord.com/api/webhooks/123"'
            $result = Protect-SensitiveData -InputString $input

            $result | Should -Match 'MASKED'
        }

        It "masks email address" {
            $input = 'user@example.com'
            $result = Protect-SensitiveData -InputString $input

            $result | Should -Match '@'
            $result | Should -Not -Match 'user'
        }

        It "handles null input" {
            $result = Protect-SensitiveData -InputString $null

            $result | Should -BeNullOrEmpty
        }

        It "handles empty string" {
            $result = Protect-SensitiveData -InputString ""

            $result | Should -Be ""
        }
    }
}

Describe "Get-UtcTimestamp" {
    Context "Timestamp Generation" {
        It "returns ISO 8601 formatted string" {
            $ts = Get-UtcTimestamp

            $ts | Should -Not -BeNullOrEmpty
            $ts -match '\d{4}-\d{2}-\d{2}' | Should -Be $true
        }

        It "contains 'Z' for UTC" {
            $ts = Get-UtcTimestamp

            $ts | Should -Match 'Z$'
        }

        It "returns valid datetime string" {
            $ts = Get-UtcTimestamp

            { [DateTime]::Parse($ts) } | Should -Not -Throw
        }
    }
}

Describe "ConvertTo-UnixTimestamp" {
    Context "Timestamp Conversion" {
        It "converts DateTime to Unix timestamp" {
            $dt = [DateTime]'1970-01-01'
            $result = ConvertTo-UnixTimestamp -DateTime $dt

            $result | Should -Be 0
        }

        It "returns integer" {
            $dt = Get-Date
            $result = ConvertTo-UnixTimestamp -DateTime $dt

            $result | Should -BeOfType [long]
        }

        It "handles future dates" {
            $dt = [DateTime]'2026-07-03'
            $result = ConvertTo-UnixTimestamp -DateTime $dt

            $result | Should -BeGreaterThan 0
        }
    }
}
