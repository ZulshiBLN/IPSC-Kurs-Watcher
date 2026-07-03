#Requires -Version 5.1

function Get-State { param([string]$StateFile = 'data/state.json')
    $stateDir = Split-Path $StateFile
    if ($stateDir -and -not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    
    if (Test-Path $StateFile) {
        try {
            $stateJson = Get-Content $StateFile -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
            return @{ version = $stateJson.version; last_poll = $stateJson.last_poll; last_notified = @($stateJson.last_notified) }
        }
        catch { return @{ version = 1; last_poll = [datetime]::UtcNow.ToString('o'); last_notified = @() } }
    }
    return @{ version = 1; last_poll = [datetime]::UtcNow.ToString('o'); last_notified = @() }
}

function Save-State { param([hashtable]$State, [string]$StateFile = 'data/state.json')
    $stateDir = Split-Path $StateFile
    if ($stateDir -and -not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    try {
        $State.last_poll = [datetime]::UtcNow.ToString('o')
        $State | ConvertTo-Json -Depth 10 -Compress | Set-Content $StateFile -Encoding UTF8 -ErrorAction Stop
    }
    catch { Write-Log -Level ERROR -Message "Failed to save state" -Context @{ file = $StateFile } -Exception $_ }
}

function Get-NewCourses { param([object[]]$CurrentCourses, [object[]]$PreviousCourses)
    $newCourses = @()
    foreach ($current in $CurrentCourses) {
        $courseId = "$($current.name)|$($current.date)|$($current.time)"
        $previous = $PreviousCourses | Where-Object { $_.id -eq $courseId }
        if (-not $previous) { $current | Add-Member -NotePropertyName 'alert_reason' -NotePropertyValue 'NEW_COURSE' -Force; $newCourses += $current }
        elseif ($current.availability -lt $previous.availability) { $current | Add-Member -NotePropertyName 'alert_reason' -NotePropertyValue 'AVAILABILITY_REDUCED' -Force; $newCourses += $current }
    }
    return $newCourses
}

function Update-StateWithCourses { param([hashtable]$State, [object[]]$Courses)
    $notifiedCourses = @()
    foreach ($course in $Courses) {
        $notifiedCourses += @{
            id = "$($course.name)|$($course.date)|$($course.time)"
            name = $course.name; date = $course.date; time = $course.time
            availability = $course.availability; price = $course.price; url = $course.url
            monitor_id = $course.monitor_id; notified_at = [datetime]::UtcNow.ToString('o')
        }
    }
    $State.last_notified = $notifiedCourses
    return $State
}
