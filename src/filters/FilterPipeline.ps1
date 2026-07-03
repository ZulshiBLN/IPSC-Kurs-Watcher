#Requires -Version 5.1

<#
.SYNOPSIS
    Complete filter pipeline orchestration
.DESCRIPTION
    Orchestrates the full filtering pipeline: Type → Exclusion → Deduplication → Availability
.NOTES
    This module ties together all filter modules into a cohesive pipeline
#>

. "$PSScriptRoot/FilterByType.ps1"
. "$PSScriptRoot/FilterByExclusion.ps1"
. "$PSScriptRoot/Deduplicator.ps1"

function Invoke-FilterPipeline {
    <#
    .SYNOPSIS
        Run complete filter pipeline on courses
    .PARAMETER Courses
        Array of courses from monitor
    .PARAMETER Config
        Configuration object with filters and state
    .PARAMETER State
        Application state for deduplication
    .EXAMPLE
        $filtered = Invoke-FilterPipeline -Courses $courses -Config $config -State $state
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Courses,

        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($Courses.Count -eq 0) {
        Write-Verbose "No courses to filter"
        return @()
    }

    Write-Verbose "Starting filter pipeline with $($Courses.Count) courses"

    $coursesAfterFilter = $Courses

    # Step 1: Filter by Type
    try {
        $typeFilter = New-CourseTypeFilter -CourseTypes $Config.filters.course_types
        $coursesAfterFilter = Invoke-FilterByType -Courses $coursesAfterFilter -Filter $typeFilter
        Write-Verbose "After type filter: $($coursesAfterFilter.Count) courses"
    } catch {
        Write-Error "Type filter failed: $_"
        return @()
    }

    if ($coursesAfterFilter.Count -eq 0) {
        Write-Verbose "No courses passed type filter"
        return @()
    }

    # Step 2: Filter by Exclusion
    try {
        $excludePatterns = $Config.filters.exclude_patterns ?? @()
        $exclusionFilter = New-ExclusionFilter -ExcludePatterns $excludePatterns
        $coursesAfterFilter = Invoke-FilterByExclusion -Courses $coursesAfterFilter -Filter $exclusionFilter
        Write-Verbose "After exclusion filter: $($coursesAfterFilter.Count) courses"
    } catch {
        Write-Error "Exclusion filter failed: $_"
        return @()
    }

    if ($coursesAfterFilter.Count -eq 0) {
        Write-Verbose "No courses passed exclusion filter"
        return @()
    }

    # Step 3: Deduplication
    try {
        $minAvailability = $Config.filters.min_availability ?? 1
        $deduplicator = New-Deduplicator -State $State -MinAvailability $minAvailability
        $coursesAfterFilter = Invoke-Deduplication -Courses $coursesAfterFilter -Deduplicator $deduplicator
        Write-Verbose "After deduplication: $($coursesAfterFilter.Count) courses"
    } catch {
        Write-Error "Deduplication failed: $_"
        return @()
    }

    Write-Verbose "Filter pipeline complete: $($coursesAfterFilter.Count) new/updated courses ready for notification"

    return $coursesAfterFilter
}

function Get-PipelineStatistics {
    <#
    .SYNOPSIS
        Get statistics about filter pipeline results
    .PARAMETER Original
        Original course count
    .PARAMETER AfterType
        Courses after type filter
    .PARAMETER AfterExclusion
        Courses after exclusion filter
    .PARAMETER Final
        Final courses after deduplication
    #>
    [CmdletBinding()]
    param(
        [int]$Original,
        [int]$AfterType,
        [int]$AfterExclusion,
        [int]$Final
    )

    $stats = @{
        total_found = $Original
        passed_type_filter = $AfterType
        passed_exclusion_filter = $AfterExclusion
        new_to_notify = $Final
        type_filtered = $Original - $AfterType
        excluded = $AfterType - $AfterExclusion
        duplicates = $AfterExclusion - $Final
        filter_efficiency = if ($Original -gt 0) {
            [math]::Round(($Final / $Original) * 100, 2)
        } else {
            0
        }
    }

    return $stats
}

Export-ModuleMember -Function @(
    'Invoke-FilterPipeline',
    'Get-PipelineStatistics'
)
