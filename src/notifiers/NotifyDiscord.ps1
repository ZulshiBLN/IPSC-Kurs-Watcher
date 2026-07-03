#Requires -Version 5.1

function Send-DiscordNotification {
    <#
    .SYNOPSIS
    Send Discord webhook notifications for course alerts (v0.1 stub).

    .PARAMETER Alerts
    Array of alert objects with alert_reason (NEW_COURSE, AVAILABILITY_REDUCED, SOLD_OUT)

    .PARAMETER Config
    Discord configuration from config.json
    #>
    param([object[]]$Alerts, [object]$Config)

    if (-not $Config.enabled) { return }
    if (-not $Alerts -or $Alerts.Count -eq 0) { return }

    # v0.1: Stub - log alerts by type
    $byReason = $Alerts | Group-Object -Property alert_reason

    foreach ($group in $byReason) {
        Write-Log -Level INFO -Message "Discord notification ($($group.Name) stub)" `
            -Context @{ count = $group.Count; status = 'STUB_v0.1_not_sent' }
    }
}

