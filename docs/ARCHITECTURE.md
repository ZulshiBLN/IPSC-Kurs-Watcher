# System Architecture – IPSC Kurs Watcher

Comprehensive system design and component interactions.

---

## 1. System Overview

IPSC Kurs Watcher is a Windows-native monitoring automation tool that:
1. **Fetches** course availability data from websites (HTML scraping)
2. **Parses** HTML to extract course details
3. **Filters** courses by type and exclusion patterns
4. **Deduplicates** to prevent duplicate notifications
5. **Notifies** users via Email, Discord, Windows Toast
6. **Persists** state to avoid re-notifying same courses

**Deployment Model:**
- Runs as Windows Scheduled Task (every 30 minutes)
- Single-machine local automation (no cloud)
- Logs to local filesystem

---

## 2. Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Windows Scheduled Task                        │
│                    (runs every 30 minutes)                       │
└────────────────────────────┬──────────────────────────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │     1. FETCH (Monitor Module)           │
        │  Invoke-SecureWebRequest                │
        │  + URL Validation                       │
        │  + Retry Logic (3x exponential backoff)│
        │  + 30-second timeout                    │
        └────────────────────┬───────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │     2. PARSE (Monitor Module)           │
        │  Extract: Name, Date, Time, Slots      │
        │  via Regex + HTML parsing               │
        │  Returns: [Course] array                │
        └────────────────────┬───────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │     3. FILTER (Filter Pipeline)         │
        │  - Filter by type (Basic, Advanced)    │
        │  - Exclude patterns (Privatunterricht) │
        │  - Min availability threshold           │
        │  Returns: Filtered [Course] array       │
        └────────────────────┬───────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │     4. DEDUPLICATE (State Module)       │
        │  Compare vs state.json                  │
        │  - NEW: ID not in state → Alert        │
        │  - REDUCED: Slots < previous → Alert   │
        │  - UNCHANGED: Skip alert                │
        │  Returns: [Alert] array                 │
        └────────────────────┬───────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  5. NOTIFY (Notifier Modules - Parallel)│
        │  ├─ Email (SMTP via OAuth2)            │
        │  ├─ Discord (Webhook)                  │
        │  └─ Windows Toast (WinRT)              │
        │  Each runs independently (fault-iso)   │
        └────────────────────┬───────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │     6. UPDATE STATE (State Module)      │
        │  Write all current courses to          │
        │  data/state.json for next cycle        │
        └────────────────────┬───────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  7. LOG (Logging Module)                │
        │  JSON structured logs to                │
        │  data/logs/watcher-YYYY-MM-DD.log      │
        │  Rotation: Daily, Retention: 30 days   │
        └────────────────────────────────────────┘
```

---

## 3. Module Architecture

### 3.1 Core Modules (No Dependencies)

**Helpers.ps1** – Shared utilities
- `Test-ValidUrl` – URL scheme/format validation
- `Invoke-SecureWebRequest` – HTTPS validation wrapper
- `Protect-OAuthError` – Error message sanitization
- `Protect-SensitiveData` – Log data masking
- Date/Time, JSON, encryption helpers

**Logging.ps1** – Structured logging
- `Write-Log` – JSON-formatted logging to file + console
- `Initialize-Logging` – Setup log directory/rotation
- `Remove-OldLogs` – 30-day retention cleanup
- Log levels: DEBUG, INFO, WARN, ERROR

**Config.ps1** – Configuration management
- `Get-Config` – Load & validate config.json against schema
- Schema validation (required fields, types, ranges)
- Throws on validation failure (startup aborts)

**State.ps1** – State persistence
- `Get-State` – Load state.json or initialize empty
- `Update-State` – Save current courses to state
- Deduplication logic (compare old vs new)
- Auto-backup on corruption

### 3.2 Monitor Modules

**MonitorBase.ps1** – Abstract base class
- Common interface for all monitors
- Error handling template
- Retry logic with exponential backoff
- Logging integration

**CourseMonitor.ps1** – shooting-store.ch implementation
- `Get-CoursesFromShootingStore` – Fetch + parse HTML
- Category page scraping
- Course detail page scraping
- Regex patterns for course data extraction
- Specific to shooting-store.ch HTML structure

**MonitorFactory.ps1** – Monitor routing
- `Get-Monitor` – Route config.monitors[].id → implementation
- Extensible: Add new site = new Monitor file + factory entry

**GenericMonitor.ps1** – Template for new sites (optional)
- Base structure for implementing new website monitors

### 3.3 Filter Modules

**FilterByType.ps1** – Type-based filtering
- `Get-FilteredByType` – Match course names against configured patterns
- Example: "Basic" pattern matches "IPSC Basic 2.0"
- Multi-pattern support per type

**FilterByExclusion.ps1** – Pattern exclusion
- `Get-FilteredByExclusion` – Remove courses matching exclusion patterns
- Example: Exclude "Privatunterricht" courses

**FilterPipeline.ps1** – Chain all filters
- `Invoke-FilterPipeline` – Apply all filters in sequence
- Type filter → Exclusion filter → Min availability

### 3.4 Notifier Modules

**NotifyEmail.ps1** – Email via OAuth2
- `Send-EmailNotification` – SMTP via Microsoft Graph API
- OAuth2 token handling (encrypt/decrypt)
- HTML email formatting with sanitization
- Recipient validation (regex pattern check)

**NotifyDiscord.ps1** – Discord webhooks
- `Send-DiscordNotification` – Post embed to webhook
- Webhook URL validation
- Error handling (webhook down → graceful degrade)
- Currently stub (v0.1, future implementation)

**NotifyToast.ps1** – Windows Toast notifications
- `Send-ToastNotification` – WinRT Toast API
- Local desktop notification
- No network dependency (always works)

---

## 4. Dependency Graph (Acyclic)

```
BasicCourseWatcher.ps1 (Orchestrator)
  │
  ├─→ src/core/Helpers.ps1
  │    └─ No dependencies
  │
  ├─→ src/core/Logging.ps1
  │    └─ Depends: Helpers
  │
  ├─→ src/core/Config.ps1
  │    └─ Depends: Logging, Helpers
  │
  ├─→ src/core/State.ps1
  │    └─ Depends: Logging, Helpers
  │
  ├─→ src/monitors/MonitorBase.ps1
  │    └─ Depends: Logging, Helpers
  │
  ├─→ src/monitors/CourseMonitor.ps1
  │    └─ Depends: MonitorBase, Logging, Helpers
  │
  ├─→ src/monitors/MonitorFactory.ps1
  │    └─ Depends: CourseMonitor, Logging
  │
  ├─→ src/filters/FilterByType.ps1
  │    └─ Depends: Logging
  │
  ├─→ src/filters/FilterByExclusion.ps1
  │    └─ Depends: Logging
  │
  ├─→ src/filters/FilterPipeline.ps1
  │    └─ Depends: FilterByType, FilterByExclusion, Logging
  │
  ├─→ src/notifiers/NotifyEmail.ps1
  │    └─ Depends: Logging, Helpers (OAuth2, encryption)
  │
  ├─→ src/notifiers/NotifyDiscord.ps1
  │    └─ Depends: Logging, Helpers
  │
  └─→ src/notifiers/NotifyToast.ps1
       └─ Depends: Logging

Rule: No circular dependencies (A→B→A is forbidden)
```

---

## 5. Execution Flow (Per Monitor Cycle)

```
START: Scheduled Task triggers BasicCourseWatcher.ps1
  │
  ├─ Load all modules (in order: core → monitors → filters → notifiers)
  ├─ Load config.json (validate against schema)
  ├─ Load state.json (or initialize empty)
  │
  └─ FOR EACH MONITOR IN config.monitors[]:
      │
      ├─ 1. FETCH
      │  ├─ Monitor.Get-Courses()
      │  ├─ If network error: Retry 3x (exponential backoff: 1s, 2s, 4s)
      │  └─ If all fail: Log error, continue to next monitor
      │
      ├─ 2. PARSE
      │  ├─ Extract [Course] array from HTML
      │  └─ If parse error: Log error, return empty, continue
      │
      ├─ 3. FILTER
      │  ├─ Invoke-FilterPipeline (type + exclusion + min slots)
      │  └─ Result: Filtered [Course] array
      │
      ├─ 4. DEDUPLICATE
      │  ├─ Compare filtered courses vs state.json last_notified[]
      │  ├─ For each course:
      │  │  ├─ NEW: ID not in state → Add to [Alert]
      │  │  ├─ REDUCED: Slots < previous → Add to [Alert]
      │  │  └─ UNCHANGED: Skip
      │  └─ Result: [Alert] array (may be empty)
      │
      ├─ 5. NOTIFY (Parallel, each independent)
      │  ├─ IF config.notifiers.email.enabled:
      │  │  └─ Send-EmailNotification($alerts) in parallel
      │  │      ├─ If SMTP error: Log, continue (don't block other notifiers)
      │  │      └─ Success: Log sent
      │  │
      │  ├─ IF config.notifiers.discord.enabled:
      │  │  └─ Send-DiscordNotification($alerts) in parallel
      │  │      └─ If webhook error: Log, continue
      │  │
      │  └─ IF config.notifiers.windows_toast.enabled:
      │     └─ Send-ToastNotification($alerts) in parallel
      │         └─ Always succeeds (local API)
      │
      └─ 6. UPDATE & LOG
         ├─ Update state.json with all current courses
         └─ Write monitoring cycle log entry (duration, course count, alerts)

END: Exit (Scheduled Task completes)
```

---

## 6. Configuration Architecture

**config.json structure:**
```
{
  monitors[]          ← Array of monitored websites
  filters{}           ← Global filtering rules
  notifiers{}         ← Notification channels
  state{}             ← State file location
  logging{}           ← Log rotation + retention
  error_handling{}    ← Error thresholds
}
```

**Module-specific config:**
- Monitors read: `config.monitors[i]` (per-monitor settings)
- Filters read: `config.filters` (global type patterns)
- Notifiers read: `config.notifiers.email`, `.discord`, `.windows_toast`

**Secrets (NOT in config.json):**
- Stored in environment variables: `IPSC_AZURE_*`, `IPSC_DISCORD_*`
- Token cache encrypted with DPAPI
- Environment variables take precedence over config fallback

---

## 7. State Management

**state.json structure:**
```json
{
  "version": 1,
  "last_poll": "2026-07-03T14:30:00Z",
  "last_notified": [
    {
      "id": "IPSC Basic 2.0|08.08.2026|09:30-13:00",
      "name": "IPSC Basic 2.0",
      "date": "2026-08-08",
      "time": "09:30-13:00",
      "availability": 3,
      "url": "https://...",
      "notified_at": "2026-07-03T14:30:00Z"
    }
  ]
}
```

**Deduplication Logic:**
1. Load current state from disk
2. Fetch new courses from monitor
3. For each new course:
   - Check if ID exists in `last_notified[]`
   - If NOT exists → NEW alert
   - If exists but `availability < previous` → REDUCED alert
   - Otherwise → no alert
4. Write all current courses back to state (for next cycle)

**Auto-Backup:**
- If state.json is corrupted: Create `state.json.backup.YYYYMMDD`
- Auto-recover: Initialize fresh state.json
- Log warning event

---

## 8. Error Handling Architecture

### Retry Strategy (Exponential Backoff)

```
Attempt 1: Immediately
  ├─ Timeout? → Wait 1 second
  │
Attempt 2: After 1 second
  ├─ Timeout? → Wait 2 seconds
  │
Attempt 3: After 2 seconds
  ├─ Timeout? → Fail
  └─ Log error, skip this monitor, continue next
```

### Fault Isolation

**Monitor Failure:**
- Only affects that monitor
- Other monitors continue
- No cascade failure

**Notifier Failure:**
- Email fails → Discord/Toast still send
- Discord fails → Email/Toast still send
- Toast fails → Email/Discord still send
- Each independent with own try-catch

**State Corruption:**
- Auto-detected on load
- Auto-recover: Initialize fresh state
- Create backup for analysis
- Log warning, continue

### Error Alerting (Optional)

**Trigger:** 5+ errors in 60 minutes
- Send admin alert via email + Discord
- Only if `config.error_handling.alert_on_repeated_errors: true`
- Max 1 alert per 60 minutes per monitor (prevent spam)

---

## 9. Logging Architecture

### Log Format (JSON Structured)

```json
{
  "timestamp": "2026-07-03T14:30:00.123Z",
  "level": "INFO",
  "component": "Monitor.CourseMonitor",
  "message": "Found 8 courses",
  "context": {
    "monitor_id": "shooting-store",
    "course_count": 8,
    "new_courses": 2,
    "duration_ms": 1234
  }
}
```

### Log Destinations

1. **File** (Primary)
   - Location: `data/logs/watcher-YYYY-MM-DD.log`
   - Format: JSON (one per line)
   - Rotation: Daily at 00:00
   - Retention: 30 days (auto-cleanup)

2. **Console** (Interactive mode)
   - Format: Human-readable plaintext
   - Color-coded: INFO=Green, WARN=Yellow, ERROR=Red
   - Only when run manually (not via Scheduled Task)

3. **Windows Event Log** (Optional, future)
   - Event Source: "IPSC Kurs Watcher"
   - For sysadmin integration
   - Not yet implemented (Phase 2+)

### Log Levels

| Level | Usage | Example |
|-------|-------|---------|
| DEBUG | Development tracing | Function entry/exit, variable values |
| INFO | Normal operations | "Found 8 courses, 2 new" |
| WARN | Concerning but not critical | "Retry attempt 2/3" |
| ERROR | Failures requiring attention | "SMTP connection timeout" |

---

## 10. Security Architecture

### Credential Flow

```
┌──────────────────────────────────────────────────────┐
│ Environment Variables (Set once at setup)            │
│ - IPSC_AZURE_TENANT_ID                              │
│ - IPSC_AZURE_CLIENT_ID                              │
│ - IPSC_AZURE_USER_ID                                │
│ - IPSC_DISCORD_WEBHOOKS                             │
└──────────────────────┬───────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────┐
        │ OAuth2 Token Acquisition         │
        │ (via Microsoft Graph API)        │
        └──────────────┬───────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────┐
        │ DPAPI Encryption (LocalMachine)  │
        │ Encrypt token bytes with entropy │
        └──────────────┬───────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────┐
        │ Persist to Disk                  │
        │ data/.token_cache.json (binary)  │
        │ Not human-readable               │
        └──────────────┬───────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────┐
        │ Token Refresh (Auto on expire)   │
        │ Decrypt → use → refresh if <30min│
        │ Encrypt → save                   │
        └──────────────────────────────────┘
```

### URL Validation

```
Input URL
  ├─ Scheme validation → Must be http:// or https:// only
  ├─ Format validation → Must be absolute (no relative paths)
  ├─ Regex matching → Must match http(s)://... pattern
  └─ Result: Valid or Rejected
```

### Error Sanitization

```
Raw error: "Error: invalid client_secret xyz123 for tenant_id: xxxxxxxx-xxxx..."
  ├─ Mask: client_secret: xxx → client_secret: [REDACTED_SECRET]
  ├─ Mask: tenant_id: xxx → tenant_id: [REDACTED_TENANT]
  ├─ Mask: Email addresses → [REDACTED_EMAIL]
  └─ Logged sanitized version
```

---

## 11. Deployment Architecture

### Windows Scheduled Task

**How it runs:**
```
Scheduled Task: "IPSC-Kurs-Watcher"
  ├─ Trigger: Repeat every 30 minutes
  ├─ Action: PowerShell -File BasicCourseWatcher.ps1
  ├─ Principal: SYSTEM (highest privileges)
  ├─ Start time: Immediately + auto-restart on reboot
  └─ Logs: data/logs/watcher-YYYY-MM-DD.log
```

**Installation:**
```powershell
.\scripts\Install-ScheduledTask.ps1  # Registers task with Windows
```

**Uninstallation:**
```powershell
Unregister-ScheduledTask -TaskName "IPSC-Kurs-Watcher"
```

---

## 12. Scalability

### Single Monitor (1 website)
- Fetch + Parse: 2-3 seconds
- Filter + Dedup: <100ms
- Notifications: 1-5 seconds
- **Total: ~5-10 seconds**

### Multiple Monitors (3+ websites)
- Monitors fetch in parallel (PowerShell Background Jobs)
- Max 10 concurrent jobs (resource limit)
- Notifiers run in parallel (independent)
- **Total: ~10-15 seconds (not sequential)**

### Adding New Website

1. Create `src/monitors/SiteMonitor.ps1`
   - Extend MonitorBase
   - Implement `Get-CoursesFromSite()`
   - Handle site-specific HTML parsing
2. Update `src/monitors/MonitorFactory.ps1`
   - Add routing: `'site-id' → SiteMonitor`
3. Add config entry in `config.json`
   - New monitor in `monitors[]` array
4. No other code changes needed

---

## 13. Future Architecture (Phase 2+)

### Planned Enhancements

1. **WPF GUI** (Phase 2)
   - Configuration UI (no JSON editing)
   - Real-time status dashboard
   - Test buttons for monitors/notifiers
   - Logs viewer

2. **Advanced Filtering** (Phase 3)
   - Regex patterns (not just string matching)
   - Time-based filters (exclude evening courses)
   - Price range filters

3. **Alerting** (Phase 3)
   - Slack integration
   - SMS notifications
   - Custom webhook support

4. **Cloud Backup** (Phase 4+)
   - Optional state sync to cloud
   - Cross-device coordination
   - Historical analytics

---

## 14. References

- [DECISIONS.md](../DECISIONS.md) – Architectural decisions (why)
- [STRUCTURE.md](../STRUCTURE.md) – Implementation rules (how)
- [SECURITY.md](SECURITY.md) – Security implementation
- [ADR-001](../DECISIONS.md#adr-001-technology-stack-selection) – Technology choice
- [ADR-003](../DECISIONS.md#adr-003-monitoring-architecture--pipeline) – Pipeline design
- [ADR-006](../DECISIONS.md#adr-006-error-handling--recovery) – Error handling
- [ADR-007](../DECISIONS.md#adr-007-logging--observability) – Logging strategy
