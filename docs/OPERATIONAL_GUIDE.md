# Operational Guide & Runbook – IPSC Kurs Watcher v1.0.0

**Last Updated:** 2026-07-05  
**Version:** v1.0.0  
**Audience:** System Administrators, DevOps, Support Engineers

---

## Quick Reference

| Scenario | Command | Time to Resolve |
|----------|---------|-----------------|
| **Test manual run** | `.\Scheduler.ps1 -RunOnce` | <1 min |
| **View recent logs** | `Get-Content data/logs/watcher-*.log -Tail 50` | <1 min |
| **View all alerts** | `Get-Content data/logs/watcher-*.log \| Select-String "alert_reason"` | <1 min |
| **Check monitoring status** | `Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher"` | <1 min |
| **Reset course tracking** | `Remove-Item data/state.json` | <1 min |
| **Clear token cache** | `Remove-Item data/.token_cache.json` (will refresh on next run) | <1 min |
| **Troubleshoot monitoring** | See [Troubleshooting](#troubleshooting) section | 5-15 min |
| **Full health check** | See [Health Check](#health-check) section | 5-10 min |

---

## State Management & Recovery

### Understanding state.json

**Purpose:** Track courses that have already been alerted on (deduplication).

**File:** `data/state.json`

**Structure:**
```json
{
  "version": 1,
  "last_poll": "2026-07-05T14:30:00Z",
  "last_notified": [
    {
      "id": "IPSC Basic 2.0|05.08.2026|09:30-13:00",
      "name": "IPSC Basic 2.0",
      "date": "05.08.2026",
      "time": "09:30-13:00",
      "availability": 3,
      "url": "https://...",
      "notified_at": "2026-07-05T14:30:00Z"
    }
  ]
}
```

**How It Works:**
1. On each cycle, current courses fetched from website
2. New courses compared against `last_notified[]`
3. If course NOT in `last_notified[]` → NEW alert
4. If course in `last_notified[]` but availability decreased → REDUCED alert
5. All current courses written back to `last_notified[]` for next cycle

### Resetting State (Fresh Start)

**When to Reset:**
- First deployment (courses incorrectly appear as "new")
- After extended downtime (want to clear accumulated changes)
- If state file is corrupted

**How to Reset:**
```powershell
Remove-Item data/state.json
.\Scheduler.ps1 -RunOnce
# All courses will appear as NEW in next cycle
```

**Consequence:** All currently available courses will trigger NEW alerts (one-time).

### State Corruption Recovery

**Symptoms:**
- Logs show: `"State file corrupted"`
- All courses triggering NEW alerts repeatedly
- state.json file is empty or malformed

**Recovery Steps:**
1. Backup corrupted file: `Copy-Item data/state.json data/state.json.backup`
2. Delete corrupted file: `Remove-Item data/state.json`
3. Next cycle auto-initializes fresh state
4. Analyze backup if debugging needed

---

## Error Scenarios & Responses

### Scenario 1: Monitor Fetch Fails (Website Down)

**Symptom:**
```
[ERROR] Monitor execute failed: Network timeout after 3 retries
context: { monitor: "shooting-store", url: "https://...", error: "Timeout" }
```

**What Happens:**
- Current cycle skips this monitor (non-fatal)
- Other monitors still run (fault isolation)
- Next cycle retries (auto-recovery)

**What to Do:**
- Check website reachability: `Test-NetConnection shooting-store.ch -Port 443`
- Verify network connectivity
- Wait 30 minutes for next cycle (or run manual: `.\Scheduler.ps1 -RunOnce`)
- Check logs for pattern (repeated failures = real issue)

**If Persistent:**
- Verify URL in config.json: `Get-Content config/config.json | Select-String "url"`
- Check firewall rules (if behind proxy)
- Contact website owner if site is actually down

### Scenario 2: Email Notification Fails (OAuth2 Token Issue)

**Symptom:**
```
[ERROR] Email send failed: Failed to get OAuth2 token
context: { error: "Invalid credentials or tenant not found" }
```

**What Happens:**
- Email notification skipped (non-fatal)
- Discord/Toast notifications still sent (independent channels)
- Error logged with context

**What to Do:**
1. Delete token cache: `Remove-Item data/.token_cache.json`
2. Run manual test: `.\Scheduler.ps1 -RunOnce`
3. First run will request fresh token (interactive prompt)
4. If prompt fails, check environment variables:
   ```powershell
   $env:IPSC_AZURE_TENANT_ID     # Should not be empty
   $env:IPSC_AZURE_CLIENT_ID     # Should not be empty
   $env:IPSC_AZURE_USER_ID       # Should not be empty
   ```

**If Still Failing:**
- Run setup script: `.\scripts\Setup.ps1` (re-configure credentials)
- Verify credentials in Azure Portal (check tenant/client IDs)
- Check network (can reach login.microsoftonline.com?)

### Scenario 3: Discord Webhook Fails (Invalid URL)

**Symptom:**
```
[WARN] Discord webhook retry attempt 1/3
context: { webhook: "https://discord.com/...", error: "404 Not Found" }
```

**What Happens:**
- Discord notification retried 3x (exponential backoff: 1s, 2s, 4s)
- After 3 failures, logged as warning and skipped
- Email/Toast notifications still sent

**What to Do:**
1. Test webhook manually: `curl -X POST <webhook_url> -H "Content-Type: application/json" -d '{"content":"test"}'`
2. If 404: Webhook URL is invalid or deleted
3. Create new webhook in Discord: Server → Webhooks → New Webhook
4. Update environment variable: `setx IPSC_DISCORD_WEBHOOKS "<new_webhook_url>"`
5. Test: `.\Scheduler.ps1 -RunOnce`

### Scenario 4: Toast Notification Not Appearing

**Symptom:**
- No Toast on screen
- Logs show: `[INFO] Toast notification sent` (but not visible)

**What Happens:**
- Toast API is platform-dependent (Windows 10+ only)
- Could be disabled in Windows settings
- Could be throttled by Windows (too many notifications)

**What to Do:**
1. Check Windows version: `[Environment]::OSVersion.Version`
   - Must be Windows 10 or later
   - Windows 7/8 not supported
2. Check Toast settings:
   - Settings → System → Notifications & actions → Notifications → ON
3. Check app notifications disabled:
   - Settings → System → Notifications → Scroll down → Find PowerShell
   - Ensure PowerShell notifications enabled
4. Check Do Not Disturb:
   - Settings → System → Notifications → "Do Not Disturb" ON?

---

## Monitoring & Health Checks

### Health Check (Manual)

```powershell
# 1. Check Scheduled Task status
Get-ScheduledTask -TaskName "IPSC-Kurs-Watcher" | Select-Object State, LastTaskResult, LastRunTime

# 2. Check recent logs (last 50 lines)
Get-Content data/logs/watcher-*.log -Tail 50

# 3. Run manual test cycle
.\Scheduler.ps1 -RunOnce

# 4. Check state.json (courses being tracked)
Get-Content data/state.json | ConvertFrom-Json | Select-Object -ExpandProperty last_notified | Measure-Object

# 5. Check error count in logs
(Get-Content data/logs/watcher-*.log | Select-String '"level":"ERROR"' | Measure-Object).Count
```

### Automated Health Metrics

**Last Cycle Duration:**
```powershell
# Parse last log entry
$log = Get-Content data/logs/watcher-*.log -Tail 1 | ConvertFrom-Json
$log.context.duration_ms  # Milliseconds for last cycle
```

**Course Tracking:**
```powershell
# Count courses being monitored
(Get-Content data/state.json | ConvertFrom-Json).last_notified.Count
```

**Alert Trend:**
```powershell
# Count NEW alerts in last 24 hours
$yesterday = (Get-Date).AddDays(-1)
Get-Content data/logs/watcher-*.log | 
  Select-String '"alert_reason":"NEW"' |
  Where-Object { [datetime]::Parse($_.Line | ConvertFrom-Json | Select-Object timestamp) -gt $yesterday } |
  Measure-Object
```

---

## Performance Tuning

### Cycle Duration Optimization

**Current Bottlenecks (in order):**
1. HTTP fetches (2-5 sec): Depends on website response time
2. Notifications (1-5 sec): Depends on email/Discord API response
3. Parsing (< 1 sec): Regex-based, fast
4. Filtering (<100ms): In-memory, fast
5. State persistence (<100ms): File write

**Optimization Options:**

| Area | Change | Impact | Difficulty |
|------|--------|--------|-----------|
| **Monitor timeout** | Decrease from 30s to 15s | Faster failure, possible timeouts | Easy |
| **Poll interval** | Change 30 min to 15 min | More monitoring, more load | Easy |
| **Notification retry** | Disable retry (set to 1) | Faster cycle, possible lost alerts | Easy |
| **Parallel monitors** | Run multiple monitors concurrently | Not yet implemented (v2.0) | Hard |
| **Caching** | Cache course list for N minutes | More stale data, risk missed courses | Medium |

### Log Rotation Tuning

**Current:** 30-day retention, daily rotation

**To Change:**
```json
"logging": {
  "retention_days": 7    // Keep only 7 days
}
```

**Impact:**
- Less disk usage (~700 KB per 7 days)
- Less historical data for debugging
- Automatic cleanup still works

---

## Regular Maintenance Tasks

### Daily Checks (5 minutes)

```powershell
# Check for errors in last 24 hours
$today = (Get-Date).Date
Get-Content data/logs/watcher-*.log | 
  Select-String '"level":"ERROR"' |
  ForEach-Object { $_ | ConvertFrom-Json } |
  Where-Object { [datetime]::Parse($_.timestamp) -gt $today }
```

### Weekly Audit (10 minutes)

```powershell
# 1. Count total cycles run
(Get-Content data/logs/watcher-*.log | 
  Select-String '"message":"Monitoring cycle completed"' | 
  Measure-Object).Count

# 2. Count total alerts sent
(Get-Content data/logs/watcher-*.log | 
  Select-String '"alert_reason"' | 
  Measure-Object).Count

# 3. Check disk usage
Get-Item data/logs/ | ForEach-Object { [math]::Round($_.FullName -as [long] / 1MB, 2) }
```

### Monthly Maintenance (30 minutes)

1. **Log Archive** (if compliance required):
   ```powershell
   $oldLogs = Get-ChildItem data/logs/ -Filter "watcher-*.log" | 
     Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
   # Archive $oldLogs to external storage
   ```

2. **Credentials Rotation** (if sensitive):
   - Review Discord webhook access logs (if available)
   - Rotate Discord webhook (regenerate URL) if desired
   - Review Azure app permissions (Azure Portal)

3. **Config Review**:
   - Verify all configured monitors still exist
   - Verify all patterns still match current courses
   - Adjust filters if curriculum changed

---

## Troubleshooting

### "No courses found" (0 courses detected)

**Possible Causes:**
1. Website structure changed → Regex parser broken
2. Website is down → Network timeout
3. Course catalog is temporarily empty
4. URL is wrong → 404 or 403

**Diagnosis:**
```powershell
# 1. Test website reachability
Invoke-WebRequest -Uri "https://www.shooting-store.ch/de/kategorie/kurse1" -TimeoutSec 10

# 2. Check URL in config.json
Get-Content config/config.json | Select-String "url"

# 3. Inspect HTML manually
$html = Invoke-WebRequest -Uri "..." -TimeoutSec 10
$html.RawContent | Select-String "course" | Select-Object -First 5
```

**Fix:**
- If website structure changed, update CourseMonitor.ps1 regex patterns
- If URL wrong, update config.json
- If website down, wait and retry

### "Failed to send email" (repeated)

**Possible Causes:**
1. OAuth2 token expired → Need refresh
2. Azure app no longer has permissions
3. Graph API endpoint changed or blocked
4. Network issue (can't reach login.microsoftonline.com)

**Diagnosis:**
```powershell
# 1. Check credentials are set
$env:IPSC_AZURE_TENANT_ID; $env:IPSC_AZURE_CLIENT_ID

# 2. Test network to Graph endpoint
Test-NetConnection -ComputerName "login.microsoftonline.com" -Port 443

# 3. Delete token cache, force refresh
Remove-Item data/.token_cache.json
.\Scheduler.ps1 -RunOnce
```

**Fix:**
- Run `.\scripts\Setup.ps1` to re-authenticate
- Check Azure Portal for app permissions
- Check network/proxy configuration

### "High memory usage" or "Process hangs"

**Symptoms:**
- Memory > 200 MB
- Cycle takes > 60 seconds
- CPU at 100% for extended time

**Possible Causes:**
1. Website returns huge HTML (parsing slow)
2. Infinite loop in filter logic (unlikely, but possible)
3. Large state.json file (thousands of courses tracked)

**Diagnosis:**
```powershell
# Monitor process memory
$proc = Get-Process | Where-Object Name -like "*powershell*"
$proc.WorkingSet / 1MB  # MB

# Check state file size
(Get-Item data/state.json).Length / 1MB  # MB
```

**Fix:**
- Reset state if > 100 MB: `Remove-Item data/state.json`
- Reduce poll interval if website slow
- Check for network issues (DNS resolution slow?)

---

## Backup & Disaster Recovery

### What to Backup

| File/Folder | Importance | Backup Frequency |
|-------------|-----------|-----------------|
| `config/config.json` | CRITICAL | Once (configuration) |
| `data/state.json` | HIGH | Optional (deduplication) |
| `data/logs/` | MEDIUM | Optional (historical, auto-deleted) |
| `data/.token_cache.json` | MEDIUM | Optional (DPAPI-encrypted, auto-refreshed) |

### Backup Strategy

```powershell
# Backup configuration (safe to version control)
Copy-Item config/config.json backups/config.backup.json

# Backup state (optional, for disaster recovery)
Copy-Item data/state.json backups/state.backup.json

# Backup logs (optional, for compliance/audit)
Copy-Item data/logs/ backups/logs-$(Get-Date -Format yyyyMMdd)/ -Recurse
```

### Restore from Backup

```powershell
# Restore configuration
Copy-Item backups/config.backup.json config/config.json

# Restore state (will continue from saved point)
Copy-Item backups/state.backup.json data/state.json

# Restore logs (for historical analysis)
Copy-Item backups/logs-*/ data/logs/ -Recurse
```

---

## Performance Metrics & Trending

### Key Metrics to Track

```powershell
# Export metrics to CSV
$metrics = Get-Content data/logs/watcher-*.log | 
  ConvertFrom-Json |
  Where-Object { $_.message -like "*cycle*" } |
  Select-Object @{N="timestamp"; E={$_.timestamp}},
                @{N="duration_ms"; E={$_.context.duration_ms}},
                @{N="new_courses"; E={$_.context.new}},
                @{N="total_courses"; E={$_.context.total_tracked}}

$metrics | Export-Csv "metrics-$(Get-Date -Format yyyyMMdd).csv" -NoTypeInformation
```

### Expected Ranges (Healthy System)

| Metric | Healthy Range | Alert If |
|--------|---|---|
| Cycle Duration | 5-15 seconds | > 60 seconds |
| NEW Alerts | 0-5 per cycle | > 10 (may indicate spam) |
| REDUCED Alerts | 0-3 per cycle | > 5 |
| Errors per Cycle | 0 | Any (investigate) |
| Successful Cycles | 100% | < 95% |

---

## References

- [SECURITY.md](SECURITY.md) – Credential management, incident response
- [DEPLOYMENT.md](DEPLOYMENT.md) – Installation & deployment procedures
- [ARCHITECTURE.md](ARCHITECTURE.md) – System design, error handling strategy
- [CONFIG_SCHEMA.md](CONFIG_SCHEMA.md) – Configuration reference
