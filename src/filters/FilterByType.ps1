#Requires -Version 5.1

<#
.SYNOPSIS
    Filter courses by type using pattern matching
.DESCRIPTION
    Filters courses based on configured course types with flexible pattern matching
.NOTES
    Supports case-insensitive contains matching for course types
#>

function New-CourseTypeFilter {
    <#
    .SYNOPSIS
        Create a course type filter instance
    .PARAMETER CourseTypes
        Array of course type configurations
    .EXAMPLE
        $types = @(
            @{ id = "basic"; patterns = @("Basic", "Anfänger") },
            @{ id = "tryout"; patterns = @("Tryout") }
        )
        $filter = New-CourseTypeFilter -CourseTypes $types
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$CourseTypes
    )

    if ($CourseTypes.Count -eq 0) {
        throw "At least one course type must be configured"
    }

    # Enable only course types that have enabled = $true or not set
    $enabledTypes = @()
    foreach ($type in $CourseTypes) {
        if ($null -eq $type.enabled -or $type.enabled -eq $true) {
            $enabledTypes += $type
        }
    }

    if ($enabledTypes.Count -eq 0) {
        throw "At least one course type must be enabled"
    }

    return @{
        Types = $enabledTypes
        Count = $enabledTypes.Count
    }
}

function Test-CourseType {
    <#
    .SYNOPSIS
        Test if course matches any configured type
    .PARAMETER Course
        Course object with 'type' property
    .PARAMETER Filter
        Course type filter
    .EXAMPLE
        $matches = Test-CourseType -Course $course -Filter $filter
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Course,

        [Parameter(Mandatory)]
        [hashtable]$Filter
    )

    if ([string]::IsNullOrWhiteSpace($Course.type)) {
        Write-Verbose "Course '$($Course.title)' has no type, skipping"
        return $false
    }

    $courseType = $Course.type.Trim()

    foreach ($configuredType in $Filter.Types) {
        foreach ($pattern in $configuredType.patterns) {
            # Case-insensitive contains match
            if ($courseType -like "*$pattern*") {
                return $true
            }
        }
    }

    return $false
}

function Get-MatchingCourseType {
    <#
    .SYNOPSIS
        Get which course type matched for a course
    .PARAMETER Course
        Course object
    .PARAMETER Filter
        Course type filter
    .RETURNS
        hashtable with matched type id and name, or null if no match
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Course,

        [Parameter(Mandatory)]
        [hashtable]$Filter
    )

    if ([string]::IsNullOrWhiteSpace($Course.type)) {
        return $null
    }

    $courseType = $Course.type.Trim()

    foreach ($configuredType in $Filter.Types) {
        foreach ($pattern in $configuredType.patterns) {
            if ($courseType -like "*$pattern*") {
                return @{
                    id = $configuredType.id
                    name = $configuredType.name
                }
            }
        }
    }

    return $null
}

function Invoke-FilterByType {
    <#
    .SYNOPSIS
        Filter array of courses by type
    .PARAMETER Courses
        Array of course objects
    .PARAMETER Filter
        Course type filter
    .EXAMPLE
        $filtered = Invoke-FilterByType -Courses $courses -Filter $filter
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

    $filtered = @()

    foreach ($course in $Courses) {
        if (Test-CourseType -Course $course -Filter $Filter) {
            # Enrich course with matched type info
            $matchedType = Get-MatchingCourseType -Course $course -Filter $Filter
            if ($matchedType) {
                $course.matched_type = $matchedType
                $filtered += $course
            }
        }
    }

    Write-Verbose "Filtered courses: $($Courses.Count) -> $($filtered.Count)"

    return $filtered
}

Export-ModuleMember -Function @(
    'New-CourseTypeFilter',
    'Test-CourseType',
    'Get-MatchingCourseType',
    'Invoke-FilterByType'
)
