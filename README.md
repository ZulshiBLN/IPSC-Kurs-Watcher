# IPSC Kurs Watcher

Automated course monitoring and availability tracking for shooting-store.ch IPSC courses with intelligent change detection and notifications.

---

## Status

**Version:** v0.2.0  
**Status:** [DEVELOPMENT] Core monitoring + notifications stable, security hardened (v0.1.1), code quality improved (v0.2.0)  
**Last Updated:** 2026-07-03

**What Works (v0.1.1):**
- ✅ Course monitoring from shooting-store.ch
- ✅ Modular architecture (core, monitors, filters, notifiers)
- ✅ HTML parsing and course extraction
- ✅ Availability tracking (free slots per course)
- ✅ New course detection + change tracking
- ✅ Deduplication (no duplicate alerts)
- ✅ State persistence (data/state.json)
- ✅ Structured JSON logging with rotation
- ✅ Filter system (type matching + exclusions)
- ✅ Configuration validation (config.schema.json)
- ✅ Email notifications (Microsoft Graph OAuth2)
- ✅ Discord webhook notifications
- ✅ Windows Toast notifications
- ✅ Security hardening (token encryption, URL validation, error sanitization)

**What's Planned (v0.2+):**
- 📋 Multi-website support via config
- 📋 Windows Scheduled Task integration
- 📋 GUI configuration (WPF)
- 📋 HTML parser upgrade (HtmlAgilityPack)

---

## Features (v0.0.2 MVP)

- **Course Monitoring:** Automatically fetches all courses from shooting-store.ch Kurse category
- **Availability Tracking:** Extracts available slots per course from detail pages
- **Change Detection:** Identifies NEW courses and REDUCED availability
- **Deduplication:** Prevents duplicate notifications for same course
- **State Management:** Persists notified courses to avoid re-alerting
- **Logging:** Structured JSON logs with rotation (daily, 30-day retention)
- **Command-line Interface:** Simple PowerShell scripts for manual runs

---

## Requirements

- **PowerShell:** 5.1+ (Windows PowerShell)
- **Windows:** Windows 10 / Windows Server 2016+
- **Network:** Internet access to shooting-store.ch
- **Disk:** ~1MB for logs + state files

---

## Security Features (v0.1.1)

**Token Protection:**
- OAuth2 tokens encrypted with DPAPI (LocalMachine scope) before disk storage
- Tokens automatically refreshed on expiry
- Failed decryption triggers fresh token request

**Credential Handling:**
- Credentials managed via environment variables (not in config files)
- SecureString input for Client Secret (prevents PowerShell history exposure)
- Error messages sanitized (credentials masked in logs)

**Network Security:**
- URL validation prevents injection attacks (only http/https allowed)
- HTTPS certificate validation for critical endpoints (login.microsoftonline.com, graph.microsoft.com)
- Signed requests with bearer token for OAuth2

**Configuration Security:**
- No secrets stored in config.json (only non-sensitive fields)
- Token cache encrypted and excluded from version control
- Structured logging with sensitive data masking

---

## Environment Variables (Required for Email/Discord)

Set these before running with notifications enabled:

```powershell
# Azure AD OAuth2 (required for email notifications)
$env:IPSC_AZURE_TENANT_ID = 'your-tenant-id'
$env:IPSC_AZURE_CLIENT_ID = 'your-client-id'
$env:IPSC_AZURE_USER_ID = 'your-user-id'

# Discord Webhooks (optional, required only if Discord notifications enabled)
$env:IPSC_DISCORD_WEBHOOKS = 'https://discord.com/api/webhooks/ID/TOKEN,...'

# Credential Store (optional, custom location for encrypted credentials)
$env:IPSC_CREDENTIAL_STORE_PATH = 'C:\Custom\Path\credentials'
```

**Setup Script:**
```powershell
# Interactive setup (recommended)
.\scripts\Setup-AzureCredentials.ps1
```

**Persistent Setup (Windows):**
```powershell
# Set permanently in user environment
setx IPSC_AZURE_TENANT_ID 'your-tenant-id'
setx IPSC_AZURE_CLIENT_ID 'your-client-id'
setx IPSC_AZURE_USER_ID 'your-user-id'
setx IPSC_DISCORD_WEBHOOKS 'webhook-urls-here'
```

---

## Installation

### 1. Clone Repository

```bash
git clone https://github.com/YOUR-ORG/IPSC-Kurs-Watcher.git
cd "IPSC-Kurs-Watcher"
```

### 2. Edit Configuration

```powershell
# Copy example config (if needed)
# cp config/config.example.json config/config.json

# Edit config/config.json
notepad config/config.json

# Set your monitor URL, logging level, etc.
```

### 3. Test Manually

```powershell
# Run single monitoring cycle
.\BasicCourseWatcher.ps1 -RunOnce

# Check logs
Get-Content data/logs/watcher-*.log -Tail 20
```

---

## Quick Start (5 minutes)

### Run Monitoring Once (Test)

```powershell
cd "c:\Repos\IPSC Kurs Watcher"
.\Scheduler.ps1 -RunOnce
```

**Expected Output:**
```
[2026-07-03 14:30:00] Loading modules...
[2026-07-03 14:30:00] [INFO] Core modules loaded
[2026-07-03 14:30:00] [INFO] Monitor modules loaded
[2026-07-03 14:30:00] [INFO] Configuration loaded
[2026-07-03 14:30:02] [INFO] Monitoring cycle starting
[2026-07-03 14:30:04] [INFO] Monitoring cycle completed
```

### Check Results

```powershell
# View state file (courses we've notified about)
Get-Content data/state.json | ConvertFrom-Json | ForEach-Object { $_.last_notified }

# View logs
Get-Content data/logs/watcher-*.log -Tail 30
```

### Run Manually Multiple Times

```powershell
# First run: 8 new courses
.\BasicCourseWatcher.ps1 -RunOnce

# Wait a bit, run again
Start-Sleep -Seconds 30
.\BasicCourseWatcher.ps1 -RunOnce
# Expected: 0 new courses (deduplication works)
```

---

## Configuration

**Location:** `config/config.json`

```json
{
  "monitors": [
    {
      "id": "shooting-store",
      "url": "https://www.shooting-store.ch/de/kategorie/kurse1",
      "base_url": "https://www.shooting-store.ch",
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
  
  "logging": {
    "level": "INFO",
    "log_dir": "data/logs",
    "retention_days": 30
  }
}
```

**For detailed configuration guide:** See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) (coming soon)

---

## Usage

### Manual Runs (Testing & Debugging)

```powershell
# Single run (test mode)
.\BasicCourseWatcher.ps1 -RunOnce

# Continuous monitoring (every 30 minutes)
.\BasicCourseWatcher.ps1
# Press Ctrl+C to stop
```

### Scheduled Task (Future - v0.1+)

```powershell
# Install scheduled task (run as Administrator)
.\scripts\Install-ScheduledTask.ps1

# Task runs every 30 minutes automatically
# Logs go to: data/logs/watcher-YYYY-MM-DD.log
```

### Check Logs

```powershell
# View latest logs
Get-Content data/logs/watcher-*.log -Tail 50

# Follow logs in real-time
Get-Content data/logs/watcher-*.log -Wait -Tail 20
```

---

## Architecture Overview

**v0.1.0 (Current - Modular):**
```
Scheduler.ps1 (Main Orchestrator)
    ├── src/core/ (Shared utilities, no dependencies)
    │   ├── Helpers.ps1 (JSON, encryption, utilities)
    │   ├── Logging.ps1 (Structured JSON logging)
    │   ├── Config.ps1 (Load & validate config)
    │   └── State.ps1 (State management)
    ├── src/monitors/ (Monitor implementations)
    │   ├── MonitorBase.ps1 (Abstract base class)
    │   ├── CourseMonitor.ps1 (shooting-store.ch)
    │   └── MonitorFactory.ps1 (Factory pattern)
    ├── src/filters/ (Filtering logic)
    │   ├── FilterByType.ps1 (Type matching)
    │   ├── FilterByExclusion.ps1 (Exclusion patterns)
    │   └── FilterPipeline.ps1 (Filter chaining)
    └── src/notifiers/ (Notification channels - v0.2 implementation)
        ├── NotifyEmail.ps1 (Stub)
        ├── NotifyDiscord.ps1 (Stub)
        └── NotifyToast.ps1 (Stub)
```

**Monitoring Pipeline:**
```
1. Load config + state
2. For each monitor: Fetch courses → Apply filters → Detect new/changed
3. Trigger notifications (stubs in v0.1)
4. Update state
```

---

## Troubleshooting

### Issue: "No courses found" (empty result)

**Cause:** shooting-store.ch URL might have changed or website layout changed  
**Solution:**
1. Open `https://www.shooting-store.ch/de/kategorie/kurse1` in browser
2. Verify courses are visible on page
3. Check `data/logs/watcher-*.log` for parsing errors
4. Contact maintainer if HTML structure changed

### Issue: "Failed to fetch" (network error)

**Cause:** Network timeout or website unreachable  
**Solution:**
1. Check internet connection: `Test-NetConnection shooting-store.ch -Port 443`
2. Increase timeout in `config/config.json`: `"timeout_seconds": 60`
3. Check `data/logs/watcher-*.log` for details

### Issue: "Script execution disabled"

**Cause:** PowerShell execution policy too restrictive  
**Solution:**
```powershell
# Check current policy
Get-ExecutionPolicy

# Set to RemoteSigned (safe for local scripts)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Pre-Deployment Security Checklist

Before running in production or with notifications enabled:

**OAuth2 Credentials:**
- [ ] Environment variables set: `IPSC_AZURE_TENANT_ID`, `IPSC_AZURE_CLIENT_ID`, `IPSC_AZURE_USER_ID`
- [ ] Variables set via `setx` or permanent environment (not hardcoded in scripts)
- [ ] No credentials in `config.json`
- [ ] Run `.\scripts\Setup-AzureCredentials.ps1` for interactive setup

**Discord Webhooks (if enabled):**
- [ ] `IPSC_DISCORD_WEBHOOKS` environment variable configured
- [ ] Webhook URL is valid and active
- [ ] Not stored in `config.json`

**Token Cache Security:**
- [ ] `data/.token_cache.json` is encrypted (binary file, not readable JSON)
- [ ] Token cache is excluded from backups of sensitive data
- [ ] `.gitignore` prevents accidental commit

**Logging & Logs:**
- [ ] Log directory has restricted access permissions
- [ ] No credentials appear in `data/logs/watcher-*.log`
- [ ] Run this to verify: `Select-String 'secret|password|token|client_id|tenant' data/logs/* -ErrorAction SilentlyContinue`

**Network:**
- [ ] All OAuth2 requests use HTTPS (no plaintext)
- [ ] Can reach `login.microsoftonline.com` and `graph.microsoft.com`
- [ ] Corporate proxy configured (if applicable)

**Testing:**
- [ ] Test email notification: `.\BasicCourseWatcher.ps1 -RunOnce` (with email enabled)
- [ ] Check logs for errors and credential masking
- [ ] Verify token cache was created and encrypted

**For detailed security configuration:** See [docs/SECURITY.md](docs/SECURITY.md)

---

## Documentation

**Architecture & Design Decisions:**
- [DECISIONS.md](DECISIONS.md) – 9 Architecture Decision Records (ADRs)

**Implementation Rules & Structure:**
- [STRUCTURE.md](STRUCTURE.md) – 18 implementation guidelines

**Collaboration Guidelines:**
- [CLAUDE.md](CLAUDE.md) – Development practices & security rules

---

## Contributing

This is a solo project. For questions or issues:
1. Check [Troubleshooting](#troubleshooting) section
2. Review logs: `data/logs/watcher-*.log`
3. Check [DECISIONS.md](DECISIONS.md) for architectural context

---

## License

[To be determined]

---

## What's Next?

**v0.0.2 → v0.1.0 (Next Phase):**
- Refactor to modular architecture
- Add Email notifications
- Add Discord notifications
- Multi-website support

See [DECISIONS.md](DECISIONS.md) for full roadmap.
