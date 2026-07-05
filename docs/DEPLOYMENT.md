# Deployment Guide – IPSC Kurs Watcher v1.0.0

**Last Updated:** 2026-07-05  
**Version:** v1.0.0  
**Audience:** Deployment Engineers, System Administrators

---

## Deployment Overview

IPSC Kurs Watcher can be deployed in two modes:

| Mode | Use Case | Frequency | Setup |
|------|----------|-----------|-------|
| **Manual** | Testing, debugging, one-time runs | Ad-hoc | None (just run PowerShell script) |
| **Scheduled** | Production, continuous monitoring | Every 30 minutes | Scheduled Task setup |

---

## Pre-Deployment Checklist

Before deploying to production, complete these checks:

### Environment Requirements

- [ ] **Windows OS:** Windows 10 or Windows Server 2016+ (for Toast API support)
- [ ] **PowerShell:** 5.1+ installed and accessible
- [ ] **Network:** Outbound HTTPS to:
  - shooting-store.ch (course monitoring)
  - login.microsoftonline.com (OAuth2)
  - graph.microsoft.com (Email API)
  - discord.com (Discord webhooks, if enabled)
- [ ] **Disk Space:** At least 100 MB free (logs + state)
- [ ] **User Account:** If running scheduled task:
  - SYSTEM or high-privilege account required (for Toast API)
  - Full access to installation directory

### Credentials & Secrets Setup

- [ ] **Azure AD Tenant ID** obtained from Azure Portal
- [ ] **Azure AD Client ID** for app registration
- [ ] **Azure AD User ID** of account to send emails from
- [ ] **Discord Webhooks** created in Discord server (if Discord enabled)
- [ ] Environment variables created via `setx` (not hardcoded in scripts)
- [ ] Verified credentials work: `.\Scheduler.ps1 -RunOnce` (manual test)

### Configuration Review

- [ ] config.json reviewed and validated
- [ ] Monitor URL points to correct website
- [ ] Course type filters match current curriculum
- [ ] Notification channels enabled/disabled as needed
- [ ] Log retention set appropriately (30 days default)

### Security Hardening

- [ ] Configuration file NOT committed to version control with secrets
- [ ] Environment variables set at machine level (`setx`, not user level)
- [ ] File permissions restricted on installation directory
- [ ] No credentials in PowerShell history or logs
- [ ] Pre-deployment security checklist passed (see [SECURITY.md](SECURITY.md#8-security-hardening-checklist))

---

## Installation Methods

### Method 1: PowerShell Gallery (Recommended)

**Best for:** Production deployments, users who don't need source code access

```powershell
# Install from PowerShell Gallery
Install-Module -Name IPSCKursWatcher -Repository PSGallery

# Verify installation
Get-Module IPSCKursWatcher -ListAvailable

# Run once to test
Invoke-MonitoringCycle
```

**Advantages:**
- ✅ Single command installation
- ✅ Automatic updates via PowerShell
- ✅ Module isolated in PowerShell modules directory
- ✅ Global access via `Invoke-MonitoringCycle`

**Location:** Module installs to `$env:ProgramFiles\WindowsPowerShell\Modules\IPSCKursWatcher\`

### Method 2: Git Clone (Development/Custom)

**Best for:** Development, custom modifications, troubleshooting

```powershell
cd C:\Scripts
git clone https://github.com/ZulshiBLN/IPSC-Kurs-Watcher.git
cd IPSC-Kurs-Watcher

# Test immediately
.\Scheduler.ps1 -RunOnce
```

**Advantages:**
- ✅ Full source code access
- ✅ Easy to modify and debug
- ✅ Local logs visible in `/data/logs`
- ✅ Can run from any directory

---

## Step-by-Step Deployment (Development/Testing)

### 1. Clone Repository

```powershell
cd C:\Scripts
git clone https://github.com/ZulshiBLN/IPSC-Kurs-Watcher.git
cd IPSC-Kurs-Watcher
```

### 2. Verify PowerShell & Dependencies

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion  # Should be 5.1+

# Check execution policy (must allow scripts)
Get-ExecutionPolicy  # Should be RemoteSigned or Unrestricted
if ((Get-ExecutionPolicy) -eq "Restricted") {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
}

# Verify modules available
Import-Module Pester -ErrorAction SilentlyContinue
Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue
```

### 3. Configure Application

```powershell
# Copy template config (if not already present)
if (-not (Test-Path config/config.json)) {
    Copy-Item config/config.example.json config/config.json
}

# Edit configuration
notepad config/config.json
# - Set monitor URL
# - Review filters (course types, exclusions)
# - Enable/disable notification channels
```

### 4. Setup Credentials

**Interactive Setup (Recommended):**
```powershell
.\scripts\Setup.ps1
# Prompts for:
# - Azure Tenant ID
# - Azure Client ID
# - Azure User ID
# - Discord Webhooks (optional)
# Automatically sets environment variables
```

**Manual Setup (Alternative):**
```powershell
# Set at user level (temporary, only for current session)
$env:IPSC_AZURE_TENANT_ID = "00000000-0000-0000-0000-000000000000"
$env:IPSC_AZURE_CLIENT_ID = "11111111-1111-1111-1111-111111111111"
$env:IPSC_AZURE_USER_ID = "22222222-2222-2222-2222-222222222222"

# Set permanently (persists across sessions)
setx IPSC_AZURE_TENANT_ID "00000000-0000-0000-0000-000000000000"
setx IPSC_AZURE_CLIENT_ID "11111111-1111-1111-1111-111111111111"
setx IPSC_AZURE_USER_ID "22222222-2222-2222-2222-222222222222"
```

### 5. Validate Configuration

```powershell
# Run linting & tests
.\build.ps1 -Validate
# Output: Summary of linting errors, syntax checks, tests

# Run manual test cycle
.\Scheduler.ps1 -RunOnce
# Expected: [INFO] Monitoring cycle completed successfully
```

### 6. Review Logs

```powershell
# View last 50 log entries
Get-Content data/logs/watcher-*.log -Tail 50

# Search for errors
Get-Content data/logs/watcher-*.log | Select-String "ERROR"
```

### 7. Test Notifications (Optional)

```powershell
# Manual test of each channel
.\Scheduler.ps1 -RunOnce -TestNotifications $true
# Should trigger Toast, Email, and Discord

# Or run individual notifier tests
.\Scheduler.ps1 -RunOnce -Notifiers @("Toast", "Email", "Discord")
```

---

## Step-by-Step Deployment (Production/Scheduled)

### 1. Follow Development Deployment Steps 1-6

All the setup, configuration, and validation above applies.

### 2. Install Scheduled Task

**Important:** If using Git Worktrees (local development), point the task to the `main/` worktree only.

```powershell
# Run as Administrator (required)
# Path must point to main/ worktree (production-stable branch)
$taskPath = "C:\Repos\IPSC Kurs Watcher\main\Scheduler.ps1"

# Create task pointing to main/ worktree
.\scripts\Set-ScheduledTask.ps1 -ScriptPath $taskPath

# Creates task "IPSC-Kurs-Watcher"
# Trigger: Every 30 minutes
# Principal: SYSTEM
# Action: PowerShell -NoProfile -Command "& 'C:\Repos\IPSC Kurs Watcher\main\Scheduler.ps1' -RunOnce"
```

**Why the `main/` path?**
- Main branch is production-stable (thoroughly tested)
- Develop/Prerelease branches are not stable for production
- Scheduled Task will always use the stable version
- Development in other branches won't interfere with production monitoring

**See also:** [LOCAL_WORKTREE_SETUP.md](LOCAL_WORKTREE_SETUP.md) for complete Git Worktree configuration.

### 3. Verify Task Installation

```powershell
# Check task exists
Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher"

# Check task configuration
Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher" | Select-Object -ExpandProperty Triggers
Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher" | Select-Object -ExpandProperty Actions

# Check last run status
Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher" | Select-Object LastTaskResult, LastRunTime
# LastTaskResult: 0 = success, non-zero = error
```

### 4. Wait for First Scheduled Run

- Task will run at next 30-minute interval
- Check logs: `Get-Content data/logs/watcher-*.log -Tail 50`
- Verify emails/Discord/Toast received

### 5. Monitor for 24 Hours

```powershell
# Check cycles are running
(Get-Content data/logs/watcher-*.log | 
  Select-String '"message":"Monitoring cycle completed"' | 
  Measure-Object).Count  # Should show multiple cycles

# Check for errors
Get-Content data/logs/watcher-*.log | Select-String "ERROR"
# Should be empty or rare
```

---

## Deployment Verification

### Health Check (After Deployment)

```powershell
# 1. Task is installed and enabled
Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher" | 
  Select-Object TaskName, State, LastRunTime, LastTaskResult

# 2. Logs are being generated
Get-ChildItem data/logs/watcher-*.log | Select-Object Name, Length, LastWriteTime

# 3. State file exists and is being updated
Get-Item data/state.json | Select-Object Length, LastWriteTime

# 4. No repeated errors
$errorCount = (Get-Content data/logs/watcher-*.log | 
  Select-String '"level":"ERROR"' | 
  Measure-Object).Count
if ($errorCount -gt 5) { Write-Warning "Multiple errors detected" }
else { Write-Output "[OK] Errors: $errorCount (acceptable)" }

# 5. Token cache exists and is DPAPI-encrypted (binary)
if (Test-Path data/.token_cache.json) {
    $bytes = [System.IO.File]::ReadAllBytes("data/.token_cache.json")
    Write-Output "[OK] Token cache exists, size: $($bytes.Length) bytes (binary)"
}
```

### Functional Verification

After 24 hours of running:

```powershell
# 1. Multiple cycles completed
$cycles = Get-Content data/logs/watcher-*.log | 
  Select-String '"message":"Monitoring cycle completed"' | 
  Measure-Object
Write-Output "Cycles completed: $($cycles.Count) (should be >= 24 for 24h)"

# 2. Alerts were generated
$alerts = Get-Content data/logs/watcher-*.log | 
  Select-String '"alert_reason"' | 
  Measure-Object
Write-Output "Total alerts: $($alerts.Count)"

# 3. No catastrophic failures
$errors = Get-Content data/logs/watcher-*.log | 
  Select-String '"level":"ERROR"' | 
  Measure-Object
if ($errors.Count -eq 0) {
    Write-Output "[OK] No errors (perfect)"
} elseif ($errors.Count -lt 5) {
    Write-Output "[WARN] Errors: $($errors.Count) (minor, monitor)"
} else {
    Write-Output "[ERROR] Errors: $($errors.Count) (investigate)"
}
```

---

## Post-Deployment Steps

### Documentation

1. **Record Installation Details:**
   - Installation date: __________
   - PowerShell version: __________
   - Installation path: __________
   - Scheduled Task status: __________
   - First run completed: __________

2. **Create Runbook:**
   - Document any customizations made
   - Document credential setup process
   - Store backups of config.json

### Monitoring & Alerting (Optional)

Setup external monitoring:

```powershell
# Export logs to external monitoring system (e.g., Splunk, ELK)
# Example: JSON logs easily parseable by external tools

# Setup health check alert:
# If task hasn't run in > 60 minutes, alert
# If error count > threshold, alert
```

### Scheduled Maintenance

```powershell
# Daily: 5 min
# - Check for errors: Get-Content data/logs/watcher-*.log | Select-String ERROR
# - Verify task still running: Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher"

# Weekly: 15 min
# - Review alerts: Get-Content data/logs/watcher-*.log | Select-String "alert_reason"
# - Check disk usage: Get-ChildItem data/logs/ | Measure-Object -Sum Length
# - Review config (any changes needed?): Notepad config/config.json

# Monthly: 30 min
# - Archive logs if compliance required
# - Rotate credentials (Discord webhooks, Azure app)
# - Review and update course filters
```

---

## Uninstallation / Rollback

### Uninstall Scheduled Task

```powershell
.\scripts\Remove-ScheduledTask.ps1
# Removes "IPSC-Kurs-Watcher" task from Windows Task Scheduler
```

### Complete Cleanup

```powershell
# 1. Remove scheduled task
.\scripts\Remove-ScheduledTask.ps1

# 2. Delete application directory (optional)
Remove-Item C:\Scripts\IPSC-Kurs-Watcher -Recurse -Force

# 3. Delete logs and state (optional)
# (only if completely removing)

# 4. Clear environment variables
$env:IPSC_AZURE_TENANT_ID = ""
$env:IPSC_AZURE_CLIENT_ID = ""
$env:IPSC_AZURE_USER_ID = ""
$env:IPSC_DISCORD_WEBHOOKS = ""
# (persistent removal requires user to manually remove from Registry)
```

---

## Troubleshooting Deployment

### Scheduled Task Won't Start

**Symptoms:**
- Task created, but LastRunTime remains blank
- LastTaskResult: 2147750695 (0x80041309) or similar error

**Diagnosis:**
```powershell
Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher" | Get-ScheduledTaskInfo
# LastTaskResult should be 0 (success)

# Check task XML for issues
Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher" | Export-ScheduledTask | Out-File task.xml
notepad task.xml  # Review XML structure
```

**Fix:**
- Run task manually: `Start-ScheduledTask -TaskName "IPSC-Kurs-Watcher"`
- Check PowerShell execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned`
- Verify file paths in script: Check if `Scheduler.ps1` path is correct
- Run as administrator: `cmd.exe` → `runas /user:SYSTEM powershell.exe`

### Token Cache Not Created

**Symptoms:**
- Email notification fails
- No `data/.token_cache.json` file

**Diagnosis:**
```powershell
# Check if OAuth2 token requested
Get-Content data/logs/watcher-*.log | Select-String "OAuth2\|token"

# Check environment variables are set
$env:IPSC_AZURE_TENANT_ID
$env:IPSC_AZURE_CLIENT_ID
```

**Fix:**
- Re-run Setup: `.\scripts\Setup.ps1`
- Manually set env vars: `setx IPSC_AZURE_TENANT_ID "..."`
- Run manual test: `.\Scheduler.ps1 -RunOnce` (will request token)

### Notifications Not Sending

See [OPERATIONAL_GUIDE.md - Error Scenarios](OPERATIONAL_GUIDE.md#error-scenarios--responses)

---

## Deployment Checklist (TL;DR)

- [ ] PowerShell 5.1+ installed
- [ ] Network connectivity tested (HTTPS to all endpoints)
- [ ] Credentials configured (via `setx` or Setup.ps1)
- [ ] config.json reviewed and validated
- [ ] Manual test run successful (`.\Scheduler.ps1 -RunOnce`)
- [ ] Build validation passed (`.\build.ps1 -Validate`)
- [ ] Logs reviewed (no critical errors)
- [ ] Scheduled Task installed (`.\scripts\Set-ScheduledTask.ps1`)
- [ ] First scheduled run confirmed in logs
- [ ] Health check passed (24-hour monitor)
- [ ] Documentation recorded

---

## References

- [SECURITY.md](SECURITY.md) – Security hardening checklist
- [CONFIG_SCHEMA.md](CONFIG_SCHEMA.md) – Configuration reference
- [OPERATIONAL_GUIDE.md](OPERATIONAL_GUIDE.md) – Runtime operations
- [ARCHITECTURE.md](ARCHITECTURE.md) – System design
