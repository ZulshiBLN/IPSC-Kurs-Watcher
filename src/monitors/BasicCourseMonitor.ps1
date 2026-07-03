
function Get-BasicCoursesFromShootingStore {
    <#
    .SYNOPSIS
    Fetches and extracts "Basic" courses from Shooting-Store.ch Kurse category.

    .DESCRIPTION
    Retrieves the course listing page, parses course names from HTML, and filters
    for courses containing "Basic" in the name.

    .PARAMETER Url
    The category page URL (default: Shooting-Store Kurse category)

    .PARAMETER TimeoutSeconds
    HTTP request timeout in seconds (default: 30)

    .EXAMPLE
    $courses = Get-BasicCoursesFromShootingStore
    #>

    param(
        [string]$Url = "https://www.shooting-store.ch/de/kategorie/kurse1",
        [int]$TimeoutSeconds = 30
    )

    Write-Verbose "[BasicCourseMonitor] Fetching courses from $Url"

    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSeconds -UseBasicParsing
        $html = $response.Content

        [regex]$pattern = 'class="content artikel_box_name">([^<]+)</a>'
        $matches = $pattern.Matches($html)

        Write-Verbose "[BasicCourseMonitor] Found $($matches.Count) total courses"

        $basicCourses = @()
        foreach ($match in $matches) {
            $courseName = $match.Groups[1].Value.Trim()
            if ($courseName -like "*Basic*") {
                $basicCourses += @{
                    name = $courseName
                    fetched_at = ([datetime]::UtcNow).ToString("o")
                }
                Write-Verbose "[BasicCourseMonitor] Found Basic course: $courseName"
            }
        }

        Write-Verbose "[BasicCourseMonitor] Total Basic courses found: $($basicCourses.Count)"
        return $basicCourses
    }
    catch {
        Write-Error "[BasicCourseMonitor] Failed to fetch courses: $_"
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
    Compares current courses against previously notified courses and returns new ones.

    .PARAMETER CurrentCourses
    Array of currently found courses

    .PARAMETER NotifiedCourses
    Array of previously notified courses

    .EXAMPLE
    $new = Find-NewBasicCourses -CurrentCourses $current -NotifiedCourses $previous
    #>

    param(
        [object[]]$CurrentCourses,
        [object[]]$NotifiedCourses
    )

    $newCourses = @()

    foreach ($course in $CurrentCourses) {
        $isNew = -not ($NotifiedCourses | Where-Object { $_.name -eq $course.name })
        if ($isNew) {
            $newCourses += $course
        }
    }

    return $newCourses
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

    # Format course list for notification
    $courseList = ($Courses | ForEach-Object { "  - $($_.name)" }) -join "`n"

    $message = @"
$($Courses.Count) neue Basic Kurs(e) auf Shooting-Store.ch verfügbar:

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
        [string]$StateFile = "data/notified-basic-courses.json"
    )

    Write-Output "[INFO] Starting Basic Course Monitor"

    # Step 1: Fetch current courses
    $currentCourses = Get-BasicCoursesFromShootingStore

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
        Write-Output "[INFO] No new Basic courses found"
    }

    # Step 5: Update state with all current Basic courses
    Save-NotifiedCourses -Courses $currentCourses -StateFile $StateFile

    Write-Output "[INFO] Basic Course Monitor completed"
    return @{
        timestamp = ([datetime]::UtcNow).ToString("o")
        total_current = $currentCourses.Count
        newly_found = $newCourses.Count
        courses = $newCourses
    }
}

