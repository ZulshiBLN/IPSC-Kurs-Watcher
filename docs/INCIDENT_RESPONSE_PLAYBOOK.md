# Incident Response Playbook – IPSC Kurs Watcher

**Version:** 1.0  
**Effective Date:** 2026-07-04  
**GDPR Requirement:** Article 33 (Breach Notification)

---

## 1. Introduction

This document provides step-by-step procedures for responding to data security incidents involving IPSC Kurs Watcher.

**Scope:** 
- Unauthorized access to personal data
- Data breaches (tokens, emails, logs exposed)
- System compromise (malware, intrusion)
- Privacy violations

**Goal:** Minimize harm to affected users and meet GDPR notification requirements (72-hour window).

---

## 2. Incident Severity Levels

### Level 1: LOW RISK (Notification NOT required)

**Examples:**
- User accidentally deletes own config file (user action, not breach)
- Log file older than 30 days auto-deleted (normal retention)
- Token expires after 1 hour (designed behavior)

**Response:** No notification needed.

### Level 2: MEDIUM RISK (Notify within 72 hours)

**Examples:**
- Old log file from 6 months ago found in backup (low risk: old data, limited exposure)
- Config file with email addresses accidentally shared internally (contained exposure)
- Token cache file on unencrypted USB drive (low probability, but possible)

**Response:** Assess exposure, notify users, notify DPA if personal data involved.

**Timeline:** 72 hours from discovery

### Level 3: HIGH RISK (Notify immediately, within 72 hours)

**Examples:**
- Token cache file publicly exposed on GitHub
- Log files containing email addresses on publicly accessible server
- Malware access to data/ directory
- Unauthorized access to user's machine via ransomware
- Config.json with credentials accidentally committed to public repo

**Response:** Immediate containment, user notification, DPA notification.

**Timeline:** Immediately upon discovery, formal notification within 72 hours

---

## 3. Incident Response Phases

### Phase 1: DETECT & ASSESS (Immediate, <1 hour)

**Step 1.1: Confirm Incident**
```
[ ] Is this a real breach or false alarm?
[ ] What data is potentially exposed? (emails, logs, tokens, configs)
[ ] How many users affected? (1 = low risk, many = high risk)
[ ] How was it exposed? (github, email, physical, malware, etc.)
```

**Step 1.2: Classify Severity**
```
Risk Assessment:
[ ] Is personal data (emails) exposed?          → Yes = increase severity
[ ] Is authentication token (OAuth2) exposed?   → Yes = increase severity
[ ] How likely is misuse?                       → High = increase severity
[ ] How long was data exposed?                  → Long = increase severity
[ ] Can exposure be easily limited?             → No = increase severity

Severity = Level 1, 2, or 3 (from Section 2)
```

**Step 1.3: Log Incident**
```
Create incident record:
- Date/time discovered
- What data exposed
- How exposed (suspected cause)
- Who discovered it
- Initial severity assessment
- Immediate actions taken

Location: Keep incident log for audit trail
```

---

### Phase 2: CONTAIN (Within 1 hour)

**Step 2.1: Stop the Bleeding**
```powershell
# Step 1: Stop application immediately
Stop-ScheduledTask -TaskName "IPSC-Kurs-Watcher" -Confirm:$false

# Step 2: Isolate affected systems
# - If breach is on user's machine: Disconnect from network (if severe)
# - If breach is on GitHub: Revoke leaked tokens immediately
# - If breach is email: Change Azure AD password immediately

# Step 3: Revoke exposed tokens
# In Azure Portal:
# - App Registrations → Your App → Certificates & Secrets
# - Delete leaked client secrets
# - Create new secret (old one invalidated)

# Step 4: Backup evidence (before deletion)
Copy-Item -Path data/ -Destination "incident-backup-$(Get-Date -Format yyyyMMddHHmm)" -Recurse -Force
```

**Step 2.2: Prevent Further Exposure**
```
[ ] If GitHub exposure: Delete sensitive files from repo
[ ] If email exposure: Change sender email password
[ ] If local exposure: Change Windows password
[ ] If malware suspected: Run antivirus scan
```

**Step 2.3: Temporary Mitigation**
```
[ ] Disable application: Stop scheduled task
[ ] Remove from startup: Ensure it doesn't auto-restart
[ ] Isolate user account: If needed
[ ] Backup all data: For forensics before cleanup
```

---

### Phase 3: INVESTIGATE (Within 4 hours)

**Step 3.1: Root Cause Analysis**
```
[ ] How was breach discovered?
[ ] When did breach likely occur? (estimate: check timestamps)
[ ] How long was data exposed? (days, weeks, months?)
[ ] Who had access? (malware, insider, external, etc.)
[ ] Why wasn't it caught? (missing controls?)
```

**Step 3.2: Scope the Damage**
```
Personal Data Exposed:
[ ] Email addresses: Yes/No - How many? (1, 10, 100+?)
[ ] Passwords: Yes/No
[ ] OAuth2 tokens: Yes/No
[ ] Log files: Yes/No - How much data? (1MB, 1GB?)

Sensitivity Assessment:
[ ] Would misuse cause harm to users? (HIGH RISK)
[ ] Are there any mitigating factors? (short exposure, old data)
[ ] What is probability of misuse? (HIGH = assume worst case)
```

**Step 3.3: Forensics** (if needed for high-risk incidents)
```
[ ] Check Windows Event Logs for unauthorized access
[ ] Check file modification timestamps: data/state.json, data/.token_cache.json
[ ] Check git logs for leaked credentials: git log -p --all -S "password"
[ ] Check email sent logs (Graph API audit logs in Azure)
[ ] Interview user: How did breach occur?
```

---

### Phase 4: REMEDIATE (Within 24 hours)

**Step 4.1: Fix the Vulnerability**
```
Issue: How was this possible? What control failed?

Examples:
[ ] Credentials in plaintext in config.json
    → Move to environment variables (IPSC_AZURE_*)
    → Regenerate leaked credentials

[ ] OAuth2 token cache unencrypted
    → Ensure DPAPI encryption is enabled
    → Regenerate leaked tokens

[ ] Log files accessible without authentication
    → Move logs to restricted directory
    → Encrypt log files

[ ] Source code with credentials in GitHub
    → Force-push with history rewrite (git filter-branch)
    → Rotate leaked credentials
    → Review git logs for other leaks

[ ] Malware infection
    → Full system scan with antivirus
    → Update Windows + all software
    → Change all passwords
    → Enable MFA on all accounts
```

**Step 4.2: Implement Controls**
```
[ ] Encrypt sensitive files (DPAPI, BitLocker, EFS)
[ ] Use environment variables instead of config files
[ ] Add file permissions restrictions
[ ] Enable logging of access attempts
[ ] Regular backup + testing restore
```

**Step 4.3: Test Remediation**
```powershell
# Test 1: Verify tokens are encrypted
$cacheFile = "data/.token_cache.json"
$bytes = [System.IO.File]::ReadAllBytes($cacheFile)
# Should be binary (not readable as JSON)

# Test 2: Verify no credentials in config
Select-String -Path "config/config.json" -Pattern "(password|secret|token)" -ErrorAction SilentlyContinue
# Should return nothing

# Test 3: Verify no plaintext data in logs
Select-String -Path "data/logs/*.log" -Pattern "(password|api_key|token|secret)" -ErrorAction SilentlyContinue
# Should return nothing (all masked)

# Test 4: Verify app restarts cleanly
Start-ScheduledTask -TaskName "IPSC-Kurs-Watcher"
Start-Sleep -Seconds 60
# Check: logs/watcher-*.log should show successful startup
```

---

### Phase 5: NOTIFY (Within 72 hours of discovery)

**Step 5.1: User Notification**

**If HIGH RISK (exposed emails):**

```
Email to affected users:

Subject: Security Incident – [Date] – Action Required

Dear User,

A security incident has been discovered affecting your account.

WHAT HAPPENED:
[Describe incident in plain language]
- What data was involved
- When it occurred
- How it was exposed
- Duration of exposure

WHO WAS AFFECTED:
- You (and possibly [N] other users)

WHAT WE'RE DOING:
- We have contained the incident [describe]
- We are fixing the root cause [describe]
- Your data is [encrypted/deleted/verified secure]

WHAT YOU SHOULD DO:
1. [Change your password / verify your account is secure]
2. [Monitor your email for suspicious activity]
3. [Contact us if you notice unusual activity]
4. [See attached FAQ for details]

CONTACT:
- Email: [security contact]
- Phone: [phone number]
- Website: [support portal]

NEXT STEPS:
- We will provide updates within [X days]
- Your privacy is our priority

[Your Name]
[Your Organization]
```

**If MEDIUM or LOW RISK:**
- No user notification required (unless required by local law)
- Document decision: why notification not needed
- Keep evidence for potential audit

**Step 5.2: Data Protection Authority (DPA) Notification**

**Required if:** Personal data breach + HIGH RISK

**Timeline:** Within 72 hours of discovery

**Report contents:**
```
1. Description of breach:
   - What happened
   - When discovered
   - When it occurred
   - Likely cause

2. Likely consequences:
   - What harm could result
   - Who could be affected
   - How many people

3. Measures taken or proposed:
   - How breach was contained
   - How vulnerability will be fixed
   - How users are being notified
   - Preventive measures

4. Data controller contact:
   - Your name/organization
   - Contact email/phone

5. Attached evidence:
   - Incident report
   - Forensics findings
   - Remediation plan
```

**Contact DPA:**
- Germany: https://www.bfdi.bund.de/
- France: https://www.cnil.fr/
- Austria: https://www.dsb.gv.at/
- Your country: https://edpb.ec.europa.eu/about-edpb/members_en

**Step 5.3: Internal Notification**

```
[ ] Notify management/security team
[ ] Update incident log (see Phase 1, Step 1.3)
[ ] Schedule post-incident review meeting
[ ] Assign owner to tracking remediation
```

---

### Phase 6: RECOVERY (Within 1 week)

**Step 6.1: System Restoration**
```powershell
# Step 1: Verify fixes are in place
# (See Phase 4, Step 4.3 - Test Remediation)

# Step 2: Restore from backup (if system was compromised)
# (Only after security verification)

# Step 3: Restart application
Start-ScheduledTask -TaskName "IPSC-Kurs-Watcher"

# Step 4: Monitor for recurrence
# Watch logs for unusual errors or access patterns
# Duration: 2+ weeks
```

**Step 6.2: User Communication**
```
Email to users:

Subject: Security Update – Remediation Complete

Dear User,

We wanted to follow up on the security incident [date].

STATUS: RESOLVED
- The vulnerability has been fixed
- All affected data has been secured
- Application is back to normal operation

IMPROVEMENTS MADE:
[List specific security enhancements]

TESTING COMPLETED:
[Describe verification testing done]

MONITORING:
- We are actively monitoring for any recurrence
- Enhanced logging enabled for audit trail
- Daily security scans in place

NEXT STEPS:
- We recommend you [verify account security / change password]
- No further action required at this time
- We apologize for the inconvenience

Thank you for your patience.

[Your Name]
```

---

### Phase 7: POST-INCIDENT REVIEW (Within 2 weeks)

**Step 7.1: Root Cause Analysis Meeting**
```
Attendees: Security team, application owner, IT admin

Agenda:
1. What happened? (timeline review)
2. Why did it happen? (root cause identification)
3. Why wasn't it caught? (control gaps)
4. How do we prevent recurrence? (preventive measures)
5. Lessons learned? (process improvements)

Output: Post-Incident Report (see Step 7.2)
```

**Step 7.2: Documentation**
```
Create Post-Incident Report:

[ ] Executive Summary (1 page)
[ ] Timeline (when did what happen)
[ ] Root Cause Analysis (why it happened)
[ ] Immediate Actions (what we did)
[ ] Long-term Fixes (prevention)
[ ] Cost Analysis (if applicable)
[ ] Recommendations (process changes)
[ ] Lessons Learned (what we'll do differently)

Distribute to: Management, security team, DPA (if involved)
Archive for: Audit trail, future reference
```

**Step 7.3: Process Improvements**
```
Based on incident, implement:

[ ] New monitoring/alerting for similar incidents
[ ] Enhanced access controls
[ ] Improved backup/restore procedures
[ ] Security training for team
[ ] Policy updates (this playbook, incident response procedures)
[ ] Regular penetration testing or security audits
[ ] Quarterly incident response drills
```

---

## 4. Contact & Escalation

### Incident Response Team

| Role | Name | Email | Phone | On-Call |
|------|------|-------|-------|---------|
| **Data Controller** | [Your Name] | [email] | [phone] | 24/7 |
| **Security Lead** | [Name] | [email] | [phone] | Business hours |
| **IT Admin** | [Name] | [email] | [phone] | Business hours |
| **Legal/Compliance** | [Name] | [email] | [phone] | On-call |

### External Contacts

| Organization | Contact | Purpose | Response Time |
|--------------|---------|---------|----------------|
| **DPA** | [your country DPA] | Breach reporting | 72 hours |
| **Microsoft** | support.microsoft.com | Azure/Graph incidents | 4 hours |
| **Antivirus Vendor** | [vendor] | Malware incidents | 24 hours |
| **ISP/Hosting** | [provider] | Network-level incidents | 2 hours |

---

## 5. Template: Incident Report

```markdown
# INCIDENT REPORT

**Report Date:** YYYY-MM-DD
**Incident ID:** INC-[YYYYMMDD-001]
**Severity:** [ ] Low [ ] Medium [ ] High

## Discovery
- **When:** YYYY-MM-DD HH:MM
- **How:** [Detected by monitoring / User report / Audit / etc]
- **Who Discovered:** [Name]

## Incident Details
- **Data Affected:** [emails, tokens, logs, etc]
- **Users Affected:** [count]
- **Estimated Exposure Duration:** [hours/days/weeks]
- **Root Cause:** [brief description]

## Timeline
- YYYY-MM-DD HH:MM: [Event]
- YYYY-MM-DD HH:MM: [Event]

## Actions Taken
- [ ] Contained breach (stopped app, revoked tokens)
- [ ] Investigated root cause
- [ ] Implemented fix
- [ ] Notified users (if required)
- [ ] Notified DPA (if required)

## Lessons Learned
1. [Control that failed]
2. [Why it wasn't detected]
3. [Preventive measure added]

**Approver:** [Name, Title]
```

---

## 6. Quick Reference Checklist

**IMMEDIATE (within 1 hour):**
- [ ] Stop application
- [ ] Assess severity and scope
- [ ] Revoke exposed tokens
- [ ] Backup evidence

**SHORT-TERM (within 24 hours):**
- [ ] Investigate root cause
- [ ] Implement fix
- [ ] Test remediation
- [ ] Prepare user notification

**MEDIUM-TERM (within 72 hours):**
- [ ] Notify affected users
- [ ] Notify DPA (if required)
- [ ] Resume operations
- [ ] Monitor for recurrence

**LONG-TERM (within 2 weeks):**
- [ ] Post-incident review meeting
- [ ] Document lessons learned
- [ ] Implement preventive measures
- [ ] Training and awareness

---

## 7. References

- [GDPR_PRIVACY_POLICY.md](GDPR_PRIVACY_POLICY.md) – Privacy policy
- [DATA_RETENTION_POLICY.md](DATA_RETENTION_POLICY.md) – Retention procedures
- [SECURITY.md](SECURITY.md) – Security controls
- GDPR Article 33: https://gdpr-info.eu/art-33-gdpr/

---

**Version:** 1.0  
**Last Updated:** July 4, 2026  
**Status:** Active  
**Review Frequency:** Annually or after incident
