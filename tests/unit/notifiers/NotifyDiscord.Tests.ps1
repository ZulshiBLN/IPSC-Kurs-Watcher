#Requires -Version 5.1

BeforeAll {
    # Load modules
    . (Join-Path $PSScriptRoot '../../../src/core/Logging.ps1')
    . (Join-Path $PSScriptRoot '../../../src/core/Helpers.ps1')
    . (Join-Path $PSScriptRoot '../../../src/notifiers/NotifyDiscord.ps1')
}

Describe "Discord Notifier" {

    # Sample test alerts
    $testAlerts = @(
        @{
            id = "Basic|12.08.2026|09:30"
            name = "IPSC Basic 2.0"
            date = "12.08.2026"
            time = "09:30-13:00"
            availability = 3
            price = "CHF 280"
            url = "https://www.shooting-store.ch/basic"
            alert_reason = "NEW"
        },
        @{
            id = "Advanced|15.08.2026|14:00"
            name = "IPSC Advanced Level"
            date = "15.08.2026"
            time = "14:00-17:00"
            availability = 1
            price = "CHF 350"
            url = "https://www.shooting-store.ch/advanced"
            alert_reason = "AVAILABILITY_REDUCED"
        },
        @{
            id = "Stages|20.08.2026|10:00"
            name = "IPSC Stages"
            date = "20.08.2026"
            time = "10:00-14:00"
            availability = 0
            price = "CHF 400"
            url = "https://www.shooting-store.ch/stages"
            alert_reason = "SOLD_OUT"
        }
    )

    $testConfig = @{
        enabled = $true
        retry_attempts = 3
        timeout_seconds = 30
        webhook_urls = @()
    }

    Context "Configuration Validation" {
        It "should return false when config is null" {
            _ValidateDiscordConfig -Config $null | Should -Be $false
        }

        It "should return false when Discord is disabled" {
            $config = @{ enabled = $false }
            _ValidateDiscordConfig -Config $config | Should -Be $false
        }

        It "should return true when Discord is enabled" {
            $config = @{ enabled = $true }
            _ValidateDiscordConfig -Config $config | Should -Be $true
        }
    }

    Context "Webhook URL Retrieval" {
        It "should read URLs from environment variable" {
            $env:IPSC_DISCORD_WEBHOOKS = "https://discord.com/api/webhooks/123,https://discord.com/api/webhooks/456"
            $urls = _GetDiscordWebhookUrls -Config $testConfig

            $urls | Should -HaveCount 2
            $urls[0] | Should -Be "https://discord.com/api/webhooks/123"
            $urls[1] | Should -Be "https://discord.com/api/webhooks/456"

            $env:IPSC_DISCORD_WEBHOOKS = ""
        }

        It "should fallback to config when env var is empty" {
            $env:IPSC_DISCORD_WEBHOOKS = ""
            $config = @{
                enabled = $true
                webhook_urls = @("https://discord.com/webhook/1")
            }
            $urls = _GetDiscordWebhookUrls -Config $config

            $urls | Should -HaveCount 1
            $urls[0] | Should -Be "https://discord.com/webhook/1"
        }

        It "should return empty array when no webhooks configured" {
            $env:IPSC_DISCORD_WEBHOOKS = ""
            $config = @{ enabled = $true; webhook_urls = @() }
            $urls = _GetDiscordWebhookUrls -Config $config

            $urls | Should -HaveCount 0
        }

        It "should trim whitespace from webhook URLs" {
            $env:IPSC_DISCORD_WEBHOOKS = "https://discord.com/api/webhooks/123 , https://discord.com/api/webhooks/456  "
            $urls = _GetDiscordWebhookUrls -Config $testConfig

            $urls | Should -HaveCount 2
            $urls[0] | Should -Be "https://discord.com/api/webhooks/123"
            $urls[1] | Should -Be "https://discord.com/api/webhooks/456"

            $env:IPSC_DISCORD_WEBHOOKS = ""
        }
    }

    Context "Alert Grouping" {
        It "should group alerts by alert_reason" {
            $grouped = _GroupAlertsByReason -Alerts $testAlerts

            $grouped.Keys | Should -Contain "NEW"
            $grouped.Keys | Should -Contain "AVAILABILITY_REDUCED"
            $grouped.Keys | Should -Contain "SOLD_OUT"
        }

        It "should have correct count per group" {
            $grouped = _GroupAlertsByReason -Alerts $testAlerts

            $grouped["NEW"] | Should -HaveCount 1
            $grouped["AVAILABILITY_REDUCED"] | Should -HaveCount 1
            $grouped["SOLD_OUT"] | Should -HaveCount 1
        }

        It "should handle empty alerts array" {
            $grouped = _GroupAlertsByReason -Alerts @()

            $grouped | Should -HaveCount 0
        }

        It "should handle alerts with missing alert_reason" {
            $alertsWithMissing = @(
                @{ name = "Course1"; alert_reason = "NEW" },
                @{ name = "Course2" }  # Missing alert_reason
            )
            $grouped = _GroupAlertsByReason -Alerts $alertsWithMissing

            $grouped["NEW"] | Should -HaveCount 1
            $grouped["OTHER"] | Should -HaveCount 1
        }
    }

    Context "Embed Building" {
        It "should build embeds for grouped alerts" {
            $grouped = _GroupAlertsByReason -Alerts $testAlerts
            $embeds = _BuildDiscordEmbeds -GroupedAlerts $grouped

            $embeds | Should -HaveCount 3
        }

        It "should set correct colors per alert reason" {
            $grouped = _GroupAlertsByReason -Alerts $testAlerts
            $embeds = _BuildDiscordEmbeds -GroupedAlerts $grouped

            # NEW embed (green)
            $newEmbed = $embeds | Where-Object { $_.title -match "\[NEW\]" }
            $newEmbed.color | Should -Be 3066993

            # REDUCED embed (orange)
            $reducedEmbed = $embeds | Where-Object { $_.title -match "\[REDUCED\]" }
            $reducedEmbed.color | Should -Be 16243689

            # SOLD_OUT embed (red)
            $soldOutEmbed = $embeds | Where-Object { $_.title -match "\[SOLD_OUT\]" }
            $soldOutEmbed.color | Should -Be 15671588
        }

        It "should include course details in embed fields" {
            $grouped = _GroupAlertsByReason -Alerts @($testAlerts[0])
            $embeds = _BuildDiscordEmbeds -GroupedAlerts $grouped

            $embed = $embeds[0]
            $embed.fields | Should -HaveCount 1
            $embed.fields[0].name | Should -Match "IPSC Basic 2.0"
            $embed.fields[0].value | Should -Match "09:30-13:00"
            $embed.fields[0].value | Should -Match "CHF 280"
            $embed.fields[0].value | Should -Match "3 Slots"
        }

        It "should set footer and timestamp" {
            $grouped = _GroupAlertsByReason -Alerts @($testAlerts[0])
            $embeds = _BuildDiscordEmbeds -GroupedAlerts $grouped

            $embeds[0].footer.text | Should -Be "IPSC Kurs Watcher"
            $embeds[0].timestamp | Should -Match "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"
        }

        It "should handle empty grouped alerts" {
            $grouped = @{}
            $embeds = _BuildDiscordEmbeds -GroupedAlerts $grouped

            $embeds | Should -HaveCount 0
        }
    }

    Context "Alert Emoji" {
        It "should return correct emoji for NEW" {
            _GetAlertEmoji -AlertReason "NEW" | Should -Be "[NEW]"
        }

        It "should return correct emoji for AVAILABILITY_REDUCED" {
            _GetAlertEmoji -AlertReason "AVAILABILITY_REDUCED" | Should -Be "[REDUCED]"
        }

        It "should return correct emoji for SOLD_OUT" {
            _GetAlertEmoji -AlertReason "SOLD_OUT" | Should -Be "[SOLD_OUT]"
        }

        It "should return default emoji for unknown reason" {
            _GetAlertEmoji -AlertReason "UNKNOWN" | Should -Be "[ALERT]"
        }
    }

    Context "Alert Color" {
        It "should return correct color for NEW" {
            _GetAlertColor -AlertReason "NEW" | Should -Be 3066993
        }

        It "should return correct color for AVAILABILITY_REDUCED" {
            _GetAlertColor -AlertReason "AVAILABILITY_REDUCED" | Should -Be 16243689
        }

        It "should return correct color for SOLD_OUT" {
            _GetAlertColor -AlertReason "SOLD_OUT" | Should -Be 15671588
        }

        It "should return default color for unknown reason" {
            _GetAlertColor -AlertReason "UNKNOWN" | Should -Be 3947580
        }
    }

    Context "Send-DiscordNotification Public Function" {
        It "should not send when Discord is disabled" {
            $config = @{ enabled = $false }
            { Send-DiscordNotification -Alerts $testAlerts -Config $config } | Should -Not -Throw
        }

        It "should not send when alerts array is empty" {
            { Send-DiscordNotification -Alerts @() -Config $testConfig } | Should -Not -Throw
        }

        It "should not send when no webhooks configured" {
            $env:IPSC_DISCORD_WEBHOOKS = ""
            $config = @{ enabled = $true; webhook_urls = @() }
            { Send-DiscordNotification -Alerts $testAlerts -Config $config } | Should -Not -Throw
            $env:IPSC_DISCORD_WEBHOOKS = ""
        }

        It "should respect WhatIf parameter" {
            $env:IPSC_DISCORD_WEBHOOKS = "https://discord.com/api/webhooks/test"
            $result = Send-DiscordNotification -Alerts $testAlerts -Config $testConfig -WhatIf

            # Should return null (WhatIf prevents execution)
            $result | Should -Be $null
            $env:IPSC_DISCORD_WEBHOOKS = ""
        }
    }
}
