#Requires -Version 5.1

function Get-State {
    <#
    .SYNOPSIS
    Loads course state from state.json, with automatic initialization if missing.

    .DESCRIPTION
    Reads state.json and returns a hashtable with version, last_poll timestamp, and tracked courses.
    If the file doesn't exist, creates the directory and returns an initialized state.
    On read error, returns a clean initial state rather than failing.

    .PARAMETER StateFile
    Path to state.json. Defaults to 'data/state.json' in the current directory.

    .OUTPUTS
    Hashtable with 'version' (int), 'last_poll' (ISO 8601 string), and 'last_notified' (array of course objects).

    .EXAMPLE
    $state = Get-State
    # Returns: @{ version = 1; last_poll = '2026-07-03T10:30:00Z'; last_notified = @() }

    .EXAMPLE
    $state = Get-State -StateFile 'custom/state.json'

    .NOTES
    File encoding is always UTF-8. Gracefully handles missing files and parse errors.
    #>
    [CmdletBinding()]
    param([ValidateNotNullOrEmpty()][string]$StateFile = 'data/state.json')
    $stateDir = Split-Path $StateFile
    if ($stateDir -and -not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

    if (Test-Path $StateFile) {
        try {
            $stateJson = Get-Content $StateFile -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
            $trackedCourses = if ($null -ne $stateJson.last_notified) { @($stateJson.last_notified) } else { @() }
            return @{ version = $stateJson.version; last_poll = $stateJson.last_poll; last_notified = $trackedCourses }
        }
        catch { return @{ version = 1; last_poll = [datetime]::UtcNow.ToString('o'); last_notified = @() } }
    }
    return @{ version = 1; last_poll = [datetime]::UtcNow.ToString('o'); last_notified = @() }
}

function Save-State {
    <#
    .SYNOPSIS
    Persists course state to state.json with formatted JSON output.

    .DESCRIPTION
    Writes the state hashtable to JSON file, including all course data and timestamps.
    Updates last_poll to current UTC time before persisting. Logs errors but does not throw.
    Creates directory if it doesn't exist.

    .PARAMETER State
    Hashtable with 'version', 'last_poll', and 'last_notified' (array of courses).

    .PARAMETER StateFile
    Path to state.json. Defaults to 'data/state.json' in the current directory.

    .EXAMPLE
    $state = @{
        version = 1
        last_poll = '2026-07-03T10:30:00Z'
        last_notified = @(
            @{ id = 'course|2026-07-15|10:00'; name = 'Basic 1'; date = '2026-07-15'; availability = 5 }
        )
    }
    Save-State -State $state

    .NOTES
    Does not throw on error; failures are logged via Write-Log with ERROR level.
    File encoding is always UTF-8.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([ValidateNotNull()][hashtable]$State, [ValidateNotNullOrEmpty()][string]$StateFile = 'data/state.json')
    $stateDir = Split-Path $StateFile
    if ($stateDir -and -not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    try {
        $State.last_poll = [datetime]::UtcNow.ToString('o')
        $json = @("{")
        $json += '  "version": ' + ($State.version | ConvertTo-Json) + ','
        $json += '  "last_poll": ' + ($State.last_poll | ConvertTo-Json) + ','
        $json += '  "last_notified": ['

        if ($State.last_notified -and $State.last_notified.Count -gt 0) {
            foreach ($i in 0..($State.last_notified.Count - 1)) {
                $course = $State.last_notified[$i]
                $json += '    {'
                $json += '      "id": ' + ($course.id | ConvertTo-Json) + ','
                $json += '      "name": ' + ($course.name | ConvertTo-Json) + ','
                $json += '      "date": ' + ($course.date | ConvertTo-Json) + ','
                $json += '      "time": ' + ($course.time | ConvertTo-Json) + ','
                $json += '      "availability": ' + ($course.availability | ConvertTo-Json) + ','
                $json += '      "price": ' + ($course.price | ConvertTo-Json) + ','
                $json += '      "url": ' + ($course.url | ConvertTo-Json) + ','
                $json += '      "monitor_id": ' + ($course.monitor_id | ConvertTo-Json) + ','
                $json += '      "notified_at": ' + ($course.notified_at | ConvertTo-Json)
                if ($course.last_updated) { $json += ',' + "`n" + '      "last_updated": ' + ($course.last_updated | ConvertTo-Json) }
                if ($i -lt $State.last_notified.Count - 1) { $json += '    },' }
                else { $json += '    }' }
            }
        }
        $json += '  ]'
        $json += "}"

        if ($PSCmdlet.ShouldProcess($StateFile, "Write state")) {
            $json -join "`n" | Set-Content $StateFile -Encoding UTF8 -ErrorAction Stop
        }
    }
    catch { Write-Log -Level ERROR -Message "Failed to save state" -Context @{ file = $StateFile } -Exception $_ }
}

function Merge-CourseState {
    <#
    .SYNOPSIS
    Merges current courses with tracked state, detecting changes (NEW, REDUCED, SOLD_OUT).

    .DESCRIPTION
    Compares current website courses with previously tracked courses, detecting:
    - NEW: Courses not previously seen
    - REDUCED: Courses with decreased availability (>0)
    - SOLD_OUT: Courses with availability=0 or disappeared from website
    Returns alerts and merged state for persistence.

    .PARAMETER CurrentCourses
    Courses fetched from website (this run)

    .PARAMETER TrackedCourses
    Courses from last state.json (previous run)

    .OUTPUTS
    Hashtable with 'alerts' (new, reduced, sold_out) and 'updated_state' (merged courses for state.json)
    #>
    [CmdletBinding()]
    param([ValidateNotNull()][object[]]$CurrentCourses, [ValidateNotNull()][object[]]$TrackedCourses)

    $alerts = @{ new = @(); reduced = @(); sold_out = @() }
    $mergedState = @()

    # 1. Process all CURRENT courses (what website shows)
    foreach ($current in $CurrentCourses) {
        $courseId = if ($current.id) { $current.id } else { "$($current.name)|$($current.date)|$($current.time)" }
        $tracked = $TrackedCourses | Where-Object { $_.id -eq $courseId }

        if ($tracked) {
            # Course was previously tracked
            if ($current.availability -eq 0) {
                # Availability dropped to 0 = SOLD OUT
                $current | Add-Member -NotePropertyName 'alert_reason' -NotePropertyValue 'SOLD_OUT' -Force
                $alerts.sold_out += $current
                # Do NOT add to mergedState (delete it)
            }
            elseif ($current.availability -lt $tracked.availability) {
                # Availability decreased (but still > 0)
                $current | Add-Member -NotePropertyName 'alert_reason' -NotePropertyValue 'AVAILABILITY_REDUCED' -Force
                $alerts.reduced += $current
                # UPDATE in mergedState with new availability
                $mergedState += @{
                    id = $courseId
                    name = $current.name
                    date = $current.date
                    time = $current.time
                    availability = $current.availability
                    price = $current.price
                    url = $current.url
                    monitor_id = $current.monitor_id
                    notified_at = $tracked.notified_at
                    last_updated = [datetime]::UtcNow.ToString('o')
                }
            }
            else {
                # Availability unchanged (or increased - shouldn't happen per requirements)
                # UNCHANGED = do not alert, keep in state as-is
                $mergedState += $tracked
            }
        }
        else {
            # Course is NEW
            $current | Add-Member -NotePropertyName 'alert_reason' -NotePropertyValue 'NEW' -Force
            $alerts.new += $current
            # ADD to mergedState
            $mergedState += @{
                id = $courseId
                name = $current.name
                date = $current.date
                time = $current.time
                availability = $current.availability
                price = $current.price
                url = $current.url
                monitor_id = $current.monitor_id
                notified_at = [datetime]::UtcNow.ToString('o')
            }
        }
    }

    # 2. Process all TRACKED courses not in CURRENT (disappeared)
    foreach ($tracked in $TrackedCourses) {
        $courseId = $tracked.id
        $current = $CurrentCourses | Where-Object {
            $currentId = if ($_.id) { $_.id } else { "$($_.name)|$($_.date)|$($_.time)" }
            $currentId -eq $courseId
        }

        if (-not $current) {
            # Course was tracked but is NO LONGER on website
            $tracked | Add-Member -NotePropertyName 'alert_reason' -NotePropertyValue 'SOLD_OUT' -Force
            $tracked | Add-Member -NotePropertyName 'disappeared' -NotePropertyValue $true -Force
            $alerts.sold_out += $tracked
            # Do NOT add to mergedState (delete it)
        }
    }

    return @{
        alerts = $alerts
        updated_state = $mergedState
    }
}

function Update-StateWithCourse {
    <#
    .SYNOPSIS
    Merges current courses into state, returns both updated state and alerts.

    .DESCRIPTION
    Uses Merge-CourseState to intelligently update state.json, tracking only changes.
    Returns hashtable with 'state' (updated) and 'alerts' (for notifications).

    .PARAMETER State
    Current state hashtable from state.json

    .PARAMETER CurrentCourses
    Courses fetched this run

    .OUTPUTS
    Hashtable with 'state' and 'alerts'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([ValidateNotNull()][hashtable]$State, [ValidateNotNull()][object[]]$CurrentCourses)

    if ($PSCmdlet.ShouldProcess("state.last_notified", "Update course state")) {
        $trackedCourses = if ($null -ne $State.last_notified) { $State.last_notified } else { @() }
        Write-Host "[DEBUG] TrackedCourses type: $($trackedCourses.GetType().Name), Count: $($trackedCourses.Count), IsNull: $($null -eq $trackedCourses)" -ForegroundColor Cyan
        $mergeResult = Merge-CourseState -CurrentCourses $CurrentCourses -TrackedCourses $trackedCourses
        $State.last_notified = $mergeResult.updated_state
    }
    else {
        $mergeResult = @{ alerts = @{ new = @(); reduced = @(); sold_out = @() }; updated_state = $State.last_notified }
    }

    return @{
        state = $State
        alerts = $mergeResult.alerts
    }
}

function Get-NewCourse {
    <#
    .SYNOPSIS
    DEPRECATED: Use Merge-CourseState instead.

    .DESCRIPTION
    Legacy function kept for backwards compatibility. New code should use Merge-CourseState
    which properly handles SOLD_OUT courses and state merging.
    #>
    param([object[]]$CurrentCourses, [object[]]$PreviousCourses)

    Write-Log -Level WARN -Message "Get-NewCourses is deprecated, use Merge-CourseState instead"

    $trackedCourses = if ($null -ne $PreviousCourses) { $PreviousCourses } else { @() }
    $mergeResult = Merge-CourseState -CurrentCourses $CurrentCourses -TrackedCourses $trackedCourses
    return $mergeResult.alerts.new + $mergeResult.alerts.reduced
}
