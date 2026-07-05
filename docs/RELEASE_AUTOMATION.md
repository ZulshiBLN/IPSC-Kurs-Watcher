# Release Automation & PowerShell Gallery Publishing

**Last Updated:** 2026-07-05  
**Version:** v1.0.0  
**Audience:** Maintainers, DevOps, Release Engineers

---

## Overview

IPSC Kurs Watcher uses **GitHub Actions** for automated releases:

```
Git Tag (v1.0.0)
         ↓
GitHub Actions Trigger
         ↓
[Extract Version] → [Generate Release Notes] → [Create ZIP] → [GitHub Release]
                                                                    ↓
                                                         [Publish to PSGallery]
                                                          (stable only)
                                                                    ↓
                                                         [Verify Publication]
```

---

## How to Create a Release

### 1. Update Version

**Update in CLAUDE.md:**
```markdown
**Version:** v1.1.0
**Status:** [STABLE] ...
```

**Update in README.md:**
```markdown
**Version:** v1.1.0 (Stable)
```

**Update in IPSCKursWatcher.psd1:**
```powershell
ModuleVersion = '1.1.0'
```

### 2. Commit Changes

```powershell
git add CLAUDE.md README.md IPSCKursWatcher.psd1 ...
git commit -m "Release: v1.1.0 - Feature description"
```

### 3. Create Git Tag

```powershell
# For stable release (published to PSGallery)
git tag v1.1.0 -m "Release v1.1.0"

# For pre-release (NOT published to PSGallery)
git tag v1.1.0-beta.1 -m "Beta 1"
git tag v1.1.0-rc.1 -m "Release Candidate 1"
```

### 4. Push Tag

```powershell
git push origin v1.1.0
git push github v1.1.0
```

**That's it!** GitHub Actions automatically handles:
- ✅ GitHub Release creation (with ZIP download)
- ✅ Release notes generation
- ✅ PowerShell Gallery publishing (stable only)
- ✅ Publication verification

---

## PSGallery Integration Setup

### 1. Generate API Key

1. Navigate to: https://www.powershellgallery.com/account/Edit
2. Click **Create** to generate a new API key
3. Copy the key (you'll need it for GitHub)

### 2. Add to GitHub Secrets

1. Go to: https://github.com/ZulshiBLN/IPSC-Kurs-Watcher/settings/secrets/actions
2. Click **New repository secret**
3. **Name:** `PSGALLERY_API_KEY`
4. **Value:** (paste API key from step 1)
5. Click **Add secret**

### 3. Verify Setup

Run the release workflow to test:

```powershell
git tag v1.0.0-test -m "Test release"
git push origin v1.0.0-test
```

Check GitHub Actions at: https://github.com/ZulshiBLN/IPSC-Kurs-Watcher/actions

---

## Release Automation Workflow

### Stable Release (Published to PSGallery)

**Tag format:** `v1.x.x` (e.g., `v1.0.0`, `v1.1.0`, `v2.0.0`)

**Workflow:**
```
1. GitHub Actions triggered by tag push
2. Extract version (1.0.0)
3. Generate release notes from commits
4. Create ZIP archive
5. Create GitHub Release
6. Publish to PowerShell Gallery ✓
7. Verify on PSGallery (5-10 min)
8. Notification complete
```

**Installation after stable release:**
```powershell
Install-Module -Name IPSCKursWatcher -RequiredVersion 1.0.0
```

### Pre-Release (NOT Published to PSGallery)

**Tag format:** `v1.x.x-beta.N`, `v1.x.x-rc.N`, `v1.x.x-alpha.N`

**Examples:**
- `v1.1.0-beta.1` – Beta version
- `v1.1.0-rc.1` – Release candidate
- `v1.2.0-alpha.1` – Alpha version

**Workflow:**
```
1. GitHub Actions triggered by tag push
2. Extract version (1.1.0-beta.1)
3. Generate release notes from commits
4. Create ZIP archive
5. Create GitHub Release
6. SKIP PowerShell Gallery publishing ⏭
7. Available on GitHub Releases only
8. Notification complete
```

**Installation after pre-release:**
```powershell
# Download ZIP from: https://github.com/ZulshiBLN/IPSC-Kurs-Watcher/releases/tag/v1.1.0-beta.1
# Extract and run: .\Scheduler.ps1 -RunOnce
```

---

## Multi-Registry Publication Strategy

### Overview

```
Pre-Release (v1.1.0-beta.1)
    ├─ GitHub Release ✅
    ├─ GitHub Packages ✅
    └─ PowerShell Gallery ❌ (NOT published)

Stable Release (v1.1.0)
    ├─ GitHub Release ✅
    ├─ GitHub Packages ✅
    └─ PowerShell Gallery ✅
```

### Step 1: GitHub Actions Triggers Release

```yaml
on:
  push:
    tags:
      - 'v*'  # Any tag starting with v (v1.0.0, v2.0.0-rc, etc.)
```

### Step 2: Version Detection

```powershell
VERSION="1.0.0"    # Extracted from tag v1.0.0
IS_PRERELEASE="false"
PUBLISH_TO_GALLERY="true"
```

### Step 3: ZIP Archive Creation

```bash
zip -r IPSC-Kurs-Watcher-v1.0.0.zip . \
  -x '*.git*' '*.github*' '*.log' 'release/*'
```

### Step 4: GitHub Release

```
Release: IPSC Kurs Watcher v1.0.0
Files: IPSC-Kurs-Watcher-v1.0.0.zip
Status: Published (not pre-release)
```

### Step 5: PSGallery Publishing

**Only if:**
- ✓ Is stable release (not beta/rc/alpha)
- ✓ PSGALLERY_API_KEY secret is set

**Publication:**
```powershell
Publish-Module -Path . `
  -NuGetApiKey $apiKey `
  -Repository PSGallery `
  -Force
```

**Result:**
```
Module: IPSCKursWatcher
Version: 1.0.0
URL: https://www.powershellgallery.com/packages/IPSCKursWatcher/1.0.0
Indexing: 5-10 minutes
```

### Step 6: Verification

```powershell
Find-Module -Name IPSCKursWatcher -RequiredVersion 1.0.0
```

Expected output:
```
Name             Version    Repository Description
----             -------    ---------- -----------
IPSCKursWatcher  1.0.0      PSGallery  Automated IPSC course monitoring...
```

---

## Common Release Scenarios

### Scenario 1: Stable Release (v1.0.0)

```powershell
# 1. Update version files
# 2. Commit
git add CLAUDE.md README.md IPSCKursWatcher.psd1
git commit -m "Release: v1.0.0"

# 3. Tag
git tag v1.0.0 -m "Release v1.0.0"

# 4. Push
git push origin v1.0.0
git push github v1.0.0

# Result: GitHub Release + PSGallery Published
# Installation: Install-Module -Name IPSCKursWatcher -RequiredVersion 1.0.0
```

### Scenario 2: Beta Release (v1.1.0-beta.1)

```powershell
git tag v1.1.0-beta.1 -m "Beta 1 for v1.1.0"
git push origin v1.1.0-beta.1

# Result: GitHub Release ONLY (not PSGallery)
# Installation: Download ZIP from GitHub Release
```

### Scenario 3: Release Candidate (v1.1.0-rc.1)

```powershell
git tag v1.1.0-rc.1 -m "Release Candidate 1"
git push origin v1.1.0-rc.1

# Result: GitHub Release ONLY (not PSGallery)
# For testing before final v1.1.0 release
```

---

## Troubleshooting

### GitHub Release Created but PSGallery Not Updated

**Possible causes:**
1. Pre-release tag detected (beta/rc/alpha) – workflow intentionally skips PSGallery
2. PSGALLERY_API_KEY secret not set – check GitHub repo settings
3. API key is invalid – regenerate at https://www.powershellgallery.com/account/Edit
4. Module manifest invalid – run `Test-ModuleManifest IPSCKursWatcher.psd1`

**Solution:**
```powershell
# Check workflow run
# https://github.com/ZulshiBLN/IPSC-Kurs-Watcher/actions

# View step: "Run PowerShell Publishing Script"
# Check error message

# If pre-release:
# Release is working as intended (pre-releases not published to PSGallery)

# If missing API key:
# Add PSGALLERY_API_KEY to GitHub secrets

# If invalid manifest:
# Run: Test-ModuleManifest IPSCKursWatcher.psd1
# Fix errors and re-tag
```

### Module Not Found on PSGallery After 10 Minutes

**Possible causes:**
1. Module is still indexing (normal, takes 5-10 minutes)
2. Module publish failed silently
3. Connection timeout during verification

**Solution:**
```powershell
# Check PSGallery directly
Start-Sleep -Seconds 60
Find-Module -Name IPSCKursWatcher -Repository PSGallery

# Or browse: https://www.powershellgallery.com/packages/IPSCKursWatcher
```

### Release Workflow Failed

**Check GitHub Actions logs:**

1. Go to: https://github.com/ZulshiBLN/IPSC-Kurs-Watcher/actions
2. Click failed workflow run
3. Expand step that failed (usually "Run PowerShell Publishing Script")
4. Read error message

**Common errors:**
- `NuGetApiKey is empty` → Add PSGALLERY_API_KEY secret
- `Module already exists` → Version already published (normal, workflow skips)
- `Manifest validation failed` → Fix IPSCKursWatcher.psd1 syntax

---

## Version Numbering Policy

| Version | PSGallery | GitHub | Example |
|---------|-----------|--------|---------|
| Stable Release | ✅ Published | ✅ Release | v1.0.0, v1.1.0, v2.0.0 |
| Beta | ❌ Skipped | ✅ Release | v1.1.0-beta.1, v1.1.0-beta.2 |
| Release Candidate | ❌ Skipped | ✅ Release | v1.1.0-rc.1, v1.1.0-rc.2 |
| Alpha | ❌ Skipped | ✅ Release | v1.2.0-alpha.1 |

**Rationale:** PSGallery listing policy restricts published modules to stable releases. Pre-releases must be downloaded from GitHub directly.

---

## Files Involved

| File | Purpose |
|------|---------|
| `.github/workflows/release.yml` | GitHub Actions workflow (triggered by tag) |
| `scripts/Publish-ToGallery.ps1` | PowerShell Gallery publishing script |
| `IPSCKursWatcher.psd1` | Module manifest (name, version, metadata) |
| `CLAUDE.md` | Version string (must be updated before tag) |
| `README.md` | Version string (must be updated before tag) |

---

## References

- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [PowerShell Gallery Publishing](https://docs.microsoft.com/en-us/powershell/scripting/gallery/publishing-guidelines/publishing-to-the-gallery)
- [Publish-Module Documentation](https://docs.microsoft.com/en-us/powershell/module/powershellget/publish-module)
- [Semantic Versioning](https://semver.org/)
