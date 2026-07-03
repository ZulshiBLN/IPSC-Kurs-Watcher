#Requires -Version 5.1

function Invoke-FilterPipeline { param([object[]]$Courses, [object]$FilterConfig)
    if (-not $Courses) { return @() }
    $result = $Courses
    if ($FilterConfig.course_types) { $result = Get-FilteredCoursesByType -Courses $result -TypeFilters $FilterConfig.course_types }
    if ($FilterConfig.exclude_patterns) { $result = Get-FilteredCoursesByExclusion -Courses $result -ExcludePatterns $FilterConfig.exclude_patterns }
    if ($FilterConfig.min_availability -and $FilterConfig.min_availability -gt 0) { $result = @($result | Where-Object { $_.availability -ge $FilterConfig.min_availability }) }
    return $result
}
