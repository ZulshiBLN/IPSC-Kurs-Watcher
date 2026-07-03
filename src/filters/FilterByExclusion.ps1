#Requires -Version 5.1

function Filter-ByExclusion { param([object[]]$Courses, [string[]]$ExcludePatterns)
    if (-not $Courses -or -not $ExcludePatterns) { return $Courses }
    $filtered = @()
    foreach ($course in $Courses) {
        $shouldExclude = $false
        foreach ($pattern in $ExcludePatterns) { if ($course.name -match $pattern) { $shouldExclude = $true; break } }
        if (-not $shouldExclude) { $filtered += $course }
    }
    return $filtered
}
