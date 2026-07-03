#Requires -Version 5.1

function Get-FilteredCoursesByExclusion {
    <#
    .SYNOPSIS
    Filters out courses matching exclusion patterns.

    .DESCRIPTION
    Returns courses that do NOT match any of the exclusion regex patterns.
    Useful for removing courses by keywords like 'Private Lessons' or 'VIP'.

    .PARAMETER Courses
    Array of course objects with 'name' property.

    .PARAMETER ExcludePatterns
    Array of regex patterns for courses to exclude.

    .OUTPUTS
    Array of course objects that do not match any exclusion pattern.

    .EXAMPLE
    $patterns = @('Privatunterricht', 'VIP', 'Geschlossen')
    Get-FilteredCoursesByExclusion -Courses $courses -ExcludePatterns $patterns

    .NOTES
    Case-insensitive regex matching. Returns all courses if patterns is null/empty.
    #>
    [CmdletBinding()]
    param([object[]]$Courses, [string[]]$ExcludePatterns)
    if (-not $Courses -or -not $ExcludePatterns) { return $Courses }
    $filtered = @()
    foreach ($course in $Courses) {
        $shouldExclude = $false
        foreach ($pattern in $ExcludePatterns) { if ($course.name -match $pattern) { $shouldExclude = $true; break } }
        if (-not $shouldExclude) { $filtered += $course }
    }
    return $filtered
}
