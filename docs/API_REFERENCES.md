# API References & External Dependencies

Complete documentation of all external APIs and third-party services used by IPSC Kurs Watcher.

---

## 1. Microsoft Azure AD (OAuth2)

### Purpose
Authentication and email sending via Microsoft Graph API.

### Endpoint Details

**Token Acquisition:**
- **URL:** `https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token`
- **Method:** POST
- **Headers:** `Content-Type: application/x-www-form-urlencoded`
- **Body Parameters:**
  - `client_id` – Azure AD Application Client ID
  - `client_secret` – Application Client Secret (stored in credential store)
  - `scope` – Requested permissions (e.g., `https://graph.microsoft.com/.default`)
  - `grant_type` – Always `client_credentials`

**Response:**
```json
{
  "access_token": "eyJ0eXAi...",  // JWT token (valid 1 hour)
  "expires_in": 3599,               // Seconds until expiry
  "token_type": "Bearer"
}
```

**Error Handling:**
- Invalid credentials → `invalid_client` error
- Expired credentials → Request new token
- Network timeout → Retry 3x with exponential backoff

### Implementation Location
- **File:** `src/notifiers/NotifyEmail.ps1`
- **Functions:** `_GetOAuthToken`, `_RefreshOAuthToken`
- **Token Cache:** `data/.token_cache.json` (DPAPI encrypted)

### Required Configuration

**Environment Variables:**
```powershell
$env:IPSC_AZURE_TENANT_ID      # UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
$env:IPSC_AZURE_CLIENT_ID      # UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
$env:IPSC_AZURE_USER_ID        # UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (resource owner)
```

**Setup Instructions:**
1. Register app in Azure AD: https://portal.azure.com
2. Create application secret (credential)
3. Grant permission: `Mail.Send` in Microsoft Graph API
4. Set environment variables
5. First run will acquire OAuth2 token

---

## 2. Microsoft Graph API (Email)

### Purpose
Send email notifications via user's mailbox.

### Endpoint Details

**Send Mail:**
- **URL:** `https://graph.microsoft.com/v1.0/users/{USER_ID}/sendMail`
- **Method:** POST
- **Headers:**
  - `Authorization: Bearer {ACCESS_TOKEN}`
  - `Content-Type: application/json`

**Request Body:**
```json
{
  "message": {
    "subject": "IPSC Course Alert",
    "body": {
      "contentType": "HTML",
      "content": "<html>...</html>"  // Sanitized HTML
    },
    "toRecipients": [
      { "emailAddress": { "address": "user@example.com" } }
    ],
    "from": {
      "emailAddress": { "address": "sender@example.com" }
    }
  },
  "saveToSentItems": true
}
```

**Response:**
- Success: HTTP 202 (Accepted)
- Error: HTTP 400 (Bad request), 401 (Unauthorized), 403 (Forbidden), 500 (Server error)

### Implementation Location
- **File:** `src/notifiers/NotifyEmail.ps1`
- **Function:** `Send-EmailNotification`
- **Email Formatting:** HTML template with sanitized course data

### Rate Limiting
- **Throttling:** Microsoft Graph API has rate limits (~2000 requests/minute per app)
- **Mitigation:** Email sending is infrequent (max ~20 emails per 30-min cycle)
- **Current Status:** Not a concern for this usage pattern

---

## 3. Shooting-Store.ch (Web Scraping)

### Purpose
Monitor course availability by scraping HTML from the website.

### Endpoint Details

**Category Page:**
- **URL:** `https://www.shooting-store.ch/de/kategorie/kurse1`
- **Method:** GET
- **Headers:** Standard User-Agent (no authentication needed)
- **Returns:** HTML with course listings

**Course Detail Page:**
- **URL:** `https://www.shooting-store.ch/de/produkt/{course-slug}`
- **Method:** GET
- **Returns:** HTML with availability status

### HTML Structure
- Category page contains course link stubs
- Course slugs extracted via regex: `href="/de/produkt/([^"]+)"`
- Detail pages parsed for: availability slots, date, time, price

### Implementation Location
- **File:** `src/monitors/CourseMonitor.ps1`
- **Functions:** `Get-CoursesFromShootingStore`, `_ParseHtmlPage`, `_ExtractCourseDetails`

### Resilience
- **Timeout:** 30 seconds per request
- **Retries:** 3x with exponential backoff (1s, 2s, 4s)
- **Failure Handling:** Log error, skip this cycle, retry next interval

### HTML Parsing Strategy
- **No DOM library:** Pure PowerShell regex + string manipulation
- **Fragility:** Layout changes can break parsing
- **Mitigation:** Regular testing against live website
- **Test fixtures:** Sample HTML stored in `tests/fixtures/html/`

---

## 4. Discord Webhooks

### Purpose
Send course alert notifications to Discord channels.

### Endpoint Details

**Send Message:**
- **URL:** `https://discord.com/api/webhooks/{WEBHOOK_ID}/{WEBHOOK_TOKEN}`
- **Method:** POST
- **Headers:** `Content-Type: application/json`
- **Body:** Discord embed payload

**Example Payload:**
```json
{
  "embeds": [
    {
      "title": "IPSC Basic 2.0",
      "description": "New course available!",
      "fields": [
        { "name": "Date", "value": "2026-08-08", "inline": true },
        { "name": "Time", "value": "09:30-13:00", "inline": true },
        { "name": "Slots", "value": "3", "inline": true },
        { "name": "URL", "value": "[Book Now](https://...)" }
      ],
      "color": 3066993  // Green
    }
  ]
}
```

**Response:**
- Success: HTTP 204 (No Content)
- Error: HTTP 400 (Bad request), 404 (Webhook not found), 429 (Rate limit)

### Implementation Location
- **File:** `src/notifiers/NotifyDiscord.ps1`
- **Function:** `Send-DiscordNotification` (stub in v0.1, full in v0.2+)
- **Status:** Currently not fully implemented

### Webhook Management
- **Creation:** Discord Server → Server Settings → Integrations → Webhooks → Create
- **Credentials:** Webhook URL is secret (like a password)
- **Storage:** Environment variable `IPSC_DISCORD_WEBHOOKS` (NOT config.json)
- **Revocation:** Delete webhook in Discord if compromised

### Rate Limiting
- **Throttling:** Discord allows ~5 requests per webhook per 5 seconds
- **Current Status:** Not a concern (max ~20 notifications per 30-min cycle)

---

## 5. Windows Notification Center (Toast)

### Purpose
Local desktop toast notifications (no internet required).

### API Details

**Windows Toast API:**
- **Type:** WinRT (Windows Runtime)
- **Namespace:** `Windows.UI.Notifications`
- **Classes:** `ToastNotificationManager`, `ToastNotification`
- **XML Format:** Toast notification template (customizable)

**Example Toast:**
```xml
<toast>
  <visual>
    <binding template="ToastText02">
      <text id="1">IPSC Course Alert</text>
      <text id="2">IPSC Basic 2.0 – 2026-08-08, 09:30-13:00 (3 slots)</text>
    </binding>
  </visual>
</toast>
```

### Implementation Location
- **File:** `src/notifiers/NotifyToast.ps1`
- **Function:** `Send-ToastNotification`
- **Status:** Fully implemented

### Resilience
- **No network:** Always succeeds (local API)
- **No authentication:** No credentials needed
- **User permission:** Shows in notification center automatically

---

## 6. Windows File System

### Purpose
Store configuration, state, and logs locally.

### Key Paths

**Configuration:**
- **File:** `config/config.json`
- **Format:** JSON
- **Read:** On every startup (via `Get-Config`)
- **Schema:** `config/config.schema.json`

**State Persistence:**
- **File:** `data/state.json`
- **Format:** JSON
- **Read/Write:** Every monitoring cycle
- **Backup:** Auto-backup on corruption (`.backup.YYYYMMDD`)

**Logging:**
- **Directory:** `data/logs/`
- **File Pattern:** `watcher-YYYY-MM-DD.log`
- **Format:** JSON (one entry per line)
- **Rotation:** Daily at 00:00
- **Retention:** 30 days (auto-cleanup)

**Token Cache:**
- **File:** `data/.token_cache.json`
- **Format:** Binary DPAPI-encrypted (not human-readable)
- **Protection:** `.gitignore` prevents accidental commit

### Windows Permissions
- **Location:** `C:\Scripts\IPSC-Kurs-Watcher\` (recommended)
- **Permissions:** Readable/writable by SYSTEM account (Scheduled Task)
- **Encryption:** Token cache protected by DPAPI (LocalMachine scope)

---

## 7. PowerShell Built-in Cmdlets

### Required PowerShell Version
- **Version:** PowerShell 5.1 (Windows PowerShell)
- **Status:** Built-in on Windows 10+ and Server 2016+
- **No installation required**

### Key Cmdlets Used

**Web Requests:**
- `Invoke-WebRequest` – Fetch HTTP content
- Custom wrapper: `Invoke-SecureWebRequest` – HTTPS validation

**File Operations:**
- `Get-Content` – Read files
- `Set-Content` / `Out-File` – Write files
- `Test-Path` – Check file existence
- `Remove-Item` – Delete files

**JSON Processing:**
- `ConvertFrom-Json` – Parse JSON strings
- `ConvertTo-Json` – Serialize to JSON

**Encryption:**
- `System.Security.Cryptography.ProtectedData` – DPAPI encryption/decryption

**Process Management:**
- `Start-Job` / `Get-Job` / `Wait-Job` – Background job execution (parallel monitors)

**Scheduled Tasks:**
- `Register-ScheduledTask` – Create scheduled task
- `Unregister-ScheduledTask` – Delete scheduled task

---

## 8. External Tools (Build & Testing)

### PSScriptAnalyzer

**Purpose:** Code style linting and security checks

**Installation:**
```powershell
Install-Module PSScriptAnalyzer -Repository PSGallery
```

**Usage (in build.ps1):**
```powershell
Invoke-ScriptAnalyzer -Path src/ -Severity Error
```

**Checks:**
- Unapproved verbs (e.g., Filter → Get-Filtered)
- Write-Host usage (not allowed)
- Empty catch blocks
- PSCredential handling

### Pester

**Purpose:** PowerShell testing framework

**Installation:**
```powershell
Install-Module Pester -Repository PSGallery -MinimumVersion 5.0
```

**Usage (in build.ps1):**
```powershell
Invoke-Pester tests/ -CodeCoverage src/ -PassThru
```

**Test Types:**
- Unit tests (against fixtures)
- Integration tests (against real APIs)
- Coverage reports (90%+ target)

---

## 9. System Requirements

### Operating System
- **Windows 10** or later
- **Windows Server 2016** or later
- **Not supported:** macOS, Linux

### PowerShell
- **Version:** 5.1 (Windows PowerShell)
- **Installation:** Pre-installed on Windows 10+

### Network
- **Outbound HTTPS:** Required for Azure AD, Graph API, Discord, Shooting-Store
- **No inbound:** No ports need to be open
- **Proxy:** Corporate proxies supported via System settings

### Storage
- **Minimum:** 50 MB (code + logs)
- **Logs growth:** ~150 MB over 30 days (daily rotation)
- **No database:** Local files only

---

## 10. Dependency Summary Table

| Service | Purpose | Authentication | Rate Limit | Required |
|---------|---------|-----------------|-----------|----------|
| Azure AD OAuth2 | Token acquisition | Client secret | 2000 req/min | Email only |
| Microsoft Graph | Email sending | Bearer token | 2000 req/min | Email only |
| Shooting-Store | Web scraping | None | None | Yes |
| Discord Webhooks | Notifications | Bearer (in URL) | 5 req/5s per webhook | Discord only |
| Windows Toast | Desktop notifications | None | None | Optional |
| Windows File System | Config/Logs | File permissions | None | Yes |
| PowerShell 5.1 | Runtime | None | None | Yes |
| PSScriptAnalyzer | Linting (dev) | None | None | Dev only |
| Pester | Testing (dev) | None | None | Dev only |

---

## 11. Failure Scenarios & Mitigation

### If Azure AD is down
- **Impact:** Email notifications fail
- **Mitigation:** Retry 3x, skip this cycle, try next interval
- **Fallback:** Discord/Toast still work
- **User sees:** Alert via Discord/Toast (if configured)

### If Graph API is down
- **Impact:** Email sending fails
- **Mitigation:** Same as Azure AD
- **Fallback:** Other notifiers still work
- **Duration:** Typically <1 hour (Microsoft SLA 99.9%)

### If Shooting-Store.ch is down
- **Impact:** Course monitoring stops
- **Mitigation:** Retry 3x, skip cycle, try next interval
- **Alert:** Error logged, user can check logs
- **Duration:** Until site comes back online

### If Discord webhook is invalid
- **Impact:** Discord notifications fail
- **Mitigation:** Log error, continue with other notifiers
- **Fallback:** Email/Toast still work
- **Fix:** Update webhook URL in environment variable

### If network is unavailable
- **Impact:** All external APIs unreachable
- **Mitigation:** Retry all requests 3x
- **Graceful Degrade:** Local Toast still works, state still updates
- **Recovery:** Automatic when network restored

---

## 12. Security Considerations

### Token Exposure Risk
- **Azure AD tokens:** Encrypted with DPAPI, short-lived (1 hour)
- **Discord webhook:** Bearer token in URL (treat like password)
- **Mitigation:** Store in environment variables, not config.json

### HTTP vs HTTPS
- **Azure AD endpoints:** Always HTTPS (enforced by code)
- **Graph API endpoints:** Always HTTPS (enforced by code)
- **Shooting-Store:** HTTPS preferred, HTTP allowed (site decision)
- **Discord:** Always HTTPS (enforced)

### Rate Limiting Impact
- **Current usage:** Well below all service limits
- **Scaling:** Monitor rate limits if adding many new websites

### Man-in-the-Middle Attacks
- **Mitigation:** HTTPS certificate validation via Windows CA store
- **Certificate pinning:** Future enhancement (ADR-010 note)

---

## References

- [SECURITY.md](SECURITY.md) – Security implementation details
- [STRUCTURE.md](../STRUCTURE.md) – Configuration structure
- [ARCHITECTURE.md](ARCHITECTURE.md) – System design
- Microsoft Graph API: https://docs.microsoft.com/graph
- Discord Webhook Docs: https://discord.com/developers/docs/resources/webhook
- DPAPI: https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.protecteddata
