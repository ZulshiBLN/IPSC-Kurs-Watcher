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
                if ($i -lt $State.last_notified.Count - 1) { $json += '    },' }
                else { $json += '    }' }
            }
        }
        $json += '  ]'
        $json += "}"

        $json -join "`n" | Set-Content $StateFile -Encoding UTF8 -ErrorAction Stop
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
