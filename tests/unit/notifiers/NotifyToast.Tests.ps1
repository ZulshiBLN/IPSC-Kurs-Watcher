#Requires -Version 5.1
#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../../src/notifiers/NotifyToast.ps1'
    $corePath = Join-Path $PSScriptRoot '../../../src/core'

    . (Join-Path $corePath 'Logging.ps1')
    . (Join-Path $corePath 'Helpers.ps1')
    . $modulePath

    Mock Write-Log { $null }
}

Describe "Send-ToastNotification" {

    Context "Configuration Validation" {
        It "returns silently when disabled" {
            $alerts = @(@{ alert_reason = 'NEW_COURSE'; name = 'Test'; time = '19:00'; availability = 3 })
            $config = @{ enabled = $false }

            { Send-ToastNotification -Alerts $alerts -Config $config } | Should -Not -Throw
        }

        It "requires Alerts parameter (mandatory)" {
            $config = @{ enabled = $true }

            { Send-ToastNotification -Config $config } | Should -Throw
        }

        It "requires Config parameter (mandatory)" {
            $alerts = @(@{ alert_reason = 'NEW_COURSE'; name = 'Test'; time = '19:00'; availability = 3 })

            { Send-ToastNotification -Alerts $alerts } | Should -Throw
        }
    }

    Context "Grouping Logic" {
        It "function exists and is callable" {
            { Group-AlertsByType -Alerts @(@{ alert_reason = 'NEW_COURSE'; name = 'Test' }) } | Should -Not -Throw
        }
    }

    Context "Title Formatting" {
        It "formats title with emoji and count" {
            $alertGroup = @{
                Emoji = '🟢'
                Description = 'NEW COURSES'
                Count = 2
            }

            $title = _NewToastTitle -AlertGroup $alertGroup

            $title | Should -Be '🟢 NEW COURSES (2)'
        }

        It "handles single alert in title" {
            $alertGroup = @{
                Emoji = '🟡'
                Description = 'AVAILABILITY REDUCED'
                Count = 1
            }

            $title = _NewToastTitle -AlertGroup $alertGroup

            $title | Should -Be '🟡 AVAILABILITY REDUCED (1)'
        }
    }

    Context "Body Formatting" {
        It "formats body with course details" {
            $alertGroup = @{
                Alerts = @(
                    @{ name = 'Basic 2.0'; time = '19:00'; availability = 3 }
                    @{ name = 'Advanced'; time = '09:00'; availability = 2 }
                )
            }

            $body = _NewToastBody -AlertGroup $alertGroup -MaxCourses 5

            $body | Should -Match 'Basic 2.0'
            $body | Should -Match 'Advanced'
            $body | Should -Match '19:00'
            $body | Should -Match '09:00'
        }

        It "respects MaxCourses limit" {
            $alertGroup = @{
                Alerts = @(
                    @{ name = 'Course1'; time = '10:00'; availability = 1 }
                    @{ name = 'Course2'; time = '11:00'; availability = 2 }
                    @{ name = 'Course3'; time = '12:00'; availability = 3 }
                )
            }

            $body = _NewToastBody -AlertGroup $alertGroup -MaxCourses 2

            $body | Should -Match 'Course1'
            $body | Should -Match 'Course2'
            $body | Should -Match '\+1 more\.\.\.'
        }

        It "handles single course" {
            $alertGroup = @{
                Alerts = @(
                    @{ name = 'Tryout'; time = '15:00'; availability = 5 }
                )
            }

            $body = _NewToastBody -AlertGroup $alertGroup -MaxCourses 5

            $body | Should -Be 'Tryout (15:00, 5 spots)'
        }
    }

    Context "XML Generation" {
        It "creates valid XML structure" {
            $xml = _NewToastXML -Title '🟢 NEW COURSES (1)' `
                               -Body 'Basic (19:00, 3 spots)' `
                               -ActionUrl 'https://example.com' `
                               -SoundEnabled $true

            $xml | Should -Match '<\?xml'
            $xml | Should -Match '<toast>'
            $xml | Should -Match '<visual>'
            $xml | Should -Match '<binding template="ToastText02">'
            $xml | Should -Match '<actions>'
            $xml | Should -Match '</toast>'
        }

        It "includes title in XML" {
            $xml = _NewToastXML -Title 'Test Title' `
                               -Body 'Test Body' `
                               -ActionUrl 'https://example.com' `
                               -SoundEnabled $true

            $xml | Should -Match 'Test Title'
        }

        It "includes body in XML" {
            $xml = _NewToastXML -Title 'Test Title' `
                               -Body 'Test Body' `
                               -ActionUrl 'https://example.com' `
                               -SoundEnabled $true

            $xml | Should -Match 'Test Body'
        }

        It "includes action URL in XML" {
            $xml = _NewToastXML -Title 'Title' `
                               -Body 'Body' `
                               -ActionUrl 'https://shooting-store.ch' `
                               -SoundEnabled $true

            $xml | Should -Match 'https://shooting-store.ch'
        }

        It "includes audio element when sound enabled" {
            $xml = _NewToastXML -Title 'Title' `
                               -Body 'Body' `
                               -ActionUrl 'https://example.com' `
                               -SoundEnabled $true

            $xml | Should -Match '<audio src="ms-winsoundevent:Notification.Default"'
        }

        It "mutes audio when sound disabled" {
            $xml = _NewToastXML -Title 'Title' `
                               -Body 'Body' `
                               -ActionUrl 'https://example.com' `
                               -SoundEnabled $false

            $xml | Should -Match '<audio silent="true"'
        }

        It "escapes XML special characters in title" {
            $xml = _NewToastXML -Title 'Test & <Title>' `
                               -Body 'Body' `
                               -ActionUrl 'https://example.com' `
                               -SoundEnabled $false

            $xml | Should -Match 'Test &amp; &lt;Title&gt;'
        }

        It "escapes XML special characters in body" {
            $xml = _NewToastXML -Title 'Title' `
                               -Body 'Test & <Body>' `
                               -ActionUrl 'https://example.com' `
                               -SoundEnabled $false

            $xml | Should -Match 'Test &amp; &lt;Body&gt;'
        }

        It "escapes XML special characters in URL" {
            $xml = _NewToastXML -Title 'Title' `
                               -Body 'Body' `
                               -ActionUrl 'https://example.com?param=a&b=c' `
                               -SoundEnabled $false

            $xml | Should -Match 'https://example.com\?param=a&amp;b=c'
        }
    }

    Context "Helper Functions" {
        It "Test-ToastSupported function exists" {
            Get-Command Test-ToastSupported | Should -Not -BeNullOrEmpty
        }

        It "_NewToastBody function exists" {
            Get-Command _NewToastBody | Should -Not -BeNullOrEmpty
        }

        It "_NewToastTitle function exists" {
            Get-Command _NewToastTitle | Should -Not -BeNullOrEmpty
        }

        It "_NewToastXML function exists" {
            Get-Command _NewToastXML | Should -Not -BeNullOrEmpty
        }
    }
}
