#Requires -Version 5.1

function Test-CourseType {
    <#
    .SYNOPSIS
    Tests whether a course name matches any regex pattern.

    .DESCRIPTION
    Returns $true if the course name matches any of the provided regex patterns.
    Used to classify courses by type (e.g., "Basic", "Advanced", "Tryout").

    .PARAMETER CourseName
    Name of the course to test.

    .PARAMETER Patterns
    Array of regex patterns to match against.

    .OUTPUTS
    Boolean - $true if name matches any pattern, $false otherwise.

    .EXAMPLE
    Test-CourseType -CourseName 'Basic Level 1' -Patterns @('Basic', 'Anfänger')
    # Returns: $true

    .NOTES
    Uses PowerShell -match operator (case-insensitive regex).
    #>
    param([string]$CourseName, [string[]]$Patterns)
    foreach ($pattern in $Patterns) { if ($CourseName -match $pattern) { return $true } }
    return $false
}

function Get-FilteredCoursesByType {
    <#
    .SYNOPSIS
    Filters courses to only those matching enabled type filters.

    .DESCRIPTION
    Returns courses whose names match patterns in at least one enabled type filter.
    If no filters are enabled or list is empty, returns all courses unfiltered.

    .PARAMETER Courses
    Array of course objects with 'name' property.

    .PARAMETER TypeFilters
    Array of filter objects with 'enabled' (bool) and 'patterns' (string[]) properties.

    .OUTPUTS
    Array of course objects that match at least one enabled filter.

    .EXAMPLE
    $filters = @(
        @{ enabled = $true; patterns = @('Basic', 'Anfänger') }
        @{ enabled = $true; patterns = @('Advanced', 'Fortgeschritten') }
        @{ enabled = $false; patterns = @('VIP') }
    )
    Get-FilteredCoursesByType -Courses $courses -TypeFilters $filters

    .NOTES
    Matches are case-insensitive via regex. Returns empty array for null/empty input.
    #>
    param([object[]]$Courses, [object[]]$TypeFilters)
    if (-not $Courses) { return @() }
    $enabledFilters = @($TypeFilters | Where-Object { $_.enabled })
    if ($enabledFilters.Count -eq 0) { return $Courses }
    $filtered = @()
    foreach ($course in $Courses) {
        foreach ($filter in $enabledFilters) {
            if (Test-CourseType -CourseName $course.name -Patterns $filter.patterns) { $filtered += $course; break }
        }
    }
    return $filtered
}
