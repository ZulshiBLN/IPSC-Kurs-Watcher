#Requires -Version 5.1

<#
.SYNOPSIS
    Configuration validation module for IPSC Kurs Watcher
.DESCRIPTION
    Validates configuration against JSON schema and consistency checks
.NOTES
    Schema validation ensures config structure is correct before use
#>

function Test-ConfigSchema {
    <#
    .SYNOPSIS
        Validate configuration against JSON schema
    .PARAMETER Config
        Configuration object to validate
    .PARAMETER SchemaPath
        Path to JSON schema file
    .EXAMPLE
        Test-ConfigSchema -Config $config -SchemaPath "config/config.schema.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Config,

        [string]$SchemaPath = "config/config.schema.json"
    )

    if (-not (Test-Path $SchemaPath)) {
        throw "Schema file not found: $SchemaPath"
    }

    try {
        $schema = Get-Content -Path $SchemaPath -Raw | ConvertFrom-Json

        $validationErrors = @()

        # Check required properties
        foreach ($required in $schema.required) {
            if ($null -eq $Config.$required) {
                $validationErrors += "Missing required property: $required"
            }
        }

        # Validate monitors
        if ($Config.monitors -and $Config.monitors.Count -gt 0) {
            foreach ($monitor in $Config.monitors) {
                if (-not $monitor.id) {
                    $validationErrors += "Monitor missing required property: id"
                }
                if (-not $monitor.url) {
                    $validationErrors += "Monitor '$($monitor.id)' missing required property: url"
                }
                if (-not $monitor.provider) {
                    $validationErrors += "Monitor '$($monitor.id)' missing required property: provider"
                }
            }
        } else {
            $validationErrors += "At least one monitor must be configured"
        }

        # Validate filters
        if ($Config.filters.course_types -and $Config.filters.course_types.Count -gt 0) {
            foreach ($courseType in $Config.filters.course_types) {
                if (-not $courseType.id) {
                    $validationErrors += "Course type missing required property: id"
                }
                if (-not $courseType.patterns -or $courseType.patterns.Count -eq 0) {
                    $validationErrors += "Course type '$($courseType.id)' must have at least one pattern"
                }
            }
        } else {
            $validationErrors += "At least one course type must be configured"
        }

        # Validate notifiers
        $hasEnabledNotifier = $false
        if ($Config.notifiers.email.enabled) {
            $hasEnabledNotifier = $true
            if (-not $Config.notifiers.email.smtp_host) {
                $validationErrors += "Email notifier enabled but missing smtp_host"
            }
            if (-not $Config.notifiers.email.recipients -or $Config.notifiers.email.recipients.Count -eq 0) {
                $validationErrors += "Email notifier enabled but no recipients configured"
            }
        }
        if ($Config.notifiers.discord.enabled) {
            $hasEnabledNotifier = $true
            if (-not $Config.notifiers.discord.webhook_url) {
                $validationErrors += "Discord notifier enabled but missing webhook_url"
            }
        }
        if ($Config.notifiers.windows_toast.enabled) {
            $hasEnabledNotifier = $true
        }

        if (-not $hasEnabledNotifier) {
            $validationErrors += "At least one notifier must be enabled"
        }

        if ($validationErrors.Count -gt 0) {
            $errorMsg = $validationErrors -join "`n"
            throw "Configuration validation failed:`n$errorMsg"
        }

        return $true
    } catch {
        throw "Schema validation error: $_"
    }
}

function Test-ConfigConsistency {
    <#
    .SYNOPSIS
        Perform consistency checks on configuration
    .PARAMETER Config
        Configuration object to check
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Config
    )

    $warnings = @()

    # Check for duplicate monitor IDs
    $monitorIds = $Config.monitors.id
    $duplicates = $monitorIds | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($duplicates) {
        $warnings += "Duplicate monitor IDs found: $($duplicates.Name -join ', ')"
    }

    # Check for duplicate course type IDs
    $courseTypeIds = $Config.filters.course_types.id
    $duplicates = $courseTypeIds | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($duplicates) {
        $warnings += "Duplicate course type IDs found: $($duplicates.Name -join ', ')"
    }

    # Check for empty patterns
    foreach ($courseType in $Config.filters.course_types) {
        $emptyPatterns = $courseType.patterns | Where-Object { [string]::IsNullOrWhiteSpace($_) }
        if ($emptyPatterns) {
            $warnings += "Course type '$($courseType.id)' has empty patterns"
        }
    }

    if ($warnings.Count -gt 0) {
        Write-Warning "Configuration consistency warnings:`n$($warnings -join "`n")"
        return $false
    }

    return $true
}

function Test-Configuration {
    <#
    .SYNOPSIS
        Run all configuration validation checks
    .PARAMETER Config
        Configuration object to validate
    .PARAMETER SchemaPath
        Path to JSON schema file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Config,

        [string]$SchemaPath = "config/config.schema.json"
    )

    $schemaValid = Test-ConfigSchema -Config $config -SchemaPath $SchemaPath
    $consistencyValid = Test-ConfigConsistency -Config $config

    return $schemaValid -and $consistencyValid
}
