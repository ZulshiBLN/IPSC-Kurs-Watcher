# IPSC Kurs Watcher – CLAUDE.md

Automation und Monitoring für IPSC-Kurse mit intelligenter Benachrichtigung und Tracking.

---

## Projekt-Kontext

**Version:** v0.1.0  
**Status:** [DEVELOPMENT] Core monitoring stable: All courses tracked, NEW + AVAILABILITY_REDUCED detected  
**Sprache/Stack:** PowerShell 5.1 (Windows)  
**Ziel:** Sichere, performante, tokensparende Zusammenarbeit mit Claude

**Wichtige Dokumente:**
- [RULES] **[STRUCTURE.md](STRUCTURE.md)** – Konkrete Implementierungs-Regeln (HOW)
- [ADR] **[DECISIONS.md](DECISIONS.md)** – Architektur-Entscheidungen & Begründungen (WHY)
- [COLLAB] **[CLAUDE.md](CLAUDE.md)** (dieses Dokument) – Collaboration Rules & Best Practices

➡️ **Lese-Reihenfolge:** DECISIONS.md (Kontext) → STRUCTURE.md (Regeln) → CLAUDE.md (Collaboration)

---

## Allgemeine Collaboration Rules (Claude Best Practices)

### Sicherheit & Datenhandling

**Regel 1.1 - Zero Data Retention (ZDR)**
- Keine Credentials, Secrets oder sensible Daten in Prompts
- `.env`, `.local`, `secrets.json` grundsätzlich NICHT mit Claude teilen
- Nur Struktur/Patterns zeigen, keine echten Werte
- Bei Sicherheitsreviews: Anonymisierte Beispiele verwenden

**Regel 1.2 - Validierung an Grenzen**
- Externe Eingaben validieren (User-Input, APIs, Config-Files)
- Interne Code-Garantien vertrauen; nicht über-validieren
- OWASP Top 10 im Auge behalten (XSS, Injection, CSRF, etc.)

**Regel 1.3 - Destructive Operations erfordern Bestätigung**
- Force-Push, Hard-Reset, Permanent Delete → Explizite Genehmigung ERST einholen
- Bei Unsicherheit fragen, nicht silent weitermachen
- Git-Hooks nicht skippen (--no-verify) ohne guten Grund

**Regel 1.4 - Keine gefährlichen Code-Patterns**
- Injection-anfällige Patterns vermeiden (eval, exec, dynamic code execution)
- SQL Injection, Command Injection, Template Injection
- Erst static Analysis, dann Manual Review für Security-kritischen Code

**Regel 1.5 - Dokumentation von Public vs Private Funktionen**
- **PUBLIC Funktionen/APIs**: Vollständige Dokumentation erforderlich
  - Syntax: JSDoc, Docstring, Comment-based Help (je nach Sprache)
  - Muss enthalten: Summary, Parameters, Return Type, Example, Exceptions
- **PRIVATE Funktionen**: Minimal-Help erforderlich
  - Mindestens Summary + Parameter oder aussagekräftige Inline-Kommentare

---

### Token-Effizienz & Context-Management

**Regel 2.1 - Token-bewusste Prompts**
- Relevante Code-Ausschnitte gezielt teilen (nicht ganze Dateien)
- Grep/Glob für Suche nutzen → Read nur spezifische Bereiche
- Large Context Windows = Ressource, nicht Freibrief für alles hochladen

**Regel 2.2 - Context Discipline**
- **Progressive Disclosure:** Nur relevante Kontexte pro Request
- **Lookback-Fenster:** Alte Conversation-Turns nicht unnötig re-laden
- **Tool-Strategien:** Spezialisierte Tools statt Shell-Commands
  - Grep für Content-Search
  - Glob für Datei-Pattern
  - Edit/Write statt Echo/Sed für File-Ops

**Regel 2.3 - Parallelisierung wo möglich**
- Unabhängige Tool-Calls parallel ausführen
- Abhängigkeiten auflösen → sequenzielle Ausführung nur wenn nötig

**Regel 2.4 - Agent-Delegation sinnvoll nutzen**
- Agents nur für breite Codebase-Erkundung
- Für fokussierte Lookups direkt Tools nutzen (Grep, Glob, Read)
- Nie mehrfach recherchieren: Agent-Ergebnisse vertrauen

---

### Code-Qualität & Hygiene

**Regel 3.1 - Minimale Kommentare, maximale Klarheit**
- Keine Kommentare für offensichtliches (selbsprechende Namen)
- Nur Kommentare für **WHY**, nicht WHAT
- Beispiel [NO]: `# loop through array`
- Beispiel [YES]: `// Retry with exponential backoff due to rate limiting`

**Regel 3.1a - Keine problematischen Unicode-Zeichen in Output**
- Verwende nur ASCII für User-Output (robuster für Encoding-Probleme)
- Keine Unicode Symbole (°, ✓, ✗, •, █, ░, →, ←) in Logs/Messages
- STATTDESSEN: [OK]/[ERROR]/[WARN]/[INFO], *, -, #, >, <, etc.

**Regel 3.2 - Keine Über-Abstraktionen**
- YAGNI-Prinzip: Nicht für hypothetische Zukunft bauen
- 3 gleiche Zeilen = noch nicht reif für Abstraktion
- Keine Fallbacks für unmögliche Szenarien

**Regel 3.3 - Keine unnötigen Cleanup-Commits**
- Bugfix = nur Bugfix, keine Umbenennungen im gleichen Commit
- Refactor = nur Struktur-Änderung, keine Features
- Separate Commits für verschiedene Zwecke

---

### Transparente Zusammenarbeit

**Regel 4.1 - Klare Statusupdates**
- State-Änderungen mit kurzen 1-2 Satz-Updates mitteilen
- Nicht über interne Überlegungen berichten, Ergebnisse fokussieren
- Blockers sofort kommunizieren, nicht silent weitermachen

**Regel 4.2 - Memory-System nutzen**
- Learnings über Zusammenarbeit speichern → zukünftige Sessions
- User-Profil, Feedback und Projekt-Kontext dokumentieren
- Memories vor Handlungen verifizieren (können veraltet sein)

---

## Arbeitsregeln für IPSC Kurs Watcher

### Context-Management für Claude-Sessions

**Regel 5.1 - Build & Validate vor jedem Commit**
- Linting-Validierung vor Commit automatisch ausführen (via `.git/hooks/pre-commit.bat`)
- Hook blockiert Commits mit Linting-Fehlern
- Fehler müssen vor Commit behoben werden
- Bei Erfolg: Commit wird erstellt. Bei Fehler: Hook blockiert → Fixen → Retry.

**Hook Installation & Verwendung:**

Hook wird automatisch von Git verwendet (keine Setup nötig). Befindet sich in: `.git/hooks/pre-commit.bat`

**Wie es funktioniert:**
1. Du tippst: `git commit -m "Fix: something"`
2. Git lädt automatisch `.git/hooks/pre-commit.bat`
3. Hook führt aus: `build.ps1 -Validate`
4. **Wenn erfolgreich:** Commit wird erstellt, Hook gibt Exit Code 0
5. **Wenn Fehler:** Commit wird BLOCKIERT, Hook zeigt Fehler-Liste

**Beispiel (Success):**
```
$ git commit -m "Fix: Remove unused parameter"

[PRE-COMMIT] Running build validation...

=== PSScriptAnalyzer Linting ===
[OK] Config.ps1
[OK] Logging.ps1
[OK] State.ps1
...
=== BUILD SUMMARY ===
Passed: 26
Failed: 0

[PRE-COMMIT] Validation passed, committing...
[main a1b2c3d] Fix: Remove unused parameter
```

**Beispiel (Error - Commit blockiert):**
```
$ git commit -m "Add feature"

[PRE-COMMIT] Running build validation...

=== PSScriptAnalyzer Linting ===
[FAIL] CourseMonitor.ps1
  Line 42: Write-Host is not allowed

=== BUILD SUMMARY ===
Passed: 25
Failed: 1

[PRE-COMMIT] Validation failed, commit blocked
Fix errors and run: git commit
```

**Notfall-Bypass (nur wenn Hook zu streng):**
```bash
git commit --no-verify -m "Emergency fix"  # Überspringt Hook
```
⚠️ **NUR in echten Notfällen verwenden!** Hook ist Qualitäts-Sicherung.

**Troubleshooting:**
- **Hook läuft nicht?** Prüfe: `ls -la .git/hooks/pre-commit.bat`
- **"powershell not found"?** Nutze vollständigen Pfad oder PATH setzen
- **Unerwartete Fehler?** Manual run: `.\build.ps1 -Validate`

**Regel 5.2 - CLAUDE.md aktuell halten**
Nach Änderungen updaten wenn:
- Tech-Stack finalisiert
- Neue Module/Komponenten hinzukommen
- Konventionen/Patterns etablieren
- Dependencies/Versionen kritisch ändern
Immer kompakt formulieren.

**Regel 5.3 - Dokumentation vor Code**
Neue Features nach Scope:
1. **Architektur-Entscheidung** (massgebliche Änderung) → ADR in [DECISIONS.md](DECISIONS.md)
2. **Implementierungs-Regel** (konkrete Standard) → Regel in [STRUCTURE.md](STRUCTURE.md)
3. **Collaboration-Update** (Claude-spezifisch) → Anpassung in [CLAUDE.md](CLAUDE.md)
4. **Große Features** → `/plan` starten vor Code

---

### Decision Making & Architecture

**Regel 5.4 - Architektur-Entscheidungen in DECISIONS.md (ADRs)**
Nur Entscheidungen, die das Projekt **massgeblich ändern**, bekommen eine ADR:

**Gehört in DECISIONS.md (massgebliche Entscheidung):**
- [YES] Projekt-Struktur / Architektur (Folder-Layout, Module-Design)
- [YES] Tech-Stack Änderungen (Frameworks, Libraries, Versions)
- [YES] Prozess-Entscheidungen (Testing-Framework, Versioning, Logging)
- [YES] Design-Patterns (Error-Handling, Conventions)

**Gehört in STRUCTURE.md (konkrete Regel):**
- Implementierungs-Standards (Naming, Kommentare, Code-Style)
- Verzeichnis-Layout
- Anforderungen pro Funktion/Klasse

**Gehört NICHT in ADR (lokale Entscheidungen):**
- Einzelne Function/Variable Namen oder lokale Bugfixes
- Taktische Implementierungen

**Wie ADR schreiben?**
1. Neue ADR in [DECISIONS.md](DECISIONS.md) hinzufügen
2. Status setzen: `[PENDING]`, `[ACCEPTED]`, `[REJECTED]`, `[SUPERSEDED]`
3. Context + Decision + Consequences + Alternatives
4. Im Code referenzieren wenn relevant: `// See ADR-002 for error handling`
5. Auf [STRUCTURE.md](STRUCTURE.md) verweisen für Implementierungs-Details

---

### Sicherheit in Development

**Regel 6.1 - Keine Secrets in Code oder Config**
- Credentials über Environment Variablen oder Credential Manager
- Lokale `.env.local` → `.gitignore` (nie committen!)
- Beispiele nur mit Platzhaltern: `api_key = "<YOUR_API_KEY>"`

**Regel 6.2 - Code Review vor Security-Commits**
- Alles was Auth/Permissions/Credentials berührt → `/code-review` vorher
- Oder direkt `/security-review` für sensitive Änderungen

---

## Git-Workflow

### Repository Remotes

| Remote | System | Rolle |
|--------|--------|-------|
| `origin` | Primary Repository | Primary |
| `[other]` | [Secondary] | Backup/Mirror (optional) |

**Standard Setup:** Ein Haupt-Repository (GitHub, GitLab, Azure DevOps, etc.)

### Branch-Struktur

**Empfohlen:**
```
develop     – Aktive Entwicklung
  ↓
prerelease – Testing/Beta
  ↓
main       – Production/Stable
```

| Branch | Typ | Zweck | Stabilität |
|--------|-----|-------|-----------|
| `main` | Production | Stabile Releases | Hoch – nur getestete Merges |
| `prerelease` | Testing | Pre-Release/Beta | Mittel – vor Production |
| `develop` | Integration | Aktive Entwicklung | Niedrig – tägliche Commits |

### Versionierung (Semantic Versioning)

```
MAJOR.MINOR.PATCH
0.1.0
│ │  │
│ │  └─ PATCH (Bugfixes): v0.1.0 → v0.1.1
│ └──── MINOR (Features): v0.1.0 → v0.2.0
└────── MAJOR (Breaking): v0.x.x → v1.0.0
```

**Pre-Release Versionen:**
- `v0.1.0-beta.1`, `v0.1.0-beta.2` – Beta
- `v0.1.0-rc.1` – Release Candidate
- `v0.1.0` – Final Stable

---

## Dokumentation & Referenzen

**Architektur-Entscheidungen (WHY):**
- Siehe [DECISIONS.md](DECISIONS.md) für alle ADRs (Kontext, Gründe, Alternativen)

**Implementierungs-Regeln (HOW):**
- Siehe [STRUCTURE.md](STRUCTURE.md) für alle Regel-Blöcke

---

## Projekt-spezifische Anpassungen

### Team & Rollen
- **Solo Developer:** Michel Brosche (Email: google@brosche-bausinger.ch)
- **Scope:** IPSC Kurs Watcher automation + monitoring

### Tools & Services
- **Target Website:** shooting-store.ch (IPSC course catalog)
- **Version Control:** 
  - Primary: Azure DevOps (origin)
  - Secondary: GitHub (github) – Public mirror
- **Language:** PowerShell 5.1 (Windows-native)
- **Notifications (v0.1+):** Email (SMTP), Discord (Webhooks), Windows Toast

### Deployment-Prozess
- **v0.0.2 (Current MVP):** Manual runs via PowerShell scripts
  - `.\BasicCourseWatcher.ps1 -RunOnce` (test)
  - `.\BasicCourseWatcher.ps1` (continuous)
  
- **v0.1+ (Planned):**
  - Windows Scheduled Task (auto-run every 30 minutes)
  - `.\scripts\Install-ScheduledTask.ps1` (setup)
  - Logs: `data/logs/watcher-YYYY-MM-DD.log` (daily rotation)
  
- **Production Release:**
  - Via PowerShell Gallery (future, not v0.0.2)
  - GitHub Releases (manual download)

### Security & Credentials
- **Secrets:** Via environment variables or Windows Credential Manager (not in code)
- **Config:** `config/config.json` (user-editable, no hardcoding)
- **Logs:** Structured JSON with sensitive data masking
- **SMTP/Webhook passwords:** DPAPI-encrypted in config (v0.1+)

