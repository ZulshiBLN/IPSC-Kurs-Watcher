#Requires -Version 5.1

function Test-CourseType { param([string]$CourseName, [string[]]$Patterns)
    foreach ($pattern in $Patterns) { if ($CourseName -match $pattern) { return $true } }
    return $false
}

function Get-FilteredCoursesByType { param([object[]]$Courses, [object[]]$TypeFilters)
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
