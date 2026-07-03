# Phase 6: Scheduler – Main Orchestration Loop

## Overview

Phase 6 implements the core `Watcher.ps1` script – the central orchestration engine that coordinates all monitoring, filtering, and notification pipelines. This is the heart of the IPSC Kurs Watcher application.

## Architecture

### Main Components

```
Watcher.ps1 (Entry Point)
├── Initialize-Watcher
│   ├── Initialize-Logging
│   ├── Read-Config
│   ├── Test-Configuration
│   └── Initialize-State
├── Invoke-WatcherLoop
│   └── Invoke-MonitoringCycle (repeating)
│       ├── New-Monitor × N (parallel execution)
│       ├── Invoke-FilterPipeline
│       └── Invoke-NotificationPipeline
└── Graceful Shutdown Handler
```

## Watcher.ps1 - Main Script

### Entry Point Parameters

```powershell
.\Watcher.ps1 [-ConfigPath <path>] [-LoopCount <int>] [-TestMode]
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `ConfigPath` | string | `config/config.json` | Configuration file path |
| `LoopCount` | int | `0` (infinite) | Number of cycles before exit; 0 = run forever |
| `TestMode` | switch | False | Execute single cycle and output results as JSON |

### Execution Modes

#### 1. Production Mode (Default)
```powershell
.\Watcher.ps1
```
- Infinite loop: continuously monitors and notifies
- Respects monitor poll intervals
- Runs until shutdown signal (SIGTERM)
- Used by Windows Scheduled Task

#### 2. Test Mode
```powershell
.\Watcher.ps1 -TestMode
```
- Executes single monitoring cycle
- Outputs statistics as JSON
- Exits with code 0 (success) or 1 (error)
- Used for validation and debugging

#### 3. Limited Loop
```powershell
.\Watcher.ps1 -LoopCount 5
```
- Runs exactly 5 cycles
- Exits automatically after last cycle
- Useful for testing/validation

## Core Functions

### 1. Initialize-Watcher
Sets up the watcher environment before the main loop.

**Steps:**
1. Initialize logging system (creates data/logs)
2. Log startup message with PID
3. Load configuration from JSON
4. Validate configuration completely
5. Initialize state tracking system
6. Return validated config object

**Error Handling:**
- Throws on any initialization failure
- Logs all errors to persistent log
- Main script catches and exits with code 1

**Example:**
```powershell
try {
    $config = Initialize-Watcher -ConfigPath "config/config.json"
    # Config is validated and ready
} catch {
    # Initialization failed, exit
}
```

### 2. Invoke-MonitoringCycle
Executes a single monitoring cycle: fetch → filter → notify.

**Algorithm:**
```
Cycle Start
├─ Get enabled monitors
├─ For each monitor:
│  ├─ Invoke monitor (fetch courses)
│  ├─ Add to aggregate list
│  └─ Handle errors (continue, don't block)
├─ Aggregate all courses
├─ Apply filter pipeline
│  ├─ Course type filter
│  ├─ Exclusion filter
│  ├─ Deduplication & availability
│  └─ Get filtered courses
├─ If filtered courses > 0:
│  └─ Send notifications (all enabled channels)
└─ Cycle Complete (log statistics)
```

**Returns:**
```powershell
@{
    timestamp = "2026-07-03T14:30:45.123Z"
    monitors_executed = 2
    courses_found = 5
    courses_filtered = 3
    courses_notified = 3
    notifiers_succeeded = @("email", "discord")
    notifiers_failed = @()
    duration_ms = 1234
    success = $true
}
```

**Error Isolation:**
- Monitor errors don't block other monitors
- Filter errors don't block notifications
- Notifier errors don't block other channels
- Cycle continues even if individual components fail
- All errors logged; cycle marked as "failed" if any component fails

### 3. Get-NextRunTime
Calculates the next scheduled cycle based on monitor intervals.

**Logic:**
1. Get all enabled monitors
2. Find minimum poll interval among them
3. Add interval to current time
4. Return as DateTime

**Example:**
- Monitor 1: 5 min interval → next run in 5 min
- Monitor 2: 15 min interval → next run in 15 min
- Result: next run in 5 min (minimum)

### 4. Wait-UntilNextRun
Sleeps until next cycle while respecting shutdown signals.

**Key Feature:** Checks `$script:Running` every 1 second
- If shutdown signal received, returns immediately
- Graceful shutdown without wait
- Prevents tight polling during shutdown

### 5. Invoke-WatcherLoop
Main infinite (or limited) event loop.

**Loop Logic:**
```
Initialize cycle counter = 0

While running and (LoopCount == 0 or counter < LoopCount):
  ├─ Increment counter
  ├─ Execute monitoring cycle
  ├─ Every 60 minutes: cleanup old state
  ├─ Calculate next run time
  ├─ Wait until next run (with shutdown check)
  └─ Repeat
```

**Periodic Maintenance:**
- Every hour: `Clear-OldStateEntries` (removes entries older than 7 days)
- Prevents state.json from growing unbounded
- Logged as DEBUG level

## Execution Flow

### Startup Sequence

```
Main Script Execution
├─ Parse parameters
├─ Set error handling: $ErrorActionPreference = 'Continue'
│  (allows cycle continuation on errors)
├─ Register shutdown handler (SIGTERM → $script:Running = $false)
├─ Import all modules:
│  ├─ Logging
│  ├─ Config (Read-Config, Get-EnabledMonitors)
│  ├─ ConfigValidator (Test-Configuration)
│  ├─ State (Initialize-State, Clear-OldStateEntries)
│  ├─ MonitorFactory (New-Monitor)
│  ├─ FilterPipeline (Invoke-FilterPipeline)
│  └─ NotificationPipeline (Invoke-NotificationPipeline)
└─ Try-Catch-Finally
   ├─ Initialize-Watcher → $config
   ├─ If TestMode:
   │  └─ Run Invoke-MonitoringCycle once, output JSON, exit
   ├─ Else:
   │  └─ Run Invoke-WatcherLoop
   └─ Log shutdown, exit with appropriate code
```

### Single Cycle Execution

```
Invoke-MonitoringCycle
├─ Create empty $allCourses array
├─ Log cycle start
├─ For each enabled monitor:
│  ├─ Create monitor instance (New-Monitor)
│  ├─ Execute monitor function (& $monitorFactory)
│  ├─ Handle result (add to $allCourses)
│  └─ Handle error (log, continue, mark cycle failed)
├─ Log total courses found
├─ If $allCourses.Count > 0:
│  ├─ Invoke-FilterPipeline:
│  │  ├─ Type filter
│  │  ├─ Exclusion filter
│  │  ├─ Deduplication
│  │  └─ Return filtered courses
│  └─ If filtered courses > 0:
│      ├─ Invoke-NotificationPipeline:
│      │  ├─ Email (if enabled)
│      │  ├─ Discord (if enabled)
│      │  └─ Toast (if enabled)
│      └─ Log notification results
├─ Calculate cycle duration
└─ Return cycle statistics
```

## Logging

All Watcher activities are logged to `data/logs/`:

### Log Levels

| Level | Purpose | Example |
|-------|---------|---------|
| **INFO** | Normal operation | Cycle start/end, courses found, notifications sent |
| **WARN** | Non-critical issues | Monitor took longer than expected |
| **ERROR** | Critical issues | Monitor failed, pipeline error, invalid config |
| **DEBUG** | Detailed info | Pipeline statistics, wait duration |

### Log Format

```
[2026-07-03T14:30:45.123Z] [INFO] Cycle 1: found 5 courses
[2026-07-03T14:30:46.456Z] [INFO] Filter pipeline: 5 → 3 courses
[2026-07-03T14:30:47.789Z] [INFO] Notifications sent: email, discord
[2026-07-03T14:30:48.012Z] [INFO] Cycle complete: 3 courses notified [1234ms]
```

### Log File Rotation

- Daily rotation (one file per day)
- Naming: `watcher-YYYY-MM-DD.log`
- 30-day retention (automatic cleanup)
- Archival support for backup

## Graceful Shutdown

### Signal Handling

```powershell
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Write-Log "INFO" "Watcher received shutdown signal, cleaning up..."
    $script:Running = $false
}
```

**When Shutdown Occurs:**
1. Script receives SIGTERM (Windows Scheduled Task stop, `Stop-Job`, etc.)
2. PowerShell exiting event fires
3. `$script:Running` set to `$false`
4. Main loop checks `$script:Running` on each iteration
5. If in `Wait-UntilNextRun`, returns immediately
6. Main loop exits gracefully

**Result:**
- No abrupt termination
- Current cycle completes (if running)
- No orphaned processes
- Final log message written

## Configuration Integration

### Loading Config

```powershell
$config = Read-Config -Path $ConfigPath
```

Returns:
```json
{
  "monitors": [
    { "name": "shooting-store", "provider": "shooting-store", "enabled": true, ... }
  ],
  "filters": {
    "course_types": [ ... ],
    "exclusions": [ ... ]
  },
  "notifiers": {
    "email": { "enabled": true, ... },
    "discord": { "enabled": true, ... },
    "windows_toast": { "enabled": true, ... }
  }
}
```

### Monitor Selection

```powershell
$enabledMonitors = @(Get-EnabledMonitors -Config $Config)
```

Returns only monitors with `"enabled": true`

### Filter Configuration

Config filters.course_types and filters.exclusions control pipeline behavior

### Notifier Configuration

Config notifiers section determines which channels are enabled

## Error Handling Strategy

### Philosophy
**Fail gracefully, log everything, continue service**

### Monitor Errors
```powershell
try {
    $courses = & $monitorFactory
} catch {
    Write-Log "ERROR" "Monitor '$($monitor.name)' failed: $_"
    $cycleStats.success = $false
    # Continue to next monitor
}
```

### Pipeline Errors
```powershell
try {
    $pipelineStats = Invoke-FilterPipeline ...
} catch {
    Write-Log "ERROR" "Filter pipeline failed: $_"
    $cycleStats.success = $false
    $filteredCourses = @()  # Empty result
    # Continue to notification (which will skip on empty list)
}
```

### Notifier Errors
```powershell
try {
    $notifStats = Invoke-NotificationPipeline ...
} catch {
    Write-Log "ERROR" "Notification pipeline failed: $_"
    $cycleStats.success = $false
    # Continue to next cycle
}
```

### Initialization Errors
```powershell
try {
    $config = Initialize-Watcher -ConfigPath $ConfigPath
} catch {
    Write-Log "ERROR" "Fatal error: $_"
    exit 1  # Cannot continue without config
}
```

## Testing

### Test Mode Output

```powershell
.\Watcher.ps1 -TestMode | ConvertFrom-Json
```

Produces JSON with cycle statistics:
```json
{
  "timestamp": "2026-07-03T14:30:45.123Z",
  "monitors_executed": 2,
  "courses_found": 5,
  "courses_filtered": 3,
  "courses_notified": 3,
  "notifiers_succeeded": ["email", "discord"],
  "notifiers_failed": [],
  "duration_ms": 1234,
  "success": true
}
```

### Validation Tests

```powershell
# Single cycle
.\Watcher.ps1 -TestMode

# Limited cycles
.\Watcher.ps1 -LoopCount 3

# Custom config
.\Watcher.ps1 -ConfigPath "config/test-config.json"

# View logs
Get-Content "data/logs/watcher-$(Get-Date -Format 'yyyy-MM-dd').log" -Tail 50
```

## Performance Considerations

### Memory Usage
- Each cycle: monitor result objects + filter temp data
- State cleanup every hour: removes old state entries
- Config loaded once at startup (re-read via new-config command)

### CPU Usage
- Monitors: network I/O bound (minimal CPU)
- Filters: regex, hash comparison (low CPU)
- Notifications: network I/O bound (minimal CPU)
- Wait loop: sleep 1-second intervals (negligible CPU)

### Network Usage
- Proportional to number of monitors and poll intervals
- Example: 2 monitors × 5-min interval = ~24 requests/day per monitor

### Logging I/O
- ~10-20 lines per cycle (typical)
- ~240-480 lines/hour = ~5-10 KB/hour
- 30-day retention ≈ 3-7 MB total

## Deployment

### Windows Scheduled Task Setup (Phase 6 Extended)

```powershell
$taskName = "IPSC-Kurs-Watcher"
$scriptPath = "C:\path\to\Watcher.ps1"
$configPath = "C:\path\to\config\config.json"

$taskAction = New-ScheduledTaskAction `
    -Execute 'PowerShell.exe' `
    -Argument "-NoProfile -ExecutionPolicy RemoteSigned -File `"$scriptPath`" -ConfigPath `"$configPath`""

$taskTrigger = New-ScheduledTaskTrigger -AtStartup

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $taskAction `
    -Trigger $taskTrigger `
    -RunLevel Highest `
    -Force
```

## Phase 6 Status: Orchestration Complete

**Implemented:**
- Watcher.ps1 main orchestration script
- Initialize-Watcher with full setup
- Invoke-MonitoringCycle with all pipelines
- Invoke-WatcherLoop with graceful shutdown
- Error isolation and comprehensive logging
- Test mode for validation

**Next Steps:**
- Phase 7: Implement Pester tests for all components
- Phase 6 Extended: Windows Scheduled Task registration
- Phase 6 Extended: Performance monitoring and optimization

## File Structure

```
IPSC Kurs Watcher/
├── Watcher.ps1                    (Main script - Phase 6)
├── PHASE6-SCHEDULER.md            (This file)
├── src/
│   ├── core/
│   │   ├── Config.ps1
│   │   ├── ConfigValidator.ps1
│   │   └── State.ps1
│   ├── monitors/
│   ├── filters/
│   ├── notifiers/
│   └── utils/
│       └── Logging.ps1
├── config/
│   └── config.json
├── data/
│   ├── logs/
│   └── state.json
└── ...
```

## Running the Watcher

```powershell
# Production mode (infinite loop)
& ".\Watcher.ps1"

# Test mode (single cycle)
& ".\Watcher.ps1" -TestMode

# Limited cycles
& ".\Watcher.ps1" -LoopCount 5

# Custom config
& ".\Watcher.ps1" -ConfigPath "C:\custom\config.json"

# View recent logs
Get-Content "data/logs/watcher-$(Get-Date -Format 'yyyy-MM-dd').log" -Tail 100
```
