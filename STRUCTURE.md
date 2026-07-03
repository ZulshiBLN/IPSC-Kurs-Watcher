# IPSC Kurs Watcher – STRUCTURE.md

Projekt-spezifische Struktur- und Organisationsregeln für IPSC Kurs Watcher.

---

## 1. VERZEICHNIS-STRUKTUR

**PowerShell Projekt-Struktur (Modulare & Erweiterbar):**

```
IPSC-Kurs-Watcher/
├── src/
│   ├── core/
│   │   ├── Scheduler.ps1         # Main orchestration loop
│   │   ├── Config.ps1            # Load & validate config.json
│   │   ├── State.ps1             # State management (JSON persistence)
│   │   └── ConfigValidator.ps1   # JSON schema validation
│   ├── gui/
│   │   ├── ConfigApp.ps1         # Main GUI entry point (WPF host)
│   │   ├── MainWindow.xaml       # WPF UI definition (XAML)
│   │   ├── MainWindow.ps1        # WPF code-behind logic
│   │   ├── Views/
│   │   │   ├── MonitorsTab.xaml          # Add/Edit/Delete Monitors
│   │   │   ├── FiltersTab.xaml           # Configure Course Types
│   │   │   ├── NotificationsTab.xaml     # Email, Discord, Toast settings
│   │   │   ├── SchedulerTab.xaml         # Start/Stop, View Logs
│   │   │   └── DataTab.xaml              # Export/Import/Backup
│   │   ├── ViewModels/
│   │   │   ├── MonitorsViewModel.ps1
│   │   │   ├── FiltersViewModel.ps1
│   │   │   ├── NotificationsViewModel.ps1
│   │   │   └── SchedulerViewModel.ps1
│   │   └── Services/
│   │       ├── ConfigService.ps1         # Load/Save config via GUI
│   │       ├── ValidatorService.ps1      # Real-time validation
│   │       └── TestService.ps1           # Test Scraping + Notifications
│   ├── monitors/
│   │   ├── MonitorBase.ps1       # Abstract base class (common logic)
│   │   ├── MonitorFactory.ps1    # Factory: route provider → Monitor
│   │   ├── MonitorShootingStore.ps1  # shooting-store.ch (CSS-Selector based)
│   │   └── MonitorGenericHtml.ps1    # Generic HTML template (neue Websites)
│   ├── filters/
│   │   ├── FilterByType.ps1      # Pattern-based course type filtering
│   │   └── FilterByExclusion.ps1 # Exclusion pattern filtering
│   ├── notifiers/
│   │   ├── NotifyEmail.ps1       # SMTP email notification
│   │   ├── NotifyDiscord.ps1     # Discord webhook notification
│   │   └── NotifyToast.ps1       # Windows Toast notification
│   └── utils/
│       ├── Logging.ps1           # Structured logging (JSON)
│       ├── Crypto.ps1            # Secret encryption (DPAPI)
│       ├── Secrets.ps1           # Secure password storage/retrieval
│       └── Helpers.ps1           # Common utilities
├── config/
│   ├── config.json               # Main configuration (user edits this)
│   ├── config.schema.json        # JSON schema for validation
│   └── config.example.json       # Template with all options
├── data/
│   ├── state.json                # Current state (courses notified)
│   └── logs/                     # Application logs (rotated)
├── tests/
│   ├── fixtures/                 # Mock data (HTML, config examples)
│   ├── unit/                     # Unit tests (Pester)
│   └── integration/              # Integration tests
├── examples/
│   ├── config-single-site.json   # Example: single monitor
│   ├── config-multi-site.json    # Example: multiple monitors
│   └── add-new-website.md        # How to add new provider/monitor
├── docs/
│   ├── architecture.md           # Architecture overview
│   ├── configuration-guide.md    # How to configure
│   └── extending.md              # How to extend (new monitors, etc.)
├── .github/
│   └── workflows/                # CI/CD (GitHub Actions)
├── build/
│   └── artifacts/                # Build output
├── Watcher.ps1                   # Main entry point (calls Scheduler)
├── build.ps1                     # Build/validate script (PSScriptAnalyzer)
├── CLAUDE.md                     # Collaboration rules
├── DECISIONS.md                  # Architecture decisions (ADRs)
├── STRUCTURE.md                  # This file (implementation rules)
├── README.md                     # Project overview
└── CHANGELOG.md                  # Version history
```

**Key Design Principles:**
- **Config-First:** Alles über `config.json` konfigurierbar (keine Hardcodes)
- **Provider-Pattern:** Neue Websites einfach als neuer Monitor hinzufügbar
- **Extensible:** Neue Notifier, Filter, oder Monitors ohne Code-Änderungen möglich
- **Stateless Execution:** Ein Run = unabhängig, State nur zur Deduplication

---

## 2. DESIGN-PRINZIPIEN

**Kernprinzipien für IPSC Kurs Watcher:**

- **Modularität** – Unabhängige Monitor-, Notifier-, Filter-Module
- **Single Responsibility Principle** – Jedes Modul hat eine klare Aufgabe
- **Composition over Inheritance** – Module zusammensetzen statt Vererbung
- **Fail-Fast Pattern** – Bei Fehlern schnell fehlagen, nicht silent swallowing
- **Configuration over Code** – Behavior durch Config definieren, nicht hard-coded
- **Extensibility** – Neue Monitor/Notifier/Filter leicht hinzufügbar
- **Config-First Architecture** – Alles über `config.json` konfigurierbar
- **Provider Pattern** – Neue Websites/Services als Plugins (Provider) ohne Core-Änderungen
- **No Hardcodes** – Websites, Kurs-Typen, Selektoren, Patterns = alles in config.json

---

### 2.1 - Neue Website Hinzufügen (Extensibility)

**Schritte:**

1. **config.json erweitern:**
```json
"monitors": [
  {
    "id": "my-website",
    "name": "My Shooting Website",
    "provider": "generic-html",
    "url": "https://my-website.com/kurse",
    "poll_interval_minutes": 20,
    "enabled": true,
    "parser_config": {
      "selector_course": "div.course",
      "selector_title": "h2.course-name",
      "selector_type": "span.level",
      "selector_availability": "span.spots"
    }
  }
]
```

2. **Kurs-Typen erweitern:**
```json
"filters": {
  "course_types": [
    {
      "id": "intermediate",
      "name": "Intermediate",
      "patterns": ["Intermediate", "Level 2-3", "Mittelstufe"],
      "enabled": true
    }
  ]
}
```

3. **Optional: Neuer Monitor-Provider (nur wenn generic-html nicht ausreicht):**
```powershell
# src/monitors/MonitorMyProvider.ps1
function Invoke-MonitorMyProvider {
  param([hashtable]$Config)
  # Custom logic für diese Website
  # Return: Array von [PSCustomObject]@{ Title, Type, Availability, ... }
}
```
Dann in `MonitorFactory.ps1` registrieren.

---

### 2.2 - Neue Kurs-Typen Hinzufügen

**Nur config.json ändern:**
```json
"filters": {
  "course_types": [
    {
      "id": "tactical",
      "name": "Tactical",
      "patterns": ["Tactical", "Einsatz-Training"],
      "enabled": true
    }
  ]
}
```

---

### 2.3 - Neue Notifier Hinzufügen

**Beispiel: Telegram Notification:**

1. **src/notifiers/NotifyTelegram.ps1** erstellen:
```powershell
function Send-TelegramNotification {
  param([array]$Courses, [hashtable]$Config)
  # Invoke-WebRequest zu Telegram Bot API
}
```

2. **config.json erweitern:**
```json
"notifiers": {
  "telegram": {
    "enabled": true,
    "bot_token": "YOUR_BOT_TOKEN",
    "chat_id": "YOUR_CHAT_ID"
  }
}
```

---

## 3. FUNKTIONS-ANFORDERUNGEN

### 3.1 - Dokumentation

**PUBLIC Funktionen/Exports:**
- Vollständige Dokumentation erforderlich
- Syntax: JSDoc, Docstring, Comment-based Help (je nach Sprache)
- Muss enthalten: 
  - Summary (1-2 Zeilen)
  - Parameters (Name, Type, Description, Default)
  - Return Type & Description
  - Example Usage
  - Possible Exceptions/Errors

**PRIVATE Funktionen:**
- Minimal-Dokumentation (Summary + Parameter)
- Oder: Aussagekräftige Inline-Kommentare

### 3.2 - Error Handling

- Externe Eingaben validieren (APIs, Config, User Input)
- Interne Guarantees vertrauen
- Fehler mit Kontext loggen
- Niemals Secrets/Credentials in Error-Messages

### 3.3 - Performance

- Monitoring sollte nicht blockierend sein
- Asynchrone Patterns wo möglich
- Graceful Degradation bei API-Timeouts
- Caching von häufig abgerufenen Daten

---

## 4. TESTING

### 4.1 - Test Organization

- Test-Datei neben Source-Code: `src/monitors.test.js` oder `tests/unit/monitors.py`
- Test-Namen: Aussagekräftig und deskriptiv
- Struktur: `describe() → context() → it()` Pattern

### 4.2 - Testing Framework

- **Framework:** [TBD – abhängig von Tech-Stack]
  - Python: pytest
  - TypeScript/JavaScript: Jest, Vitest
  - Rust: cargo test
  - Go: go test
- **Version:** [Minimum version TBD]

### 4.3 - Code Coverage

- **Minimum:** 70% Code Coverage
- **Exceptions:** Mit explizitem Kommentar dokumentieren
- **Validation:** Build-Command prüft Coverage vor Merge

### 4.4 - Mocking

- Mock externe APIs (IPSC-Websites, Benachrichtigungs-Dienste)
- Mock Filesysteme/Databases für Unit-Tests
- Nutze built-in Mocking-Framework der Sprache

### 4.5 - Test Structure

- `describe()` oder equivalent: Gruppiere verwandte Tests
- `beforeEach/afterEach` für Setup/Cleanup
- Klare Test-Namen die beschreiben was getestet wird

### 4.6 - Integration Tests

- Test gegen echte APIs in separater Test-Suite
- Use Test-Credentials/Sandbox-Umgebungen
- Dokumentiere externe Dependencies

---

## 5. DOKUMENTATION

- **README.md** – Projekt-Übersicht, Installation, Quick-Start
- **CONTRIBUTING.md** – Wie man beiträgt
- **API.md** – API-Dokumentation (wenn applicable)
- **docs/** – Detaillierte Dokumentation
  - Architektur-Übersicht
  - Monitor/Notifier-Beispiele
  - Troubleshooting

---

## 6. TECH-STACK & VERSION

**[TBD - Abhängig von Entscheidung]**

Beispiele:
- **Python 3.10+**
- **TypeScript 5.0+**
- **Rust 1.70+**
- **Go 1.21+**

Zu dokumentieren:
- Minimum Version
- Dual-Version Support?
- Modern Features erlaubt?
- Breaking Changes allowed?

---

## 7. CODE STYLE & LINTING

### 7.1 - Linting Tool

- **Tool:** [TBD – abhängig von Sprache]
  - JavaScript/TypeScript: ESLint
  - Python: Pylint, flake8
  - Rust: Clippy
  - Go: golangci-lint
- **Config:** `.eslintrc`, `pyproject.toml`, `.cargo/`, etc.
- **Enforcement:** Pre-commit hook prüft Code Style

### 7.2 - Indentation

- **Spaces vs Tabs:** Spaces (robuster)
- **Width:** 
  - Python: 4 spaces
  - JavaScript/TypeScript: 2 spaces
  - [Adjust per language standard]
- **Consistency:** Alle Zeilen im Block gleich eingerückt

### 7.3 - Bracing Style

**K&R Style (empfohlen für C-like languages):**
```
if (condition) {
    doSomething();
}
```

**Python (keine Braces, eingerückt):**
```python
if condition:
    do_something()
```

### 7.4 - Line Length

- **Soft Limit:** 100 Zeichen (empfohlen)
- **Hard Limit:** 120 Zeichen (absolu Maximum)
- **Reasoning:** Lesbarkeit + moderne Bildschirme

### 7.5 - Naming Conventions

#### Function/Method Names
- **Style:** [Sprach-Standard]
  - Python: `snake_case` (get_courses, parse_schedule)
  - JavaScript: `camelCase` (getCourses, parseSchedule)
  - Go: `PascalCase` (GetCourses, ParseSchedule)
- **Verbs:** Start mit Verb (get, parse, filter, notify)
- Beispiel: `get_available_courses()` statt `courses()`

#### Variable Names
- **Style:** [Sprach-Standard]
  - Python: `snake_case` (course_list, is_active)
  - JavaScript: `camelCase` (courseList, isActive)
- **Boolean Prefix:** `is_*`, `has_*`, `can_*`, `should_*`
  - `is_available`, `has_notification`, `can_register`

#### Constants
- **Style:** `UPPER_SNAKE_CASE`
- **Beispiel:** `MAX_RETRIES`, `DEFAULT_TIMEOUT`, `API_BASE_URL`

#### Class/Type Names
- **Style:** `PascalCase`
- **Beispiel:** `CourseMonitor`, `NotificationService`, `ScheduleParser`

### 7.6 - Comments

- **Inline Comments:** Explain WHY, not WHAT
- **No:** `# increment counter` (obvious)
- **Yes:** `# Retry with exponential backoff to handle rate limiting`

### 7.7 - Import/Require Statements

**Order:**
1. Standard Library imports
2. Third-party imports
3. Local/Project imports

**Example (Python):**
```python
import os
import json
from datetime import datetime

import requests
from bs4 import BeautifulSoup

from .monitors import CourseMonitor
from .config import load_config
```

**Example (JavaScript):**
```javascript
import fs from 'fs';
import path from 'path';

import axios from 'axios';
import { parse } from 'cheerio';

import { CourseMonitor } from './monitors.js';
import { loadConfig } from './config.js';
```

---

## 8. ERROR HANDLING

### 8.1 - Exception Types

- Define custom exception types für bekannte Fehler
- Beispiele:
  - `CourseNotFound` – Kurs existiert nicht
  - `NetworkError` – API unreachable
  - `ParseError` – HTML-Parsing fehlgeschlagen
  - `NotificationError` – Benachrichtigung konnte nicht gesendet werden

### 8.2 - Try-Catch Usage

- Nur für externe Ressourcen (APIs, Filesysteme, Datenbanken)
- Nicht für interne Logik-Validierung
- Immer mit spezifischen Exception-Types

### 8.3 - Error Logging

- Alle Fehler mit Kontext loggen
- Include: Timestamp, Level, Stack Trace, relevante Daten
- **NIEMALS** Secrets/Credentials/Passwords loggen

### 8.4 - Exit Codes (für CLI)

- `0` – Success
- `1` – General Error
- `2` – Usage Error (wrong arguments)
- `3+` – Custom Errors (define as needed)

---

## 9. LOGGING STRATEGY

### 9.1 - Log Destination

- **File:** `logs/ipsc-watcher-YYYY-MM-DD.log` (tägliche Rotation)
- **Console:** Für Development/Debugging
- **[Optional: External Service]** – Sentry, DataDog, ELK

### 9.2 - Log Format

- **Structured Logging** (JSON empfohlen):
  ```json
  {"timestamp": "2026-06-29T14:23:45.123Z", "level": "ERROR", "message": "Failed to fetch courses", "context": {"course_id": "123"}}
  ```
- Oder plaintext für einfache Use-Cases

### 9.3 - Log Levels

- **ERROR** – Critical failures (Monitoring sollte alerten)
- **WARN** – Potential issues (z.B. API timeout)
- **INFO** – Standard operations (Course updated, Notification sent)
- **DEBUG** – Detailed debugging (HTTP requests, parsing details)
- **TRACE** – Very verbose (every variable change)

### 9.4 - Sensitive Data Masking

- Automatisch maskieren: Passwords, API Keys, Email, Phone
- Replace mit: `***`
- **Beispiel:** `"api_key": "***"` statt actual key

### 9.5 - Log Retention

- Keep logs für 30 Tage
- Auto-cleanup alte Dateien nach 30 Tagen

### 9.6 - Log Level Control

- Via Environment Variable: `LOG_LEVEL=debug`
- Oder Command-Line Flag: `--log-level debug`
- Default: `INFO`

---

## 10. DEPENDENCY MANAGEMENT

### 10.1 - Dependency Hierarchy

- Core → Monitors → Notifiers
- No circular dependencies
- Dokumentiere Inter-Module Dependencies in code

### 10.2 - External Dependencies

- **Required:** Muss für Core-Funktionalität da sein
- **Optional:** Nice-to-have, graceful degradation wenn missing
- **Development:** Only for testing/building

### 10.3 - Version Management

- Use [Package Manager – TBD]
  - Python: pip + requirements.txt
  - JavaScript: npm + package-lock.json
  - Rust: Cargo + Cargo.lock
  - Go: go.mod + go.sum
- Lock file: Immer einchecken (reproducible builds)
- Update strategy: Manual review, dann commit

---

## 11. GIT & VERSION CONTROL

### 11.1 - Commit Messages

- **Format:** `[Type]: [Short description]` (50 chars max)
- **Types:** Feat, Fix, Docs, Style, Refactor, Test, Chore
- **Example:** 
  - `feat: Add IPSC course monitoring`
  - `fix: Handle course page timeout`
  - `docs: Update API documentation`

### 11.2 - Branch Naming

- **Pattern:** `[type]/[description]` (kebab-case)
- **Examples:** 
  - `feature/course-monitor`
  - `bugfix/api-timeout`
  - `docs/readme-update`

### 11.3 - Pull Request Process

- Branch off `develop` or `prerelease`
- Write meaningful PR description
- Require code review before merge
- Squash commits if wanted

### 11.4 - Tag Format

- **Semantic Versioning:** `v0.1.0`
- **Annotated tags:** `git tag -a v0.1.0 -m "Release message"`
- **Document in:** CHANGELOG.md or Release Notes

---

## 12. BUILD & DEPLOYMENT

### 12.1 - Build Process

- **Command:** [TBD – abhängig von Stack]
  - Python: `python -m build` or `pip install -e .`
  - JavaScript: `npm run build`
  - Rust: `cargo build --release`
  - Go: `go build`
- **Output:** Build-Artefakte in `build/` oder äquivalent
- **Validation:** Linting, Tests, Type-Checking vor Build-Success

### 12.2 - Pre-Commit Checks

- Linting: [Tool TBD]
- Tests: [Test-Runner TBD]
- Type Checking: [if applicable]
- **Hook File:** `.git/hooks/pre-commit` (auto-created)

### 12.3 - CI/CD Pipeline

- **Platform:** [TBD – GitHub Actions, GitLab CI, etc.]
- **Triggers:** On push, on PR, on tag
- **Jobs:** Lint → Test → Build → (Deploy if main/tag)

### 12.4 - Deployment Strategy

- **Dev:** Automatic on `develop` push
- **Staging:** Automatic on `prerelease` merge
- **Production:** Manual trigger or automatic on tag
- **Rollback:** Keep previous version deployed, easy switch-back

---

## 11. GUI ARCHITECTURE & USER INTERFACE

### 11.1 - WPF Application Structure

**Technology:** PowerShell WPF (XAML + PowerShell Code-Behind)

**Main Components:**

1. **ConfigApp.ps1 (Entry Point)**
   - Initializes WPF host
   - Loads XAML
   - Wires up ViewModels to Views
   - Handles app lifecycle

2. **MainWindow.xaml (Main UI Container)**
   - Tabbed Interface:
     - Tab 1: Monitors (Add/Edit/Delete/Test)
     - Tab 2: Filters (Course Types, Patterns)
     - Tab 3: Notifications (Email, Discord, Toast settings)
     - Tab 4: Scheduler (Start/Stop, View Logs)
     - Tab 5: Data (Export/Import/Backup)
   - Status Bar (Last run, Next run, Status)
   - System Tray Icon

3. **MVVM Pattern**
   - Views: UI (XAML)
   - ViewModels: Business Logic (PowerShell)
   - Services: Data Access (Config, Validation, Testing)
   - Binding: View ↔ ViewModel (two-way binding)

### 11.2 - Tab Details

**Tab 1: Monitors**
- List of configured monitors
- Buttons: Add, Edit, Delete, Test, Enable/Disable
- Edit Dialog: URL, Poll Interval, Parser Config (CSS Selectors)
- Test Button: Preview live scraping results
- Visual feedback: Success/Error status

**Tab 2: Filters (Course Types)**
- Per-monitor course type configuration
- Global default course types
- Pattern Matching (e.g., "Basic" matches "Basic", "basics", "beginner-basic")
- Add/Edit/Delete patterns
- Test: Show which courses match selected types

**Tab 3: Notifications (Global Settings)**
- **Email Section:**
  - SMTP Server (e.g., smtp.gmail.com)
  - SMTP Port (587, 465, 25)
  - Username & Password (encrypted with DPAPI)
  - TLS/SSL toggle
  - Sender Address & Name
  - Recipients List (add/remove multiple)
  - Test Button: Send test email
  
- **Discord Section:**
  - Webhook URL (password field for security)
  - Color Picker (embed color)
  - Mention Roles/Users (optional)
  - Test Button: Send test message
  
- **Windows Toast Section:**
  - Enable/Disable toggle
  - App ID
  - Sound selection
  - Duration (short/long)

**Tab 4: Scheduler**
- Start/Stop Watcher button (toggles Scheduled Task)
- Current Status (Running/Stopped)
- Last Run: Timestamp, Status, Courses found
- Next Run: Estimated time
- Real-time Log Viewer (tail last 50 lines)
- Auto-refresh (every 5 seconds)

**Tab 5: Data**
- Export Config (save config.json + state.json)
- Import Config (load from backup)
- Reset to Defaults (confirm dialog)
- Backup Management (list/restore backups)
- Clear State (reset course history)

### 11.3 - Security & Secrets

**Password Encryption:**
- DPAPI (Data Protection API) for storing sensitive data
- Passwords encrypted at rest in config.json
- Decryption happens only in-memory during use
- First-time setup: User enters SMTP password, encrypted for storage

**Implementation:**
```powershell
# src/utils/Secrets.ps1
function Protect-SecretData {
  param([string]$PlainText)
  $Bytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
  $EncryptedBytes = [System.Security.Cryptography.DataProtectionScope]::CurrentUser |
    ConvertTo-SecureString -AsPlainText -Force |
    ConvertFrom-SecureString
  return $EncryptedBytes
}

function Unprotect-SecretData {
  param([string]$EncryptedData)
  # Decrypt only in-memory
}
```

### 11.4 - Validation & Error Handling

**Real-time Validation:**
- SMTP credentials: Test connection on blur
- Discord webhook: Validate URL format & reachability
- Course type patterns: Show regex validation errors
- Email recipients: Validate format
- Monitor URLs: Validate URL format

**Error Dialogs:**
- Network errors: "Could not connect to SMTP server"
- Validation errors: "Invalid email format"
- Config errors: "Duplicate monitor ID"
- Show actionable error messages

### 11.5 - Testing Within GUI

**Test Buttons:**

1. **Monitor Test:**
   - Fetch courses from website (one-time, not persisted)
   - Show preview with:
     - Course Title, Type, Availability
     - Which courses would be filtered
     - Success/Error status

2. **Email Test:**
   - Send test email to primary recipient
   - Subject: "[TEST] IPSC Kurs Watcher Notification"
   - Confirm send status in dialog

3. **Discord Test:**
   - Send test message to webhook
   - Show embed format preview
   - Confirm post status

4. **Course Filter Test:**
   - Preview which courses match selected types
   - Show before/after filter results

---

## Status: Project Infrastructure [INIT]

**Completion Status:**

- [x] Core architecture documented (ADRs 001-010)
- [x] Code standards defined (STRUCTURE.md)
- [x] Testing strategy established (TBD: Pester)
- [ ] GUI architecture documented (DONE in STRUCTURE.md 11)
- [ ] CI/CD pipeline configured
- [ ] Deployment automation

**Overall Grade:** Ready for Phase 1 Implementation

