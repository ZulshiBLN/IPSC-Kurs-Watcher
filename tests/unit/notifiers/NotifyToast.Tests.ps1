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
            $alerts = @(@{ alert_reason = 'NEW_COURSE'; name = 'Test'; time = '19:00'; availability = 3; price = 'CHF 100'; url = 'https://example.com' })
            $config = @{ enabled = $false }

            { Send-ToastNotification -Alerts $alerts -Config $config } | Should -Not -Throw
        }

        It "requires Alerts parameter (mandatory)" {
            $config = @{ enabled = $true }

            { Send-ToastNotification -Config $config } | Should -Throw
        }

        It "requires Config parameter (mandatory)" {
            $alerts = @(@{ alert_reason = 'NEW_COURSE'; name = 'Test'; time = '19:00'; availability = 3; price = 'CHF 100'; url = 'https://example.com' })

            { Send-ToastNotification -Alerts $alerts } | Should -Throw
        }
    }

    Context "Alert Emoji Mapping" {
        It "_GetAlertEmoji function exists and returns value" {
            $emoji = _GetAlertEmoji -AlertReason 'NEW_COURSE'
            $emoji | Should -Not -BeNullOrEmpty
        }
    }

    Context "XML Generation" {
        It "creates valid XML structure" {
            $xml = _NewToastXML -Title '🟢 IPSC Basic 2.0' `
                               -Body '09:30-13:00 | 2 spots | CHF 280.00' `
                               -ActionUrl 'https://example.com/course1' `
                               -SoundEnabled $true

            $xml | Should -Match '<\?xml'
            $xml | Should -Match '<toast>'
            $xml | Should -Match '<visual>'
            $xml | Should -Match '<binding template="ToastText02">'
            $xml | Should -Match '<actions>'
            $xml | Should -Match '</toast>'
        }

        It "includes title in XML" {
            $xml = _NewToastXML -Title '🟢 Test Course' `
                               -Body 'Test Body' `
                               -ActionUrl 'https://example.com' `
                               -SoundEnabled $true

            $xml | Should -Match 'Test Course'
        }

        It "includes body in XML" {
            $xml = _NewToastXML -Title 'Test Title' `
                               -Body '12.07.2026 | 19:00-21:00 | CHF 150.00' `
                               -ActionUrl 'https://example.com' `
                               -SoundEnabled $true

            $xml | Should -Match '12.07.2026'
            $xml | Should -Match '19:00-21:00'
            $xml | Should -Match 'CHF 150.00'
        }

        It "includes course-specific URL in XML" {
            $xml = _NewToastXML -Title 'Course' `
                               -Body 'Details' `
                               -ActionUrl 'https://shooting-store.ch/de/produkt/course-123' `
                               -SoundEnabled $true

            $xml | Should -Match 'https://shooting-store.ch/de/produkt/course-123'
        }

        It "includes View Course action button" {
            $xml = _NewToastXML -Title 'Course' `
                               -Body 'Details' `
                               -ActionUrl 'https://example.com' `
                               -SoundEnabled $true

            $xml | Should -Match 'activationType="protocol"'
            $xml | Should -Match 'content="View Course"'
        }

        It "includes Dismiss action button" {
            $xml = _NewToastXML -Title 'Course' `
                               -Body 'Details' `
                               -ActionUrl 'https://example.com' `
                               -SoundEnabled $true

            $xml | Should -Match 'activationType="system"'
            $xml | Should -Match 'content="Dismiss"'
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

        It "_GetAlertEmoji function exists" {
            Get-Command _GetAlertEmoji | Should -Not -BeNullOrEmpty
        }

        It "_NewToastXML function exists" {
            Get-Command _NewToastXML | Should -Not -BeNullOrEmpty
        }

        It "_SendToastViaWinRT function exists" {
            Get-Command _SendToastViaWinRT | Should -Not -BeNullOrEmpty
        }
    }
}
