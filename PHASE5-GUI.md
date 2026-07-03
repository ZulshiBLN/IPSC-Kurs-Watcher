# Phase 5: WPF GUI - Configuration Application

## Overview

Phase 5 implements a complete Windows Presentation Foundation (WPF) GUI for the IPSC Kurs Watcher configuration management. The application provides a tabbed interface for managing monitors, filters, notifications, and the scheduler.

## Architecture

### Components

1. **MainWindow.xaml** - XAML UI definition with 5 tabs
2. **ConfigApp.ps1** - Entry point that initializes WPF and loads the window
3. **ViewModels/MainWindowViewModel.ps1** - MVVM ViewModel with ObservableCollections and Commands
4. **Services/WatcherService.ps1** - Background job management for the main watcher loop
5. **Services/DialogService.ps1** - File and message dialogs abstraction

### Design Pattern: MVVM

The application follows the Model-View-ViewModel pattern:
- **View**: MainWindow.xaml (pure XAML, no code-behind)
- **ViewModel**: MainWindowViewModel.ps1 (business logic, data binding, commands)
- **Services**: Specialized services for cross-cutting concerns (Watcher, Dialogs)

### Data Binding

All tabs bind to ObservableCollections in the ViewModel:
- Monitors collection (Tab 1)
- Course types collection (Tab 2)
- Notification settings (Tab 3)
- Scheduler status (Tab 4)
- Config paths (Tab 5)

## Tab Details

### Tab 1: Monitors
Manages course monitoring sources (shooting-store.ch, etc.)

**Features:**
- DataGrid view of all monitors
- Add, Edit, Delete, Test buttons
- Status display (All OK)
- Bind to `Monitors` ObservableCollection

**Commands:**
- `AddMonitorCommand` - Opens dialog for new monitor
- `EditMonitorCommand` - Edit selected monitor (disabled if none selected)
- `DeleteMonitorCommand` - Remove selected monitor
- `TestMonitorCommand` - Test all monitor connections

### Tab 2: Filters
Manages course type filtering and exclusion patterns

**Features:**
- DataGrid view of course types
- Add, Edit, Delete, Test buttons
- Exclusion patterns summary
- Bind to `CourseTypes` ObservableCollection

**Commands:**
- `AddTypeCommand` - Add new course type filter
- `EditTypeCommand` - Modify course type filter
- `DeleteTypeCommand` - Remove course type
- `TestFilterCommand` - Test filter pipeline

### Tab 3: Notifications
Global notification channel configuration (Email, Discord, Toast)

**Features:**
- Email tab: SMTP server, port, auth, recipients
- Discord tab: Webhook URL, embed color
- Toast tab: Duration setting
- Test buttons for each channel
- Bind to `EmailConfig`, `DiscordConfig`, `ToastConfig` hashtables

**Commands:**
- `TestEmailCommand` - Verify SMTP connectivity
- `TestDiscordCommand` - Verify webhook reachability
- `TestToastCommand` - Test Windows Toast capability

### Tab 4: Scheduler
Start/stop the main watcher service and view logs

**Features:**
- Status display (Running/Stopped)
- Last run and next run timestamps
- Start, Stop, Run Now buttons
- Real-time log viewer (last 20 entries)
- Bind to `SchedulerStatus`, `LastRun`, `NextRun`, `RecentLogs`

**Commands:**
- `StartWatcherCommand` - Start background watcher job
- `StopWatcherCommand` - Gracefully stop watcher
- `RunNowCommand` - Execute one monitoring cycle immediately

### Tab 5: Data
Configuration and state management

**Features:**
- Export/Import configuration JSON
- Reset to defaults
- View backup history
- Clear notification history
- File location display (config, state, logs)
- Bind to `ConfigPath`, `StatePath`, `LogsPath` strings

**Commands:**
- `ExportConfigCommand` - Save config to JSON file
- `ImportConfigCommand` - Load config from JSON file
- `ResetConfigCommand` - Restore default configuration
- `ViewBackupsCommand` - Browse backup history
- `ClearHistoryCommand` - Clear old state entries

## ViewModel Implementation

The `MainWindowViewModel` class provides:

### Properties
- **Monitors** (ObservableCollection) - List of monitor configs
- **CourseTypes** (ObservableCollection) - List of course type filters
- **EmailConfig, DiscordConfig, ToastConfig** (hashtables) - Notification settings
- **SchedulerStatus** (string) - "Running" or "Stopped"
- **RecentLogs** (ObservableCollection) - Last 20 log entries

### Commands
Each command is a `RelayCommand` with CanExecute predicates:
- CanExecute determines if button is enabled
- Execute block runs the command handler

### Methods
- `LoadConfiguration()` - Read config.json on startup
- `SaveConfiguration()` - Persist changes to disk
- `AddLog(message)` - Add to recent logs (max 20 entries)

### Classes
- **RelayCommand** - ICommand implementation for binding
- **ObservableObject** - Base class with PropertyChanged support

## Services

### WatcherService
Manages the background watcher process (Phase 6 Watcher.ps1):
- `StartWatcher()` - Launch Watcher.ps1 in background process
- `StopWatcher()` - Gracefully terminate watcher
- `IsRunning()` - Check if watcher is active
- `GetStatus()` - Return status hashtable
- `GetRecentLogs(lineCount)` - Read last N log entries

### DialogService
Abstraction for user dialogs:
- `ShowMessage()` - Generic message box
- `ShowConfirmation()` - Yes/No dialog
- `ShowError()`, `ShowWarning()`, `ShowInfo()` - Typed dialogs
- `ShowOpenFileDialog()`, `ShowSaveFileDialog()` - File dialogs
- `ShowFolderBrowserDialog()` - Folder picker

## Loading and Initialization

The application entry point:

1. **ConfigApp.ps1 Main Execution**
   - Checks PowerShell version (-Version 5.1)
   - Parses parameters: `-ConfigPath` (default: config/config.json), `-Debug`
   - Displays startup message

2. **Initialize-WPF Function**
   - Adds required assemblies (PresentationFramework, Core, WindowsBase, System.Xaml)
   - Catches assembly load errors

3. **Start-ConfigurationApp Function**
   - Creates MainWindowViewModel instance
   - Loads MainWindow.xaml
   - Creates XamlReader and loads XAML into WPF
   - Sets window DataContext = ViewModel
   - Wires up window event handlers (Loaded, Closed)
   - Shows window with ShowDialog()
   - Saves config on close

## Data Flow

### Loading
```
Startup
  └─ ConfigApp.ps1 (Main)
      └─ Initialize-WPF
      └─ Start-ConfigurationApp
          ├─ New MainWindowViewModel
          │   └─ LoadConfiguration()
          │       └─ Read config.json
          │           ├─ Populate Monitors
          │           ├─ Populate CourseTypes
          │           └─ Load Notifier Settings
          └─ Load MainWindow.xaml
              └─ Bind DataContext
```

### User Action Example
```
User clicks "Add Monitor"
  └─ MainWindow Binding → AddMonitorCommand
      └─ RelayCommand.Execute()
          └─ ViewModel.OnAddMonitor()
              └─ Open Dialog (Future: Phase 5 Extended)
                  └─ Save to Monitors Collection
                      └─ Binding updates DataGrid
```

### Saving
```
User closes window
  └─ MainWindow.Closed event
      └─ ViewModel.SaveConfiguration()
          └─ Write config.json
              └─ Application.Shutdown()
```

## Phase 5 Status: Foundation Complete

**Implemented:**
- XAML UI with all 5 tabs and controls
- ViewModel with ObservableCollections and Commands
- Data binding infrastructure
- Configuration loading/saving
- Services for Watcher and Dialogs

**Not Yet Implemented (Phase 5 Extended):**
- Dialog windows for Add/Edit operations (Monitors, Types)
- Integration with existing Monitor/Filter/Notifier pipelines
- Real-time watcher status updates
- Configuration validation UI
- Export/Import functionality
- Backup management UI

**Next Steps:**
- Phase 6: Implement Watcher.ps1 orchestration script
- Phase 7: Add Pester tests and CI/CD pipeline
- Phase 5 Extended: Complete dialog implementations

## Running the Application

```powershell
# Standard mode
.\src\gui\ConfigApp.ps1

# With custom config path
.\src\gui\ConfigApp.ps1 -ConfigPath "path/to/config.json"

# Debug mode (verbose output)
.\src\gui\ConfigApp.ps1 -Debug
```

## Build Validation

The GUI code passes PSScriptAnalyzer checks:
- 4-space indentation (K&R style)
- ASCII-only output strings
- No Invoke-Expression usage
- Comment-based help on public functions
- No undefined variables

Run validation:
```powershell
.\build.ps1 -Validate
```

## File Structure

```
IPSC Kurs Watcher/
├── src/
│   ├── gui/
│   │   ├── ConfigApp.ps1              (Entry point)
│   │   ├── MainWindow.xaml            (XAML UI)
│   │   ├── ViewModels/
│   │   │   └── MainWindowViewModel.ps1 (ViewModel class)
│   │   └── Services/
│   │       ├── WatcherService.ps1     (Watcher management)
│   │       └── DialogService.ps1      (Dialog abstraction)
│   ├── core/
│   ├── monitors/
│   ├── filters/
│   ├── notifiers/
│   └── utils/
├── config/
│   ├── config.json
│   └── config.example.json
├── PHASE5-GUI.md                       (This file)
└── ...
```
