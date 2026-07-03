#Requires -Version 5.1

<#
.SYNOPSIS
    Discord webhook notification module
.DESCRIPTION
    Sends course notifications via Discord webhook with rich embeds
.NOTES
    Uses Discord's incoming webhook API for messages
#>

function New-DiscordNotifier {
    <#
    .SYNOPSIS
        Create Discord notifier instance
    .PARAMETER Config
        Discord configuration from config.json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    if ([string]::IsNullOrWhiteSpace($Config.webhook_url)) {
        throw "Discord webhook_url is required"
    }

    # Set defaults
    $Config.embed_color = $Config.embed_color ?? 3447003  # Blue
    $Config.retry_attempts = $Config.retry_attempts ?? 2
    $Config.timeout_seconds = $Config.timeout_seconds ?? 10

    return $Config
}

function Test-DiscordConnection {
    <#
    .SYNOPSIS
        Test Discord webhook connectivity
    .PARAMETER Notifier
        Discord notifier configuration
    .RETURNS
        $true if webhook is reachable
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Notifier
    )

    try {
        $testPayload = @{
            content = "IPSC Kurs Watcher - Connection Test"
        } | ConvertTo-Json

        $params = @{
            Uri = $Notifier.webhook_url
            Method = 'POST'
            ContentType = 'application/json'
            Body = $testPayload
            TimeoutSec = $Notifier.timeout_seconds
            ErrorAction = 'Stop'
        }

        Invoke-WebRequest @params | Out-Null

        Write-Verbose "Discord webhook test successful"
        return $true
    } catch {
        Write-Error "Discord webhook test failed: $_"
        return $false
    }
}

function Send-DiscordNotification {
    <#
    .SYNOPSIS
        Send Discord webhook notification
    .PARAMETER Courses
        Array of courses to notify about
    .PARAMETER Notifier
        Discord notifier configuration
    .PARAMETER MonitorName
        Name of the monitor source
    .EXAMPLE
        Send-DiscordNotification -Courses $newCourses -Notifier $config.notifiers.discord -MonitorName "shooting-store"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Courses,

        [Parameter(Mandatory)]
        [hashtable]$Notifier,

        [string]$MonitorName = "IPSC Kurs Watcher"
    )

    if ($Courses.Count -eq 0) {
        Write-Verbose "No courses to notify via Discord"
        return $true
    }

    if (-not $Notifier.enabled) {
        Write-Verbose "Discord notifier is disabled"
        return $true
    }

    try {
        $payload = Build-DiscordPayload -Courses $Courses -MonitorName $MonitorName -EmbedColor $Notifier.embed_color

        $params = @{
            Uri = $Notifier.webhook_url
            Method = 'POST'
            ContentType = 'application/json'
            Body = $payload
            TimeoutSec = $Notifier.timeout_seconds
            ErrorAction = 'Stop'
        }

        Write-Verbose "Sending Discord notification for $($Courses.Count) course(s)"
        Invoke-WebRequest @params | Out-Null

        Write-Verbose "Discord notification sent successfully"
        return $true
    } catch {
        Write-Error "Failed to send Discord notification: $_"
        return $false
    }
}

function Build-DiscordPayload {
    <#
    .SYNOPSIS
        Build Discord webhook payload with embeds
    .PARAMETER Courses
        Courses to include
    .PARAMETER MonitorName
        Monitor name
    .PARAMETER EmbedColor
        Embed color (decimal)
    #>
    [CmdletBinding()]
    param(
        [array]$Courses,
        [string]$MonitorName,
        [int]$EmbedColor = 3447003
    )

    $fields = @()

    foreach ($course in $Courses) {
        $courseInfo = @{
            name = $course.title
            value = @(
                "**Typ:** $($course.type ?? 'N/A')",
                "**Verfügbarkeit:** $($course.availability ?? 'Unbekannt') Plätze"
            ) -join "`n"
            inline = $false
        }
        $fields += $courseInfo
    }

    $embed = @{
        title = "$($Courses.Count) neue Kurs(e) von $MonitorName"
        description = "Neue oder aktualisierte Kurse gefunden"
        color = $EmbedColor
        fields = $fields
        timestamp = (Get-Date -Format 'o')
        footer = @{
            text = "IPSC Kurs Watcher"
        }
    }

    $payload = @{
        embeds = @($embed)
        username = "IPSC Kurs Watcher"
    }

    return $payload | ConvertTo-Json -Depth 10
}

Export-ModuleMember -Function @(
    'New-DiscordNotifier',
    'Test-DiscordConnection',
    'Send-DiscordNotification'
)
