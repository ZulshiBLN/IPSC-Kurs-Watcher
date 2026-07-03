# Data Retention Policy – IPSC Kurs Watcher

**Version:** 1.0  
**Effective Date:** 2026-07-04  
**GDPR Compliance:** Article 5(1)(e) – Data Minimization

---

## 1. Overview

This policy defines how long IPSC Kurs Watcher retains data and how users can control deletion.

**Principle:** Keep data only as long as necessary (GDPR data minimization).

---

## 2. Retention Schedule

| Data Type | Location | Retention Period | Auto-Cleanup | User Delete |
|-----------|----------|------------------|--------------|-------------|
| **Email Configuration** | config/config.json | Indefinite | No | Yes (edit file) |
| **Course State** | data/state.json | Indefinite | No | Yes (delete file) |
| **System Logs** | data/logs/*.log | 30 days | Yes | Yes (delete folder) |
| **OAuth2 Tokens** | data/.token_cache.json | 1 hour | Yes (auto-refresh) | N/A (encrypted) |

---

## 3. Email Addresses (config/config.json)

**What:** Sender email address + recipient email addresses

**How Long:** Indefinite (until user removes from configuration)

**Why:** Necessary for sending notifications; user-controlled

**Deletion:** 
```bash
# Edit config/config.json
# Remove your email from "sender" and "recipients" fields
# Save file
```

**Automatic Deletion:** No (user must manually edit)

---

## 4. Course State (data/state.json)

**What:** Course names, dates, times, availability, URLs, notification timestamps

**How Long:** Indefinite (until user deletes)

**Why:** Necessary for deduplication (prevents duplicate alerts)

**Deletion:**
```powershell
# Option 1: Delete file
Remove-Item data/state.json

# Option 2: Empty file (only after full backup)
"" | Out-File data/state.json -Encoding UTF8
```

**Effect of Deletion:**
- All course history lost
- Next monitoring run treats all courses as "new"
- Users may receive repeat alerts for same courses
- New state.json auto-created on next run

**Automatic Deletion:** No (user must manually delete)

---

## 5. System Logs (data/logs/*.log)

**What:** Monitoring events, errors, course counts, timestamps

**How Long:** **30 days maximum** (auto-deleted)

**Why:** 
- Sufficient for debugging (~4 weeks of history)
- GDPR data minimization (not indefinite)
- Prevents accidental disk fill-up

**Automatic Cleanup:**
```powershell
# Runs automatically at application startup
# Deletes all logs older than 30 days
# File: src/core/Logging.ps1 - Remove-OldLogs function
```

**Retention Days:** Configurable in config.json
```json
{
  "logging": {
    "retention_days": 30  // Change to 7, 60, or other value
  }
}
```

**Manual Deletion:**
```powershell
# Delete entire logs directory
Remove-Item data/logs -Recurse -Force

# Or delete specific file
Remove-Item data/logs/watcher-2026-07-01.log
```

**Note:** New log files auto-generated on next application run.

---

## 6. OAuth2 Tokens (data/.token_cache.json)

**What:** JWT access tokens from Azure AD (valid for email API)

**How Long:** **1 hour** (auto-expires and refreshes)

**Why:** 
- Short-lived tokens minimize security risk
- Auto-refresh prevents manual token management
- If token compromised, usable only for ~1 hour

**Automatic Refresh:**
```powershell
# Token refreshed every 30 minutes (before expiry)
# Old token encrypted and discarded
# New token encrypted and cached
```

**Encryption:** DPAPI LocalMachine scope (binary format, not readable)

**No Manual Action Required:** Automatic process.

---

## 7. Data Cleanup Procedures

### 7.1 Monthly Maintenance

**Recommended:** Run once per month to manage disk space.

```powershell
# 1. Check log size
Get-ChildItem data/logs -Recurse | Measure-Object -Sum Length

# 2. Automatic cleanup (runs on app startup, but manual run also ok)
# Logs older than 30 days already deleted

# 3. Optional: Reset state if too large
# If data/state.json > 10MB:
Remove-Item data/state.json
```

### 7.2 Privacy Deletion Request (User)

**Procedure if user requests complete data deletion:**

```powershell
# Step 1: Stop application
Stop-ScheduledTask -TaskName "IPSC-Kurs-Watcher" -Confirm:$false

# Step 2: Backup (optional, for archival)
Copy-Item data/ -Destination "data-backup-$(Get-Date -Format yyyyMMdd)" -Recurse

# Step 3: Delete personal data
Remove-Item data/ -Recurse -Force
New-Item -ItemType Directory -Path data -Force | Out-Null

# Step 4: Delete config with email addresses (optional)
Remove-Item config/config.json

# Step 5: Restart application
Start-ScheduledTask -TaskName "IPSC-Kurs-Watcher"
```

### 7.3 Compliance Data Disposal

**If audit/incident requires archival:**

```powershell
# Export current logs before 30-day deletion
Copy-Item data/logs/ -Destination "logs-archive-2026-07-04" -Recurse

# Optional: Encrypt archive before storage
# (Out of scope for this tool, use Windows EFS or similar)

# Keep archive: As required by your compliance policy
```

---

## 8. Storage Considerations

### 8.1 Disk Space Usage

**Typical Monthly Growth:**
- **Logs:** ~5-10 MB per month (150 MB over 30 days)
- **State:** ~1-5 KB (stable, not growing)
- **Total:** ~10 MB per month, capped at ~150 MB (30-day retention)

**After 30 Days:**
- Old logs auto-deleted
- Disk usage stabilizes (~150 MB max)
- No cleanup needed by user

### 8.2 Disk Full Mitigation

**If disk becomes full:**

1. **Reduce retention period:**
   ```json
   {
     "logging": {
       "retention_days": 7  // Instead of 30
     }
   }
   ```

2. **Manually delete old logs:**
   ```powershell
   Get-ChildItem data/logs/*.log | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } | Remove-Item
   ```

3. **Reset state (if large):**
   ```powershell
   Remove-Item data/state.json  # Will be recreated
   ```

---

## 9. GDPR Compliance Checklist

Before deployment, verify:

- [ ] **Data Inventory:** Users informed of what data is collected (GDPR Privacy Policy)
- [ ] **Retention Schedule:** Policy documented for each data type (this document)
- [ ] **Auto-Cleanup:** Logs deleted after 30 days (automatic)
- [ ] **User Rights:** Users can delete their email addresses + state (documented)
- [ ] **Right to Erasure:** Complete deletion procedure available (Section 7.2)
- [ ] **Data Minimization:** Only collecting necessary data (Article 5)
- [ ] **No Excess Storage:** After 30 days, logs capped (~150 MB)

---

## 10. Policy Changes

**If retention requirements change:**

1. Update this document (version + date)
2. Update config.json default if needed
3. Notify users of any changes
4. Provide 30-day notice before reducing retention (may affect users)

---

## References

- [GDPR_PRIVACY_POLICY.md](GDPR_PRIVACY_POLICY.md) – Full privacy policy
- [ARCHITECTURE.md](ARCHITECTURE.md) – Data flow diagram
- GDPR Article 5(1)(e) – Data minimization: https://gdpr-info.eu/art-5-gdpr/

---

**Version:** 1.0  
**Last Updated:** July 4, 2026  
**Status:** Active
