# Complete Architecture Guide – IPSC Kurs Watcher v1.0.0

**Last Updated:** 2026-07-05  
**Version:** v1.0.0 (Stable)  
**Codebase:** 3,051 LOC (1,138 src + 1,913 tests)  
**Audit Level:** Comprehensive  
**Audience:** Developers, Architects, DevOps, Security Auditors

---

## Executive Summary

IPSC Kurs Watcher is a modular, zero-dependency PowerShell automation tool that monitors IPSC course availability on shooting-store.ch. It detects real-time changes (new courses, reduced availability, sold-out) and delivers notifications via Windows Toast, Email (OAuth2 Graph API), and Discord webhooks.

**Core Principles:**
- **Security-First:** DPAPI encryption, OAuth2 tokens, URL validation, credential isolation
- **Modular:** Acyclic dependency DAG, clean separation (core/monitors/filters/notifiers)
- **Reliable:** Graceful degradation, non-blocking delivery, automatic state recovery
- **Simple:** Pure PowerShell 5.1, no external packages, ~3,000 LOC total
- **Observable:** Structured JSON logging, performance metrics, full error context

**Deployment:** Windows Scheduled Task (every 30 min) or manual PowerShell execution

---

## 1. System-Level Data Flow

```
[Windows Task Scheduler Trigger]
         ↓
    [Scheduler.ps1]
    (Orchestrator & Module Loader)
         ↓
┌─ LOAD PHASES ─────────────────────────────────┐
│ 1. Core modules (Helpers → Logging → Config)  │
│ 2. State management                           │
│ 3. Feature modules (Monitors → Filters)       │
│ 4. Notifiers (Email, Discord, Toast)          │
└────────────────────────────────────────────────┘
         ↓
┌─ MONITORING CYCLE ────────────────────────────┐
│ (Repeats every 30 minutes or -RunOnce mode)   │
└────────────────────────────────────────────────┘
         ↓
FOR EACH MONITOR in config.monitors[]:
  
  [1] FETCH
  • CourseMonitor.Invoke()
  • HTTP GET: https://shooting-store.ch/de/kategorie/kurse1
  • Timeout: 30s, Retry: 3x exponential (1s, 2s, 4s)
  • Result: HTML page
  
  [2] PARSE
  • Extract course table via regex
  • For each course: Fetch detail page
  • Extract: name, date, time, price, availability
  • Result: [Course] array (typed objects)
  
  [3] FILTER
  • Invoke-FilterPipeline:
    - Type filter (configured patterns)
    - Exclusion filter (blacklist patterns)
    - Availability filter (min_availability >= config)
  • Result: Filtered [Course] array
  
  [4] CHANGE DETECTION
  • Merge-CourseState (current vs state.json)
  • NEW: Not in state → Alert
  • REDUCED: Availability decreased → Alert
  • SOLD_OUT: In state, not current → Alert
  • Result: [Alert] array
         ↓
COLLECT ALL ALERTS FROM ALL MONITORS
         ↓
[5] NOTIFY (Non-blocking, all parallel)

Send-ToastNotification    (Windows WinRT API)
  • Group alerts by type
  • Display desktop notification
  • Best-effort (local only)
  
Send-EmailNotification    (Graph API OAuth2)
  • Check token cache
  • Refresh token if expired
  • POST to /me/sendMail
  • Retry on network error
  
Send-DiscordNotification  (Webhooks)
  • Group by alert reason
  • Build Discord embeds
  • POST to webhook URL
  • Retry 3x exponential
         ↓
[6] STATE PERSISTENCE
• Save-State: Merge courses into state.json
• Atomic file write
• Timestamp each entry
         ↓
[7] LOGGING
• Write-Log: Cycle metrics
  - Course counts
  - Alert counts
  - Duration in ms
  - Any errors
         ↓
[CYCLE COMPLETE]
Performance: 5-10 seconds total
```

---

## 2. Module Architecture

### Layer 0: Core Foundation (Zero Dependencies)

**Helpers.ps1** – Shared utilities
- `Test-ValidUrl` – URL validation (http/https only, no injection)
- `Invoke-SecureWebRequest` – HTTP wrapper with timeout/retry
- `Protect-Data` / `Unprotect-Data` – DPAPI encryption
- `Mask-SensitiveData` – Log sanitization
- `ConvertTo-JsonSafe` – JSON conversion with error handling

*Used By:* All other modules  
*File Size:* ~150 LOC

**Logging.ps1** – Structured JSON logging
- `Initialize-Logging` – Setup log directory, retention cleanup
- `Write-Log -Level {DEBUG|INFO|WARN|ERROR} -Message "..." -Context @{...}` – Structured logging
- `Write-LogToFile-JSON` – Persist to daily rotated log file
- `Remove-OldLog` – Auto-cleanup logs older than 30 days

*Output Format:* 
```json
{"timestamp":"2026-07-05T14:30:00Z","level":"INFO","message":"...", "context":{...}}
```

*Used By:* All other modules  
*File Size:* ~150 LOC

**Config.ps1** – Configuration management
- `Get-Config -ConfigPath 'config/config.json'` – Load and parse config
- Validates JSON syntax
- ⚠️ **Known Gap:** No runtime schema validation (should validate URLs, permissions)

*Config Sections:*
- `monitors[]` – Website monitoring configurations
- `filters{}` – Course type patterns, exclusions, min availability
- `notifiers{}` – Toast/Email/Discord settings
- `state{}` – State file location and retention
- `logging{}` – Log directory, level, retention
- `error_handling{}` – Error thresholds and alerting

*Used By:* Scheduler  
*File Size:* ~100 LOC

**State.ps1** – Course tracking & deduplication
- `Get-State -Path 'data/state.json'` – Load state (or create if missing)
- `Merge-CourseState -Current $courses -Previous $state` – Detect changes (NEW/REDUCED/SOLD_OUT)
- `Save-State -State $newState` – Persist to disk

*State Structure:*
```json
{
  "version": 1,
  "last_poll": "2026-07-05T14:30:00Z",
  "last_notified": [
    {
      "id": "Course Name|date|time",
      "name": "IPSC Basic 2.0",
      "date": "05.08.2026",
      "time": "09:30-13:00",
      "availability": 3,
      "url": "https://...",
      "notified_at": "2026-07-05T14:30:00Z"
    }
  ]
}
```

*Change Detection Logic:*
```
NEW       → Current course, not in state → Alert
REDUCED   → Course in both, availability decreased → Alert
SOLD_OUT  → Course in state, not in current → Alert
NO_CHANGE → Course in both, same availability → Skip
```

*⚠️ Known Issue:* ID generation `"$name|$date|$time"` could collide if multiple courses have same name. Recommendation: Validate ID uniqueness at merge time.

*Used By:* Scheduler  
*File Size:* ~200 LOC

---

### Layer 1: Monitor Modules (Fetch & Parse)

**MonitorBase.ps1** – Abstract interface
- Defines contract: `Invoke()` method returns [Course] array
- Common error handling template
- No concrete implementation (abstract)

*Used By:* CourseMonitor, MonitorFactory

**CourseMonitor.ps1** – shooting-store.ch implementation
- `Invoke()` – Fetch and parse shooting-store.ch courses
- HTTP GET: https://www.shooting-store.ch/de/kategorie/kurse1
- Parse course table rows via regex
- For each course: Fetch detail page, extract availability
- Return [Course] array with fields: id, name, date, time, price, availability, url

*HTML Parsing:*
- Regex-based (no external parser)
- Pattern matching for course rows
- Pattern matching for availability slots
- **Known Fragility:** If shooting-store.ch HTML structure changes, parser breaks

*Performance:* 2-3 seconds per cycle (1 list page + N detail pages)

*Used By:* MonitorFactory  
*File Size:* ~250 LOC

**MonitorFactory.ps1** – Monitor instantiation
- `Get-Monitor -Config $monitorConfig` – Route to correct monitor
- Factory pattern: `switch ($config.provider) { 'shooting-store' { ... } }`
- Extensible for future monitors

*Used By:* Scheduler  
*File Size:* ~50 LOC

---

### Layer 2: Filter Modules (Course Filtering)

**FilterByType.ps1** – Type-based filtering
- `Get-FilteredByType -Courses $courses -FilterConfig $config` – Match patterns
- Config example: `{"patterns": ["Basic", "Level 1"], "enabled": true}`
- Returns: Matching courses only

**FilterByExclusion.ps1** – Pattern exclusion
- `Get-FilteredByExclusion -Courses $courses -FilterConfig $config` – Remove matched
- Config example: `{"exclude_patterns": ["Privatunterricht", "VIP"]}`
- Returns: Non-excluded courses

**FilterPipeline.ps1** – Filter chain composition
- `Invoke-FilterPipeline -Courses $courses -FilterConfig $config` – Apply all filters
- Flow: Input → Type Filter → Exclusion Filter → Availability Filter → Output
- Non-failing chain (returns empty array if no matches)

*Used By:* Scheduler  
*Combined File Size:* ~150 LOC

---

### Layer 3: Notifier Modules (Multi-Channel Delivery)

**NotifyEmail.ps1** – Email via OAuth2 Graph API
- `Send-EmailNotification -Alerts $alerts -Config $config` – Send via email
- OAuth2 flow:
  1. Check token cache (data/.token_cache.json, DPAPI-encrypted)
  2. If expired/missing: Request fresh token from login.microsoftonline.com
  3. Construct HTML email from alerts
  4. POST to Graph /me/sendMail endpoint
  5. Log success/failure
- Recipient: Configured in environment variable `IPSC_AZURE_*` (not in config.json)
- Retry: 3x on network error with exponential backoff
- ⚠️ **Known Issue:** Token refresh request has hardcoded timeout (could block cycle if Graph API is slow)

*Used By:* Scheduler  
*File Size:* ~300 LOC

**NotifyDiscord.ps1** – Discord webhooks
- `Send-DiscordNotification -Alerts $alerts -Config $config` – Send to Discord
- Group alerts by reason (NEW, REDUCED, SOLD_OUT)
- Build Discord embeds (structured format)
- POST JSON payload to webhook URL
- Retry: 3x exponential (1s, 2s, 4s) on failure
- Non-blocking (failure doesn't affect other channels)
- ⚠️ **Known Issue:** Multiple failed webhooks silently accumulate (no escalation)

*Used By:* Scheduler  
*File Size:* ~200 LOC

**NotifyToast.ps1** – Windows Toast notifications
- `Send-ToastNotification -Alerts $alerts -Config $config` – Desktop notification
- Group alerts by course type
- Construct XML for Windows.UI.Notifications API (WinRT)
- Display local desktop notification
- Platform: Windows 10+ (graceful failure on older OS)
- No network dependency (always succeeds if API available)

*Used By:* Scheduler  
*File Size:* ~150 LOC

---

## 3. Dependency Graph (Acyclic DAG)

```
Scheduler.ps1
  ├─ Helpers.ps1 ←─────────────────────┐
  │   (No dependencies)                 │
  │                                     │
  ├─ Logging.ps1 ←─────────────────┐   │
  │   Depends: Helpers              │   │
  │                                 │   │
  ├─ Config.ps1                     │   │
  │   Depends: Logging, Helpers ────┴───┘
  │
  ├─ State.ps1
  │   Depends: Logging, Helpers
  │
  ├─ MonitorBase.ps1
  │   Depends: Logging, Helpers
  │
  ├─ CourseMonitor.ps1
  │   Depends: MonitorBase, Logging, Helpers
  │
  ├─ MonitorFactory.ps1
  │   Depends: CourseMonitor, Logging
  │
  ├─ FilterByType.ps1
  │   Depends: Logging
  │
  ├─ FilterByExclusion.ps1
  │   Depends: Logging
  │
  ├─ FilterPipeline.ps1
  │   Depends: FilterByType, FilterByExclusion, Logging
  │
  ├─ NotifyEmail.ps1
  │   Depends: Logging, Helpers (encryption, web requests)
  │
  ├─ NotifyDiscord.ps1
  │   Depends: Logging, Helpers
  │
  └─ NotifyToast.ps1
      Depends: Logging

✓ Zero circular dependencies
✓ All dependencies flow "downward" (modules depend on core, never upward)
✓ Safe to reload modules independently
```

---

## 4. Data Object Schemas

**Course Object** (output from monitors):
```powershell
@{
  id              = "Course Name|DD.MM.YYYY|HH:MM-HH:MM"  # Unique ID for dedup
  name            = "IPSC Basic 2.0"
  date            = "05.08.2026"
  time            = "09:30-13:00"
  price           = "CHF 280.00"
  availability    = 3                                     # Integer slot count
  url             = "https://www.shooting-store.ch/..."
  monitor_id      = "shooting-store"
  fetched_at      = "2026-07-05T14:30:00Z"
}
```

**Alert Object** (output from change detection):
```powershell
@{
  alert_reason    = "NEW" | "AVAILABILITY_REDUCED" | "SOLD_OUT"
  # ... all fields from Course above
  previous_availability = 5  # (only for REDUCED alerts)
}
```

**Notification Payload** (input to notifiers):
```powershell
$alerts = @(
  @{ alert_reason = "NEW"; name = "..."; ... },
  @{ alert_reason = "REDUCED"; name = "..."; ... }
)
```

---

## 5. Error Handling Strategy

**Principle:** Fail gracefully, log everything, continue operations.

**Startup Errors** (Application stops):
- Module load failure → Exit with error
- Config parse failure → Exit with error
- Reason: Cannot continue without core setup

**Runtime Errors** (Non-fatal):
- Monitor fetch fails → Catch, log, skip to next monitor
  - 1 monitor down ≠ application down
- Filter fails → Return empty array (no courses pass filter)
- Notification send fails → Catch, log, try next channel
  - Email fails → Discord/Toast still sent
  - All channels independent (fault-isolated)
- State save fails → Log error, cycle continues
  - State may be stale on next run (but app doesn't crash)

**Recovery Mechanisms:**
- State file corrupted → Initialize clean state (first run behavior)
- State file missing → Initialize clean state
- Token expired → Auto-refresh via Graph API
- Webhook down → Retry 3x, then log and continue

---

## 6. Performance Characteristics

| Metric | Value | Notes |
|--------|-------|-------|
| **Cycle Duration** | 5-10 sec | Fetch (2-5s) + notify (1-5s) + overhead |
| **HTTP Requests** | 2-5 | 1 list page + N detail pages + 3 notification endpoints |
| **Memory Usage** | 50-100 MB | Course list + parsed HTML in memory |
| **CPU Peak** | 2-5% | Regex parsing, JSON conversion |
| **Network I/O** | 50-100 KB | List + detail pages + notifications |
| **Log Growth** | ~100 KB/month | Daily rotation, 30-day retention = 3 MB max |
| **Disk Usage** | <5 MB | Config (2 KB) + state (50 KB) + logs (3 MB max) |

**Scalability Limits (Known):**
- Single monitor tested (architecture supports N monitors)
- Up to ~100 courses monitored (no stress test beyond)
- Sequential HTTP requests (no parallelization)

---

## 7. Security Architecture

**Threat Model & Mitigations:**

| Threat | Mitigation |
|--------|-----------|
| OAuth2 token theft | DPAPI encryption (LocalMachine), 1-hour expiry, auto-refresh |
| URL injection | All URLs validated (http/https only via Test-ValidUrl) |
| Network eavesdropping | HTTPS for all requests, CA validation via Windows |
| Configuration injection | JSON syntax validated, no dynamic code execution |
| Log data leakage | Sensitive fields masked (passwords → `***MASKED***`) |
| Credential exposure | Environment variables (OS-level), no config.json secrets |

**Token Protection Flow:**
```
[OAuth2 Token from Graph API]
         ↓
[DPAPI Encrypt(token, LocalMachine)]
         ↓
[Write to data/.token_cache.json (binary)]
         ↓
[On Use: DPAPI Decrypt → Use → Refresh if near expiry]
```

**Why DPAPI LocalMachine?** Scheduled Task runs as SYSTEM account. LocalMachine scope allows SYSTEM to decrypt (CurrentUser scope would fail for SYSTEM).

---

## 8. Testing Coverage

**Test Suite:** 1,913 LOC in Pester tests

| Module | Coverage | Status |
|--------|----------|--------|
| Config.ps1 | ~85% | ✅ Good (file load, validation, defaults) |
| Logging.ps1 | ~90% | ✅ Excellent (all paths tested) |
| State.ps1 | ~80% | ⚠️ Fair (missing corruption recovery) |
| Helpers.ps1 | ~75% | ⚠️ Fair (missing timeout scenarios) |
| CourseMonitor.ps1 | ~70% | ⚠️ Fair (mock HTML, no real website tests) |
| FilterPipeline.ps1 | ~80% | ✅ Good (type, exclusion, chaining) |
| NotifyEmail.ps1 | ~60% | ⚠️ Fair (missing token expiry edge case) |
| NotifyDiscord.ps1 | ~65% | ⚠️ Fair (missing retry logic test) |
| NotifyToast.ps1 | ~75% | ✅ Good (XML generation, platform detection) |

**Overall Coverage:** ~75-80% (estimated)

**Missing Test Scenarios:**
- Network timeouts (Invoke-SecureWebRequest timeout handling)
- State file corruption recovery
- OAuth2 token expiration edge cases
- shooting-store.ch HTML structure regression detection
- Concurrent monitor execution (not yet implemented)

---

## 9. Known Architectural Issues

| Issue | Severity | Impact | Recommendation |
|-------|----------|--------|---|
| **State merge ID collision risk** | MEDIUM | If courses with identical name/date/time exist, dedup could fail | Validate ID uniqueness at merge time |
| **Config validation gaps** | MEDIUM | URLs not validated at startup; log directory permissions not checked | Add pre-deployment validation |
| **HTML parser fragility** | HIGH | Regex-based; breaks if shooting-store.ch structure changes | Monitor test suite for regressions |
| **No notification retry queue** | MEDIUM | Failed notifications not persisted; alerts may be lost | Implement retry queue in v1.1 |
| **Token refresh timeout** | MEDIUM | If Graph API slow, entire cycle blocks | Add circuit breaker or timeout |
| **No rate limiting** | LOW | Could be blocked if hitting shooting-store.ch too frequently | Implement backoff on 429 errors |
| **Discord webhook silent failure** | LOW | Multiple failures accumulate without escalation | Log webhook health metrics |

---

## 10. Future Architecture Roadmap

**v1.1.0** (High Priority)
- Implement notification retry queue (at-least-once semantics)
- Add circuit breaker for repeated monitor failures
- Pre-deployment validation (URL reachability, permissions)

**v2.0.0** (Medium Priority)
- Parallel monitor execution (architecture already supports)
- Multi-website support (extensible factory pattern ready)
- Windows Event Log integration
- GUI configuration tool (WPF)

**v3.0.0+** (Low Priority)
- Cloud state sync (cross-device coordination)
- Advanced filtering (regex, time-based, price range)
- Slack/SMS notifications
- Historical analytics

---

## References

- [SECURITY.md](SECURITY.md) – Detailed security analysis
- [OPERATIONAL_GUIDE.md](OPERATIONAL_GUIDE.md) – Operational runbook
- [DEPLOYMENT.md](DEPLOYMENT.md) – Step-by-step deployment guide
- [TESTING.md](TESTING.md) – Test coverage and strategy
- [AUDIT_SUMMARY.md](AUDIT_SUMMARY.md) – Comprehensive audit report
- [CONFIG_SCHEMA.md](CONFIG_SCHEMA.md) – Configuration reference
- [DECISIONS.md](../DECISIONS.md) – Architecture Decision Records
- [STRUCTURE.md](../STRUCTURE.md) – Implementation rules
