# Security Guidelines – IPSC Kurs Watcher

Comprehensive security implementation for IPSC Kurs Watcher (v0.1.1+).

---

## Overview

IPSC Kurs Watcher handles sensitive information:
- **OAuth2 Access Tokens** (valid for 1 hour, can access email account)
- **Azure AD Credentials** (Tenant ID, Client ID, User ID)
- **Discord Webhook URLs** (can post to Discord channels)

This document describes how these are protected.

---

## 1. Token Cache Encryption (DPAPI)

### What It Protects

OAuth2 access tokens obtained from Microsoft Graph API are stored in a token cache file:
- **File:** `data/.token_cache.json`
- **Format:** Binary DPAPI-encrypted content (not human-readable JSON)
- **Lifetime:** 1 hour per token (auto-refreshed on expiry)

### How It Works

**Encryption (saving token):**
```powershell
# Token JSON is converted to UTF8 bytes
$tokenJson = $token | ConvertTo-Json

# Encrypted with DPAPI (LocalMachine scope)
$tokenBytes = [System.Text.Encoding]::UTF8.GetBytes($tokenJson)
$encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
    $tokenBytes,
    [System.Text.Encoding]::UTF8.GetBytes("IPSC-Token-Cache-v1"),
    [System.Security.Cryptography.DataProtectionScope]::LocalMachine
)

# Encrypted bytes written to disk
[System.IO.File]::WriteAllBytes($cacheFile, $encryptedBytes)
```

**Decryption (loading token):**
```powershell
# Read encrypted bytes from disk
$encryptedBytes = [System.IO.File]::ReadAllBytes($cacheFile)

# Decrypt with DPAPI (same LocalMachine scope)
$decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
    $encryptedBytes,
    [System.Text.Encoding]::UTF8.GetBytes("IPSC-Token-Cache-v1"),
    [System.Security.Cryptography.DataProtectionScope]::LocalMachine
)

# Parse decrypted JSON
$tokenJson = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
$token = $tokenJson | ConvertFrom-Json
```

### Why LocalMachine Scope?

- **LocalMachine:** Can be decrypted by any user on the machine, AND by SYSTEM account
- **CurrentUser:** Can only be decrypted by the current user (Scheduled Tasks running as SYSTEM fail)

Since IPSC Kurs Watcher can run via Windows Scheduled Task (as SYSTEM), we use **LocalMachine scope**.

**Security tradeoff:** Any local admin can decrypt the token, but this is acceptable because:
- Token is short-lived (1 hour)
- Token is auto-refreshed (compromised token becomes useless quickly)
- Local admin already has full machine access

### Migration from Old Config

If you have plaintext tokens from v0.1.0:
1. First run with v0.1.1 will fail to decrypt old token
2. This triggers automatic OAuth2 token refresh
3. New token is encrypted and cached
4. Delete old `data/.token_cache.json` (plaintext version)

No manual action needed – it's automatic.

---

## 2. Environment Variables for Secrets

### Why Environment Variables?

Credentials should **NOT** be in `config.json` because:
- Config file might be version-controlled
- Config file might be backed up to shared storage
- Config file might be logged or cached

### Required Variables

**For Email Notifications:**
```powershell
$env:IPSC_AZURE_TENANT_ID      # Azure AD Tenant ID (UUID format)
$env:IPSC_AZURE_CLIENT_ID      # Azure AD Application Client ID
$env:IPSC_AZURE_USER_ID        # Azure AD User ID (your user object ID)
```

**For Discord Notifications (Optional):**
```powershell
$env:IPSC_DISCORD_WEBHOOKS     # Comma-separated webhook URLs
                               # Example: "https://discord.com/api/webhooks/123/abc,https://discord.com/api/webhooks/456/def"
```

**Optional (Custom Credential Storage):**
```powershell
$env:IPSC_CREDENTIAL_STORE_PATH # Directory for encrypted credentials
                                # Default: %APPDATA%\IPSC-Kurs-Watcher\credentials
```

### Setting Environment Variables

**Temporary (current session only):**
```powershell
$env:IPSC_AZURE_TENANT_ID = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
```

**Persistent (Windows environment):**
```powershell
setx IPSC_AZURE_TENANT_ID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
setx IPSC_AZURE_CLIENT_ID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
setx IPSC_AZURE_USER_ID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
setx IPSC_DISCORD_WEBHOOKS 'https://discord.com/api/webhooks/123/abc'
```

**Interactive Setup (Recommended):**
```powershell
.\scripts\Setup-AzureCredentials.ps1
```

### Reading Environment Variables

Code reads from env vars with fallback to config:
```powershell
# Read from environment first
$tenantId = $env:IPSC_AZURE_TENANT_ID

# Fallback to config.json (backward compatibility)
if (-not $tenantId) {
    $tenantId = $config.notifiers.email.azure_tenant_id
}
```

**Priority order:**
1. Environment variable (IPSC_AZURE_TENANT_ID) – takes precedence
2. config.json – fallback (not recommended for production)
3. Missing → Error logged, feature disabled

---

## 3. URL Validation

### What It Prevents

URL injection attacks where a malformed URL could:
- Redirect to malicious server
- Bypass HTTPS enforcement
- Access internal file URLs (file://)
- Use unsupported protocols

### Implementation

Function: `Test-ValidUrl` in `src/core/Helpers.ps1`

**Rules:**
```powershell
Test-ValidUrl -Url 'https://www.example.com/path'  # Returns: $true
Test-ValidUrl -Url 'http://example.com/api'        # Returns: $true
Test-ValidUrl -Url 'ftp://files.example.com'       # Returns: $false (unsupported scheme)
Test-ValidUrl -Url '/relative/path'                # Returns: $false (relative URL)
Test-ValidUrl -Url 'not a url'                     # Returns: $false (malformed)
```

**Allowed schemes:**
- `http://` – HTTP (deprecated but allowed for old sites)
- `https://` – HTTPS (recommended)

**Blocked schemes:**
- `ftp://`, `gopher://`, `file://`, etc.
- Any non-HTTP/HTTPS protocol

### Usage in Code

Before making web requests:
```powershell
# CourseMonitor.ps1 – Fetch course detail page
if (-not (Test-ValidUrl -Url $detailUrl)) {
    Write-Log -Level WARN -Message "Invalid URL detected, skipping" `
        -Context @{ url = $detailUrl }
    continue
}
$response = Invoke-SecureWebRequest -Uri $detailUrl
```

---

## 4. HTTPS Certificate Validation

### What It Prevents

Man-in-the-middle (MITM) attacks on critical OAuth2 endpoints:
- **login.microsoftonline.com** – Azure AD authentication
- **graph.microsoft.com** – Microsoft Graph API (email sending)

### Implementation

Function: `Invoke-SecureWebRequest` in `src/core/Helpers.ps1`

**Validates:**
1. **Certificate Chain:** Windows validates against system CA store
2. **Certificate Expiration:** Verified by Windows
3. **Domain Matching:** Certificate CN/SAN must match hostname
4. **Revocation Status:** CRL/OCSP check (if enabled in Windows)

**Logs critical endpoints:**
```powershell
# Audit trail of all OAuth2 traffic
Write-Log -Level DEBUG -Message "Secure web request" `
    -Context @{ endpoint = 'login.microsoftonline.com'; method = 'POST' }
```

### Usage Pattern

```powershell
# Instead of: Invoke-WebRequest ...
# Use: Invoke-SecureWebRequest ...

$response = Invoke-SecureWebRequest `
    -Uri 'https://graph.microsoft.com/v1.0/users/user123/sendMail' `
    -Method POST `
    -Headers @{ 'Authorization' = "Bearer $accessToken" } `
    -Body $emailJson
```

### Certificate Pinning (Future)

Currently, we rely on Windows CA validation. For additional hardening:
- Store expected certificate fingerprints
- Verify certificate hash matches
- Reject even valid certificates from unexpected CAs

This would require future enhancement (ADR-010 note).

---

## 5. Error Message Sanitization

### What It Protects

OAuth2 error responses might contain sensitive information:
- `client_secret: xyz123abc`
- `client_id: app-client-id`
- `tenant_id: tenant-guid`
- User email addresses

These should be masked before logging.

### Implementation

Function: `Protect-OAuthError` in `src/core/Helpers.ps1`

**Example:**
```powershell
# Raw error from OAuth2 API:
$rawError = "Error: invalid client_secret abc123xyz for tenant_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Sanitized version:
$sanitized = Protect-OAuthError -ErrorMessage $rawError
# Result: "Error: invalid client_secret: [REDACTED_SECRET] for tenant_id: [REDACTED_TENANT]"

# Log the sanitized version
Write-Log -Level ERROR -Message "OAuth2 failed" -Context @{ error = $sanitized }
```

**Patterns masked:**
| Pattern | Replacement |
|---------|------------|
| `client_secret: <value>` | `client_secret: [REDACTED_SECRET]` |
| `client_id: <value>` | `client_id: [REDACTED_ID]` |
| `tenant_id: <value>` | `tenant_id: [REDACTED_TENANT]` |
| `user@example.com` | `[REDACTED_EMAIL]` |

### Usage in Error Handling

```powershell
# In OAuth2 token refresh error handler:
try {
    $token = Get-AzureOAuthToken -ClientId $clientId -ClientSecret $secret -TenantId $tenantId
}
catch {
    $sanitizedError = Protect-OAuthError -ErrorMessage $_.Exception.Message
    Write-Log -Level WARN -Message "Token refresh failed" `
        -Context @{ error = $sanitizedError }
}
```

---

## Security Checklist

Before deploying to production:

- [ ] **OAuth2 Credentials Set**
  - [ ] `IPSC_AZURE_TENANT_ID` configured (not in config.json)
  - [ ] `IPSC_AZURE_CLIENT_ID` configured (not in config.json)
  - [ ] `IPSC_AZURE_USER_ID` configured (not in config.json)
  - [ ] Variables set via `setx` or environment (not hardcoded)

- [ ] **Discord Webhooks (if enabled)**
  - [ ] `IPSC_DISCORD_WEBHOOKS` set in environment
  - [ ] Not stored in config.json
  - [ ] Test webhook URL is valid (try send test message)

- [ ] **Token Cache**
  - [ ] `data/.token_cache.json` exists and is encrypted (binary, not JSON)
  - [ ] `.gitignore` excludes `data/.token_cache.json`
  - [ ] No plaintext tokens in logs or config

- [ ] **Logging**
  - [ ] Log files do not contain credentials
  - [ ] Error messages are sanitized (no client_secret in logs)
  - [ ] Logs are rotated and archived securely (30-day retention)

- [ ] **Network Security**
  - [ ] All requests to Azure/Graph use HTTPS (no http://)
  - [ ] DNS resolution works (can reach login.microsoftonline.com)
  - [ ] Corporate proxy configured if needed

- [ ] **Access Control**
  - [ ] Only authorized users have access to credential store
  - [ ] Token cache is on encrypted disk (if production requirement)
  - [ ] config.json has restricted read permissions

- [ ] **Testing**
  - [ ] Test email notification end-to-end
  - [ ] Test Discord notification end-to-end
  - [ ] Check logs for credential leakage: `Select-String 'secret|password|token' data/logs/*`
  - [ ] Verify token refresh works (wait 1+ hour or mock)

---

## Incident Response

### If Token Leaks

If `data/.token_cache.json` is exposed:
1. Revoke token in Azure: Sign in to Azure Portal → App registrations → Client credentials → Revoke
2. Delete leaked token cache: `Remove-Item data/.token_cache.json`
3. Restart watcher (will request new token via OAuth2)
4. Check logs for suspicious activity

### If Client Secret Leaks

If `IPSC_AZURE_CLIENT_ID` or `IPSC_AZURE_TENANT_ID` is exposed:
1. These are low-risk (needed for OAuth2 but not secret alone)
2. Focus on `IPSC_AZURE_USER_ID` (identifies which account was compromised)
3. Follow Azure AD incident response procedures

### If Discord Webhook Leaks

If `IPSC_DISCORD_WEBHOOKS` is exposed:
1. Delete the webhook immediately in Discord Server Settings → Integrations → Webhooks
2. Generate new webhook URL
3. Update `IPSC_DISCORD_WEBHOOKS` environment variable
4. Restart watcher

---

## References

- [ADR-010: Security & Credential Management](../DECISIONS.md) – Architectural decisions
- [CLAUDE.md](../CLAUDE.md) – Rule 1.2 (Validation at boundaries)
- [STRUCTURE.md](../STRUCTURE.md) – Implementation standards
- Microsoft Graph API Documentation: https://docs.microsoft.com/graph
- DPAPI Overview: https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.protecteddata
