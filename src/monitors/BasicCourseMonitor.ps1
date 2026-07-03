
function Get-AvailableSlotsFromDetailPage {
    <#
    .SYNOPSIS
    Fetches available slots from a course detail page.

    .PARAMETER DetailUrl
    Full URL to the course detail page

    .PARAMETER TimeoutSeconds
    HTTP request timeout in seconds (default: 30)

    .EXAMPLE
    $slots = Get-AvailableSlotsFromDetailPage -DetailUrl "https://www.shooting-store.ch/de/produkt/..."
    #>

    param(
        [string]$DetailUrl,
        [int]$TimeoutSeconds = 30
    )

    try {
        $response = Invoke-WebRequest -Uri $DetailUrl -TimeoutSec $TimeoutSeconds -UseBasicParsing
        $html = $response.Content

        # Extract availability from lagerinfo_anzeige span
        if ($html -match 'data-update="lagerinfo_anzeige\.lagerinfo">(\d+)\s+Artikel') {
            $slots = [int]$Matches[1]
            Write-Verbose "[CourseMonitor] Found $slots available slots"
            return $slots
        }
        else {
            Write-Verbose "[CourseMonitor] Could not parse availability from detail page"
            return 0
        }
    }
    catch {
        Write-Error "[CourseMonitor] Failed to fetch detail page: $_"
        return 0
    }
}

function Get-CoursesFromShootingStore {
    <#
    .SYNOPSIS
    Fetches and extracts ALL courses from Shooting-Store.ch Kurse category.

    .DESCRIPTION
    Retrieves the course listing page and parses course details (name, date, time, price, availability).
    For each course, fetches the detail page to get current available slots.

    .PARAMETER Url
    The category page URL (default: Shooting-Store Kurse category)

    .PARAMETER BaseUrl
    Base URL for constructing detail page links (default: https://www.shooting-store.ch)

    .PARAMETER TimeoutSeconds
    HTTP request timeout in seconds (default: 30)

    .EXAMPLE
    $courses = Get-CoursesFromShootingStore
    #>

    param(
        [string]$Url = "https://www.shooting-store.ch/de/kategorie/kurse1",
        [string]$BaseUrl = "https://www.shooting-store.ch",
        [int]$TimeoutSeconds = 30
    )

    Write-Verbose "[CourseMonitor] Fetching courses from $Url"

    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSeconds -UseBasicParsing
        $html = $response.Content

        # Split by artikel_box_content_wrapper (parent container for each course)
        $blocks = $html -split '<div class="artikel_box_content_wrapper">'

        Write-Verbose "[CourseMonitor] Found $($blocks.Count - 1) course blocks"

        $courses = @()

        for ($i = 1; $i -lt $blocks.Count; $i++) {
            $block = $blocks[$i]

            # Extract course name from link and detail page href
            if ($block -match '<a href="([^"]+)"[^>]*class="content artikel_box_name"[^>]*>([^<]+)</a>') {
                $detailHref = $Matches[1]
                $fullText = $Matches[2].Trim()

                # Extract price from preis span in same block
                $price = ""
                if ($block -match '<span class="artikel_preis\s*"[^>]*>\s*([^<]+)</span>') {
                    $price = $Matches[1].Trim()
                }

                # Parse: "Name DD.MM.YYYY HH:MM-HH:MM"
                if ($fullText -match '^(.*?)\s+(\d{2}\.\d{2}\.\d{4})\s+(\d{2}:\d{2}-\d{2}:\d{2})$') {
                    $courseName = $Matches[1].Trim()
                    $courseDate = $Matches[2]
                    $courseTime = $Matches[3]

                    # Fetch detail page to get available slots
                    $availability = 0
                    if ($detailHref) {
                        $detailUrl = "$BaseUrl$detailHref"
                        Write-Verbose "[CourseMonitor] Fetching detail page: $detailUrl"
                        $availability = Get-AvailableSlotsFromDetailPage -DetailUrl $detailUrl -TimeoutSeconds $TimeoutSeconds
                    }

                    $courseId = "$courseName|$courseDate|$courseTime"

                    $courses += @{
                        id = $courseId
                        name = $courseName
                        date = $courseDate
                        time = $courseTime
                        price = $price
                        availability = $availability
                        url = "$BaseUrl$detailHref"
                        fetched_at = ([datetime]::UtcNow).ToString("o")
                    }
                    Write-Verbose "[CourseMonitor] Parsed: $courseName | $courseDate $courseTime | $price | $availability Plätze"
                }
            }
        }

        Write-Verbose "[CourseMonitor] Total courses parsed: $($courses.Count)"
        return $courses
    }
    catch {
        Write-Error "[CourseMonitor] Failed to fetch courses: $_"
        return @()
    }
}

function Get-NotifiedCourses {
    <#
    .SYNOPSIS
    Loads the list of previously notified courses from state file.

    .PARAMETER StateFile
    Path to the JSON state file

    .EXAMPLE
    $notified = Get-NotifiedCourses -StateFile "data/notified-basic-courses.json"
    #>

    param(
        [string]$StateFile = "data/notified-basic-courses.json"
    )

    if (-not (Test-Path $StateFile)) {
        Write-Verbose "[BasicCourseMonitor] State file not found, initializing: $StateFile"
        $initialState = @{
            last_check = ([datetime]::UtcNow).ToString("o")
            notified_courses = @()
        }
        $initialState | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8
        return @()
    }

    try {
        $state = Get-Content $StateFile -Encoding UTF8 | ConvertFrom-Json
        return $state.notified_courses
    }
    catch {
        Write-Error "[BasicCourseMonitor] Failed to load state file: $_"
        return @()
    }
}

function Save-NotifiedCourses {
    <#
    .SYNOPSIS
    Saves the list of notified courses to state file.

    .PARAMETER Courses
    Array of course objects to save

    .PARAMETER StateFile
    Path to the JSON state file

    .EXAMPLE
    Save-NotifiedCourses -Courses $basicCourses -StateFile "data/notified-basic-courses.json"
    #>

    param(
        [object[]]$Courses,
        [string]$StateFile = "data/notified-basic-courses.json"
    )

    $state = @{
        last_check = ([datetime]::UtcNow).ToString("o")
        notified_courses = $Courses
    }

    try {
        $state | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8
        Write-Verbose "[BasicCourseMonitor] Saved $($Courses.Count) courses to state file"
    }
    catch {
        Write-Error "[BasicCourseMonitor] Failed to save state file: $_"
    }
}

function Find-NewBasicCourses {
    <#
    .SYNOPSIS
    Compares current courses against previously notified courses.
    Returns courses that are NEW or have REDUCED availability.

    .PARAMETER CurrentCourses
    Array of currently found courses

    .PARAMETER NotifiedCourses
    Array of previously notified courses

    .EXAMPLE
    $alerts = Find-NewBasicCourses -CurrentCourses $current -NotifiedCourses $previous
    #>

    param(
        [object[]]$CurrentCourses,
        [object[]]$NotifiedCourses
    )

    $alertCourses = @()

    foreach ($course in $CurrentCourses) {
        $previousCourse = $NotifiedCourses | Where-Object { $_.id -eq $course.id }

        if (-not $previousCourse) {
            # NEW course
            $course | Add-Member -NotePropertyName "alert_reason" -NotePropertyValue "NEW_COURSE" -Force
            $alertCourses += $course
            Write-Verbose "[CourseMonitor] NEW course: $($course.name)"
        }
        elseif ($course.availability -lt $previousCourse.availability) {
            # Availability DECREASED
            $course | Add-Member -NotePropertyName "alert_reason" -NotePropertyValue "AVAILABILITY_REDUCED" -Force
            $course | Add-Member -NotePropertyName "previous_availability" -NotePropertyValue $previousCourse.availability -Force
            $alertCourses += $course
            Write-Verbose "[CourseMonitor] AVAILABILITY REDUCED: $($course.name) ($($previousCourse.availability) → $($course.availability))"
        }
    }

    return $alertCourses
}

function Send-BasicCourseNotification {
    <#
    .SYNOPSIS
    Sends notifications for new Basic courses via configured channels.

    .PARAMETER Courses
    Array of new courses to notify about

    .PARAMETER Config
    Configuration object with notifier settings

    .EXAMPLE
    Send-BasicCourseNotification -Courses $newCourses -Config $config
    #>

    param(
        [object[]]$Courses,
        [hashtable]$Config
    )

    if ($Courses.Count -eq 0) {
        Write-Verbose "[BasicCourseMonitor] No new courses to notify"
        return
    }

    Write-Output "[INFO] Found $($Courses.Count) new Basic course(s):"
    foreach ($course in $Courses) {
        Write-Output "  - $($course.name)"
    }

    # Format course list for notification with alert reasons
    $courseList = ($Courses | ForEach-Object {
        $alertText = ""
        if ($_.alert_reason -eq "NEW_COURSE") {
            $alertText = "[NEW]"
        }
        elseif ($_.alert_reason -eq "AVAILABILITY_REDUCED") {
            $alertText = "[REDUCED: $($_.previous_availability) -> $($_.availability)]"
        }

        "  $alertText $($_.name)`n    $($_.date) $($_.time) | $($_.price) | $($_.availability) Plätze"
    }) -join "`n"

    $message = @"
$($Courses.Count) Kurs-Alert(e) auf Shooting-Store.ch:

$courseList

https://www.shooting-store.ch/de/kategorie/kurse1
"@

    # Email notification
    if ($Config.notifiers.email.enabled) {
        Write-Verbose "[BasicCourseMonitor] Sending email notification"
        # This would call the email notifier function from config
    }

    # Discord notification
    if ($Config.notifiers.discord.enabled) {
        Write-Verbose "[BasicCourseMonitor] Sending Discord notification"
        # This would call the Discord notifier function from config
    }

    # Windows Toast notification
    if ($Config.notifiers.windows_toast.enabled) {
        Write-Verbose "[BasicCourseMonitor] Sending toast notification"
        # This would call the toast notifier function from config
    }
}

function Invoke-BasicCourseMonitor {
    <#
    .SYNOPSIS
    Main entry point for Basic Course monitoring.

    .DESCRIPTION
    Orchestrates the complete monitoring cycle:
    1. Fetches current courses from Shooting-Store.ch
    2. Loads previously notified courses
    3. Identifies new courses
    4. Sends notifications
    5. Updates state file

    .PARAMETER Config
    Configuration object with monitor and notifier settings

    .PARAMETER StateFile
    Path to state file (default: data/notified-basic-courses.json)

    .EXAMPLE
    Invoke-BasicCourseMonitor -Config $config
    #>

    param(
        [hashtable]$Config,
        [string]$StateFile = "data/notified-courses.json"
    )

    Write-Output "[INFO] Starting Course Monitor"

    # Step 1: Fetch current courses
    $currentCourses = Get-CoursesFromShootingStore

    if ($currentCourses.Count -eq 0) {
        Write-Output "[WARN] No courses found on page (might be parse error)"
        return
    }

    # Step 2: Load previously notified courses
    $notifiedCourses = Get-NotifiedCourses -StateFile $StateFile

    # Step 3: Find new courses
    $newCourses = Find-NewBasicCourses -CurrentCourses $currentCourses -NotifiedCourses $notifiedCourses

    # Step 4: Send notifications if new courses found
    if ($newCourses.Count -gt 0) {
        Send-BasicCourseNotification -Courses $newCourses -Config $Config
    }
    else {
        Write-Output "[INFO] No new courses found"
    }

    # Step 5: Update state with all current courses
    Save-NotifiedCourses -Courses $currentCourses -StateFile $StateFile

    Write-Output "[INFO] Course Monitor completed"
    return @{
        timestamp = ([datetime]::UtcNow).ToString("o")
        total_current = $currentCourses.Count
        newly_found = $newCourses.Count
        courses = $newCourses
    }
}

