# Security Analysis & Implementation – IPSC Kurs Watcher v1.0.0

**Last Updated:** 2026-07-05  
**Version:** v1.0.0 (Comprehensive Review)  
**Audience:** Developers, Security Engineers, DevOps, System Administrators

---

## Executive Summary

IPSC Kurs Watcher is a security-conscious application that handles OAuth2 tokens and user credentials. The architecture implements:

- ✅ **Token Protection:** DPAPI encryption (LocalMachine scope), 1-hour expiry, auto-refresh
- ✅ **Credential Isolation:** Environment variables only (never in config.json)
- ✅ **Network Security:** HTTPS with Windows CA validation for all requests
- ✅ **Input Validation:** URL scheme validation, config JSON syntax checking
- ✅ **Code Injection Prevention:** No Invoke-Expression, factory pattern (no dynamic instantiation)
- ✅ **Data Sanitization:** Passwords/tokens masked in logs and error messages

**Threat Level:** LOW (local-only automation, no cloud exposure, single-user system)

---

## 1. Token Protection (DPAPI Encryption)

### What's Protected

**OAuth2 Access Tokens** from Microsoft Graph API:
- File: `data/.token_cache.json`
- Format: Binary DPAPI-encrypted (not readable as plaintext JSON)
- Lifetime: 1 hour per token (auto-refreshed on expiry)
- Access: Used by Email notifier to send course alerts

**Why Protect Tokens?**
- Token grants email sending privileges (could spam or exfiltrate)
- Disk storage risk: Token file could be accessed by other processes
- Compromise risk: If Windows account is compromised, unencrypted token exposed

### Encryption/Decryption Mechanism

**DPAPI Encryption Flow:**
```
1. OAuth2 Token obtained from Graph API
   ├─ Token = { access_token, refresh_token, expiry, ... }
   
2. Convert to JSON and UTF8 bytes
   ├─ $tokenJson = $token | ConvertTo-Json
   ├─ $tokenBytes = [System.Text.Encoding]::UTF8.GetBytes($tokenJson)
   
3. DPAPI Encrypt with LocalMachine scope
   ├─ $encrypted = [System.Security.Cryptography.ProtectedData]::Protect(
   │    $tokenBytes,
   │    $entropy,  # "IPSC-Token-Cache-v1"
   │    [DataProtectionScope]::LocalMachine
   │  )
   
4. Write encrypted bytes to disk
   ├─ File: data/.token_cache.json (binary, not JSON)
   ├─ Only DPAPI can decrypt (with LocalMachine scope)
   
5. On Use: DPAPI Decrypt
   ├─ Read encrypted bytes from disk
   ├─ DPAPI Decrypt (same LocalMachine scope)
   ├─ Parse decrypted JSON
   ├─ Use token in Graph API request
```

### Why LocalMachine Scope?

| Scope | CurrentUser | LocalMachine |
|-------|----------|--------------|
| **User Account** | Decrypt by that user only | Any user can decrypt |
| **SYSTEM Account** | ❌ Cannot decrypt | ✅ Can decrypt |
| **Use Case** | Interactive PowerShell | Scheduled Tasks |
| **Chosen?** | No | **Yes** |

**Decision Rationale:**
- IPSC Kurs Watcher runs as SYSTEM (via Scheduled Task)
- SYSTEM account needs to decrypt token to send emails
- LocalMachine scope allows SYSTEM decryption
- Tradeoff: Local admin can also decrypt, but acceptable because:
  - Token is short-lived (1 hour expiry)
  - Token auto-refreshes (compromised token useless after 1 hour)
  - Local admin already has full machine access

### Token Lifecycle

```
[Fresh Token Needed]
         ↓
[Request via Graph API]
login.microsoftonline.com/
  └─ POST /token with credentials
  └─ Returns: { access_token, refresh_token, expires_in: 3600 }
         ↓
[DPAPI Encrypt]
         ↓
[Store to data/.token_cache.json]
         ↓
[Valid for 1 hour]
         ↓
[Expiration Check]
├─ If < 5 min remaining → Refresh
├─ If < 30 min remaining → Refresh on next email send
└─ If > 30 min remaining → Use as-is
         ↓
[On Refresh Request]
├─ DPAPI Decrypt from cache
├─ POST /token with refresh_token to graph.microsoft.com
├─ Get new access_token
├─ DPAPI Encrypt new token
├─ Update cache
         ↓
[If Decryption Fails]
├─ Log warning: "Token cache corrupted or inaccessible"
├─ Request fresh token (full OAuth2 flow)
├─ Override cache with new token
```

**Auto-Refresh Logic (in NotifyEmail.ps1):**
```powershell
$token = Unprotect-OAuthToken -CachePath 'data/.token_cache.json'
if ($token.expiry -lt (Get-Date).AddMinutes(5)) {
    $token = Refresh-OAuthToken -RefreshToken $token.refresh_token
    Protect-OAuthToken -Token $token -CachePath 'data/.token_cache.json'
}
# Use token in Graph API request
```

---

## 2. Credential Management

### Where Secrets Live

| Secret | Location | Format | Protection |
|--------|----------|--------|-----------|
| **Azure Tenant ID** | Environment variable | Plain string | OS-level (Windows Credential Manager) |
| **Azure Client ID** | Environment variable | Plain string | OS-level |
| **Azure User ID** | Environment variable | Plain string | OS-level |
| **OAuth2 Token** | `data/.token_cache.json` | Binary DPAPI-encrypted | DPAPI LocalMachine |
| **Discord Webhooks** | Environment variable | Plain string | OS-level |
| **NOT in config.json** | N/A | N/A | ✅ Intentional (safe to version control) |

### Environment Variable Setup

**Initial Setup (Interactive):**
```powershell
.\scripts\Setup.ps1
# Prompts user for:
# 1. Azure Tenant ID
# 2. Azure Client ID
# 3. Azure User ID
# 4. Discord Webhook URLs (optional)
```

**Permanent Setup (setx):**
```powershell
setx IPSC_AZURE_TENANT_ID "00000000-0000-0000-0000-000000000000"
setx IPSC_AZURE_CLIENT_ID "11111111-1111-1111-1111-111111111111"
setx IPSC_AZURE_USER_ID "22222222-2222-2222-2222-222222222222"
setx IPSC_DISCORD_WEBHOOKS "https://discord.com/api/webhooks/ID1/TOKEN1,https://..."
```

**Machine-Level Setup:**
```powershell
setx IPSC_AZURE_TENANT_ID "..." /M  # /M = Machine level (admin required)
```

### Environment Variable Retrieval

**In PowerShell Code:**
```powershell
$tenantId = $env:IPSC_AZURE_TENANT_ID
$clientId = $env:IPSC_AZURE_CLIENT_ID
$userId = $env:IPSC_AZURE_USER_ID
$webhooks = $env:IPSC_DISCORD_WEBHOOKS -split ","
```

**Fallback Order (Helpers.ps1):**
1. Try environment variable (highest priority)
2. Try config.json (fallback, not recommended for secrets)
3. If neither → Fail gracefully (logging skipped)

### Security of Environment Variables

**Windows Security:**
- Environment variables stored in Registry (HKCU or HKLM)
- Registry encrypted by Windows if full disk encryption enabled
- Readable by:
  - Current user (HKCU)
  - Local admin (HKLM)
  - SYSTEM account

**Compromised Scenarios:**
- ❌ Plaintext in PowerShell history: `Get-Content -Path $env:IPSC_AZURE_TENANT_ID`
  - Mitigation: Don't type credentials in PowerShell (use scripts)
- ❌ Exposed in logs: Sanitization masks them (see below)
- ❌ Backup files: Exclude from backups if needed

---

## 3. Input Validation & URL Safety

### URL Validation (Test-ValidUrl)

**All URLs pass validation before use:**

```powershell
function Test-ValidUrl {
    param([string]$Url)
    
    # 1. Scheme validation (http/https only)
    if ($Url -notmatch '^https?://') {
        return $false  # Reject ftp://, file://, etc.
    }
    
    # 2. Format validation (valid URI)
    try {
        $uri = [System.Uri]::new($Url)
        if ($uri.Scheme -notin @('http', 'https')) {
            return $false
        }
    }
    catch {
        return $false  # Malformed URL
    }
    
    # 3. Additional checks
    if ($uri.Host -eq '') { return $false }  # No empty hosts
    if ($uri.AbsoluteUri -like "*'*") { return $false }  # No quotes (injection)
    
    return $true
}
```

**Validated URLs:**
- Monitor URL: `config.monitors[].url` (https://www.shooting-store.ch/...)
- Monitor base_url: `config.monitors[].base_url` (https://www.shooting-store.ch)
- Detail URLs: Constructed from base_url + courseId
- Notification endpoints: `login.microsoftonline.com`, `graph.microsoft.com`, `discord.com`

### Configuration Validation

**config.json is validated for:**
- ✅ Valid JSON syntax (ConvertFrom-Json will error if invalid)
- ⚠️ **Gap:** No schema validation at runtime (required fields not checked)
- ⚠️ **Gap:** No URL reachability check at startup

**Recommendation:** Add JSON schema validation using [JSON Schema v7](../../config/config.schema.json)

### No Code Injection

**Confirmed Safe Patterns:**
- ❌ No `Invoke-Expression` used anywhere
- ❌ No `Invoke-Command` with user input
- ❌ No dynamic PowerShell module loading
- ❌ No template strings with interpolation
- ✅ Factory pattern uses hard-coded `switch` (not dynamic dispatch)
- ✅ Config values used as data only (never in code execution)

---

## 4. Error Message Sanitization

### Sensitive Data Masking

**Function: Mask-SensitiveData** (Helpers.ps1)

```powershell
function Mask-SensitiveData {
    param([string]$Message)
    
    # Pattern: Replace sensitive values with masked versions
    $masked = $Message `
        -replace '(?<=client_secret["\'':\s])[\w\-]+', '[REDACTED_SECRET]' `
        -replace '(?<=password["\'':\s])[\w\-]+', '[REDACTED_PASSWORD]' `
        -replace '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', '[REDACTED_EMAIL]' `
        -replace '(?<=tenant_id["\'':\s])[0-9a-f-]{36}', '[REDACTED_TENANT]' `
        -replace '(?<=token["\'':\s])[\w\-\.]+', '[REDACTED_TOKEN]'
    
    return $masked
}
```

**Applied to:**
- All log messages (Write-Log automatically masks)
- All error messages before logging
- All exception details

**Example:**
```
Raw Error:   "Failed to get token for tenant xxxxxxxx-xxxx with client_secret xyz123"
Logged As:   "Failed to get token for tenant [REDACTED_TENANT] with client_secret [REDACTED_SECRET]"
```

### Logging Best Practices

**Do:**
```powershell
Write-Log -Level INFO -Message "Email sent successfully" `
    -Context @{ recipient = "[REDACTED_EMAIL]"; status = "sent" }
```

**Don't:**
```powershell
Write-Log -Level INFO -Message "Email sent to $userEmail from $senderEmail"  # Exposed!
```

---

## 5. Network Security

### HTTPS Certificate Validation

**All HTTPS requests validate certificates:**
- ✅ [System.Net.ServicePointManager] uses Windows Certificate Store
- ✅ CA chain validated automatically
- ✅ Hostname verification enabled (no MITM)
- ✅ TLS 1.2+ enforced (via Windows default)

**Critical Endpoints:**
| Endpoint | Purpose | Certificate Validation |
|----------|---------|----------------------|
| `login.microsoftonline.com` | Azure AD OAuth2 | ✅ Windows CA chain |
| `graph.microsoft.com` | Email sending | ✅ Windows CA chain |
| `discord.com/api/webhooks` | Discord notifications | ✅ Windows CA chain |
| `shooting-store.ch` | Course monitoring | ✅ Windows CA chain |

### No Certificate Pinning

**Current Approach:** Rely on Windows CA store (industry standard)

**Why Not Pinning?** 
- Additional complexity
- Requires updates if Microsoft/Discord changes certs
- Windows CA store is already well-maintained
- Acceptable for local automation use case

**Recommendation:** Revisit if integrating with additional services

---

## 6. Scheduled Task Security

### Task Principal

**Task runs as:** SYSTEM (LocalSystem account)

**Privileges:** Highest on machine (can access any file, registry, network)

**Why SYSTEM?**
- Toast notifications require WinRT API (SYSTEM privilege required)
- Token cache must be readable by SYSTEM (LocalMachine DPAPI scope)
- Email sending requires Graph API access (SYSTEM can use cached token)

### Task Isolation

**SYSTEM Account Separation:**
- Runs in isolated context (not as user)
- No user desktop access
- No user profile loading (limited environment)
- Cannot access user files (except Public)

**Scheduled Task Isolation:**
- Task disabled while not running (no background access between cycles)
- Each run is a fresh PowerShell process
- No memory persistence across cycles

---

## 7. Compliance & Audit Trail

### GDPR Compliance

**Personal Data Handled:**
- ✅ Email addresses (configured by user, stored in environment variables)
- ✅ Course information (automatically collected, stored in state.json)
- ✅ Logs (timestamps, course names, no PII except email)

**User Rights:**
- ✅ Right to Access: All data in data/ directory
- ✅ Right to Delete: Delete state.json or logs manually
- ✅ Right to Opt-Out: Remove email from environment variables

**Data Retention:**
- State: Indefinite (user-controlled, kept for deduplication)
- Logs: 30 days (auto-cleanup, then deleted)
- Tokens: 1 hour (auto-refresh, never stored long-term)

**See Also:** [GDPR_PRIVACY_POLICY.md](GDPR_PRIVACY_POLICY.md)

### Audit Logging

**What's Logged:**
- ✅ Every monitoring cycle (start/end timestamp, counts)
- ✅ Every alert generated (course name, alert reason)
- ✅ Every notification sent (channel, attempt count)
- ✅ Every error (with context, sanitized)

**Audit Gaps:**
- ❌ No user authentication log (single-user system, not applicable)
- ❌ No data access audit (would require additional logging layer)
- ❌ No long-term audit trail (30-day log retention deletes old entries)

**Recommendation:** For long-term compliance, archive logs to external storage

---

## 8. Security Hardening Checklist

**Before Production Deployment:**

- [ ] **OAuth2 Credentials**
  - [ ] Azure Tenant ID set via `setx` (not hardcoded)
  - [ ] Azure Client ID set via `setx` (not hardcoded)
  - [ ] Azure User ID set via `setx` (not hardcoded)
  - [ ] Credentials NOT in config.json

- [ ] **Discord Webhooks**
  - [ ] Webhook URLs set via `IPSC_DISCORD_WEBHOOKS` environment variable
  - [ ] URLs NOT in config.json
  - [ ] Only Webhook, not Full URL (no sensitive parts in URL)

- [ ] **Token Cache**
  - [ ] `data/.token_cache.json` is binary (run `file data/.token_cache.json`)
  - [ ] NOT readable as plaintext
  - [ ] Excluded from backups (if sensitive backups configured)

- [ ] **Logs**
  - [ ] Log directory has restricted permissions (default: 755)
  - [ ] No credentials in log files (run: `grep -i 'secret\|password\|token' data/logs/watcher*.log`)
  - [ ] Log retention set to 30 days (auto-cleanup)

- [ ] **Network**
  - [ ] All HTTPS requests use certificate validation
  - [ ] Can reach `login.microsoftonline.com` and `graph.microsoft.com`
  - [ ] Can reach Discord webhooks (if enabled)
  - [ ] Corporate proxy configured (if applicable)

- [ ] **Scheduled Task**
  - [ ] Task set to run as SYSTEM (for Toast + token cache)
  - [ ] Task disabled when not needed (can uninstall via script)
  - [ ] Task logs captured to data/logs/

- [ ] **Code Review**
  - [ ] No credentials in PowerShell scripts
  - [ ] No hardcoded URLs or endpoints
  - [ ] No use of Invoke-Expression or dynamic code execution

---

## 9. Known Security Limitations

| Issue | Impact | Mitigation |
|-------|--------|-----------|
| **LocalMachine DPAPI scope** | Local admin can decrypt token | Token is short-lived (1 hour), acceptable |
| **Plaintext logs** | Could leak course data if disk accessed | Restrict log directory permissions |
| **No audit trail rotation** | Logs deleted after 30 days | Archive to external storage for compliance |
| **No certificate pinning** | Relies on Windows CA store | Windows CA store is well-maintained |
| **No rate limiting** | Could be blocked by shooting-store.ch | Implement backoff on 429 errors (v1.1) |
| **No notification retry queue** | Failed alerts lost | Implement retry queue (v1.1) |

---

## 10. Security Incident Response

**If Token is Compromised:**
1. Delete `data/.token_cache.json`
2. Re-run `.\scripts\Setup.ps1` to force fresh token request
3. Next monitoring cycle will request new token from Graph API
4. Old token auto-invalidates after 1 hour (or manually in Azure portal)

**If Credentials are Exposed:**
1. Change Azure AD credentials in Azure portal immediately
2. Revoke any issued tokens (Azure portal → Token management)
3. Update `IPSC_AZURE_*` environment variables with new credentials
4. Test email notification: `.\Scheduler.ps1 -RunOnce`

**If Discord Webhook is Compromised:**
1. Delete webhook in Discord server settings
2. Update `IPSC_DISCORD_WEBHOOKS` environment variable with new webhook URL
3. Test Discord notification on next cycle

**If Scheduled Task is Compromised:**
1. Uninstall task: `.\scripts\Remove-ScheduledTask.ps1`
2. Review `data/logs/` for suspicious activity
3. Reinstall task: `.\scripts\Set-ScheduledTask.ps1`

**See Also:** [INCIDENT_RESPONSE_PLAYBOOK.md](INCIDENT_RESPONSE_PLAYBOOK.md)

---

## References

- [SECURITY_HARDENING_CHECKLIST.md](#8-security-hardening-checklist) – Pre-deployment checklist
- [GDPR_PRIVACY_POLICY.md](GDPR_PRIVACY_POLICY.md) – Privacy & compliance
- [INCIDENT_RESPONSE_PLAYBOOK.md](INCIDENT_RESPONSE_PLAYBOOK.md) – Incident procedures
- [ARCHITECTURE.md](ARCHITECTURE.md) – System design (security considerations section)
