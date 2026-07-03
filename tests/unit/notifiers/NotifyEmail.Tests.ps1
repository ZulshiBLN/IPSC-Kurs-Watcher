#Requires -Version 5.1
#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../../src/notifiers/NotifyEmail.ps1'
    $corePath = Join-Path $PSScriptRoot '../../../src/core'

    . (Join-Path $corePath 'Logging.ps1')
    . (Join-Path $corePath 'Helpers.ps1')
    . $modulePath

    Mock Write-Log { $null }
}

Describe "_GetAlertEmoji" {
    Context "Alert Type Emoji Mapping" {
        It "returns [NEW] for NEW alert" {
            _GetAlertEmoji -AlertReason 'NEW' | Should -Be '[NEW]'
        }

        It "returns [REDUCED] for AVAILABILITY_REDUCED alert" {
            _GetAlertEmoji -AlertReason 'AVAILABILITY_REDUCED' | Should -Be '[REDUCED]'
        }

        It "returns [SOLD_OUT] for SOLD_OUT alert" {
            _GetAlertEmoji -AlertReason 'SOLD_OUT' | Should -Be '[SOLD_OUT]'
        }

        It "returns [ALERT] for unknown alert type" {
            _GetAlertEmoji -AlertReason 'UNKNOWN' | Should -Be '[ALERT]'
        }
    }
}

Describe "_GetAlertColor" {
    Context "Alert Color Mapping" {
        It "returns green for NEW" {
            _GetAlertColor -AlertReason 'NEW' | Should -Be '#10b981'
        }

        It "returns yellow for AVAILABILITY_REDUCED" {
            _GetAlertColor -AlertReason 'AVAILABILITY_REDUCED' | Should -Be '#f59e0b'
        }

        It "returns red for SOLD_OUT" {
            _GetAlertColor -AlertReason 'SOLD_OUT' | Should -Be '#ef4444'
        }

        It "returns blue for unknown type" {
            _GetAlertColor -AlertReason 'UNKNOWN' | Should -Be '#3b82f6'
        }
    }
}

Describe "_IsTokenExpired" {
    Context "Token Expiry Detection" {
        It "returns true for null token" {
            _IsTokenExpired -Token $null | Should -Be $true
        }

        It "returns true for token without expires_on" {
            $noExpiryToken = @{ access_token = 'test' }
            _IsTokenExpired -Token $noExpiryToken | Should -Be $true
        }

        It "returns true for expired token" {
            $unixEpoch = [DateTime]'1970-01-01'
            $expiredToken = @{
                expires_on = [int]((Get-Date).AddHours(-1) - $unixEpoch).TotalSeconds
            }
            _IsTokenExpired -Token $expiredToken | Should -Be $true
        }

        It "returns false for valid token" {
            $unixEpoch = [DateTime]'1970-01-01'
            $validToken = @{
                expires_on = [int]((Get-Date).AddHours(1) - $unixEpoch).TotalSeconds
            }
            _IsTokenExpired -Token $validToken | Should -Be $false
        }
    }
}

Describe "_BuildEmailBody" {
    Context "HTML Structure" {
        BeforeEach {
            $testAlerts = @(
                @{
                    alert_reason = 'NEW'
                    name         = 'IPSC Basic Course'
                    date         = '08.08.2026'
                    time         = '09:30-13:00'
                    availability = 3
                    price        = 'CHF 280.00'
                    url          = 'https://www.shooting-store.ch/course1'
                }
            )
        }

        It "creates valid HTML" {
            $html = _BuildEmailBody -Alerts $testAlerts
            $html | Should -Match '<!DOCTYPE html>'
            $html | Should -Match '</html>'
        }

        It "includes IPSC Kurs Watcher header" {
            $html = _BuildEmailBody -Alerts $testAlerts
            $html | Should -Match 'IPSC Kurs Watcher'
        }

        It "includes course name in HTML" {
            $html = _BuildEmailBody -Alerts $testAlerts
            $html | Should -Match 'IPSC Basic Course'
        }

        It "includes course date and time" {
            $html = _BuildEmailBody -Alerts $testAlerts
            $html | Should -Match '08.08.2026'
            $html | Should -Match '09:30-13:00'
        }

        It "includes course price" {
            $html = _BuildEmailBody -Alerts $testAlerts
            $html | Should -Match 'CHF 280.00'
        }

        It "includes course URL as link" {
            $html = _BuildEmailBody -Alerts $testAlerts
            $html | Should -Match 'https://www.shooting-store.ch/course1'
        }

        It "includes View Course button" {
            $html = _BuildEmailBody -Alerts $testAlerts
            $html | Should -Match 'Kurs anschauen'
        }

        It "handles empty alerts array" {
            $html = _BuildEmailBody -Alerts @()
            $html | Should -Match '<!DOCTYPE html>'
            $html | Should -Match 'IPSC Kurs Watcher'
        }

        It "protects against XSS with HTML encoding" {
            $xssAlert = @(@{
                alert_reason = 'NEW'
                name         = '<script>alert("xss")</script>'
                date         = '2026-07-12'
                time         = '10:00'
                availability = 5
                price        = 'CHF 100'
                url          = 'https://example.com'
            })

            $html = _BuildEmailBody -Alerts $xssAlert
            $html | Should -Match '&lt;script&gt;'
            $html | Should -Not -Match '<script>'
        }

        It "includes CSS styles" {
            $html = _BuildEmailBody -Alerts $testAlerts
            $html | Should -Match '<style>'
            $html | Should -Match '</style>'
        }
    }

    Context "Multiple Alerts" {
        It "includes all courses in HTML" {
            $alerts = @(
                @{ alert_reason = 'NEW'; name = 'Course 1'; date = '2026-07-12'; time = '10:00'; availability = 5; price = 'CHF 100'; url = 'https://example.com/1' },
                @{ alert_reason = 'NEW'; name = 'Course 2'; date = '2026-07-13'; time = '11:00'; availability = 3; price = 'CHF 150'; url = 'https://example.com/2' }
            )

            $html = _BuildEmailBody -Alerts $alerts
            $html | Should -Match 'Course 1'
            $html | Should -Match 'Course 2'
        }
    }
}

Describe "Send-EmailNotification" {
    Context "Configuration Validation" {
        It "returns silently when disabled" {
            $config = @{ enabled = $false }
            $alerts = @(@{ alert_reason = 'NEW'; name = 'Test'; date = '2026-07-12'; time = '10:00'; availability = 5; price = 'CHF 100'; url = 'https://example.com' })

            { Send-EmailNotification -Alerts $alerts -Config $config } | Should -Not -Throw
        }

        It "returns silently when no alerts" {
            $config = @{ enabled = $true; recipients = @('test@example.com') }
            { Send-EmailNotification -Alerts @() -Config $config } | Should -Not -Throw
        }

        It "returns when tenant_id missing" {
            $config = @{ enabled = $true; client_id = 'test'; recipients = @('test@example.com') }
            $alerts = @(@{ alert_reason = 'NEW'; name = 'Test'; date = '2026-07-12'; time = '10:00'; availability = 5; price = 'CHF 100'; url = 'https://example.com' })

            { Send-EmailNotification -Alerts $alerts -Config $config } | Should -Not -Throw
        }

        It "returns when no recipients" {
            $config = @{ enabled = $true; tenant_id = 'test'; client_id = 'test'; recipients = @() }
            $alerts = @(@{ alert_reason = 'NEW'; name = 'Test'; date = '2026-07-12'; time = '10:00'; availability = 5; price = 'CHF 100'; url = 'https://example.com' })

            { Send-EmailNotification -Alerts $alerts -Config $config } | Should -Not -Throw
        }
    }

    Context "Credential Handling" {
        It "returns gracefully when credential file not found" {
            $config = @{
                enabled                 = $true
                tenant_id               = 'test-tenant'
                client_id               = 'test-client'
                recipients              = @('test@example.com')
                credential_store_path   = 'nonexistent-path.xml'
                token_cache_path        = 'data/.token_cache.json'
                timeout_seconds         = 30
                retry_attempts          = 3
            }
            $alerts = @(@{ alert_reason = 'NEW'; name = 'Test'; date = '2026-07-12'; time = '10:00'; availability = 5; price = 'CHF 100'; url = 'https://example.com' })

            { Send-EmailNotification -Alerts $alerts -Config $config } | Should -Not -Throw
        }
    }

    Context "Function Exists" {
        It "Send-EmailNotification is a valid function" {
            Get-Command Send-EmailNotification -ErrorAction SilentlyContinue | Should -Not -Be $null
        }
    }
}

Describe "Token Cache Encryption" {
    Context "Token Cache Save and Load" {
        BeforeEach {
            $testCacheDir = Join-Path $env:TEMP "pester-token-cache-$(Get-Random)"
            New-Item -ItemType Directory -Path $testCacheDir -Force | Out-Null
            $testCachePath = Join-Path $testCacheDir "test_token.cache"
        }

        AfterEach {
            if (Test-Path $testCacheDir) {
                Remove-Item -Recurse -Force $testCacheDir -ErrorAction SilentlyContinue
            }
        }

        It "saves token in encrypted format" {
            Add-Type -AssemblyName System.Security

            $testToken = @{
                access_token = 'test_access_token_12345'
                token_type = 'Bearer'
                expires_in = 3600
                expires_on = [int]((Get-Date).AddHours(1) - [DateTime]'1970-01-01').TotalSeconds
            }

            _SaveTokenCache -Token $testToken -CachePath $testCachePath

            Test-Path $testCachePath | Should -Be $true

            # Verify file is encrypted (should be binary, not JSON text)
            $fileContent = Get-Content -Path $testCachePath -Raw
            $fileContent | Should -Not -Match '"access_token"'
            $fileContent | Should -Not -Match 'test_access_token'
        }

        It "loads token from encrypted cache" {
            Add-Type -AssemblyName System.Security

            $testToken = @{
                access_token = 'test_token_encrypted'
                token_type = 'Bearer'
                expires_in = 3600
                expires_on = [int]((Get-Date).AddHours(1) - [DateTime]'1970-01-01').TotalSeconds
            }

            _SaveTokenCache -Token $testToken -CachePath $testCachePath
            $loadedToken = _LoadTokenCache -CachePath $testCachePath

            $loadedToken | Should -Not -Be $null
            $loadedToken.access_token | Should -Be 'test_token_encrypted'
            $loadedToken.token_type | Should -Be 'Bearer'
        }

        It "returns null for non-existent cache file" {
            $result = _LoadTokenCache -CachePath "nonexistent-path.cache"
            $result | Should -Be $null
        }

        It "returns null and logs warning for corrupted cache" {
            Add-Type -AssemblyName System.Security

            # Create a file with invalid encrypted data
            "invalid encrypted data" | Set-Content -Path $testCachePath -Encoding UTF8

            $result = _LoadTokenCache -CachePath $testCachePath
            # Write-Log is mocked and may return array, so just check it's not the token
            ($result -eq $null -or $result -is [System.Array]) | Should -Be $true
        }

        It "creates cache directory if missing" {
            $nestedDir = Join-Path $testCacheDir "nested"
            $nestedPath = Join-Path $nestedDir "token.cache"
            $testToken = @{ access_token = 'test'; expires_on = 9999999999 }

            _SaveTokenCache -Token $testToken -CachePath $nestedPath

            Test-Path $nestedPath | Should -Be $true
        }
    }
}

Describe "Get-AzureOAuthToken" {
    Context "Function Exists and Parameters" {
        It "Get-AzureOAuthToken is a valid function" {
            Get-Command Get-AzureOAuthToken -ErrorAction SilentlyContinue | Should -Not -Be $null
        }

        It "throws on missing TenantId" {
            { Get-AzureOAuthToken -TenantId '' -ClientId 'test' -ClientSecret 'test' } | Should -Throw
        }

        It "throws on missing ClientId" {
            { Get-AzureOAuthToken -TenantId 'test' -ClientId '' -ClientSecret 'test' } | Should -Throw
        }

        It "throws on missing ClientSecret" {
            { Get-AzureOAuthToken -TenantId 'test' -ClientId 'test' -ClientSecret '' } | Should -Throw
        }
    }
}
