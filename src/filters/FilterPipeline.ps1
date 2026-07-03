#Requires -Version 5.1

function Invoke-FilterPipeline {
    <#
    .SYNOPSIS
    Applies all configured filters to courses in sequence.

    .DESCRIPTION
    Runs a complete filter chain: type matching, exclusion patterns, and minimum availability.
    Filters are applied in order; output of one becomes input to the next.

    .PARAMETER Courses
    Array of course objects to filter.

    .PARAMETER FilterConfig
    Configuration object with sections:
      - course_types: array of type filters (enabled, patterns)
      - exclude_patterns: array of regex patterns to exclude
      - min_availability: minimum availability threshold

    .OUTPUTS
    Array of courses that pass all enabled filters.

    .EXAMPLE
    $config = @{
        course_types = @(
            @{ enabled = $true; patterns = @('Basic') }
        )
        exclude_patterns = @('VIP', 'Private')
        min_availability = 1
    }
    Invoke-FilterPipeline -Courses $courses -FilterConfig $config

    .NOTES
    Returns empty array for null/empty input. Each filter is optional.
    #>
    param([object[]]$Courses, [object]$FilterConfig)
    if (-not $Courses) { return @() }
    $result = $Courses
    if ($FilterConfig.course_types) { $result = Get-FilteredCoursesByType -Courses $result -TypeFilters $FilterConfig.course_types }
    if ($FilterConfig.exclude_patterns) { $result = Get-FilteredCoursesByExclusion -Courses $result -ExcludePatterns $FilterConfig.exclude_patterns }
    if ($FilterConfig.min_availability -and $FilterConfig.min_availability -gt 0) { $result = @($result | Where-Object { $_.availability -ge $FilterConfig.min_availability }) }
    return $result
}
