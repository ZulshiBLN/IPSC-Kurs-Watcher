#Requires -Version 5.1

<#
.SYNOPSIS
    Deduplication filter to prevent duplicate notifications
.DESCRIPTION
    Removes courses that have already been notified based on state
.NOTES
    Uses state file to track already-notified courses
#>

function New-Deduplicator {
    <#
    .SYNOPSIS
        Create a deduplicator instance
    .PARAMETER State
        Application state object (from State.ps1)
    .PARAMETER MinAvailability
        Minimum availability to include (default: 1)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [int]$MinAvailability = 1
    )

    if ($MinAvailability -lt 0) {
        throw "MinAvailability must be >= 0"
    }

    return @{
        State = $State
        MinAvailability = $MinAvailability
    }
}

function Test-CourseDuplicate {
    <#
    .SYNOPSIS
        Test if course was already notified
    .PARAMETER Course
        Course object to test
    .PARAMETER Deduplicator
        Deduplicator instance
    .RETURNS
        $true if course already notified, $false if new
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Course,

        [Parameter(Mandatory)]
        [hashtable]$Deduplicator
    )

    $state = $Deduplicator.State

    # Check if course ID exists in notified list
    $alreadyNotified = $state.last_notified |
        Where-Object { $_.course_id -eq $Course.id }

    return $null -ne $alreadyNotified
}

function Test-CourseAvailability {
    <#
    .SYNOPSIS
        Test if course meets minimum availability requirement
    .PARAMETER Course
        Course object to test
    .PARAMETER MinAvailability
        Minimum availability threshold
    .RETURNS
        $true if course has enough availability
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Course,

        [int]$MinAvailability = 1
    )

    if ($null -eq $Course.availability) {
        return $false
    }

    return $Course.availability -ge $MinAvailability
}

function Invoke-Deduplication {
    <#
    .SYNOPSIS
        Filter out already-notified courses and apply availability check
    .PARAMETER Courses
        Array of course objects
    .PARAMETER Deduplicator
        Deduplicator instance
    .EXAMPLE
        $newCourses = Invoke-Deduplication -Courses $courses -Deduplicator $dedup
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Courses,

        [Parameter(Mandatory)]
        [hashtable]$Deduplicator
    )

    if ($Courses.Count -eq 0) {
        return @()
    }

    $newCourses = @()

    foreach ($course in $Courses) {
        # Check availability
        if (-not (Test-CourseAvailability -Course $course -MinAvailability $Deduplicator.MinAvailability)) {
            Write-Verbose "Course '$($course.title)' below minimum availability ($($course.availability) < $($Deduplicator.MinAvailability))"
            continue
        }

        # Check if already notified
        if (Test-CourseDuplicate -Course $course -Deduplicator $Deduplicator) {
            Write-Verbose "Course '$($course.title)' already notified, skipping"
            continue
        }

        $newCourses += $course
    }

    $duplicates = $Courses.Count - $newCourses.Count
    Write-Verbose "Deduplication: $($Courses.Count) -> $($newCourses.Count) (duplicates/unavailable: $duplicates)"

    return $newCourses
}

Export-ModuleMember -Function @(
    'New-Deduplicator',
    'Test-CourseDuplicate',
    'Test-CourseAvailability',
    'Invoke-Deduplication'
)
