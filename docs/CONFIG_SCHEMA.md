# Configuration Schema Reference – IPSC Kurs Watcher v1.0.0

**Last Updated:** 2026-07-05  
**Version:** v1.0.0  
**Audience:** Users, Administrators, Developers

---

## File Location & Structure

**Primary Config File:** `config/config.json`

**Loading Flow:**
```
Scheduler.ps1
  ├─ Get-Config -ConfigPath 'config/config.json'
  ├─ ConvertFrom-Json → Parse JSON
  ├─ Basic validation (file exists, valid JSON)
  └─ Return PSCustomObject with all sections
```

**Validation:**
- ✅ File exists check (startup fails if missing)
- ✅ JSON syntax validation (ConvertFrom-Json will error)
- ⚠️ **Gap:** No runtime schema validation (should check required fields)
- ⚠️ **Gap:** No startup URL reachability test

---

## Complete Configuration Schema

```json
{
  "version": 1,
  
  "monitors": [
    {
      "id": "shooting-store",
      "provider": "shooting-store",
      "enabled": true,
      "url": "https://www.shooting-store.ch/de/kategorie/kurse1",
      "base_url": "https://www.shooting-store.ch",
      "timeout_seconds": 30,
      "retry_attempts": 3,
      "poll_interval_minutes": 30
    }
  ],
  
  "filters": {
    "course_types": [
      {
        "id": "tryout",
        "name": "Tryout Courses",
        "patterns": ["Tryout", "Einsteiger-Kurs"],
        "enabled": true
      },
      {
        "id": "basic",
        "name": "Basic Level",
        "patterns": ["Basic", "Anfänger", "Level 1"],
        "enabled": true
      },
      {
        "id": "basic2",
        "name": "Basic 2.0",
        "patterns": ["Basic 2.0", "Basic 2.x", "Level 2"],
        "enabled": true
      }
    ],
    "exclude_patterns": ["Privatunterricht", "VIP-Kurs", "Geschlossen"],
    "min_availability": 1
  },
  
  "notifiers": {
    "windows_toast": {
      "enabled": true,
      "sound_enabled": true,
      "group_by_type": true,
      "max_courses_per_group": 5,
      "auto_dismiss_seconds": 5,
      "main_page_url": "https://www.shooting-store.ch/de/kategorie/kurse1"
    },
    "email": {
      "enabled": true,
      "provider": "graph",
      "token_cache_path": "data/.token_cache.json",
      "timeout_seconds": 30,
      "retry_attempts": 3
    },
    "discord": {
      "enabled": true,
      "retry_attempts": 3,
      "timeout_seconds": 30,
      "webhook_urls": []
    }
  },
  
  "state": {
    "file_path": "data/state.json",
    "retention_days": 30
  },
  
  "logging": {
    "log_dir": "data/logs",
    "log_level": "INFO",
    "retention_days": 30,
    "format": "json"
  },
  
  "error_handling": {
    "alert_on_repeated_errors": false,
    "error_threshold": 5,
    "error_window_minutes": 60
  }
}
```

---

## Configuration Sections

### 1. version (Required)

```json
"version": 1
```

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `version` | Integer | ✅ Yes | Config format version (1 = current, not plans for future) |

---

### 2. monitors[] (Required)

Array of websites to monitor. Each monitor runs sequentially.

```json
"monitors": [
  {
    "id": "shooting-store",
    "provider": "shooting-store",
    "enabled": true,
    "url": "https://www.shooting-store.ch/de/kategorie/kurse1",
    "base_url": "https://www.shooting-store.ch",
    "timeout_seconds": 30,
    "retry_attempts": 3,
    "poll_interval_minutes": 30
  }
]
```

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `id` | String | ✅ Yes | N/A | Unique identifier (used for logging, routing) |
| `provider` | String | ✅ Yes | N/A | Provider type: `"shooting-store"` (only option in v1.0) |
| `enabled` | Boolean | ✅ Yes | N/A | Enable/disable this monitor |
| `url` | String | ✅ Yes | N/A | Course listing URL (must be HTTPS, validated) |
| `base_url` | String | ✅ Yes | N/A | Base URL for constructing detail page links |
| `timeout_seconds` | Integer | ⚠️ No | 30 | HTTP request timeout in seconds (range: 5-300) |
| `retry_attempts` | Integer | ⚠️ No | 3 | Number of retry attempts on network error (range: 1-10) |
| `poll_interval_minutes` | Integer | ⚠️ No | 30 | Polling interval (informational only, not used in v1.0) |

**URL Validation:**
- Must start with `https://` (http:// allowed only for local/testing)
- Must be absolute path (no relative URLs)
- No query parameters in base_url
- No username/password in URLs

**Adding New Monitors:**
1. Add entry to `monitors[]` array
2. Create new provider type in `src/monitors/`
3. Update `MonitorFactory.ps1` routing
4. No other code changes needed (extensible architecture)

---

### 3. filters{} (Required)

Global filtering rules applied to all monitors.

```json
"filters": {
  "course_types": [
    {
      "id": "basic",
      "name": "Basic Level",
      "patterns": ["Basic", "Anfänger"],
      "enabled": true
    }
  ],
  "exclude_patterns": ["Privatunterricht", "VIP-Kurs"],
  "min_availability": 1
}
```

#### 3a. course_types[]

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `id` | String | ✅ Yes | Unique filter ID (used for logging) |
| `name` | String | ✅ Yes | Human-readable name |
| `patterns` | Array[String] | ✅ Yes | Array of patterns to match (substring match, case-insensitive) |
| `enabled` | Boolean | ⚠️ No | Default: `true`. Enable/disable this filter type |

**Pattern Matching:**
- Substring match (not regex in v1.0)
- Case-insensitive
- Example: Pattern `"Basic"` matches `"IPSC Basic 2.0"`, `"Basic Course"`
- Empty patterns array = match all courses

**Use Case:**
- Alert only on "Basic" level courses
- Alert only on "Tryout" courses
- Separate filtering per course type

#### 3b. exclude_patterns[]

```json
"exclude_patterns": ["Privatunterricht", "VIP-Kurs", "Geschlossen"]
```

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `exclude_patterns` | Array[String] | ⚠️ No | Patterns to exclude (blacklist) |

**Behavior:**
- Any course matching ANY pattern is excluded
- Applied after type filtering
- Substring match, case-insensitive

#### 3c. min_availability

```json
"min_availability": 1
```

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `min_availability` | Integer | ⚠️ No | 1 | Minimum available slots to alert (range: 0+) |

**Examples:**
- `1` = Alert only if >= 1 slot available (default, most courses)
- `0` = Alert even if sold out (unusual)
- `5` = Alert only if >= 5 slots available (strict filter)

---

### 4. notifiers{} (Required)

Notification channel configurations. All channels are optional (can disable all).

#### 4a. windows_toast

```json
"windows_toast": {
  "enabled": true,
  "sound_enabled": true,
  "group_by_type": true,
  "max_courses_per_group": 5,
  "auto_dismiss_seconds": 5,
  "main_page_url": "https://www.shooting-store.ch/de/kategorie/kurse1"
}
```

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `enabled` | Boolean | ✅ Yes | N/A | Enable/disable Toast notifications |
| `sound_enabled` | Boolean | ⚠️ No | `true` | Play sound on notification |
| `group_by_type` | Boolean | ⚠️ No | `true` | Group alerts by course type in toast |
| `max_courses_per_group` | Integer | ⚠️ No | 5 | Max courses per notification (range: 1-20) |
| `auto_dismiss_seconds` | Integer | ⚠️ No | 5 | Auto-dismiss timeout in seconds (range: 3-30, 0=manual) |
| `main_page_url` | String | ⚠️ No | None | URL to open when toast is clicked |

**Platform Requirements:**
- Windows 10+ (Toast API via WinRT)
- Graceful failure on older Windows (notification skipped, logged)

#### 4b. email

```json
"email": {
  "enabled": true,
  "provider": "graph",
  "token_cache_path": "data/.token_cache.json",
  "timeout_seconds": 30,
  "retry_attempts": 3
}
```

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `enabled` | Boolean | ✅ Yes | N/A | Enable/disable email notifications |
| `provider` | String | ✅ Yes | N/A | Email provider: `"graph"` (only option in v1.0, OAuth2 via Graph API) |
| `token_cache_path` | String | ⚠️ No | `data/.token_cache.json` | Path to DPAPI-encrypted token cache |
| `timeout_seconds` | Integer | ⚠️ No | 30 | Graph API request timeout (range: 5-60) |
| `retry_attempts` | Integer | ⚠️ No | 3 | Retry attempts on network error (range: 1-10) |

**Requirements:**
- Environment variables set: `IPSC_AZURE_TENANT_ID`, `IPSC_AZURE_CLIENT_ID`, `IPSC_AZURE_USER_ID`
- See: [SECURITY.md](SECURITY.md) for credential setup

#### 4c. discord

```json
"discord": {
  "enabled": true,
  "retry_attempts": 3,
  "timeout_seconds": 30,
  "webhook_urls": []
}
```

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `enabled` | Boolean | ✅ Yes | N/A | Enable/disable Discord notifications |
| `retry_attempts` | Integer | ⚠️ No | 3 | Retry attempts on webhook fail (range: 1-10) |
| `timeout_seconds` | Integer | ⚠️ No | 30 | Webhook request timeout (range: 5-60) |
| `webhook_urls` | Array[String] | ⚠️ No | `[]` | Discord webhook URLs (deprecated, use env var) |

**Recommended:** Use environment variable `IPSC_DISCORD_WEBHOOKS` instead of config.json (safer for secrets)

---

### 5. state{} (Required)

State file management (course deduplication).

```json
"state": {
  "file_path": "data/state.json",
  "retention_days": 30
}
```

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `file_path` | String | ✅ Yes | N/A | Path to state.json (relative or absolute) |
| `retention_days` | Integer | ⚠️ No | 30 | Days to keep old states (unused in v1.0) |

**state.json Structure:**
```json
{
  "version": 1,
  "last_poll": "2026-07-05T14:30:00Z",
  "last_notified": [
    { "id": "...", "name": "...", "availability": 3, "notified_at": "..." }
  ]
}
```

---

### 6. logging{} (Required)

Logging configuration.

```json
"logging": {
  "log_dir": "data/logs",
  "log_level": "INFO",
  "retention_days": 30,
  "format": "json"
}
```

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `log_dir` | String | ✅ Yes | N/A | Directory for log files |
| `log_level` | String | ✅ Yes | N/A | Log level: `DEBUG`, `INFO`, `WARN`, `ERROR` |
| `retention_days` | Integer | ✅ Yes | N/A | Auto-delete logs older than N days (range: 1-365) |
| `format` | String | ✅ Yes | N/A | Format: `"json"` (only option in v1.0) |

**Log Files:**
- Location: `{log_dir}/watcher-YYYY-MM-DD.log`
- One file per day
- Auto-rotation at midnight
- Auto-cleanup after `retention_days`

---

### 7. error_handling{} (Required)

Error alerting configuration (optional in practice).

```json
"error_handling": {
  "alert_on_repeated_errors": false,
  "error_threshold": 5,
  "error_window_minutes": 60
}
```

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `alert_on_repeated_errors` | Boolean | ⚠️ No | `false` | Enable error escalation alerts |
| `error_threshold` | Integer | ⚠️ No | 5 | Errors before escalation (range: 1-20) |
| `error_window_minutes` | Integer | ⚠️ No | 60 | Time window for threshold (range: 5-1440) |

**Behavior:**
- If `alert_on_repeated_errors: true` and N errors occur within time window:
  - Send admin alert via email + Discord
  - Max 1 alert per 60 min (prevent spam)
- If `false`: Errors logged but not escalated (current behavior)

---

## Configuration Examples

### Example 1: Minimal (Single Monitor, Toast Only)

```json
{
  "version": 1,
  "monitors": [
    {
      "id": "shooting-store",
      "provider": "shooting-store",
      "enabled": true,
      "url": "https://www.shooting-store.ch/de/kategorie/kurse1",
      "base_url": "https://www.shooting-store.ch"
    }
  ],
  "filters": {
    "course_types": [],
    "exclude_patterns": [],
    "min_availability": 1
  },
  "notifiers": {
    "windows_toast": { "enabled": true },
    "email": { "enabled": false },
    "discord": { "enabled": false }
  },
  "state": { "file_path": "data/state.json" },
  "logging": { "log_dir": "data/logs", "log_level": "INFO", "retention_days": 30, "format": "json" },
  "error_handling": { "alert_on_repeated_errors": false }
}
```

### Example 2: Full Setup (All Notifications + Filters)

See: [config/config.json](../config/config.json) (active config with all options)

---

## Configuration Best Practices

1. **Never put secrets in config.json**
   - Use environment variables for: Azure credentials, Discord webhooks
   - See: [SECURITY.md](SECURITY.md)

2. **Use relative paths**
   - `data/state.json` (relative to working directory)
   - NOT `C:\Users\...\data\state.json` (hardcoded absolute)

3. **Keep patterns simple**
   - Use substring matching, not regex (not yet supported)
   - Case-insensitive matching
   - Example: `"Basic"` matches `"IPSC Basic 2.0"` and `"Basic Course"`

4. **Set min_availability carefully**
   - `1` = Alert on any available course (default, most use)
   - `5` = Alert only if many slots available (strict, fewer alerts)

5. **Test configuration before deployment**
   - Manual run: `.\Scheduler.ps1 -RunOnce`
   - Check logs for validation errors

---

## Configuration Validation & Troubleshooting

**Config Not Loading?**
- Check JSON syntax: `ConvertFrom-Json -Path config/config.json` (will error if invalid)
- Check file exists: `Test-Path config/config.json`
- Check file readable: File permissions (must be readable by SYSTEM if scheduled task)

**Monitors Not Running?**
- Check `monitors[].enabled: true`
- Check `monitors[].provider: "shooting-store"` (correct value)
- Check URL format: Must be https, must be absolute

**Filters Not Working?**
- Check patterns are strings, not objects
- Check `course_types[].enabled: true`
- Test pattern matching: Does `"Basic"` match your course names?

---

## References

- [ARCHITECTURE.md](ARCHITECTURE.md) – System design (configuration section)
- [SECURITY.md](SECURITY.md) – Credential management
- [OPERATIONAL_GUIDE.md](OPERATIONAL_GUIDE.md) – Configuration management at runtime
