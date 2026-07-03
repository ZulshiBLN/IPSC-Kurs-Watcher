#Requires -Version 5.1

<#
.SYNOPSIS
    Main window view model for WPF configuration GUI
.DESCRIPTION
    Manages all tabs and bindings for the configuration application
#>

class RelayCommand {
    [scriptblock]$ExecuteBlock
    [scriptblock]$CanExecuteBlock

    RelayCommand([scriptblock]$execute, [scriptblock]$canExecute = { $true }) {
        $this.ExecuteBlock = $execute
        $this.CanExecuteBlock = $canExecute
    }

    [void] Execute([object]$parameter) {
        if ($this.CanExecute($parameter)) {
            & $this.ExecuteBlock $parameter
        }
    }

    [bool] CanExecute([object]$parameter) {
        return & $this.CanExecuteBlock $parameter
    }
}

class ObservableObject : System.ComponentModel.INotifyPropertyChanged {
    [System.ComponentModel.PropertyChangedEventHandler]$PropertyChanged

    [void] RaisePropertyChanged([string]$propertyName) {
        if ($this.PropertyChanged) {
            $this.PropertyChanged.Invoke($this, (New-Object System.ComponentModel.PropertyChangedEventArgs $propertyName))
        }
    }
}

class MainWindowViewModel : ObservableObject {
    # Tab 1: Monitors
    $Monitors = New-Object System.Collections.ObjectModel.ObservableCollection[hashtable]
    $SelectedMonitor
    $MonitorCount = 0

    # Tab 2: Filters
    $CourseTypes = New-Object System.Collections.ObjectModel.ObservableCollection[hashtable]
    $SelectedCourseType
    $FilterCount = 0

    # Tab 3: Notifications
    $EmailConfig = @{
        enabled = $false
        smtp_server = ""
        port = 587
        from_address = ""
        recipients = @()
        use_tls = $true
        use_auth = $true
    }

    $DiscordConfig = @{
        enabled = $false
        webhook_url = ""
        embed_color = "3447003"
    }

    $ToastConfig = @{
        enabled = $false
        duration = "long"
    }

    # Tab 4: Scheduler
    $SchedulerStatus = "Stopped"
    $LastRun = $null
    $NextRun = $null
    $RecentLogs = New-Object System.Collections.ObjectModel.ObservableCollection[string]

    # Tab 5: Data
    $ConfigPath = "config/config.json"
    $StatePath = "data/state.json"
    $LogsPath = "data/logs/"

    # Commands
    $AddMonitorCommand
    $EditMonitorCommand
    $DeleteMonitorCommand
    $TestMonitorCommand

    $AddTypeCommand
    $EditTypeCommand
    $DeleteTypeCommand
    $TestFilterCommand

    $TestEmailCommand
    $TestDiscordCommand
    $TestToastCommand

    $StartWatcherCommand
    $StopWatcherCommand
    $RunNowCommand

    $ExportConfigCommand
    $ImportConfigCommand
    $ResetConfigCommand
    $ViewBackupsCommand
    $ClearHistoryCommand

    MainWindowViewModel() {
        $this.InitializeCommands()
        $this.LoadConfiguration()
    }

    [void] InitializeCommands() {
        # Monitor Commands
        $this.AddMonitorCommand = New-Object RelayCommand(
            { $this.OnAddMonitor() },
            { $true }
        )

        $this.EditMonitorCommand = New-Object RelayCommand(
            { $this.OnEditMonitor() },
            { $null -ne $this.SelectedMonitor }
        )

        $this.DeleteMonitorCommand = New-Object RelayCommand(
            { $this.OnDeleteMonitor() },
            { $null -ne $this.SelectedMonitor }
        )

        $this.TestMonitorCommand = New-Object RelayCommand(
            { $this.OnTestMonitor() },
            { $this.Monitors.Count -gt 0 }
        )

        # Filter Commands
        $this.AddTypeCommand = New-Object RelayCommand(
            { $this.OnAddType() },
            { $true }
        )

        $this.EditTypeCommand = New-Object RelayCommand(
            { $this.OnEditType() },
            { $null -ne $this.SelectedCourseType }
        )

        $this.DeleteTypeCommand = New-Object RelayCommand(
            { $this.OnDeleteType() },
            { $null -ne $this.SelectedCourseType }
        )

        $this.TestFilterCommand = New-Object RelayCommand(
            { $this.OnTestFilter() },
            { $this.CourseTypes.Count -gt 0 }
        )

        # Notification Commands
        $this.TestEmailCommand = New-Object RelayCommand(
            { $this.OnTestEmail() },
            { $this.EmailConfig.enabled -and $this.EmailConfig.smtp_server }
        )

        $this.TestDiscordCommand = New-Object RelayCommand(
            { $this.OnTestDiscord() },
            { $this.DiscordConfig.enabled -and $this.DiscordConfig.webhook_url }
        )

        $this.TestToastCommand = New-Object RelayCommand(
            { $this.OnTestToast() },
            { $this.ToastConfig.enabled }
        )

        # Scheduler Commands
        $this.StartWatcherCommand = New-Object RelayCommand(
            { $this.OnStartWatcher() },
            { $this.SchedulerStatus -eq "Stopped" }
        )

        $this.StopWatcherCommand = New-Object RelayCommand(
            { $this.OnStopWatcher() },
            { $this.SchedulerStatus -eq "Running" }
        )

        $this.RunNowCommand = New-Object RelayCommand(
            { $this.OnRunNow() },
            { $this.SchedulerStatus -eq "Running" }
        )

        # Data Commands
        $this.ExportConfigCommand = New-Object RelayCommand(
            { $this.OnExportConfig() },
            { $true }
        )

        $this.ImportConfigCommand = New-Object RelayCommand(
            { $this.OnImportConfig() },
            { $true }
        )

        $this.ResetConfigCommand = New-Object RelayCommand(
            { $this.OnResetConfig() },
            { $true }
        )

        $this.ViewBackupsCommand = New-Object RelayCommand(
            { $this.OnViewBackups() },
            { $true }
        )

        $this.ClearHistoryCommand = New-Object RelayCommand(
            { $this.OnClearHistory() },
            { $true }
        )
    }

    [void] LoadConfiguration() {
        try {
            if (Test-Path $this.ConfigPath) {
                $config = Get-Content $this.ConfigPath | ConvertFrom-Json

                # Load monitors
                foreach ($monitor in $config.monitors) {
                    $this.Monitors.Add($monitor)
                }
                $this.MonitorCount = $this.Monitors.Count

                # Load filters
                foreach ($type in $config.filters.course_types) {
                    $this.CourseTypes.Add($type)
                }
                $this.FilterCount = $this.CourseTypes.Count

                # Load notification settings
                if ($config.notifiers) {
                    if ($config.notifiers.email) {
                        $this.EmailConfig = $config.notifiers.email
                    }
                    if ($config.notifiers.discord) {
                        $this.DiscordConfig = $config.notifiers.discord
                    }
                    if ($config.notifiers.windows_toast) {
                        $this.ToastConfig = $config.notifiers.windows_toast
                    }
                }

                Write-Verbose "Configuration loaded from $($this.ConfigPath)"
            }
        } catch {
            Write-Error "Failed to load configuration: $_"
        }
    }

    [void] SaveConfiguration() {
        try {
            $config = @{
                monitors = @($this.Monitors)
                filters = @{
                    course_types = @($this.CourseTypes)
                }
                notifiers = @{
                    email = $this.EmailConfig
                    discord = $this.DiscordConfig
                    windows_toast = $this.ToastConfig
                }
            }

            $config | ConvertTo-Json -Depth 10 | Set-Content $this.ConfigPath

            Write-Verbose "Configuration saved to $($this.ConfigPath)"
        } catch {
            Write-Error "Failed to save configuration: $_"
        }
    }

    # Monitor Methods
    [void] OnAddMonitor() {
        Write-Verbose "Add Monitor command executed"
    }

    [void] OnEditMonitor() {
        Write-Verbose "Edit Monitor command executed"
    }

    [void] OnDeleteMonitor() {
        if ($null -ne $this.SelectedMonitor) {
            $this.Monitors.Remove($this.SelectedMonitor)
            $this.SaveConfiguration()
        }
    }

    [void] OnTestMonitor() {
        Write-Verbose "Test Monitor command executed"
    }

    # Filter Methods
    [void] OnAddType() {
        Write-Verbose "Add Course Type command executed"
    }

    [void] OnEditType() {
        Write-Verbose "Edit Course Type command executed"
    }

    [void] OnDeleteType() {
        if ($null -ne $this.SelectedCourseType) {
            $this.CourseTypes.Remove($this.SelectedCourseType)
            $this.SaveConfiguration()
        }
    }

    [void] OnTestFilter() {
        Write-Verbose "Test Filter command executed"
    }

    # Notification Methods
    [void] OnTestEmail() {
        Write-Verbose "Test Email command executed"
    }

    [void] OnTestDiscord() {
        Write-Verbose "Test Discord command executed"
    }

    [void] OnTestToast() {
        Write-Verbose "Test Toast command executed"
    }

    # Scheduler Methods
    [void] OnStartWatcher() {
        Write-Verbose "Start Watcher command executed"
        $this.SchedulerStatus = "Running"
        $this.RaisePropertyChanged("SchedulerStatus")
    }

    [void] OnStopWatcher() {
        Write-Verbose "Stop Watcher command executed"
        $this.SchedulerStatus = "Stopped"
        $this.RaisePropertyChanged("SchedulerStatus")
    }

    [void] OnRunNow() {
        Write-Verbose "Run Now command executed"
        $this.AddLog("[$(Get-Date -Format 'HH:mm:ss')] [INFO] Manual cycle triggered")
    }

    # Data Methods
    [void] OnExportConfig() {
        Write-Verbose "Export Config command executed"
    }

    [void] OnImportConfig() {
        Write-Verbose "Import Config command executed"
    }

    [void] OnResetConfig() {
        Write-Verbose "Reset Config command executed"
    }

    [void] OnViewBackups() {
        Write-Verbose "View Backups command executed"
    }

    [void] OnClearHistory() {
        Write-Verbose "Clear History command executed"
    }

    [void] AddLog([string]$message) {
        if ($this.RecentLogs.Count -ge 20) {
            $this.RecentLogs.RemoveAt(0)
        }
        $this.RecentLogs.Add($message)
    }
}
