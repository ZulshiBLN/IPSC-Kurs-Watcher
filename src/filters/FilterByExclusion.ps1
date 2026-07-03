#Requires -Version 5.1

<#
.SYNOPSIS
    Filter out courses based on exclusion patterns
.DESCRIPTION
    Removes courses matching exclusion patterns from course list
.NOTES
    Supports regex patterns for flexible exclusion matching
#>

function New-ExclusionFilter {
    <#
    .SYNOPSIS
        Create an exclusion filter instance
    .PARAMETER ExcludePatterns
        Array of regex patterns to exclude
    .EXAMPLE
        $patterns = @("Privatunterricht", "VIP-Kurs", "Geschlossen")
        $filter = New-ExclusionFilter -ExcludePatterns $patterns
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$ExcludePatterns
    )

    if ($null -eq $ExcludePatterns -or $ExcludePatterns.Count -eq 0) {
        return @{
            Patterns = @()
            Count = 0
        }
    }

    return @{
        Patterns = $ExcludePatterns
        Count = $ExcludePatterns.Count
    }
}

function Test-CourseExcluded {
    <#
    .SYNOPSIS
        Test if course should be excluded
    .PARAMETER Course
        Course object to test
    .PARAMETER Filter
        Exclusion filter
    .RETURNS
        $true if course matches any exclusion pattern, $false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Course,

        [Parameter(Mandatory)]
        [hashtable]$Filter
    )

    if ($Filter.Count -eq 0) {
        return $false
    }

    $courseText = @(
        $Course.title,
        $Course.type,
        $Course.description
    ) -join " "

    foreach ($pattern in $Filter.Patterns) {
        try {
            # Case-insensitive regex match
            if ($courseText -match "(?i)$pattern") {
                Write-Verbose "Course excluded: '$($Course.title)' matches pattern '$pattern'"
                return $true
            }
        } catch {
            Write-Warning "Invalid exclusion pattern '$pattern': $_"
            continue
        }
    }

    return $false
}

function Invoke-FilterByExclusion {
    <#
    .SYNOPSIS
        Remove courses matching exclusion patterns
    .PARAMETER Courses
        Array of course objects
    .PARAMETER Filter
        Exclusion filter
    .EXAMPLE
        $filtered = Invoke-FilterByExclusion -Courses $courses -Filter $filter
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Courses,

        [Parameter(Mandatory)]
        [hashtable]$Filter
    )

    if ($Courses.Count -eq 0) {
        return @()
    }

    if ($Filter.Count -eq 0) {
        return $Courses
    }

    $filtered = @()

    foreach ($course in $Courses) {
        if (-not (Test-CourseExcluded -Course $course -Filter $Filter)) {
            $filtered += $course
        }
    }

    $excluded = $Courses.Count - $filtered.Count
    Write-Verbose "Exclusion filter: $($Courses.Count) -> $($filtered.Count) (excluded: $excluded)"

    return $filtered
}
