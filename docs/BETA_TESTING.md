# Beta Testing Guide – IPSC Kurs Watcher

**Purpose:** Instructions for beta testers to install and test pre-release versions

**Version:** v1.0.0  
**Last Updated:** 2026-07-05  
**Audience:** Beta Testers, Early Adopters, Contributors

---

## What is Beta Testing?

Beta releases (e.g., `v1.1.0-beta.1`, `v1.1.0-rc.1`) are pre-release versions available for testing before the official stable release.

**Benefits of Beta Testing:**
- Test new features early
- Report bugs before stable release
- Influence feature direction
- Help improve quality

---

## Installation: GitHub Packages

Beta versions are published to **GitHub Packages** (private PowerShell registry).

### Step 1: Create GitHub Personal Access Token

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Set scope: `read:packages` (read packages from GitHub Packages)
4. Copy the token (you'll need it once)

### Step 2: Register GitHub Packages Repository

Run this **one time** on your system:

```powershell
# Create credential object
$Username = "YOUR_GITHUB_USERNAME"  # Replace with your GitHub username
$Token = "ghp_xxxxxxxxxxxx"  # Paste your token here
$SecureToken = ConvertTo-SecureString -String $Token -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($Username, $SecureToken)

# Register repository
Register-PSRepository `
  -Name "GitHub" `
  -SourceLocation "https://nuget.pkg.github.com/ZulshiBLN/index.json" `
  -InstallationPolicy Trusted `
  -Credential $Credential
```

**Verify registration:**
```powershell
Get-PSRepository | Select-Object Name, SourceLocation
# Should show both PSGallery and GitHub
```

### Step 3: Install Beta Version

```powershell
# List available beta versions
Find-Module -Name IPSCKursWatcher -Repository GitHub -AllVersions

# Install specific beta version
Install-Module -Name IPSCKursWatcher `
  -Repository GitHub `
  -RequiredVersion 1.1.0-beta.1 `
  -Force  # Overwrite stable version if installed
```

**Verify installation:**
```powershell
Get-Module IPSCKursWatcher -ListAvailable
# Should show 1.1.0-beta.1 (or whatever version you installed)

# Test it works
Invoke-MonitoringCycle -Verbose
```

---

## Switching Between Versions

### From Stable to Beta

```powershell
# Uninstall current version
Uninstall-Module -Name IPSCKursWatcher

# Install beta
Install-Module -Name IPSCKursWatcher `
  -Repository GitHub `
  -RequiredVersion 1.1.0-beta.1
```

### From Beta to Stable

```powershell
# Uninstall beta
Uninstall-Module -Name IPSCKursWatcher

# Install stable (from PSGallery)
Install-Module -Name IPSCKursWatcher  # Defaults to PSGallery
```

### From One Beta to Another Beta

```powershell
# Update to new beta version
Update-Module -Name IPSCKursWatcher `
  -RequiredVersion 1.1.0-beta.2
```

---

## Reporting Issues

Found a bug or problem? Report it!

### Issue Report Template

```
**Version:** 1.1.0-beta.1
**Windows Version:** Windows 10 / Windows Server 2019
**PowerShell Version:** 5.1

**Description:**
[What you were trying to do]

**Expected Behavior:**
[What should have happened]

**Actual Behavior:**
[What actually happened]

**Steps to Reproduce:**
1. ...
2. ...
3. ...

**Error Message:**
[If applicable, paste error output]

**Logs:**
[If applicable, attach relevant log entries]
```

### Where to Report

1. **GitHub Issues:** https://github.com/ZulshiBLN/IPSC-Kurs-Watcher/issues
2. **Email:** google@brosche-bausinger.ch

---

## Stability vs Testing

### When to Use Beta
- ✅ Testing environment (not critical/production)
- ✅ Development machine
- ✅ You want early features
- ✅ You don't mind occasional issues

### When NOT to Use Beta
- ❌ Production monitoring (use stable releases)
- ❌ Critical / business-critical systems
- ❌ Zero-downtime required
- ❌ You need full support

---

## Beta Release Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| **Development** (develop branch) | 2 weeks | Active feature work |
| **Beta Testing** (prerelease branch) | 1 week | `v1.1.0-beta.1` available |
| **Release Candidate** | 1 week | `v1.1.0-rc.1` (optional) |
| **Stable Release** (main branch) | Ongoing | `v1.1.0` on PowerShell Gallery |

---

## FAQ

**Q: Will beta updates break my configuration?**
A: Not intentionally, but breaking changes are possible. Back up your `config.json` before upgrading.

**Q: Can I run beta alongside stable?**
A: No, only one version can be installed at a time. Uninstall one before installing the other.

**Q: What if I find a critical bug?**
A: Report immediately to github@brosche-bausinger.ch with `[CRITICAL]` in subject.

**Q: When will the stable version be released?**
A: Check GitHub Releases for timeline. Typically 1-2 weeks after beta.

**Q: Can I downgrade from beta to stable?**
A: Yes, uninstall beta, then `Install-Module -Name IPSCKursWatcher` (defaults to latest stable).

---

## Feedback

Your feedback helps improve IPSC Kurs Watcher!

- **Bug reports:** GitHub Issues
- **Feature requests:** GitHub Discussions (if available)
- **Direct feedback:** google@brosche-bausinger.ch

Thank you for beta testing! 🎉
