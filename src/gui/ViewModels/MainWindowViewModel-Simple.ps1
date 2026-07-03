#Requires -Version 5.1

<#
.SYNOPSIS
    Simplified view model for WPF configuration GUI
.DESCRIPTION
    Object-based data binding for the configuration application
#>

function New-MainWindowViewModel {
    <#
    .SYNOPSIS
        Create a new view model instance
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "config/config.json"
    )

    $viewModel = @{
        ConfigPath = $ConfigPath
        Monitors = @()
        CourseTypes = @()
        EmailConfig = @{ enabled = $false }
        DiscordConfig = @{ enabled = $false }
        ToastConfig = @{ enabled = $false }
        SchedulerStatus = "Stopped"
        RecentLogs = @()
        WindowTitle = "IPSC Kurs Watcher - Configuration"
    }

    return $viewModel
}

function Load-ViewModelConfiguration {
    <#
    .SYNOPSIS
        Load configuration into view model
    #>
    [CmdletBinding()]
    param(
        [hashtable]$ViewModel,
        [string]$ConfigPath
    )

    try {
        . "$PSScriptRoot\..\core\Config.ps1"
        $config = Read-Config -ConfigPath $ConfigPath

        $ViewModel.Monitors = @($config.monitors)
        $ViewModel.CourseTypes = @($config.filters.course_types)

        if ($config.notifiers.email) {
            $ViewModel.EmailConfig = $config.notifiers.email
        }
        if ($config.notifiers.discord) {
            $ViewModel.DiscordConfig = $config.notifiers.discord
        }
        if ($config.notifiers.windows_toast) {
            $ViewModel.ToastConfig = $config.notifiers.windows_toast
        }

        Write-Verbose "ViewModel loaded: $($ViewModel.Monitors.Count) monitors, $($ViewModel.CourseTypes.Count) course types"
        return $true
    } catch {
        Write-Error "Failed to load configuration: $_"
        return $false
    }
}

function Export-ViewModelViewModel {
    <#
    .SYNOPSIS
        Convert view model back to configuration
    #>
    [CmdletBinding()]
    param(
        [hashtable]$ViewModel
    )

    $config = @{
        monitors = $ViewModel.Monitors
        filters = @{
            course_types = $ViewModel.CourseTypes
        }
        notifiers = @{
            email = $ViewModel.EmailConfig
            discord = $ViewModel.DiscordConfig
            windows_toast = $ViewModel.ToastConfig
        }
    }

    return $config
}
