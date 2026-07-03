# Configuration Schema Documentation

Complete JSON schema reference and configuration examples for IPSC Kurs Watcher.

---

## 1. Configuration File Location

**File Path:** `config/config.json`

**How it's loaded:**
```powershell
# At startup (BasicCourseWatcher.ps1)
$config = Get-Config -Path "config/config.json"
```

**Validation:**
- Schema validation: `config/config.schema.json`
- Runtime validation: Type checking, range validation
- Invalid config → Startup fails with error message

---

## 2. JSON Schema (config.schema.json)

Complete JSON Schema for validation:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "IPSC Kurs Watcher Configuration",
  "type": "object",
  "required": ["version", "monitors", "filters", "notifiers", "state", "logging"],
  
  "properties": {
    "version": {
      "type": "integer",
      "description": "Config format version (1 = current)",
      "minimum": 1,
      "maximum": 1
    },
    
    "monitors": {
      "type": "array",
      "description": "Array of website monitors to run",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["id", "url", "base_url", "enabled"],
        "properties": {
          "id": {
            "type": "string",
            "description": "Unique monitor identifier",
            "minLength": 1,
            "maxLength": 50,
            "pattern": "^[a-z0-9-]+$"
          },
          "url": {
            "type": "string",
            "description": "Category/listing page URL to monitor",
            "minLength": 10,
            "pattern": "^https?://"
          },
          "base_url": {
            "type": "string",
            "description": "Base URL for relative URL resolution",
            "minLength": 10,
            "pattern": "^https?://"
          },
          "enabled": {
            "type": "boolean",
            "description": "Enable/disable this monitor"
          },
          "timeout_seconds": {
            "type": "integer",
            "description": "HTTP request timeout in seconds",
            "minimum": 5,
            "maximum": 300,
            "default": 30
          },
          "retry_attempts": {
            "type": "integer",
            "description": "Number of retries on failure",
            "minimum": 1,
            "maximum": 10,
            "default": 3
          },
          "poll_interval_minutes": {
            "type": "integer",
            "description": "Polling interval in minutes (for reference)",
            "minimum": 5,
            "maximum": 1440,
            "default": 30
          }
        }
      }
    },
    
    "filters": {
      "type": "object",
      "required": ["course_types", "exclude_patterns"],
      "properties": {
        "course_types": {
          "type": "array",
          "description": "Course type filters (matching patterns)",
          "items": {
            "type": "object",
            "required": ["id", "name", "patterns", "enabled"],
            "properties": {
              "id": {
                "type": "string",
                "description": "Type identifier",
                "minLength": 1,
                "maxLength": 30
              },
              "name": {
                "type": "string",
                "description": "Display name",
                "minLength": 1,
                "maxLength": 50
              },
              "patterns": {
                "type": "array",
                "description": "String patterns to match (case-insensitive)",
                "items": { "type": "string", "minLength": 1 },
                "minItems": 1
              },
              "enabled": {
                "type": "boolean",
                "description": "Enable/disable this filter"
              }
            }
          }
        },
        "exclude_patterns": {
          "type": "array",
          "description": "Courses to exclude (matched against name)",
          "items": { "type": "string", "minLength": 1 }
        },
        "min_availability": {
          "type": "integer",
          "description": "Minimum slots required to alert",
          "minimum": 0,
          "maximum": 1000,
          "default": 1
        }
      }
    },
    
    "notifiers": {
      "type": "object",
      "properties": {
        "email": {
          "type": "object",
          "properties": {
            "enabled": { "type": "boolean" },
            "azure_tenant_id": { 
              "type": "string",
              "description": "Fallback (prefer env var IPSC_AZURE_TENANT_ID)"
            },
            "azure_client_id": {
              "type": "string",
              "description": "Fallback (prefer env var IPSC_AZURE_CLIENT_ID)"
            },
            "azure_user_id": {
              "type": "string",
              "description": "Fallback (prefer env var IPSC_AZURE_USER_ID)"
            },
            "sender": {
              "type": "string",
              "description": "Sender email address",
              "format": "email"
            },
            "recipients": {
              "type": "array",
              "description": "Recipient email addresses",
              "items": { "type": "string", "format": "email" },
              "minItems": 1
            }
          }
        },
        "discord": {
          "type": "object",
          "properties": {
            "enabled": { "type": "boolean" },
            "webhook_urls": {
              "type": "array",
              "description": "Discord webhook URLs (prefer env var IPSC_DISCORD_WEBHOOKS)",
              "items": { "type": "string", "pattern": "^https://discord.com/api/webhooks/" }
            }
          }
        },
        "windows_toast": {
          "type": "object",
          "properties": {
            "enabled": { "type": "boolean" }
          }
        }
      }
    },
    
    "state": {
      "type": "object",
      "required": ["file_path"],
      "properties": {
        "file_path": {
          "type": "string",
          "description": "Path to state.json file",
          "default": "data/state.json"
        }
      }
    },
    
    "logging": {
      "type": "object",
      "properties": {
        "level": {
          "type": "string",
          "enum": ["DEBUG", "INFO", "WARN", "ERROR"],
          "default": "INFO",
          "description": "Minimum log level"
        },
        "log_dir": {
          "type": "string",
          "description": "Directory for log files",
          "default": "data/logs"
        },
        "retention_days": {
          "type": "integer",
          "description": "Keep logs for this many days",
          "minimum": 1,
          "maximum": 365,
          "default": 30
        }
      }
    },
    
    "error_handling": {
      "type": "object",
      "properties": {
        "alert_on_repeated_errors": {
          "type": "boolean",
          "description": "Send admin alert if error threshold exceeded",
          "default": false
        },
        "error_threshold": {
          "type": "integer",
          "description": "Number of errors to trigger alert",
          "minimum": 1,
          "maximum": 100,
          "default": 5
        },
        "error_window_minutes": {
          "type": "integer",
          "description": "Time window for counting errors",
          "minimum": 1,
          "maximum": 1440,
          "default": 60
        }
      }
    }
  }
}
```

---

## 3. Example Configuration (config.example.json)

Minimal working configuration:

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
      {
        "id": "basic",
        "name": "Basic Courses",
        "patterns": ["Basic", "Level 1", "Einführung"],
        "enabled": true
      },
      {
        "id": "advanced",
        "name": "Advanced Courses",
        "patterns": ["Advanced", "Level 2+", "Fortgeschrittene"],
        "enabled": true
      }
    ],
    "exclude_patterns": [
      "Privatunterricht",
      "Corporate",
      "Seminar"
    ],
    "min_availability": 1
  },
  
  "notifiers": {
    "email": {
      "enabled": true,
      "sender": "your-email@example.com",
      "recipients": [
        "recipient1@example.com",
        "recipient2@example.com"
      ]
    },
    "discord": {
      "enabled": false
    },
    "windows_toast": {
      "enabled": true
    }
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
    "alert_on_repeated_errors": false,
    "error_threshold": 5,
    "error_window_minutes": 60
  }
}
```

---

## 4. Configuration Sections Explained

### 4.1 Monitors Section

Defines which websites to monitor.

```json
"monitors": [
  {
    "id": "shooting-store",                                    // Unique ID
    "url": "https://www.shooting-store.ch/de/kategorie/kurse1",  // Category page
    "base_url": "https://www.shooting-store.ch",               // Base for relative URLs
    "enabled": true,                                           // Enable/disable
    "timeout_seconds": 30,                                     // HTTP timeout
    "retry_attempts": 3,                                       // Retry count
    "poll_interval_minutes": 30                                // How often (reference only)
  }
]
```

**Rules:**
- At least 1 monitor required
- `id` must be unique, lowercase, alphanumeric + hyphens
- `url` and `base_url` must start with `http://` or `https://`
- All monitors run in parallel (not sequentially)

**Adding New Monitor:**
1. Add entry to `monitors[]` array
2. Set `id` to unique identifier
3. Set `url` to category/listing page
4. Monitor must be implemented in `src/monitors/`

### 4.2 Filters Section

Defines which courses to alert on.

```json
"filters": {
  "course_types": [
    {
      "id": "basic",                            // Unique type ID
      "name": "Basic Courses",                  // Display name
      "patterns": ["Basic", "Level 1"],         // Match patterns (case-insensitive)
      "enabled": true                           // Enable/disable this type
    }
  ],
  "exclude_patterns": [                         // Patterns to EXCLUDE
    "Privatunterricht",
    "Corporate"
  ],
  "min_availability": 1                         // Alert only if slots >= this
}
```

**Rules:**
- Course name matched against patterns (case-insensitive substring match)
- Pattern "Basic" matches: "IPSC Basic 2.0", "basic_course", "THE BASIC ONE"
- Exclude patterns checked AFTER type matching
- Multiple types can match same course (all alerted)

**Example:**
```
Course: "IPSC Basic 2.0 Level 1"
├─ Matches type "basic" (pattern "Basic")
├─ Not excluded (not "Privatunterricht")
├─ Has 3 slots >= min 1
└─ ALERT SENT
```

### 4.3 Notifiers Section

Defines notification channels.

**Email (via OAuth2):**
```json
"email": {
  "enabled": true,
  "sender": "your-email@example.com",
  "recipients": ["user1@example.com", "user2@example.com"]
}
```

**Setup Requirements:**
1. Set environment variables (see [API_REFERENCES.md](API_REFERENCES.md))
   - `IPSC_AZURE_TENANT_ID`
   - `IPSC_AZURE_CLIENT_ID`
   - `IPSC_AZURE_USER_ID`
2. Run `.\scripts\Setup-AzureCredentials.ps1` (interactive setup)
3. Sender must be your Azure AD mailbox
4. Recipients can be any email addresses

**Discord (via Webhooks):**
```json
"discord": {
  "enabled": false
}
```

**Setup Requirements:**
1. Set environment variable:
   - `IPSC_DISCORD_WEBHOOKS` (comma-separated webhook URLs)
2. Create webhook in Discord server (Server Settings → Integrations → Webhooks)
3. Copy webhook URL to environment variable
4. Test: Run one monitoring cycle and check Discord channel

**Windows Toast:**
```json
"windows_toast": {
  "enabled": true
}
```

**No setup required:** Uses Windows notification center (local, no internet).

### 4.4 State Section

Where to store persistent state.

```json
"state": {
  "file_path": "data/state.json"
}
```

**Rules:**
- File is created automatically if missing
- Should be in `data/` directory
- Use relative path (relative to working directory)
- Auto-backed up if corrupted

### 4.5 Logging Section

Log file configuration.

```json
"logging": {
  "level": "INFO",              // MIN level: DEBUG, INFO, WARN, ERROR
  "log_dir": "data/logs",       // Directory for log files
  "retention_days": 30          // Delete logs older than this
}
```

**Log Levels:**
- **DEBUG:** Development/tracing (verbose)
- **INFO:** Normal operations (default)
- **WARN:** Concerning but not critical
- **ERROR:** Failures requiring attention

**Default:** INFO (logs normal operations + warnings + errors, not DEBUG)

**File Pattern:** `watcher-2026-07-03.log` (daily rotation)

### 4.6 Error Handling Section

Alert configuration for repeated errors.

```json
"error_handling": {
  "alert_on_repeated_errors": true,   // Send admin alert
  "error_threshold": 5,               // After 5 errors
  "error_window_minutes": 60          // In 60 minutes
}
```

**Usage:**
- If 5+ errors occur within 60 minutes
- Send admin alert via email + Discord
- Max 1 alert per 60 minutes per monitor (prevent spam)
- Disabled by default (set to false to disable)

---

## 5. Secrets Management

### DO NOT PUT IN config.json:
- ❌ Azure AD credentials
- ❌ Discord webhook URLs
- ❌ OAuth2 tokens
- ❌ Email passwords
- ❌ Any sensitive data

### WHERE TO PUT SECRETS:

**Environment Variables:**
```powershell
# Set once at machine setup
setx IPSC_AZURE_TENANT_ID "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
setx IPSC_AZURE_CLIENT_ID "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
setx IPSC_DISCORD_WEBHOOKS "https://discord.com/api/webhooks/123/abc"

# Or use interactive setup
.\scripts\Setup-AzureCredentials.ps1
```

**Token Cache (Auto-encrypted):**
- `data/.token_cache.json` (DPAPI encrypted, binary format)
- Generated automatically on first OAuth2 token request
- Never commit to version control

---

## 6. Configuration Validation Checklist

Before deploying to production:

- [ ] **Monitors**
  - [ ] At least 1 monitor configured and enabled
  - [ ] All URLs start with http:// or https://
  - [ ] Base URL matches website domain

- [ ] **Filters**
  - [ ] At least 1 course type configured
  - [ ] Patterns are meaningful (match expected course names)
  - [ ] Exclude patterns correct (courses you want to skip)
  - [ ] min_availability >= 1

- [ ] **Notifiers**
  - [ ] Email enabled: sender + recipients set, env vars configured
  - [ ] Discord enabled: webhook URL set in env var
  - [ ] At least 1 notifier enabled (email or discord or toast)

- [ ] **Secrets**
  - [ ] No credentials in config.json
  - [ ] Environment variables set (IPSC_AZURE_*, IPSC_DISCORD_*)
  - [ ] Sender email is valid Azure mailbox
  - [ ] Recipients are valid email addresses

- [ ] **Logging**
  - [ ] Log directory writable (data/logs/)
  - [ ] Retention days is reasonable (1-365)

- [ ] **Testing**
  - [ ] Run: `.\BasicCourseWatcher.ps1 -RunOnce`
  - [ ] Check logs: `data/logs/watcher-YYYY-MM-DD.log`
  - [ ] Verify notifications sent (email + discord)

---

## 7. Troubleshooting Configuration Issues

### "Config validation failed"
**Cause:** Schema violation (missing field, wrong type, invalid value)  
**Fix:** Check error message, compare against schema examples

### "Invalid monitor URL"
**Cause:** URL doesn't start with http:// or https://  
**Fix:** Add protocol: `https://www.example.com/path`

### "Email not sent"
**Cause:** Credentials not configured  
**Fix:** Set environment variables: `IPSC_AZURE_TENANT_ID`, `IPSC_AZURE_CLIENT_ID`, `IPSC_AZURE_USER_ID`

### "Discord webhook failed"
**Cause:** Webhook URL invalid or expired  
**Fix:** Create new webhook in Discord, update env var `IPSC_DISCORD_WEBHOOKS`

### "No courses found"
**Cause:** Filters too strict OR website HTML changed  
**Fix:** Check log file, adjust filters, update HTML parsing if needed

---

## 8. Configuration Examples by Use Case

### Minimal Setup (Email Only)
```json
{
  "version": 1,
  "monitors": [
    {
      "id": "shooting-store",
      "url": "https://www.shooting-store.ch/de/kategorie/kurse1",
      "base_url": "https://www.shooting-store.ch",
      "enabled": true
    }
  ],
  "filters": {
    "course_types": [
      {"id": "all", "name": "All", "patterns": [""], "enabled": true}
    ],
    "exclude_patterns": []
  },
  "notifiers": {
    "email": {"enabled": true, "sender": "you@example.com", "recipients": ["you@example.com"]},
    "discord": {"enabled": false},
    "windows_toast": {"enabled": false}
  },
  "state": {"file_path": "data/state.json"},
  "logging": {"level": "INFO", "log_dir": "data/logs", "retention_days": 30},
  "error_handling": {"alert_on_repeated_errors": false}
}
```

### Full Setup (Email + Discord + Toast)
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
      {"id": "basic", "name": "Basic", "patterns": ["Basic", "Level 1"], "enabled": true},
      {"id": "advanced", "name": "Advanced", "patterns": ["Advanced", "Level 2"], "enabled": true}
    ],
    "exclude_patterns": ["Privatunterricht", "Corporate"],
    "min_availability": 1
  },
  "notifiers": {
    "email": {"enabled": true, "sender": "you@example.com", "recipients": ["you@example.com", "friend@example.com"]},
    "discord": {"enabled": true},
    "windows_toast": {"enabled": true}
  },
  "state": {"file_path": "data/state.json"},
  "logging": {"level": "DEBUG", "log_dir": "data/logs", "retention_days": 30},
  "error_handling": {"alert_on_repeated_errors": true, "error_threshold": 5, "error_window_minutes": 60}
}
```

---

## References

- [STRUCTURE.md](../STRUCTURE.md) – Configuration details section
- [API_REFERENCES.md](API_REFERENCES.md) – External services
- [SECURITY.md](SECURITY.md) – Credential storage
- [config/config.example.json](../../config/config.example.json) – Sample file
- [config/config.schema.json](../../config/config.schema.json) – JSON Schema
