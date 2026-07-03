#Requires -Version 5.1

<#
.SYNOPSIS
    State management module for IPSC Kurs Watcher
.DESCRIPTION
    Manages persistent state (already notified courses) to prevent duplicates
.NOTES
    State is stored in JSON format for portability and readability
#>

$script:StateFileEncoding = 'UTF8'

function Initialize-State {
    <#
    .SYNOPSIS
        Create new state file with initial structure
    .PARAMETER StatePath
        Path where to create state file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StatePath
    )

    $initialState = @{
        version = 1
        last_notified = @()
        last_poll = $null
        last_error = $null
    }

    $stateDir = Split-Path -Parent $StatePath
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }

    $jsonState = $initialState | ConvertTo-Json
    Set-Content -Path $StatePath -Value $jsonState -Encoding $script:StateFileEncoding

    return $initialState
}

function Read-State {
    <#
    .SYNOPSIS
        Read state from file
    .PARAMETER StatePath
        Path to state file
    .PARAMETER CreateIfMissing
        Create state file if it doesn't exist (default: true)
    #>
    [CmdletBinding()]
    param(
        [string]$StatePath = "data/state.json",
        [switch]$CreateIfMissing = $true
    )

    if (-not (Test-Path $StatePath)) {
        if ($CreateIfMissing) {
            return Initialize-State -StatePath $StatePath
        } else {
            throw "State file not found: $StatePath"
        }
    }

    try {
        $stateContent = Get-Content -Path $StatePath -Raw -Encoding $script:StateFileEncoding
        $state = $stateContent | ConvertFrom-Json

        # Ensure expected properties exist
        if ($null -eq $state.version) {
            $state | Add-Member -NotePropertyName version -NotePropertyValue 1
        }
        if ($null -eq $state.last_notified) {
            $state.last_notified = @()
        }

        return $state
    } catch {
        throw "Failed to read state: $_"
    }
}

function Save-State {
    <#
    .SYNOPSIS
        Save state to file (atomically with temp file)
    .PARAMETER State
        State object to save
    .PARAMETER StatePath
        Path where to save state
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$State,

        [string]$StatePath = "data/state.json"
    )

    try {
        $tempPath = "$StatePath.tmp"

        $stateDir = Split-Path -Parent $StatePath
        if (-not (Test-Path $stateDir)) {
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
        }

        $jsonState = $State | ConvertTo-Json -Depth 10
        Set-Content -Path $tempPath -Value $jsonState -Encoding $script:StateFileEncoding

        # Atomic move
        Move-Item -Path $tempPath -Destination $StatePath -Force

        Write-Verbose "State saved to: $StatePath"
    } catch {
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Force
        }
        throw "Failed to save state: $_"
    }
}

function Add-NotifiedCourse {
    <#
    .SYNOPSIS
        Add course to notified list
    .PARAMETER State
        State object
    .PARAMETER CourseId
        Unique course identifier
    .PARAMETER CourseName
        Display name of course
    .PARAMETER CourseType
        Course type (e.g., Basic, Tryout)
    .PARAMETER Channels
        Notification channels used (array: email, discord, toast)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$State,

        [Parameter(Mandatory)]
        [string]$CourseId,

        [Parameter(Mandatory)]
        [string]$CourseName,

        [string]$CourseType = "",
        [string[]]$Channels = @('email')
    )

    $notified = @{
        course_id = $CourseId
        course_name = $CourseName
        course_type = $CourseType
        notified_at = (Get-Date -Format 'o')
        notification_channels = $Channels
        hash = (Get-CourseHash -CourseId $CourseId -CourseName $CourseName)
    }

    $State.last_notified += $notified
    $State.last_poll = (Get-Date -Format 'o')

    return $State
}

function Test-CourseNotified {
    <#
    .SYNOPSIS
        Check if course was already notified
    .PARAMETER State
        State object
    .PARAMETER CourseId
        Course identifier to check
    .PARAMETER CourseName
        Course name to check
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$State,

        [Parameter(Mandatory)]
        [string]$CourseId,

        [Parameter(Mandatory)]
        [string]$CourseName
    )

    $courseHash = Get-CourseHash -CourseId $CourseId -CourseName $CourseName

    $notifiedCourse = $State.last_notified |
        Where-Object { $_.hash -eq $courseHash }

    return $null -ne $notifiedCourse
}

function Get-CourseHash {
    <#
    .SYNOPSIS
        Generate hash for course deduplication
    .PARAMETER CourseId
        Course ID
    .PARAMETER CourseName
        Course name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CourseId,

        [Parameter(Mandatory)]
        [string]$CourseName
    )

    $combined = "$CourseId|$CourseName"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($combined)
    $hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hashAlgorithm.ComputeHash($bytes)
    $hash = [System.BitConverter]::ToString($hashBytes) -replace '-', ''

    return $hash.Substring(0, 16)
}

function Clear-OldStateEntries {
    <#
    .SYNOPSIS
        Remove state entries older than retention period
    .PARAMETER State
        State object
    .PARAMETER RetentionDays
        Days to keep state entries (default: 30)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$State,

        [int]$RetentionDays = 30
    )

    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)

    $originalCount = $State.last_notified.Count
    $State.last_notified = @(
        $State.last_notified |
            Where-Object {
                [DateTime]::Parse($_.notified_at) -ge $cutoffDate
            }
    )

    $removedCount = $originalCount - $State.last_notified.Count
    if ($removedCount -gt 0) {
        Write-Verbose "Removed $removedCount old state entries"
    }

    return $State
}
