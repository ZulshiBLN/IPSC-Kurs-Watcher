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

**Status:** [PENDING]

**Context:**
IPSC Kurs Watcher muss für verschiedene Betriebssysteme (Windows, Linux, macOS) funktionieren und regelmäßig Kursinformationen monitoren. Die Wahl des Tech-Stacks beeinflusst die Wartbarkeit, Performance und Deployment-Komplexität.

**Decision:**
[TBD – Abhängig von Anforderungen]

Optionen zur Überlegung:
- **Python 3.10+** – Einfach, cross-platform, gute Libraries (requests, BeautifulSoup, Pydantic)
- **TypeScript/Node.js** – Schnell, JavaScript-Ecosystem
- **Rust** – Performance, aber steiler Learning Curve
- **Go** – Binaries, schnell, einfach zu deployen

**Consequences:**
- (+) Cross-platform Support
- (+) Easy to maintain
- (-) Abhängig von Ecosystem + Libraries
- (-) Performance-Trade-offs möglich

**Alternatives:**
- Monolithic single-language approach (simpler, aber weniger flexibel)
- Microservices (komplexer, aber skalierbar)

**Implementation Notes:**
- Tech-Stack sollte früh in Projekt-Setup entschieden werden
- Update STRUCTURE.md Section 6 mit entschiedenem Stack

---

## ADR-002: Monitoring Architecture

**Status:** [PENDING]

**Context:**
IPSC Kurs Watcher muss regelmäßig IPSC-Kurse monitoren (Schedule-Änderungen, Verfügbarkeit, etc.) und Benachrichtigungen senden. Die Architektur beeinflusst Skalierbarkeit und Wartbarkeit.

**Decision:**
[TBD – Modulare Architektur empfohlen]

Konzept:
- **Core Engine:** Zentrale Koordination
- **Monitors:** Unabhängige Module für verschiedene Quellen (z.B. IPSC-Website, externe APIs)
- **Filters:** Datenaggregation und Filterung
- **Notifiers:** Pluggable Benachrichtigungs-Module (Email, Webhook, Slack, etc.)

**Consequences:**
- (+) Einfach neue Monitors/Notifiers hinzufügen
- (+) Unabhängig testbar
- (+) Fault isolation (1 Monitor-Fehler crasht nicht alles)
- (-) Mehr Code/Komplexität als Monolith
- (-) Koordination zwischen Modulen nötig

**Alternatives:**
- Monolithic design (einfacher, aber harder to extend)
- Microservices (overkill für dieses Projekt)

**Implementation Notes:**
- Siehe STRUCTURE.md Section 2 (Design-Prinzipien)
- Modulare Architektur erlaubt späte Entscheidungen über Deployment-Strategie

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

