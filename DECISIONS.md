# IPSC Kurs Watcher – Architectural Decision Records (ADRs)

Zentrale Dokumentation für Architektur-Entscheidungen, die IPSC Kurs Watcher massgeblich beeinflussen.

---

## ADR Template

Kopiere dieses Template für neue Entscheidungen:

```markdown
## ADR-XXX: [Decision Title]

**Status:** [PENDING / ACCEPTED / REJECTED / SUPERSEDED]

**Context:**
[Why is this decision needed? What problem are we solving?]

**Decision:**
[What did we decide? Be specific.]

**Consequences:**
- (+) [Positive consequence]
- (+) [Positive consequence]
- (-) [Negative consequence]
- (-) [Negative consequence]

**Alternatives:**
- [Alternative 1: Why did we reject it?]
- [Alternative 2: Why did we reject it?]

**See Also:**
- Related ADRs
- STRUCTURE.md references
```

---

## ADR-001: Technology Stack Selection

**Status:** [ACCEPTED] ✅

**Context:**
IPSC Kurs Watcher ist Windows-only mit Deployment via Windows Scheduled Task.
Anforderungen: 
- Höchste Performance + Resilience
- Einfaches Deployment (no runtime)
- Solo-Entwicklung mit PowerShell-Expertise
- Zukünftige Erweiterung: mehrere Websites + GUI möglich

**Decision:**
### **PowerShell 5.1 + Modular Architecture**

**Language Choice: PowerShell 5.1 (Windows PowerShell)**

Gründe:
- **Windows-native:** Direct access to WinAPI, Scheduled Task Integration, Windows Toast Notifications
- **Performance:** Compiled cmdlets, minimal startup overhead, direct OS access
- **Zero Runtime Dependencies:** Läuft auf jedem Windows ≥ Server 2016 (PowerShell 5.1 vorinstalliert)
- **Solo Developer:** Deine PowerShell-Expertise (WinHarden, SharedMailboxProvisioner background)
- **HTML Scraping:** PowerShell Regex + Invoke-WebRequest völlig ausreichend
- **No External Dependencies:** Pure PowerShell (ConvertTo-Json, standard cmdlets)

**Architecture: Modular for Scalability**

Struktur:
```
src/
├── core/              (Config, State, Logging)
├── monitors/          (HTML parsers: CourseMonitor, future sites)
├── filters/           (Pattern matching: type filters, exclusions)
├── notifiers/         (Email, Discord, Toast)
└── utils/             (Helpers, encryption)
```

Rationale:
- **Extensibility:** Neue Websites = neue Monitor-Datei (keine Duplikation)
- **Maintainability:** Bugfixes an einer Stelle propagieren
- **Testability:** Unabhängig testbare Module
- **Future GUI:** Web/WPF GUI kann Config laden
- **Professional Structure:** Skaliert von 1→50+ Websites

**Current State (v1.0 - MVP):**
- CourseMonitor.ps1: Monolithic standalone (proven working)
- BasicCourseWatcher.ps1: Simple orchestration
- Planned Refactor (v1.1): Extract to modular structure

**Consequences:**
- (+) **Windows-native:** No cross-platform overhead
- (+) **Minimal footprint:** Pure PowerShell, no runtime needed
- (+) **Expert leverage:** Your PowerShell expertise directly applicable
- (+) **Scalable architecture:** Supports 1 to 50+ websites without redesign
- (+) **Easy to extend:** Add new monitor = new file (no refactoring existing code)
- (+) **Maintainable:** Core logic changes propagate to all monitors
- (+) **Future-proof:** GUI can be added as separate layer
- (-) **Learning curve:** Module patterns require PowerShell 5.1+ understanding
- (-) **Initial effort:** Refactoring from monolithic to modular takes time

**Alternatives Considered & Rejected:**
- **Python 3.10+:** Cross-platform but heavier, requires runtime, less Windows-native
- **Node.js/TypeScript:** Heavier, not Windows-optimized, new language
- **C# / .NET:** Good option but PowerShell quicker to iterate
- **Staying monolithic long-term:** Works for 1 site, breaks at 3+ (code duplication nightmare)

---

## ADR-002: Module Architecture & Configuration Management

**Status:** [ACCEPTED] ✅

**Context:**
IPSC Kurs Watcher ist modular strukturiert (siehe ADR-001). Modules müssen klare Grenzen haben, Abhängigkeiten müssen definiert sein, Configuration muss zentral & dezentral funktionieren.

**Decision:**

### Module Structure: By Feature

```
src/
├── core/                    (Shared utilities)
│   ├── Config.ps1          (Load & validate config)
│   ├── State.ps1           (State management)
│   └── Logging.ps1         (Structured logging)
├── monitors/                (Monitor implementations)
│   ├── MonitorBase.ps1     (Abstract base)
│   ├── CourseMonitor.ps1   (shooting-store.ch)
│   └── GenericMonitor.ps1  (Template for new sites)
├── filters/                 (Filtering logic)
│   ├── FilterByType.ps1    (Course type matching)
│   └── FilterByExclusion.ps1 (Exclusion patterns)
├── notifiers/               (Notification channels)
│   ├── NotifyEmail.ps1     (SMTP)
│   ├── NotifyDiscord.ps1   (Webhooks)
│   └── NotifyToast.ps1     (Windows Toast)
└── utils/                   (Helpers)
    └── Helpers.ps1         (Common utilities)
```

**Rationale:**
- **Feature-based:** Easy to find code by feature
- **Scalable:** Add new monitor = new file in src/monitors/
- **Clear boundaries:** Each folder has single responsibility

### Configuration Management: Hybrid

**Central Configuration (by Main.ps1 / Scheduler.ps1):**
- Load `config.json` once at startup
- Parse top-level sections: `monitors[]`, `filters`, `notifiers`
- Validate schema (ConfigValidator)
- Pass config object to modules

**Module-Specific Configuration (distributed):**
- Each module reads its own sections from config
- Example: `Get-EmailConfig` reads `config.notifiers.email`
- Reduces coupling, allows module independence

### Dependency Hierarchy: Acyclic (No Circular Dependencies)

**Strict Rule:** If A imports B, B cannot import A

**Allowed Flow:**
```
Main.ps1
  ├─→ core/Config.ps1
  ├─→ core/State.ps1
  ├─→ monitors/*
  │   └─→ core/Logging.ps1
  ├─→ filters/*
  │   └─→ core/Logging.ps1
  └─→ notifiers/*
      └─→ core/Logging.ps1
```

### Module Exports: Explicit Public API

**Pattern: Export-ModuleMember (when using PS modules)**

For dot-sourced files:
```powershell
# End of src/monitors/CourseMonitor.ps1

# Explicitly export public functions
Export-ModuleMember -Function @(
    'Get-CoursesFromShootingStore'  # Public
    # Do NOT export helper functions (even without _ prefix)
)

# Private helpers (no export)
function _ParseHtmlRow { ... }      # Not exported (internal only)
```

**Consequences:**
- (+) **Clear Structure:** Easy to find/add code
- (+) **Scalable:** New features = new file (no changes elsewhere)
- (+) **Maintainable:** No circular dependencies (easier to understand)
- (+) **Testable:** Each module can be tested independently
- (+) **Explicit Exports:** Clear public API, no surprises
- (-) **Complexity:** Dot-sourcing + exports adds boilerplate
- (-) **Learning Curve:** Developers need to understand dependency rules

**See Also:**
- STRUCTURE.md: Detailed folder layout
- ADR-001: PowerShell module system choice

---

## ADR-003: Monitoring Architecture & Pipeline

**Status:** [ACCEPTED] ✅

**Context:**
IPSC Kurs Watcher überwacht Kursverfügbarkeit auf Websites (starting: shooting-store.ch, future: 2-5+ sites).
Anforderungen:
- Neue Kurse erkennen + notifizieren
- Verfügbarkeitsänderungen tracken (Plätze verfügbar/belegt)
- Multi-Website Support (via config.json, kein Code-Änderung nötig)
- Duplikat-Benachrichtigungen verhindern
- Robust gegen Netzwerkfehler

**Decision:**

### Core Pipeline (pro Monitor-Run)
```
1. FETCH       → HTML von Website abrufen (mit Retry-Logic)
2. PARSE       → Kurse extrahieren (Name, Date, Time, Availability)
3. FILTER      → Nach Kurtstyp filtern + Exclusions (config-driven)
4. DEDUPLICATE → Mit state.json vergleichen (nur NEW oder REDUCED melden)
5. NOTIFY      → Email + Discord + Toast (parallel, fault-isolated)
6. UPDATE      → state.json mit neuen Kursen aktualisieren
```

### Deduplication Strategy
- **State File:** data/state.json speichert last_notified[]
- **Eintrag:** {id, name, date, notified_at, available_slots}
- **Vergleich:** Aktuell vs. gespeichert
  - NEW COURSE: ID nicht in state → ALERT
  - REDUCED AVAILABILITY: available_slots < previous → ALERT
  - NO CHANGE: Gleiche Daten → Kein Alert
- **Update:** Alle aktuellen Kurse in state.json schreiben (für nächsten Cycle)

### Resilience: Retry Logic
- **Trigger:** Network error, timeout, website down, DNS fail
- **Strategy:** 3x Retry mit exponential backoff
  - Attempt 1: Sofort
  - Attempt 2: Nach 1 Sekunde
  - Attempt 3: Nach 2 Sekunden
  - Fail: Log error + skip monitoring cycle (retry bei nächstem Poll)
- **Scope:** Monitor fetch, notifier sends (Email, Discord, Toast)
- **Timeout:** Configurable per Monitor (default 30s)

### Parallel Execution (Multi-Monitor)
- **Wenn 3+ Monitore konfiguriert sind:**
  - Scheduler startet alle als PowerShell Background Jobs parallel
  - Keine sequential waiting
  - Max 10 concurrent jobs (Ressource-Limit)
  - Scheduler wartet auf alle Jobs (mit timeout protection)
- **Performance:** 3 Websites à 10 Sekunden = ~10s total (nicht 30s sequential)

### Notifier Fault Isolation
- **Execution:** Alle aktivierten Notifier parallel (unabhängig)
- **Fehlerbehandlung:**
  - Email fehlgeschlagen? Discord + Toast funktionieren trotzdem
  - Keine Abhängigkeiten zwischen Notifier
  - Jeder Notifier hat eigene Retry-Logic
  - Fehler geloggt, nicht fatal für Watcher

**Consequences:**
- (+) **Duplicate Prevention:** State tracking verhindert Duplikat-Alerts
- (+) **Resilient:** 3x Retry + exponential backoff gegen transient Fehler
- (+) **Fast:** Parallel Job execution für Multi-Monitor
- (+) **Isolation:** Notifier-Fehler blockieren sich nicht gegenseitig
- (+) **Observable:** Strukturierte JSON Logs für Debugging
- (+) **Configurable:** Neue Websites via config.json (kein Code-Änderung)
- (-) **State Fragility:** state.json kann beschädigt werden (braucht recovery)
- (-) **Parser Fragility:** HTML-Layout Änderungen können Monitor brechen
- (-) **Complexity:** Pipeline mit Retry + Parallel + Dedup ist komplexer

**See Also:**
- ADR-002: Module structure for monitors
- ADR-004: Error handling for pipeline
- ADR-006: Retry logic implementation

---

## ADR-004: Code Style & Linting Standards

**Status:** [ACCEPTED] ✅

**Context:**
Konsistent formatierter Code verbessert Lesbarkeit, Maintenance, und Collaboration. PowerShell hat Conventions, die wir standardisieren sollten.

**Decision:**

### PSScriptAnalyzer Enforcement: STRICT

**Configuration:** All violations are ERRORS (not warnings)
- Pre-commit hook runs: `Invoke-ScriptAnalyzer src/ -Severity Error`
- Blocks commit if ANY error found
- Developers must fix before commit

**Formatting Standards**

**Indentation:**
- **4 Spaces** per nesting level
- NO TABS (PSScriptAnalyzer enforces this)
- PowerShell Standard

**Line Length:**
- **Soft Limit:** 100 characters (aim for readability)
- **Hard Limit:** 120 characters (enforce via linter)
- **Exception:** Very long strings/URLs may exceed

**Brace Style: K&R (PowerShell Standard)**

```powershell
# Opening brace on SAME line
if ($condition) {
    Write-Host "Statement"
}

# For functions too
function Get-Data {
    param([string]$Name)
    # implementation
}
```

**Comment Standards**

**No comments for obvious code:**
```powershell
# ❌ BAD:
$count = $courses.Count  # Get the count

# ✅ GOOD:
$count = $courses.Count
```

**Comments for WHY, not WHAT:**
```powershell
# ✅ GOOD:
# Skip Privatunterricht (not available for public enrollment)
$filteredCourses = $courses | Where-Object { $_.Name -notmatch "Privatunterricht" }
```

**Comment-based Help for PUBLIC functions:**
```powershell
function Get-CoursesFromHtml {
    <#
    .SYNOPSIS
    Fetches and parses courses from HTML.
    
    .DESCRIPTION
    Retrieves the category page and extracts course details using regex patterns.
    
    .PARAMETER Url
    The category page URL
    
    .EXAMPLE
    $courses = Get-CoursesFromHtml -Url "https://www.shooting-store.ch/..."
    #>
    param([string]$Url)
    # implementation
}
```

**Pre-commit Hook Integration**

**Hook runs:**
1. PSScriptAnalyzer (all .ps1 files in src/)
2. Aborts commit if errors found
3. Shows error list to developer
4. Developer fixes + retries commit

**Consequences:**
- (+) **Consistent:** All code follows same standards
- (+) **Readable:** Developers instantly recognize patterns
- (+) **Secure:** PSScriptAnalyzer catches security issues automatically
- (+) **Professional:** Looks polished, industry-standard
- (+) **Maintainable:** Easy to refactor with confidence
- (-) **Strict:** Can feel constraining initially
- (-) **Setup:** Pre-commit hook requires configuration

**See Also:**
- ADR-005: Naming Conventions (detailed rules)
- ADR-001: PSScriptAnalyzer in dev dependencies
- STRUCTURE.md: Pre-commit hook setup

---

## ADR-005: Naming Conventions

**Status:** [ACCEPTED] ✅

**Context:**
Clear, consistent naming makes code self-documenting. PowerShell has conventions we standardize for clarity.

**Decision:**

| Category | Pattern | Example |
|----------|---------|---------|
| **Functions** | Verb-Noun (PascalCase) | `Get-CoursesFromHtml`, `Send-EmailNotification` |
| **Private Functions** | _Verb-Noun (underscore prefix) | `_ParseCourseRow`, `_MaskSecrets` |
| **Parameters** | PascalCase | `$Url`, `$TimeoutSeconds`, `$IncludeDetails` |
| **Variables** | camelCase | `$courseName`, `$availableSlots` |
| **Boolean Variables** | is*, has*, can*, should* | `$isAvailable`, `$hasError`, `$canRetry` |
| **Constants** | UPPER_SNAKE_CASE | `$MAX_RETRIES`, `$STATE_FILE_PATH` |
| **Classes** | PascalCase | `class CourseMonitor`, `class NotificationService` |
| **Enums** | PascalCase | `enum CourseType { Basic, Advanced }` |
| **Test Files** | FileName.Tests.ps1 | `CourseMonitor.Tests.ps1`, `Config.Tests.ps1` |
| **Config Files** | kebab-case.json | `config.json`, `state.example.json` |

### PowerShell-Specific Conventions

**CmdletBinding on functions:**
```powershell
function Get-Data {
    [CmdletBinding()]
    param(
        [string]$Name,
        [int]$Timeout = 30
    )
    # implementation
}
```

**Parameter Validation:**
```powershell
param(
    [ValidateNotNullOrEmpty()][string]$Url,
    [ValidateRange(1, 100)][int]$Retries = 3
)
```

**Consequences:**
- (+) **Self-documenting:** Function names clearly indicate purpose
- (+) **Intuitive:** Boolean prefixes obvious at first glance
- (+) **Consistent:** Everyone follows same rules
- (-) **Verbose:** Names can be longer (e.g., `Get-CoursesFromHtmlPage` vs `GetCourses`)

**See Also:**
- ADR-004: Code Style (detailed formatting rules)

---

## ADR-006: Error Handling & Recovery

**Status:** [ACCEPTED] ✅

**Context:**
IPSC Kurs Watcher läuft 24/7. Fehler können auftreten: Network timeouts, HTML parsing Fehler, Notifier-Ausfälle, etc. Fehler müssen robust gehandhabt werden ohne Monitoring zu stoppen.

**Decision:**

### Defensive Error Handling

**Scope: Try-Catch überall an kritischen Punkten**
- Monitor Fetch (Invoke-WebRequest)
- HTML Parsing (Regex/extraction)
- State Management (JSON read/write)
- All Notifiers (Email, Discord, Toast)
- Filter Pipeline

**Pattern:**
```powershell
try {
    $result = Monitor-Function
    return $result
} catch {
    Write-Log -Level ERROR -Message "Monitor fetch failed" `
        -Context @{ Monitor = $monitorId; Error = $_.Exception.Message }
    # Trigger retry logic (siehe ADR-003: 3x exponential backoff)
    return $null
}
```

### Error Logging: Comprehensive

**What to Log:**
1. **Error Message:** Konkrete Fehlermeldung (`$_.Exception.Message`)
2. **Exception Type:** Was ist fehlgeschlagen (`$_.Exception.GetType().Name`)
3. **Stack Trace:** Volle call stack (`$_.Exception.StackTrace`)
4. **Context:** Was war am Laufen (`Monitor=shooting-store, Course=Basic 2.0`)
5. **Remediation:** Wie beheben (`Check SMTP credentials`, `Website might be down`)

### Recovery Strategy: Graceful Degradation

**Principle:** Ein Fehler blockiert nicht andere Komponenten

**Monitor Fetch Error:**
- Retry 3x (exponential backoff)
- After 3 failed attempts: log, skip this cycle, retry next interval
- Other monitors continue (keine cascade failure)

**Notifier Errors:**
- Email fehlgeschlagen? Discord + Toast trotzdem senden
- Kein Wait-and-fail
- Jeder Notifier hat eigene try-catch
- Fehler geloggt, aber nicht fatal

**State File Corruption:**
- Corrupted JSON? Auto-recovery: Initialize fresh state.json
- Backup erstellt: state.json.backup.YYYYMMDD
- Warnung geloggt (important event)
- Monitoring läuft weiter

### Admin Alerts: Optional, Configurable

**Configuration (config.json):**
```json
{
  "error_handling": {
    "alert_on_repeated_errors": true,
    "error_threshold": 5,
    "error_window_minutes": 60
  }
}
```

**Trigger:** Nach 5 Fehlern in 60 Minuten
- Alert via Email, Discord
- Nur wenn `alert_on_repeated_errors: true`
- Verhindert Alert-Spam: max 1 alert pro 60 Minuten pro Monitor

**Consequences:**
- (+) **Robust:** Fehler blockieren Monitoring nicht
- (+) **Observable:** Comprehensive error logging für Debugging
- (+) **Recoverable:** Auto-recovery für State corruption
- (+) **Admin-friendly:** Optional alerts + remediation hints
- (+) **Fault-tolerant:** Notifier failures isoliert
- (-) **Complexity:** Try-catch überall erhöht code complexity
- (-) **Alert Spam:** Ohne Konfiguration → zu viele alerts
- (-) **Silent Failures:** Wenn Alerts ausgeschaltet, könnte Monitor unbemerkt down sein

**See Also:**
- ADR-003: Retry logic (exponential backoff)
- ADR-007: Error logging details
- ADR-008: Error path testing (Pester coverage)

---

## ADR-007: Logging & Observability

**Status:** [ACCEPTED] ✅

**Context:**
IPSC Kurs Watcher läuft 24/7 unbeaufsichtigt. Logs sind einzige Quelle für Debugging, Auditing, und Monitoring von Fehlern. Gute Logging-Strategie ist critical.

**Decision:**

### Log Format: Structured JSON

**Every log entry:**
```json
{
  "timestamp": "2026-07-03T14:30:00.123Z",
  "level": "INFO",
  "component": "Monitor.CourseMonitor",
  "message": "Found 8 courses on shooting-store.ch",
  "context": {
    "monitor_id": "shooting-store",
    "course_count": 8,
    "new_courses": 2,
    "duration_ms": 1234
  }
}
```

**Benefits:**
- **Machine-readable:** Easy to parse, filter, aggregate
- **Structured:** Context data separate from message
- **Consistent:** Every entry has same fields
- **Queryable:** Can filter by component, level, context

### Log Levels

| Level | Usage | Example |
|-------|-------|---------|
| **DEBUG** | Detailed trace, function entry/exit | `DEBUG: Get-CoursesFromHtml entered with url=...` |
| **INFO** | Normal events, successful operations | `INFO: Found 8 courses, 2 new` |
| **WARN** | Concerning but not critical | `WARN: Retry attempt 2/3 for shooting-store` |
| **ERROR** | Critical errors requiring attention | `ERROR: SMTP connection timeout` |

**Default:** INFO + WARN + ERROR  
**Development:** + DEBUG (verbose)

### Log Rotation & Retention

**File Pattern:** `data/logs/watcher-YYYY-MM-DD.log`

**Rotation:**
- New file created every day at 00:00
- Old files: `watcher-2026-07-01.log`, `watcher-2026-07-02.log`, etc.

**Retention:**
- Keep 30 days of logs
- Older files auto-deleted
- Retention configurable via config.json

### Sensitive Data Masking

**What to Mask:**
- Passwords (SMTP, API credentials)
- API Keys (Discord Webhook tokens)
- Email Addresses
- URLs mit Credentials
- Personal Information (wenn geloggt)

**Implementation:**
```powershell
# Auto-masking function
$logMessage = Mask-SensitiveData -Message $message
# Replaces: "password=xyz" → "password=***MASKED***"
```

### Log Destinations

**1. File (Primary - for history & auditing)**
- Location: `data/logs/watcher-YYYY-MM-DD.log`
- Format: JSON (one object per line)
- Rotation: Daily
- Retention: 30 days (configurable)

**2. Console/Stdout (for interactive debugging)**
- When Watcher runs manually (via PowerShell)
- Format: Plaintext (human-readable)
- Example: `[2026-07-03 14:30:00] [INFO] CourseMonitor: Found 8 courses`
- Color-coded: INFO=Green, WARN=Yellow, ERROR=Red

**3. Windows Event Log (optional, for sys admins)**
- Event Source: `IPSC Kurs Watcher`
- Event Types: ERROR (Prio 2), WARN (Prio 3), INFO (Prio 4)
- Purpose: Integration with Windows monitoring/alerting
- Searchable via Event Viewer

**Consequences:**
- (+) **Observable:** Structured JSON easy to parse, query, alert on
- (+) **Auditable:** Complete history of monitoring + errors
- (+) **Secure:** Automatic masking of sensitive data
- (+) **Debuggable:** Multiple log formats (JSON + console + event log)
- (+) **Maintainable:** Rotation + retention prevents disk bloat
- (+) **Integrated:** Windows Event Log integration for sysadmins
- (-) **Complexity:** Multiple destinations + masking adds code
- (-) **Storage:** 150MB over 30 days (minor concern)

**See Also:**
- ADR-006: Error logging details (context, stack trace)
- ADR-008: Testing logging functionality
- STRUCTURE.md: Logging module architecture

---

## ADR-008: Testing Framework & Quality Assurance

**Status:** [ACCEPTED] ✅

**Context:**
IPSC Kurs Watcher läuft 24/7. Testing ist critical für Qualität + Confidence bei Refactoring.

**Decision:**

### Testing Framework: Pester 5.0+
- **Framework:** Pester (built-in PowerShell testing)
- **Syntax:** Describe / Context / It blocks (standard pattern)
- **Assertions:** Pester assertions (Should -Be, -Contain, -Throw, etc.)
- **Mocking:** Pester Mock/Assert-MockCalled

### Code Coverage Requirement: 90%+
- **Target:** 90%+ for critical modules (core/, monitors/, notifiers/)
- **Measured via:** Pester Code Coverage reports
- **Non-critical:** utils/ 70%+ acceptable
- **CI/CD:** Pre-commit hook validates coverage

### Test Organization

```
tests/
├── unit/
│   ├── core/
│   │   ├── Config.Tests.ps1
│   │   ├── State.Tests.ps1
│   │   └── Logging.Tests.ps1
│   ├── monitors/
│   │   └── CourseMonitor.Tests.ps1
│   ├── filters/
│   │   └── FilterByType.Tests.ps1
│   └── notifiers/
│       └── NotifyEmail.Tests.ps1
├── integration/
│   ├── Pipeline.Integration.Tests.ps1 (Full end-to-end)
│   ├── MultiMonitor.Integration.Tests.ps1
│   └── NotifierIntegration.Tests.ps1
├── fixtures/
│   ├── html/
│   │   ├── shooting-store-sample.html (Mock website)
│   │   └── course-detail-page.html
│   ├── json/
│   │   ├── config.example.json
│   │   └── state.example.json
│   └── data/
│       └── test-courses.json (Sample data objects)
└── run-tests.ps1 (Test runner script)
```

### Test Types

**Unit Tests (tests/unit/):**
- Test einzelne Funktionen isoliert
- Gegen fixtures (nicht echte website)
- Schnell (<100ms pro test)
- Example: `Get-CoursesFromHtml() → returns 8 courses`

**Integration Tests (tests/integration/):**
- Full pipeline testing: Fetch → Parse → Filter → Dedupe → Notify
- Gegen echte APIs (shooting-store.ch, Email SMTP, Discord Webhook)
- Realistisch aber langsamer (~1-10 Sekunden pro test)
- Example: `Pipeline runs → state.json updated → notifications sent`

### Test Data & Fixtures

**Location:** tests/fixtures/

**HTML Fixtures:**
- `shooting-store-sample.html` - Echte HTML von shooting-store.ch category page
- `course-detail-page.html` - Echte Detail-Seite (Verfügbarkeit)
- Regelmäßig aktualisiert (website layout changes)

**JSON Fixtures:**
- `config.example.json` - Gültige Config für Tests
- `state.example.json` - Gültige State file (already notified courses)
- `test-courses.json` - Mock course objects (id, name, date, availability)

### Mock Strategy: Integration-focused

**NO Unit Mocking:**
- Tests gehen gegen echte shooting-store.ch
- Realistisch: capturen echte HTML
- Fragil: Layout changes können tests brechen → Aber akzeptiert
- Vorteil: Keine sync-Problem zwischen code + mocks

### Test Execution

**Run All Tests:**
```powershell
Invoke-Pester tests/ -CodeCoverage src/ -PassThru
```

**Run Specific Suite:**
```powershell
Invoke-Pester tests/unit/monitors/ -Verbose
Invoke-Pester tests/integration/ -PassThru
```

**Pre-commit Hook:**
- Runs: `Invoke-Pester tests/unit/ -CodeCoverage src/` 
- Blocks commit if coverage < 90% or tests fail

**Consequences:**

Positive:
- (+) **High Confidence:** 90% coverage catches most bugs
- (+) **Regression Prevention:** Changes validated against test suite
- (+) **Realistic:** Integration tests against real APIs (not mocks)
- (+) **Maintainable:** Tests follow standard Pester patterns
- (+) **Refactoring Safe:** Can refactor confidently with high coverage

Negative:
- (-) **High Effort:** 90% coverage requires significant test writing
- (-) **Fragility:** Integration tests break if website layout changes
- (-) **Slow:** Integration tests take longer (10-30 seconds per suite)
- (-) **Real API Dependency:** Tests fail if shooting-store.ch is down

**See Also:**
- ADR-001: PSScriptAnalyzer + Pester in dependencies
- ADR-006: Error handling patterns (what tests validate)
- STRUCTURE.md: Test execution in CI/CD

---

## ADR-009: GUI & User Interface (Phase 2, Optional)

**Status:** [ACCEPTED] ✅

**Context:**
v1.0 is CLI/JSON-based. Advanced users comfortable with JSON editing. But Phase 2 should have GUI for non-technical users to configure monitoring without JSON editing.

**Decision:**

### Technology: WPF Desktop Application (Windows-native)

**Why WPF:**
- PowerShell can load XAML directly (no Electron, no web framework needed)
- Native Windows look & feel
- Direct access to Windows APIs
- Runs on Windows 10+ without additional runtime

### GUI Scope: MVP (Phase 2)

**Main Window - 4 Tabs:**

1. **Monitors Tab**
   - List of configured monitors (shooting-store.ch, etc.)
   - Add/Edit/Delete buttons
   - Enable/Disable toggles
   - Test Connection button (validates website reachability)

2. **Filters Tab**
   - Configure course types (Basic, Advanced, Tryout, etc.)
   - Add/Remove type patterns
   - Exclusion patterns (e.g., "Privatunterricht")
   - Preview: Show which courses would be filtered

3. **Notifications Tab**
   - Email settings (SMTP host, port, auth, recipients)
   - Discord webhook URL
   - Windows Toast toggle
   - Test Notification buttons (send test to each channel)

4. **Scheduler Tab**
   - Start/Stop monitoring
   - View status: "Running" / "Stopped" / "Error"
   - View logs (real-time tail of latest log file)
   - Poll interval slider (15-120 minutes)

### GUI Capabilities

**Configuration Management:**
- Load config.json on startup
- Real-time form validation
- Save changes back to config.json
- Backup config before changes

**Testing:**
- Monitor Test: Fetch courses from website (preview only)
- Email Test: Send test message to configured address
- Discord Test: Post test embed to webhook
- Filter Test: Show which courses match configured types

**Security:**
- SMTP passwords stored encrypted (DPAPI)
- Discord webhook URLs not displayed in plain text
- No credentials in logs or exports

### Architecture

**Files (when implemented):**
```
src/gui/
├── ConfigApp.ps1              # Main entry point
├── MainWindow.xaml            # WPF UI definition (XAML)
├── MainWindow.ps1             # Code-behind + event handlers
├── Views/
│   ├── MonitorsTab.xaml
│   ├── FiltersTab.xaml
│   ├── NotificationsTab.xaml
│   └── SchedulerTab.xaml
└── Services/
    ├── ConfigService.ps1      # Load/save config
    ├── ValidationService.ps1  # Real-time validation
    └── SchedulerService.ps1   # Start/stop monitoring
```

### Phase 2 Limitations

- **No:** Remote management (yet)
- **No:** Multi-user support
- **No:** Advanced scheduling (cron-like syntax)
- **No:** Monitor history charts
- Those can be Phase 3+

**Timeline:**
- v1.0 (Current): CLI + JSON only
- v1.1: Modular refactor (no GUI)
- v2.0 (Phase 2): Add WPF GUI alongside existing CLI

**Consequences:**

Positive:
- (+) **User-friendly:** Non-technical users can configure without JSON
- (+) **Validation:** Form validation prevents misconfigurations
- (+) **Testing:** Built-in test buttons for all features
- (+) **Native:** WPF feels native on Windows
- (+) **Independent:** Can run alongside CLI Watcher

Negative:
- (-) **XAML Learning Curve:** WPF/XAML requires study
- (-) **Time Investment:** GUI adds 30-50 hours development
- (-) **Maintenance:** Keep GUI in sync with config changes

**See Also:**
- ADR-001: PowerShell + Windows-native choice (supports WPF)
- ADR-002: Config structure (GUI loads/saves same config)

---

## FINAL ADR Status Summary

| # | Title | Status | Scope |
|---|-------|--------|-------|
| 001 | Technology Stack | [ACCEPTED] ✅ | PowerShell 5.1 + Modular |
| 002 | Module Architecture | [ACCEPTED] ✅ | By-feature, no circular deps, explicit exports |
| 003 | Monitoring Architecture | [ACCEPTED] ✅ | Pipeline + Retry + Parallel + Dedup |
| 004 | Code Style & Linting | [ACCEPTED] ✅ | Strict PSScriptAnalyzer, 4-space indents |
| 005 | Naming Conventions | [ACCEPTED] ✅ | Verb-Noun, camelCase, Boolean prefix |
| 006 | Error Handling | [ACCEPTED] ✅ | Defensive try-catch, graceful degradation |
| 007 | Logging & Observability | [ACCEPTED] ✅ | JSON + File + Event Log + Masking |
| 008 | Testing Framework | [ACCEPTED] ✅ | Pester 5.0+, 90% coverage, integration tests |
| 009 | GUI (Phase 2) | [ACCEPTED] ✅ | WPF Desktop, Monitors/Filters/Notifiers/Scheduler |

### All Critical Architectural Decisions MADE ✅

- **Technology:** PowerShell 5.1 (Windows-native, modular)
- **Architecture:** Modular by feature (src/monitors, src/filters, src/notifiers)
- **Monitoring:** Fetch→Parse→Filter→Dedupe→Notify with 3x retry + parallel execution
- **Resilience:** Graceful degradation, fault isolation, auto-recovery
- **Quality:** Pester 90% coverage, PSScriptAnalyzer strict, pre-commit hooks
- **Logging:** Structured JSON + file rotation + sensitive data masking
- **Testing:** Integration tests against real APIs, fixtures in tests/fixtures/
- **Code Standards:** 4-space indents, K&R bracing, Verb-Noun functions, Boolean prefix
- **Configuration:** Hybrid (central + module-specific), no code changes for new sites
- **GUI:** Phase 2 WPF desktop app (optional, v2.0)

### Ready for Implementation ✅

**Phase 1 (v0.0.2 - CURRENT):**
- ✅ CourseMonitor.ps1: Monolithic HTML scraper
- ✅ BasicCourseWatcher.ps1: Orchestration wrapper
- ✅ Proven working: 8 courses detected, deduplication works
- **Status:** MVP - Core monitoring functional

**Phase 2 (v0.1.0 - NEXT):**
- Refactor to modular structure (src/core, src/monitors, etc.)
- Implement Config/State/Logging utilities
- Add Filter + Notifier system (Email, Discord, Toast)
- Multi-website support via config.json
- Windows Scheduled Task integration
- Timeline: 2-3 weeks

**Phase 3 (v1.0.0 - FUTURE):**
- Feature-complete stable release
- WPF GUI for configuration
- Full documentation + troubleshooting guides
- Production-ready deployment
- Timeline: 4-6 weeks after v0.1.0
