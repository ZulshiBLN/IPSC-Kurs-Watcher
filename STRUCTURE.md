# IPSC Kurs Watcher – STRUCTURE.md

Projekt-spezifische Struktur- und Implementierungs-Regeln.

**Lese-Reihenfolge:** DECISIONS.md (WHY) → STRUCTURE.md (HOW) → Code

---

## 1. Folder-Struktur & Verzeichnis-Layout

```
IPSC-Kurs-Watcher/
├── src/
│   ├── core/                  (Shared utilities, no dependencies)
│   │   ├── Helpers.ps1
│   │   ├── Logging.ps1
│   │   ├── Config.ps1
│   │   └── State.ps1
│   ├── monitors/              (Monitor implementations)
│   │   ├── MonitorBase.ps1
│   │   ├── CourseMonitor.ps1
│   │   ├── MonitorFactory.ps1
│   │   └── GenericMonitor.ps1
│   ├── filters/               (Filtering logic)
│   │   ├── FilterByType.ps1
│   │   ├── FilterByExclusion.ps1
│   │   └── FilterPipeline.ps1
│   ├── notifiers/             (Notification channels)
│   │   ├── NotifyEmail.ps1
│   │   ├── NotifyDiscord.ps1
│   │   └── NotifyToast.ps1
│   └── utils/                 (Helpers)
│       └── Helpers.ps1
├── config/
│   ├── config.json            (Main configuration - user edits this)
│   ├── config.schema.json     (Validation schema)
│   └── config.example.json    (Template with comments)
├── data/
│   ├── state.json             (Auto-maintained current state)
│   └── logs/                  (Auto-created, daily rotation)
├── tests/
│   ├── unit/                  (Unit tests)
│   │   ├── core/
│   │   ├── monitors/
│   │   ├── filters/
│   │   └── notifiers/
│   ├── integration/           (End-to-end tests)
│   └── fixtures/              (Test data: HTML samples, JSON, etc.)
├── docs/
│   ├── INSTALLATION.md        (Setup & prerequisites)
│   ├── CONFIGURATION.md       (config.json guide)
│   ├── USAGE.md               (How to run)
│   └── ARCHITECTURE.md        (Module interactions)
├── scripts/
│   └── Install-ScheduledTask.ps1  (Deploy script)
├── BasicCourseWatcher.ps1     (v1.0 orchestrator)
├── Watcher.ps1                (v1.1+ scheduler - future)
├── build.ps1                  (Validation & build)
├── README.md
├── DECISIONS.md
├── STRUCTURE.md               (This file)
└── CLAUDE.md

```

---

## 2. Datei-Namen in src/

### src/core/ - Shared Utilities (No Dependencies)

```
Helpers.ps1              Load first. Common utilities (JSON, encryption, etc.)
Logging.ps1              Write-Log function, rotation, masking
Config.ps1               Load & validate config.json against schema
State.ps1                Read/Write state.json, deduplication logic
```

### src/monitors/ - Monitor Implementations

```
MonitorBase.ps1          Abstract base class (common logic for all monitors)
CourseMonitor.ps1        shooting-store.ch implementation
MonitorFactory.ps1       Route provider → implementation
GenericMonitor.ps1       Template for new sites (optional)
```

### src/filters/ - Filtering Logic

```
FilterByType.ps1         Pattern-matching by course type
FilterByExclusion.ps1    Reject patterns
FilterPipeline.ps1       Chain all filters together
```

### src/notifiers/ - Notification Channels

```
NotifyEmail.ps1          SMTP email sending
NotifyDiscord.ps1        Discord webhook posting
NotifyToast.ps1          Windows Toast notifications (.NET WinRT)
```

---

## 3. Module Loading Order

**Loading sequence (in BasicCourseWatcher.ps1 or Watcher.ps1):**

```powershell
# Step 1: Load core modules (no dependencies)
. ./src/core/Helpers.ps1
. ./src/core/Logging.ps1
. ./src/core/Config.ps1
. ./src/core/State.ps1

# Step 2: Load feature modules (depend on core)
. ./src/monitors/MonitorBase.ps1
. ./src/monitors/CourseMonitor.ps1
. ./src/monitors/MonitorFactory.ps1

. ./src/filters/FilterByType.ps1
. ./src/filters/FilterByExclusion.ps1
. ./src/filters/FilterPipeline.ps1

. ./src/notifiers/NotifyEmail.ps1
. ./src/notifiers/NotifyDiscord.ps1
. ./src/notifiers/NotifyToast.ps1

# Step 3: Initialize & run
$config = Get-Config -Path "config/config.json"
$state = Get-State -Path $config.state.file_path
# ... proceed with monitoring
```

**Dependency Rule:** If A imports B, B cannot import A (no circular dependencies)

---

## 4. Function Structure Requirements

### PUBLIC Functions (exported, no `_` prefix)

**Must Have:**
1. **Comment-based Help** (PSScriptAnalyzer enforced)
   ```powershell
   <#
   .SYNOPSIS
   One-line summary
   
   .DESCRIPTION
   Detailed description of what function does
   
   .PARAMETER ParamName
   Description of each parameter
   
   .EXAMPLE
   Usage example
   
   .OUTPUTS
   What the function returns
   #>
   ```

2. **CmdletBinding** with parameter validation
   ```powershell
   [CmdletBinding()]
   param(
       [ValidateNotNullOrEmpty()][string]$Url,
       [ValidateRange(1, 300)][int]$TimeoutSeconds = 30
   )
   ```

3. **Error Handling** (try-catch)
   ```powershell
   try {
       # Implementation
   }
   catch {
       Write-Log -Level ERROR -Message "..." -Exception $_
       throw  # Re-throw for caller
   }
   ```

### PRIVATE Functions (`_` prefix)

**Minimum requirements:**
- Minimal help (`.SYNOPSIS` only)
- No CmdletBinding needed
- Simplified error handling (optional)

```powershell
function _ParseCourseRow {
    <# .SYNOPSIS Internal helper #>
    param([string]$Html)
    # Implementation
    return $result
}
```

---

## 5. config.json Structure (NO HARDCODING)

**v1.0 config.json (minimal but complete):**

```json
{
  "version": 1,
  
  "monitors": [
    {
      "id": "shooting-store",
      "url": "https://www.shooting-store.ch/de/kategorie/kurse1",
      "base_url": "https://www.shooting-store.ch",
      "enabled": true,
      "timeout_seconds": 30,
      "retry_attempts": 3,
      "poll_interval_minutes": 30
    }
  ],
  
  "filters": {
    "course_types": [
      { "id": "basic", "name": "Basic", "patterns": ["Basic", "Level 1"], "enabled": true }
    ],
    "exclude_patterns": ["Privatunterricht"],
    "min_availability": 1
  },
  
  "notifiers": {
    "windows_toast": { "enabled": true }
  },
  
  "state": {
    "file_path": "data/state.json"
  },
  
  "logging": {
    "level": "INFO",
    "log_dir": "data/logs",
    "retention_days": 30
  },
  
  "error_handling": {
    "alert_on_repeated_errors": true,
    "error_threshold": 5,
    "error_window_minutes": 60
  }
}
```

**Rules:**
- ❌ NO hardcoded URLs in code
- ✅ All URLs in config.json
- Config is loaded at startup
- Invalid config = startup fails with clear error

---

## 6. state.json Structure (Auto-Maintained)

**Format (one JSON object per file):**

```json
{
  "version": 1,
  "last_poll": "2026-07-03T14:30:00Z",
  "last_notified": [
    {
      "id": "IPSC Basic 2.0|08.08.2026|09:30-13:00",
      "name": "IPSC Basic 2.0 Course",
      "date": "2026-08-08",
      "time": "09:30-13:00",
      "availability": 3,
      "url": "https://www.shooting-store.ch/de/produkt/...",
      "notified_at": "2026-07-03T14:30:00Z"
    }
  ]
}
```

**Rules:**
- Auto-created if missing (Get-State.ps1)
- ID = unique identifier (Name|Date|Time)
- `last_notified[]` = courses we've already alerted about
- Updated after each monitoring run
- Used for deduplication (don't notify same course twice)

---

## 7. Logging Details

**Log Files (auto-rotated daily):**
```
data/logs/
├── watcher-2026-07-01.log
├── watcher-2026-07-02.log
├── watcher-2026-07-03.log
```

**Format (JSON, one per line):**
```json
{"timestamp":"2026-07-03T14:30:00.123Z","level":"INFO","component":"Monitor.CourseMonitor","message":"Found 8 courses","context":{"monitor_id":"shooting-store","course_count":8}}
```

**Log Levels:**
- **DEBUG** (dev-only): Function entry/exit, variable values
- **INFO** (default): Monitoring events, new courses, notifications sent
- **WARN**: Retries, slow requests, config issues
- **ERROR**: Critical failures (exceptions, connection errors)

**Console Output (interactive mode):**
- Plaintext, human-readable
- Color-coded: INFO=Green, WARN=Yellow, ERROR=Red

**Sensitive Data Masking:**
- Passwords masked: `password=***MASKED***`
- API Keys masked: `api_key=***MASKED***`
- Email addresses masked: `user@domain.com` → `***@***.***`

---

## 8. Testing Rules & Execution

**Test Execution:**
```powershell
# Run all tests
Invoke-Pester tests/ -CodeCoverage src/ -PassThru

# Run specific suite
Invoke-Pester tests/unit/monitors/ -Verbose
Invoke-Pester tests/integration/ -PassThru
```

**Coverage Requirements:**
- **Critical modules:** 90%+ (core/, monitors/, notifiers/)
- **Utilities:** 70%+ (utils/)
- **Pre-commit hook:** Blocks commit if < 90%

**Test Organization:**
```
tests/
├── unit/              (Fast, isolated tests)
├── integration/       (Against real APIs)
└── fixtures/          (Test data: HTML, JSON, etc.)
```

**Test Naming Convention:**
```powershell
Describe "CourseMonitor" {
    Context "When parsing HTML" {
        It "should extract 8 courses from sample HTML" {
            # Test implementation
        }
    }
}
```

---

## 9. build.ps1 Script - Validation & Build

**Usage:**
```powershell
.\build.ps1 -Validate          # Linting + Schema check
.\build.ps1 -Test              # Run tests
.\build.ps1 -All               # All checks
```

**Checks:**
1. **PSScriptAnalyzer** - Linting (Security + Style)
2. **Syntax Check** - Compile all .ps1 files
3. **JSON Validation** - config.json against schema
4. **Test Coverage** - Minimum 90%

**Exit Code:**
- `0` = Success
- `1` = Failure (used by CI/CD, pre-commit hooks)

---

## 10. Pre-commit Hooks

**Location:** `.git/hooks/pre-commit`

**Runs automatically before each commit:**
1. PSScriptAnalyzer (errors block commit)
2. Unit Tests (failures block commit)
3. JSON Validation (invalid config blocks commit)

**If checks fail:**
- Error message shown
- Commit is BLOCKED
- Developer must fix and retry: `git commit`

**Can bypass (not recommended):**
```powershell
git commit --no-verify -m "message"  # Only in emergencies
```

---

## 11. Versioning & Release Management

**Version Format (Semantic Versioning):**
```
MAJOR.MINOR.PATCH
v1.0.0 = stable release
v1.1.0 = new features
v1.0.1 = bugfix
v2.0.0 = breaking changes

Pre-release: v1.0.0-beta.1, v1.0.0-rc.1
```

**Version Locations (must stay in sync):**
- `DECISIONS.md` - Version and Phase info at top
- `CLAUDE.md` - "Version: v0.0.x" at top
- `README.md` - "Version: v0.0.x" at top
- Git Tags - annotated: `git tag -a v0.0.2 -m "Release: v0.0.2"`

**Release Cycle (Three-Tier from CLAUDE.md):**
```
develop (active development)
    ↓
prerelease (testing/beta)
    ↓
main (stable production)
```

---

## 12. Module Export & Import Rules

**Exporting PUBLIC Functions:**
```powershell
# End of src/monitors/CourseMonitor.ps1

Export-ModuleMember -Function @(
    'Get-CoursesFromShootingStore'   # Public API
)

# Private helpers are NOT exported
function _ParseCourseRow { ... }     # Internal only
```

**Importing Modules:**
```powershell
# Load in order (core first, then features)
. ./src/core/Helpers.ps1
. ./src/core/Logging.ps1
. ./src/core/Config.ps1
. ./src/core/State.ps1
. ./src/monitors/CourseMonitor.ps1

# Now public functions available
$courses = Get-CoursesFromShootingStore -Url $url
```

**Naming Enforces Access:**
- `Get-CoursesFromShootingStore` = PUBLIC (no underscore)
- `_ParseCourseRow` = PRIVATE (underscore prefix, internal only)

---

## 13. Error Handling Patterns

**PUBLIC Functions (errors thrown to caller):**
```powershell
function Get-CoursesFromShootingStore {
    [CmdletBinding()]
    param([string]$Url)
    
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 30
        $courses = _ParseHtml -Html $response.Content
        return $courses
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to fetch courses" `
            -Context @{ url = $Url; error = $_.Exception.Message }
        throw  # Re-throw for caller
    }
}
```

**PRIVATE Functions (errors logged, graceful return):**
```powershell
function _ParseHtml {
    param([string]$Html)
    
    try {
        # Parsing logic
        return $courses
    }
    catch {
        Write-Log -Level ERROR -Message "HTML parsing failed"
        return @()  # Graceful return, don't throw
    }
}
```

**Retry Logic (exponential backoff):**
```powershell
$maxRetries = 3
$attempt = 0

while ($attempt -lt $maxRetries) {
    try {
        $result = Get-CoursesFromShootingStore -Url $url
        return $result
    }
    catch {
        $attempt++
        if ($attempt -lt $maxRetries) {
            $waitSeconds = [Math]::Pow(2, $attempt - 1)  # 1s, 2s, 4s
            Write-Log -Level WARN -Message "Retry attempt $attempt/$maxRetries"
            Start-Sleep -Seconds $waitSeconds
        }
    }
}

Write-Log -Level ERROR -Message "All retries failed after $maxRetries attempts"
return $null
```

---

## 14. Performance Guidelines

**Target Performance (per monitoring run):**
```
Single Monitor (shooting-store.ch):
- Fetch + Parse: 2-3 seconds
- Filter + Dedup: <100ms
- Notifications: 1-5 seconds
- Total: ~5-10 seconds

Multiple Monitors (3 sites, parallel):
- Parallel fetch: ~10 seconds (not 30 sequential)
- Total: ~10-15 seconds
```

**Optimization Strategies:**
1. **Parallel Execution** - PowerShell Jobs for multiple monitors (max 10 concurrent)
2. **Timeouts** - Monitor: 30s, Notifier: 10s
3. **Lazy Evaluation** - Don't construct expensive strings unless needed
4. **Logging** - Include duration_ms in logs for monitoring

**Performance Logging:**
```json
{"timestamp":"2026-07-03T14:30:00Z","level":"INFO","message":"Monitoring cycle completed","context":{"duration_ms":8234,"monitors":1,"courses":8,"new_courses":2}}
```

---

## 15. Documentation Requirements

**In-Code Documentation (required):**
- Comment-based Help for PUBLIC functions (enforced by PSScriptAnalyzer)
- `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`

**External Documentation (nice-to-have):**
- `README.md` - Overview + quick start (required)
- `docs/CONFIGURATION.md` - config.json guide
- `docs/USAGE.md` - How to run + Scheduled Task setup
- `docs/INSTALLATION.md` - Prerequisites + first run

---

## 16. Code Organization Within Files

**File Structure (top-to-bottom):**

```powershell
#Requires -Version 5.1

<# .SYNOPSIS Module description #>

# ============================================================================
# CONSTANTS
# ============================================================================
$TIMEOUT_DEFAULT = 30
$MAX_RETRIES = 3
$STATE_FILE_PATH = "data/state.json"

# ============================================================================
# PRIVATE FUNCTIONS (Helpers)
# ============================================================================
function _ParseCourseRow { ... }
function _ExtractPrice { ... }

# ============================================================================
# PUBLIC FUNCTIONS (Exported API)
# ============================================================================
function Get-CoursesFromShootingStore { ... }
function Save-CourseState { ... }

# ============================================================================
# EXPORTS
# ============================================================================
Export-ModuleMember -Function @(
    'Get-CoursesFromShootingStore',
    'Save-CourseState'
)
```

**Rationale:** Top-to-bottom readability, clear sections, exports at end

---

## 17. Configuration File Validation (config.schema.json)

**Schema validation (via Get-Config function):**

```powershell
function Get-Config {
    param([string]$Path = "config/config.json")
    
    # 1. Load JSON
    $config = Get-Content $Path | ConvertFrom-Json
    
    # 2. Validate against schema
    $schema = Get-Content "config/config.schema.json" | ConvertFrom-Json
    
    if (-not (Validate-JsonSchema -Instance $config -Schema $schema)) {
        throw "Config validation failed: Invalid format or missing required fields"
    }
    
    # 3. Validate values
    foreach ($monitor in $config.monitors) {
        if (-not ($monitor.url -match '^https?://')) {
            throw "Config error: Monitor URL must start with http:// or https://"
        }
    }
    
    return $config
}
```

**Validation Failure:**
```
[ERROR] Config validation failed: Missing required field 'monitors'
[ERROR] Location: config/config.json
[ERROR] Fix: Add monitors[] array with at least one entry
Startup: ABORTED
```

---

## 18. Deployment Rules (Scheduled Task)

**Installation (scripts/Install-ScheduledTask.ps1):**
```powershell
# Run as Administrator

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PWD\BasicCourseWatcher.ps1`""

$trigger = New-ScheduledTaskTrigger `
    -RepetitionInterval (New-TimeSpan -Minutes 30) `
    -Once -At (Get-Date)

$principal = New-ScheduledTaskPrincipal -UserID "SYSTEM" -RunLevel Highest

Register-ScheduledTask `
    -TaskName "IPSC-Kurs-Watcher" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "Monitor shooting-store.ch for new courses"
```

**First Run Checklist:**
1. ✅ Clone/Extract repo to C:\Scripts\IPSC-Kurs-Watcher
2. ✅ Edit config/config.json (URL, notifiers)
3. ✅ Run: `.\scripts\Install-ScheduledTask.ps1` (as Admin)
4. ✅ Test: `.\BasicCourseWatcher.ps1 -RunOnce`
5. ✅ Check logs: `data/logs/watcher-YYYY-MM-DD.log`
6. ✅ Configure notifiers (optional)

**Task Details:**
- Runs every 30 minutes (configurable via config.json)
- Runs as SYSTEM user (Highest privileges)
- Auto-starts after reboot
- Logs to: `data/logs/watcher-YYYY-MM-DD.log`

**Uninstall:**
```powershell
Unregister-ScheduledTask -TaskName "IPSC-Kurs-Watcher" -Confirm:$false
Remove-Item C:\Scripts\IPSC-Kurs-Watcher -Recurse -Force
```

---

## Summary & Quick Reference

| Item | Rule |
|------|------|
| **Config** | NO hardcoding. All in config.json |
| **State** | Auto-maintained, JSON format |
| **Logging** | Structured JSON, daily rotation, 30-day retention |
| **Functions** | PUBLIC (full help) vs PRIVATE (minimal help) |
| **Modules** | Load core first, then features (no circular deps) |
| **Testing** | 90%+ coverage required, unit + integration |
| **Build** | `build.ps1 -All` (PSScriptAnalyzer, tests, schema) |
| **Pre-commit** | Validation checks before commit allowed |
| **Versioning** | Semantic versioning (v1.x.x), sync across files |
| **Deployment** | Scheduled Task every 30 minutes (configurable) |

---

**Ready for Phase 1 (v1.0) Implementation!** ✅
