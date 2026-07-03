#Requires -Version 5.1

<#
.SYNOPSIS
    IPSC Kurs Watcher Configuration Application (WPF GUI)
.DESCRIPTION
    Entry point for the WPF configuration application
.NOTES
    Launches the configuration UI for managing monitors, filters, and notifications
#>

param(
    [string]$ConfigPath = "config/config.json",
    [switch]$Debug
)

$ErrorActionPreference = 'Stop'

function Initialize-WPF {
    try {
        # Load required assemblies
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName System.Xaml

        Write-Verbose "WPF assemblies loaded successfully"
    } catch {
        Write-Error "Failed to load WPF assemblies: $_"
        exit 1
    }
}

function Start-ConfigurationApp {
    param(
        [string]$ConfigPath,
        [switch]$Debug
    )

    Initialize-WPF

    try {
        # Determine script directory
        $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

        # Load ViewModel
        $viewModelPath = Join-Path $scriptDir "ViewModels/MainWindowViewModel.ps1"
        if (-not (Test-Path $viewModelPath)) {
            throw "ViewModel not found at: $viewModelPath"
        }
        . $viewModelPath
        $viewModel = [MainWindowViewModel]::new()

        # Load XAML
        $xamlPath = Join-Path $scriptDir "MainWindow.xaml"
        if (-not (Test-Path $xamlPath)) {
            throw "MainWindow.xaml not found at: $xamlPath"
        }

        [xml]$xaml = Get-Content -Path $xamlPath -Raw

        # Create WPF window
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        $window = [Windows.Markup.XamlReader]::Load($reader)

        # Set DataContext
        $window.DataContext = $viewModel

        # Wire up event handlers
        $window.Add_Loaded({
            Write-Verbose "Configuration window loaded"
        })

        $window.Add_Closed({
            Write-Verbose "Configuration application closed"
            $viewModel.SaveConfiguration()
            [System.Windows.Application]::Current.Shutdown()
        })

        # Show window
        Write-Verbose "Launching configuration GUI"
        $window.ShowDialog() | Out-Null

    } catch {
        Write-Error "Failed to start configuration app: $_"
        exit 1
    }
}

# Main execution
if ($Debug) {
    $VerbosePreference = 'Continue'
}

Write-Host "IPSC Kurs Watcher - Configuration Application" -ForegroundColor Cyan
Write-Host "Loading configuration from: $ConfigPath" -ForegroundColor Gray

Start-ConfigurationApp -ConfigPath $ConfigPath -Debug:$Debug
