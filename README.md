# IPSC Kurs Watcher – Automated Course Monitoring & Notifications

Automated monitoring and real-time notifications for IPSC courses on shooting-store.ch. Detects new courses, availability changes, and sends alerts via Windows Toast, Email (OAuth2), and Discord webhooks.

**Version:** v1.0.0 (Stable)  
**Status:** ✅ Production Ready  
**Updated:** 2026-07-05

---

## What is IPSC Kurs Watcher?

IPSC Kurs Watcher is a local Windows automation tool that:

1. **Monitors** course availability on shooting-store.ch every 30 minutes
2. **Detects** changes (new courses, reduced slots, sold-out)
3. **Alerts** you via multiple channels (Toast, Email, Discord)
4. **Tracks** state to prevent duplicate notifications
5. **Logs** all activity for debugging and compliance

**Perfect for:** IPSC shooters who want to be notified immediately when new courses open or availability changes.

---

## Current Features (v1.0.0)

### ✅ Core Monitoring
- Automatic course fetching from shooting-store.ch (every 30 minutes)
- HTML parsing and course detail extraction
- Available slots tracking per course
- Real-time change detection (NEW, REDUCED, SOLD_OUT)

### ✅ Smart Notifications
- **Windows Toast** – Desktop notifications (local, instant)
- **Email** – OAuth2 via Microsoft Graph API (reliable, full HTML)
- **Discord** – Webhook notifications (shareable, formatted)
- All channels non-blocking (failure in one doesn't stop others)

### ✅ Deduplication & State
- Course state persistence (data/state.json)
- Prevents duplicate alerts for same course
- Automatic state recovery on corruption

### ✅ Filtering & Control
- Course type matching (Basic, Advanced, Tryout, etc.)
- Exclusion patterns (Privatunterricht, VIP, etc.)
- Minimum availability threshold
- Enable/disable per notification channel

### ✅ Security & Compliance
- DPAPI encryption for OAuth2 tokens
- Credential isolation (environment variables, not config)
- URL validation (no injection attacks)
- Structured JSON logging with sensitive data masking
- GDPR-compliant data handling

### ✅ Operations
- Scheduled Task integration (automatic every 30 minutes)
- Structured JSON logging (30-day auto-rotation)
- Comprehensive error handling and recovery
- Manual testing via PowerShell

### ✅ Documentation
- Complete architecture guides
- Security analysis & threat model
- Deployment procedures (dev & production)
- Operational runbooks & troubleshooting
- Comprehensive test suite (75-80% coverage)

---

## Quick Start (5 Minutes)

### 1. Clone Repository

```powershell
cd C:\Scripts
git clone https://github.com/ZulshiBLN/IPSC-Kurs-Watcher.git
cd IPSC-Kurs-Watcher
```

### 2. Setup Credentials

```powershell
# Interactive setup
.\scripts\Setup.ps1

# Or manual setup
setx IPSC_AZURE_TENANT_ID "your-tenant-id"
setx IPSC_AZURE_CLIENT_ID "your-client-id"
setx IPSC_AZURE_USER_ID "your-user-id"
setx IPSC_DISCORD_WEBHOOKS "https://discord.com/api/webhooks/..."
```

### 3. Test Manually

```powershell
# Test single run
.\Scheduler.ps1 -RunOnce

# Check logs
Get-Content data/logs/watcher-*.log -Tail 50

# Verify notifications received (Toast, Email, Discord)
```

### 4. Deploy to Production (Optional)

```powershell
# Install Scheduled Task (runs every 30 minutes)
.\scripts\Set-ScheduledTask.ps1

# Verify task
Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher"
```

---

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| **PowerShell** | 5.1+ | Windows PowerShell (built-in) |
| **Windows** | 10 / Server 2016+ | For Toast API support |
| **Network** | Any | Outbound HTTPS to shooting-store.ch, login.microsoftonline.com, graph.microsoft.com, discord.com |
| **Disk Space** | 100 MB | Config (~2KB) + State (~50KB) + Logs (~3MB max, auto-rotation) |

---

## Configuration

**File:** `config/config.json`

```json
{
  "monitors": [{
    "id": "shooting-store",
    "provider": "shooting-store",
    "enabled": true,
    "url": "https://www.shooting-store.ch/de/kategorie/kurse1",
    "base_url": "https://www.shooting-store.ch"
  }],
  "filters": {
    "course_types": [
      {"id": "basic", "name": "Basic", "patterns": ["Basic", "Anfänger"]}
    ],
    "exclude_patterns": ["Privatunterricht", "VIP-Kurs"],
    "min_availability": 1
  },
  "notifiers": {
    "windows_toast": {"enabled": true},
    "email": {"enabled": true},
    "discord": {"enabled": true}
  },
  "logging": {
    "log_dir": "data/logs",
    "log_level": "INFO",
    "retention_days": 30,
    "format": "json"
  }
}
```

**See:** [CONFIG_SCHEMA.md](docs/CONFIG_SCHEMA.md) for complete reference

---

## Architecture

**Modular Design:**
```
Scheduler (Orchestrator)
  ├─ Core (Helpers, Logging, Config, State)
  ├─ Monitors (CourseMonitor → MonitorFactory)
  ├─ Filters (Type → Exclusion → Availability)
  └─ Notifiers (Email, Discord, Toast)
```

**Data Flow:**
```
Fetch Courses → Parse HTML → Apply Filters → Change Detection → 
Notifications (parallel) → Persist State → Log Metrics
```

**Performance:** ~8-10 seconds per cycle

**See:** [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed design

---

## Security

✅ **Token Protection** – DPAPI encryption, 1-hour expiry  
✅ **Credential Isolation** – Environment variables, not config  
✅ **URL Validation** – http/https only, no injection  
✅ **Data Sanitization** – Passwords/tokens masked in logs  
✅ **No Code Injection** – Factory patterns, no eval/exec  

**Pre-Deployment Checklist:** [SECURITY.md](docs/SECURITY.md#8-security-hardening-checklist)

---

## Documentation

| Guide | Purpose |
|-------|---------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, modules, data flow |
| [SECURITY.md](docs/SECURITY.md) | Threat model, token protection, security checklist |
| [CONFIG_SCHEMA.md](docs/CONFIG_SCHEMA.md) | Configuration reference with examples |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Step-by-step deployment guide |
| [OPERATIONAL_GUIDE.md](docs/OPERATIONAL_GUIDE.md) | Runbook, troubleshooting, health checks |
| [TESTING.md](docs/TESTING.md) | Test strategy, coverage, regression testing |
| [AUDIT_SUMMARY.md](docs/AUDIT_SUMMARY.md) | Audit findings, recommendations, sign-off |
| [DECISIONS.md](DECISIONS.md) | Architecture Decision Records (ADRs) |
| [STRUCTURE.md](STRUCTURE.md) | Implementation rules & conventions |
| [CLAUDE.md](CLAUDE.md) | Collaboration guidelines & security rules |

---

## Usage

### Manual Testing

```powershell
# Single run (test)
.\Scheduler.ps1 -RunOnce

# Continuous (every 30 min, Ctrl+C to stop)
.\Scheduler.ps1

# View logs
Get-Content data/logs/watcher-*.log -Tail 50

# Check course tracking
Get-Content data/state.json | ConvertFrom-Json | Select-Object -ExpandProperty last_notified
```

### Production Deployment

```powershell
# Install scheduled task
.\scripts\Set-ScheduledTask.ps1

# Verify installation
Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher"

# Uninstall
.\scripts\Remove-ScheduledTask.ps1
```

### Troubleshooting

See [OPERATIONAL_GUIDE.md](docs/OPERATIONAL_GUIDE.md) for:
- Email notification failures
- Discord webhook issues
- Toast notification not appearing
- "No courses found" errors
- Health checks

---

## Roadmap

### v1.1.0 (Next Quarter)
- Notification retry queue (at-least-once delivery)
- Pre-deployment validation (URL reachability, permissions)
- State merge ID collision detection
- Improved test coverage (edge cases, timeouts)

### v2.0.0 (Future)
- Parallel monitor execution
- Multi-website support (extensible)
- WPF configuration GUI
- External monitoring integration (Splunk, Azure Monitor)
- Advanced filtering (regex, time-based, price range)

---

## Changelog & Version History

### v1.0.0 (2026-07-05) – Production Release ✅

**Status:** STABLE – All core features implemented and tested

**Features:**
- ✅ Complete modular architecture (no breaking changes expected)
- ✅ All notification channels (Toast, Email, Discord)
- ✅ State persistence & deduplication
- ✅ Structured JSON logging (30-day rotation)
- ✅ Security hardening (DPAPI, OAuth2, URL validation)
- ✅ Comprehensive documentation (7 guides)
- ✅ Test suite (75-80% coverage, 1,900+ LOC)
- ✅ Deployment scripts (setup, scheduled task)

**Known Limitations:**
- Single monitor only (tested; architecture supports multiple)
- Regex not supported in filters (substring matching only)
- No external monitoring integration (local logs only)
- 30-day log retention (no long-term archive)

**Security:** ⭐⭐⭐⭐⭐ (Audit Grade: A-)  
**Reliability:** ⭐⭐⭐⭐☆ (Test Coverage: 75-80%)

---

### v0.6.0 (2026-07-03) – Audit & Documentation

**Changes:**
- Complete project audit (3,051 LOC review)
- Fixed email architecture (sender/recipients split)
- Fixed null-array bug in Discord embeds
- PowerShell array return from _BuildDiscordEmbeds using comma operator
- Discord webhook posting: serial execution instead of background jobs
- Re-enabled email and Windows toast notifiers

**Status:** Ready for v1.0.0 release

---

### v0.2.0 (2026-06-30) – Discord Webhook Notifications

**Status:** [FEATURE] Discord integration complete

**Features:**
- Discord webhook notifications for course alerts
- Embed-based message formatting (grouped by alert reason)
- Retry logic with exponential backoff (3x: 1s, 2s, 4s)
- Webhook URL from environment variable `IPSC_DISCORD_WEBHOOKS`

**Fixes:**
- Fixed PowerShell array handling in embed building
- Fixed webhook URL validation

---

### v0.1.1 (2026-06-28) – Email & Security

**Status:** [RELEASE] Email notifications stable

**Features:**
- Email notifications via Microsoft Graph API (OAuth2)
- DPAPI token encryption (LocalMachine scope)
- Token auto-refresh (1-hour expiry)
- Error message sanitization (mask passwords/tokens in logs)

**Security:**
- Credentials via environment variables (not in config.json)
- Token cache encrypted and excluded from git
- GDPR-compliant data handling

---

### v0.1.0 (2026-06-25) – Modular Architecture

**Status:** [DEVELOPMENT] Modular redesign

**Changes:**
- Refactored monolithic script → modular architecture
- Created module hierarchy: core → monitors → filters → notifiers
- Implemented factory pattern for monitors
- Added filter pipeline (type, exclusion, availability)
- Added notification infrastructure (stubs for Email, Discord, Toast)

**Modules:**
- Core: Helpers, Logging, Config, State (no dependencies)
- Monitors: MonitorBase, CourseMonitor, MonitorFactory
- Filters: FilterByType, FilterByExclusion, FilterPipeline
- Notifiers: NotifyEmail (stub), NotifyDiscord (stub), NotifyToast (stub)

---

### v0.0.2 (2026-06-20) – MVP Release

**Status:** [RELEASE] Minimum Viable Product

**Features:**
- Course monitoring from shooting-store.ch
- HTML parsing and course extraction
- Availability tracking (free slots per course)
- Change detection (NEW, REDUCED, SOLD_OUT)
- Deduplication (prevent duplicate alerts)
- State persistence (data/state.json)
- Structured JSON logging with rotation (daily, 30-day retention)
- Windows Toast notifications
- Filter system (type matching + exclusions)
- Configuration via JSON

**Known Limitations:**
- No email notifications (v0.1+)
- No Discord notifications (v0.2+)
- No Scheduled Task integration (v1.0+)
- Single monitor only

---

### v0.0.1 (2026-06-15) – Proof of Concept

**Status:** [ALPHA] Experimental

**Features:**
- Basic course fetching from shooting-store.ch
- HTML table parsing via regex
- Simple change detection
- Console output logging

**Not Production Ready** – Used for prototyping and requirement validation

---

## Contributing

This is a solo project maintained by ZulshiBLN (IPSCCourseWatcher@brosche-bausinger.ch).

For questions, suggestions, or issues:
1. Check [OPERATIONAL_GUIDE.md](docs/OPERATIONAL_GUIDE.md) – Troubleshooting section
2. Review [DECISIONS.md](DECISIONS.md) – Architectural context
3. Examine logs: `data/logs/watcher-*.log`

---

## License

[To be determined]

---

## Support & Documentation

**Getting Started:**
1. [Quick Start](#quick-start-5-minutes) (this page)
2. [DEPLOYMENT.md](docs/DEPLOYMENT.md) – Detailed setup
3. [CONFIG_SCHEMA.md](docs/CONFIG_SCHEMA.md) – Configuration reference

**Deployment:**
- [DEPLOYMENT.md](docs/DEPLOYMENT.md) – Step-by-step guide
- [SECURITY.md](docs/SECURITY.md) – Pre-deployment checklist

**Operations:**
- [OPERATIONAL_GUIDE.md](docs/OPERATIONAL_GUIDE.md) – Runbook & troubleshooting
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) – System design & performance

**Development:**
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) – Module design
- [TESTING.md](docs/TESTING.md) – Test strategy & coverage
- [DECISIONS.md](DECISIONS.md) – Architecture decisions
- [STRUCTURE.md](STRUCTURE.md) – Implementation rules

---

## Project Status Summary

| Aspect | v0.0.1 | v0.0.2 | v0.1.0 | v0.1.1 | v0.2.0 | v0.6.0 | v1.0.0 |
|--------|--------|--------|--------|--------|--------|--------|--------|
| **Monitoring** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Change Detection** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Toast Notifications** | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Email Notifications** | ❌ | ❌ | 📋 | ✅ | ✅ | ✅ | ✅ |
| **Discord Notifications** | ❌ | ❌ | 📋 | ❌ | ✅ | ✅ | ✅ |
| **Scheduled Task** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 📋 |
| **Modular Architecture** | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Security Hardening** | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Comprehensive Tests** | ❌ | ❌ | ❌ | 📋 | 📋 | 📋 | ✅ |
| **Full Documentation** | ❌ | ❌ | ❌ | ❌ | ❌ | 📋 | ✅ |

**Legend:** ✅ = Implemented | 📋 = Planned | ❌ = Not yet

---

## Performance Metrics

**Single Monitoring Cycle:**
- **Duration:** 8-10 seconds (typical)
- **Fetch + Parse:** 2-5 seconds
- **Filter + Dedup:** <100ms
- **Notifications:** 1-5 seconds (all parallel)
- **Memory:** 50-100 MB

**Long-Term:**
- **Log Growth:** ~100 KB/month
- **State File:** ~50 KB (auto-maintained)
- **Disk Usage:** <5 MB typical

---

**Made with ❤️ for IPSC shooters**

Latest: v1.0.0 (2026-07-05) | [Full Changelog](#changelog--version-history)
