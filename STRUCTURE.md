# IPSC Kurs Watcher – STRUCTURE.md

Projekt-spezifische Struktur- und Organisationsregeln für IPSC Kurs Watcher.

---

## 1. VERZEICHNIS-STRUKTUR

**Generische Projekt-Struktur:**

```
IPSC-Kurs-Watcher/
├── src/                    # Source code
│   ├── core/              # Kernfunktionalität
│   ├── monitors/          # Monitoring-Module
│   ├── notifiers/         # Benachrichtigungs-Module
│   ├── utils/             # Helper-Funktionen
│   └── config/            # Konfiguration
├── tests/                 # Tests (parallel zu src)
│   ├── fixtures/          # Test-Daten
│   ├── unit/
│   └── integration/
├── docs/                  # Dokumentation
├── examples/              # Beispiel-Skripte
├── .github/               # GitHub workflows (if applicable)
├── build/                 # Build-Artefakte
├── CLAUDE.md              # Claude Collaboration Rules
├── DECISIONS.md           # Architektur-Entscheidungen
├── STRUCTURE.md           # This file
├── README.md              # Projekt-Übersicht
├── CHANGELOG.md           # Versionshistorie
└── [config]               # Abhängig von Tech-Stack (package.json, setup.py, Cargo.toml, etc.)
```

---

## 2. DESIGN-PRINZIPIEN

**Kernprinzipien für IPSC Kurs Watcher:**

- **Modularität** – Unabhängige Monitor-, Notifier-, Filter-Module
- **Single Responsibility Principle** – Jedes Modul hat eine klare Aufgabe
- **Composition over Inheritance** – Module zusammensetzen statt Vererbung
- **Fail-Fast Pattern** – Bei Fehlern schnell fehlagen, nicht silent swallowing
- **Configuration over Code** – Behavior durch Config definieren, nicht hard-coded
- **Extensibility** – Neue Monitor/Notifier/Filter leicht hinzufügbar

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

## Status: Project Infrastructure [INIT]

**Completion Status:**

- [ ] Core architecture documented
- [ ] Code standards defined
- [ ] Testing strategy established
- [ ] CI/CD pipeline configured
- [ ] Deployment automation
- [ ] Monitoring & alerts

**Overall Grade:** [TBD]

