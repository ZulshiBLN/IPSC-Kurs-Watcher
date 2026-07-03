# IPSC Kurs Watcher – Architectural Decision Records (ADRs)

Zentrale Dokumentation für Architektur-Entscheidungen, die IPSC Kurs Watcher massgeblich beeinflussen.

**Status:** [PENDING - Projektstart]  
**Konkrete Implementierungs-Regeln:** Siehe [STRUCTURE.md](STRUCTURE.md)

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

**Implementation Notes:**
- Link to STRUCTURE.md rules
- Code examples
- Links to related ADRs
```

---

## ADR-001: Technology Stack Selection

**Status:** [ACCEPTED]

**Context:**
IPSC Kurs Watcher ist Windows-only (Deployment via Scheduled Task). Anforderungen: Höchste Performance + Resilience, einfache Deployment, Solo-Entwicklung, Integration mit Windows-Ecosystem.

**Decision:**
### **PowerShell 5.1+ (Windows PowerShell)**

Gründe:
- **Windows-native:** Direct access to WinAPI, Scheduled Task trivial, Windows Toast Notifications native
- **Performance:** Compiled cmdlets, fast startup, minimal overhead
- **Deployment:** Kein Runtime nötig, läuft auf jedem Windows ≥ Server 2016
- **Solo Developer:** Deine PowerShell-Expertise (WinHarden, SharedMailboxProvisioner)
- **HTML Scraping:** PowerShell + HtmlAgilityPack oder Regex völlig ausreichend
- **Scheduled Task Integration:** Nativer Einsatzpunkt für PowerShell Scripts

**Architecture:**
- PowerShell 5.1 (Windows Standard)
- Modules: Custom PS-Modules in src/ (monitors, notifiers, filters)
- Dependencies: HtmlAgilityPack (NuGet), optional Pester für Tests
- State: JSON (ConvertTo-Json / ConvertFrom-Json)
- Config: JSON (ConvertFrom-Json)
- Logging: Custom Write-Log function (strukturiert)
- Build: build.ps1 (PSScriptAnalyzer validation)
- Tests: Pester 5.0+

**Consequences:**
- (+) **Windows-native:** Kein Cross-platform overhead
- (+) **Highest Performance:** Direct WinAPI, fast startup
- (+) **Minimal Dependencies:** PowerShell 5.1 vorinstalliert auf Windows Server 2016+
- (+) **Expert Knowledge:** Du kennst PowerShell sehr gut
- (+) **Deployment:** Script + Scheduled Task = trivial
- (+) **Resilient:** Fehlerbehandlung + Logging built-in
- (-) **Windows-only:** Kein Linux/macOS (aber nicht erforderlich)
- (-) **No Native Web Framework:** HTML Scraping manuell via Regex oder HtmlAgilityPack

**Alternatives:**
- Python 3.10+ (cross-platform, aber overkill & neuer Runtime nötig)
- TypeScript/Node.js (cross-platform, aber heavier, nicht Windows-optimiert)
- Go (sehr schnell, aber neue Sprache für dich)
- C# / .NET (auch gut, aber PowerShell nativer für dich)

**Implementation Notes:**
- Siehe STRUCTURE.md Section 6: PowerShell 5.1+ Anforderungen, Module-System
- Siehe ADR-002: Modul-Struktur (src/monitors/*.ps1, src/notifiers/*.ps1, etc.)
- Build: `.\build.ps1 -Validate` (PSScriptAnalyzer)
- Tests: `Invoke-Pester tests/` (Pester 5.0+)
- Deployment: Scheduled Task mit PowerShell Script-Block

---

## ADR-002: Monitoring Architecture

**Status:** [ACCEPTED]

**Context:**
IPSC Kurs Watcher muss shooting-store.ch/de/kategorie/kurse1 monitoren. Anforderungen:
- Neue Kurse + Verfügbarkeitänderungen (Plätze frei/belegt)
- Filter nach Kurs-Typ (Tryout, Basic, Basic 2.0, etc.)
- Benachrichtigungen: Email, Webhook, Windows Toast
- Config-File basierte Konfiguration
- State-Persistierung: JSON-File
- Poll-Frequenz: Konfigurierbar via Windows Scheduled Task
- Deployment: Windows-only, Scheduled Task
- Performance & Resilience: Höchste Priorität

**Decision:**

### Modulare Event-Driven Architektur (PowerShell)

Datenfluss:
```
Monitor (HTML Scraper)
    ↓
Filter (by Course Type)
    ↓
Deduplicator (Check State)
    ↓
Notifiers (Email, Webhook, Toast) → State Update
```

### Module Structure

| Modul | Zweck | PowerShell Pattern |
|-------|-------|-------------------|
| **src/core/Scheduler.ps1** | Orchestrierung, Poll-Loop | Main loop, interval control |
| **src/core/State.ps1** | State-Persistierung (JSON) | Read/Write JSON state file |
| **src/monitors/MonitorShootingStore.ps1** | shooting-store.ch scrapen | Invoke-WebRequest, HTML parsing |
| **src/filters/FilterByType.ps1** | Nach Kurs-Typ filtern | Array filter mit Kurs-Typen |
| **src/notifiers/NotifyEmail.ps1** | Email versenden | Send-MailMessage (SMTP) |
| **src/notifiers/NotifyWebhook.ps1** | Webhook (Discord, Slack) | Invoke-WebRequest (JSON) |
| **src/notifiers/NotifyToast.ps1** | Windows Toast Notification | .NET WinRT API |
| **src/utils/Logging.ps1** | Strukturierte Logs | Write-Output, JSON logs |
| **src/utils/Config.ps1** | Config laden (JSON) | ConvertFrom-Json |

### config.json Template

```json
{
  "monitors": [
    {
      "name": "shooting-store",
      "url": "https://www.shooting-store.ch/de/kategorie/kurse1",
      "poll_interval_minutes": 15,
      "enabled": true,
      "request_timeout_seconds": 30,
      "retry_attempts": 3
    }
  ],
  "filters": {
    "course_types": ["Tryout", "Basic", "Basic 2.0"],
    "min_availability": 1
  },
  "notifiers": {
    "email": {
      "enabled": true,
      "recipients": ["user@example.com"],
      "smtp_host": "smtp.gmail.com",
      "smtp_port": 587,
      "use_tls": true,
      "from_address": "watcher@example.com"
    },
    "webhook": {
      "enabled": true,
      "url": "https://hooks.slack.com/services/YOUR/WEBHOOK",
      "timeout_seconds": 10
    },
    "toast": {
      "enabled": true,
      "app_id": "IPSC-Kurs-Watcher"
    }
  },
  "state": {
    "file_path": "data/state.json",
    "retention_days": 30,
    "backup_count": 3
  },
  "logging": {
    "log_dir": "logs",
    "max_log_size_mb": 10,
    "retention_days": 30,
    "log_level": "INFO"
  }
}
```

### state.json Structure

```json
{
  "last_notified": [
    {
      "course_id": "shooting-store-123",
      "course_name": "Basic Pistol",
      "course_type": "Basic",
      "notified_at": "2026-07-03T14:30:00Z",
      "notification_channels": ["email", "webhook"],
      "hash": "abc123def456"
    }
  ],
  "last_poll": "2026-07-03T14:30:00Z",
  "last_error": null,
  "version": 1
}
```

### Deployment: Windows Scheduled Task

```powershell
# Register scheduled task
$TaskName = "IPSC-Kurs-Watcher"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\Scripts\IPSC-Kurs-Watcher\Watcher.ps1`""
$Trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 15) -Once -At (Get-Date)
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -RunLevel Highest
```

**Consequences:**
- (+) **High Performance:** PowerShell native, minimal overhead, direct WinAPI zugriff
- (+) **Resilient:** Retry-Logic mit exponential backoff, graceful error handling
- (+) **Modular:** Monitors, Filters, Notifiers unabhängig testbar + erweiterbar
- (+) **Simple State:** JSON-File, keine DB nötig
- (+) **Windows-native:** Scheduled Task Integration trivial
- (+) **Fault Isolation:** 1 Notifier-Fehler blockiert nicht andere
- (-) **HTML Scraping Fragility:** shooting-store Layout-Änderungen können Parser brechen
- (-) **Polling Strategy:** Nicht ideal für sehr häufige Checks (aber 15 Min Intervall realistisch)
- (-) **PowerShell Performance:** Nicht optimal für massive Datamenge (aber für dieses Use-Case ok)

**Alternatives:**
- Webhook-based (shooting-store müsste API expose – nicht realistisch)
- Full microservices (Overkill)
- Monolithic Script (weniger wartbar, weniger erweiterbar)

**Implementation Notes:**
- Siehe STRUCTURE.md Section 1: PowerShell Folder-Layout
- HTML Parsing: BeautifulSoup-äquivalent via PowerShell (HtmlAgilityPack oder Regex)
- Error Handling: ADR-004 (Retry-Logic, Logging)
- State Management: Atomic JSON writes (temp file → move)
- Logging: ADR-005 (strukturierte Logs, Rotation)
- Configuration: Externe config.json (kein hardcoding)

---

## ADR-003: Testing Framework & Standards

**Status:** [PENDING]

**Context:**
IPSC Kurs Watcher sollte zuverlässig monitoren. Testing ist critical für Qualität. Brauchen standardisierte Test-Patterns.

**Decision:**
[TBD – Abhängig von Tech-Stack]

Standard-Anforderungen:
- **Minimum Coverage:** 70% Code Coverage
- **Test Organization:** Unit-Tests neben Code, Integration-Tests in separate Suite
- **Mocking:** Mock externe APIs (IPSC-Website, Notification-Services)
- **Test Data:** Fixtures in `tests/fixtures/`

**Consequences:**
- (+) High coverage findet meiste Bugs
- (+) Klare Testing-Patterns
- (+) Confidence in Refactoring
- (-) Braucht Zeit zum Schreiben
- (-) Maintenance Burden für Test-Data

**Alternatives:**
- No testing (unacceptable)
- Only integration tests (zu slow)
- Lower coverage limits (mehr Bugs slip through)

**Implementation Notes:**
- Siehe STRUCTURE.md Section 4 für detaillierte Testing-Regeln
- Pre-commit Hook prüft Coverage vor Commit

---

## ADR-004: Error Handling & Recovery

**Status:** [PENDING]

**Context:**
Monitoring läuft 24/7. Fehler müssen robust gehandhabt werden (z.B. Website down, API timeout, Notifikation-Fehler).

**Decision:**
[TBD – Empfohlene Strategie]

- **Failure Isolation:** Monitor-Fehler sollten andere Monitors nicht beeinflussen
- **Retry Logic:** Exponential backoff für transient errors
- **Fallback:** Graceful degradation wenn einzelne Services unavailable
- **Logging:** Alle Fehler mit Kontext loggen
- **Alerting:** Kritische Fehler sollten manuell alerten

**Consequences:**
- (+) Robust gegen vorübergehende Ausfälle
- (+) Gute Observability
- (+) Einfacher zu debuggen
- (-) Komplexere Error-Handling-Logic
- (-) Need für Retry-Strategie

**Alternatives:**
- Fail-fast (simpel, aber weniger robust)
- Centralized error handler (schwer zu testen)

**Implementation Notes:**
- Siehe STRUCTURE.md Section 8 für Error-Handling-Patterns
- Logging Strategy siehe ADR-005

---

## ADR-005: Logging & Observability

**Status:** [PENDING]

**Context:**
Monitoring sollte Observable sein. Need für strukturierte Logs zum Troubleshooting und Compliance.

**Decision:**
[TBD – Strukturierte Logging empfohlen]

- **Format:** Structured Logging (JSON empfohlen)
- **Destination:** File + Console (optional: External Service)
- **Retention:** 30 Tage Log Rotation
- **Sensitive Data:** Automatic masking von API Keys, Passwords
- **Levels:** ERROR, WARN, INFO, DEBUG, TRACE

**Consequences:**
- (+) Centralized observability
- (+) Consistent format
- (+) Easy parsing/filtering
- (+) Audit trail
- (-) Storage/Cost concerns
- (-) Privacy concerns bei sensitive data

**Alternatives:**
- No logging (kann't debug)
- Log everything unstructured (hard to parse)
- External service only (expensive)

**Implementation Notes:**
- Siehe STRUCTURE.md Section 9 für Log-Strategie-Details
- Sensitive data masking automatisch implementieren

---

## ADR-006: Code Style & Linting Standards

**Status:** [PENDING]

**Context:**
Konsistent formatierter Code verbessert Lesbarkeit und Maintainability.

**Decision:**
[TBD – Abhängig von Tech-Stack]

Standard-Anforderungen:
- **Linting Tool:** [ESLint, Pylint, Clippy, etc.]
- **Indentation:** [4 spaces, 2 spaces, etc. – Tech-Stack Standard]
- **Naming:** camelCase, snake_case, PascalCase (per type)
- **Line Length:** 100 soft limit, 120 hard limit
- **Enforcement:** Pre-commit hook blockiert non-compliant code

**Consequences:**
- (+) Konsistent formatierter Code
- (+) Automatische Quality Checks
- (-) Kann sich constrained anfühlen
- (-) Tool setup/configuration nötig

**Alternatives:**
- Manual code reviews (time-consuming, inconsistent)
- No standards (code zoo)

**Implementation Notes:**
- Siehe STRUCTURE.md Section 7 für detaillierte Code-Style-Regeln
- Pre-commit Hook automatisch erzeugt beim Setup

---

## ADR-007: Naming Conventions

**Status:** [PENDING]

**Context:**
Clear, consistent naming ist critical für Readability und Understanding.

**Decision:**
[TBD – Standard-Konventionen]

- **Functions:** Verb + Noun (get_courses, parse_schedule, notify_users)
- **Variables:** Deskriptiv (course_list, is_available, has_notification)
- **Constants:** UPPER_SNAKE_CASE (MAX_RETRIES, DEFAULT_TIMEOUT)
- **Classes:** PascalCase (CourseMonitor, NotificationService)
- **Booleans:** is_*, has_*, can_*, should_* (is_available, has_notification)

**Consequences:**
- (+) Immediately clear what is what
- (+) Standard across codebase
- (-) More rules to remember
- (-) Refactoring wenn inconsistent

**Alternatives:**
- No conventions (chaos)
- Language defaults only (less clarity)

**Implementation Notes:**
- Siehe STRUCTURE.md Section 7.5 für detaillierte Naming-Regeln
- Linting Tool prüft Naming-Konventionen

---

## ADR-008: Module & Dependency Structure

**Status:** [PENDING]

**Context:**
IPSC Kurs Watcher sollte modular organisiert sein. Clear dependency hierarchy macht Codebase wartbar.

**Decision:**
[TBD – Lineare Dependency-Chain]

Hierarchy:
```
Core
  ├── Monitors (depend on Core)
  ├── Filters (depend on Core)
  └── Notifiers (depend on Core)
```

- No circular dependencies
- Alle external dependencies dokumentieren
- Optional dependencies graceful degradation

**Consequences:**
- (+) Clear architecture
- (+) No circular dependencies
- (+) Easy to understand
- (-) Requires discipline
- (-) Documentation maintenance

**Alternatives:**
- Monolithic (hard to maintain)
- Loose organization (chaos)

**Implementation Notes:**
- Siehe STRUCTURE.md Section 10 für Dependency-Management-Details
- Document dependency graph in README.md

---

## ADR-009: Git Workflow & Release Strategy

**Status:** [PENDING]

**Context:**
Clear Git workflow ensures coordinated development und saubere releases.

**Decision:**
[TBD – Three-Tier Release Model empfohlen]

- **Branching:** main ← prerelease ← develop
- **Versioning:** Semantic Versioning (v0.1.0)
- **Commits:** Conventional Commits (feat: , fix: , docs: , etc.)
- **Tags:** Annotated tags für Releases
- **Release Policy:** Nur stabile Releases publiclizen (z.B. zu PyPI, GitHub Releases)

**Consequences:**
- (+) Clear, coordinated development
- (+) Clean git history
- (+) Easy to track changes
- (-) Requires discipline
- (-) Merge conflicts möglich

**Alternatives:**
- No workflow (chaos)
- Strict workflow (can be slow)

**Implementation Notes:**
- Siehe CLAUDE.md Section "Git-Workflow" für detaillierte Strategie
- Siehe STRUCTURE.md Section 11 für Git-Konventionen

---

## ADR-010: Configuration & Extensibility

**Status:** [PENDING]

**Context:**
IPSC Kurs Watcher sollte konfigurierbar sein für verschiedene Use-Cases (verschiedene Kurse, verschiedene Notifier, verschiedene Schedule).

**Decision:**
[TBD – Config-File basiert empfohlen]

- **Config Format:** YAML oder JSON (user-friendly vs. machine-readable)
- **Monitors:** Definierbar in Config
- **Notifiers:** Pluggable, konfigurierbar
- **Filters:** Customizable Rules für Benachrichtigungen

**Consequences:**
- (+) Einfach neue Use-Cases hinzufügen
- (+) No code changes für neue Monitors/Notifiers
- (+) User-friendly
- (-) Config-Validation nötig
- (-) Mehr Code/Komplexität

**Alternatives:**
- Hardcoded config (einfach, aber inflexibel)
- Fully programmatic (hard für non-developers)

**Implementation Notes:**
- Config Schema validieren beim Start
- Gute Fehler-Messages wenn Config invalid
- Config-Beispiele in `examples/` Verzeichnis

---

## Status Summary

| ADR | Title | Status |
|-----|-------|--------|
| 001 | Technology Stack | [PENDING] |
| 002 | Monitoring Architecture | [PENDING] |
| 003 | Testing Framework | [PENDING] |
| 004 | Error Handling | [PENDING] |
| 005 | Logging Strategy | [PENDING] |
| 006 | Code Style | [PENDING] |
| 007 | Naming Conventions | [PENDING] |
| 008 | Module Structure | [PENDING] |
| 009 | Git Workflow | [PENDING] |
| 010 | Configuration | [PENDING] |

---

## ADR References & Update Policy

- **Format Inspiration:** [adr.github.io](https://adr.github.io/)
- **Best Practices:** Keep ADRs short, focused, decision-oriented
- **Update Policy:** Mark superseded ADRs as [SUPERSEDED], don't delete
- **Version Control:** ADRs live in git alongside code
- **Referencing:** Im Code: `// See ADR-002 for architecture`, in PRs/Discussions

