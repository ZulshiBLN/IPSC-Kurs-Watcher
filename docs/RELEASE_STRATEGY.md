# Release Strategy – IPSC Kurs Watcher

**Version:** v1.0.0  
**Status:** IMPLEMENTED  
**Last Updated:** 2026-07-05

---

## Overview

IPSC Kurs Watcher uses a **3-branch + 2-registry** release strategy for:
- Controlled feature development
- Beta testing before stable releases
- Multi-channel distribution (PSGallery, GitHub Packages, GitHub Releases)
- Clear workflow for maintainers and contributors

---

## Visual Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ FEATURE DEVELOPMENT (develop)                               │
│ - Daily commits                                             │
│ - Feature branch work                                       │
│ - PR reviews                                                │
│ - Pre-commit hooks validate code                            │
└────────────────────────────┬────────────────────────────────┘
                             │
                    Feature Complete
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│ BETA TESTING (prerelease)                                   │
│ - v1.1.0-beta.1, v1.1.0-beta.2, ...                         │
│ - GitHub Release (marked as pre-release)                    │
│ - Published to GitHub Packages (opt-in)                     │
│ - NOT on PowerShell Gallery                                 │
│ - Duration: 1-2 weeks                                       │
└────────────────────────────┬────────────────────────────────┘
                             │
                    Stable After Testing
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│ PRODUCTION RELEASE (main)                                   │
│ - v1.1.0 (final release)                                    │
│ - GitHub Release                                            │
│ - Published to GitHub Packages                              │
│ - Published to PowerShell Gallery                           │
│ - Supported long-term                                       │
└────────────────────────────┬────────────────────────────────┘
                             │
                    Bug Found in Prod
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│ HOTFIX (main)                                               │
│ - v1.1.1 (patch release)                                    │
│ - Critical bugs only                                        │
│ - Merge back to develop                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Branch Details

### 1. develop (Main Development)

**Purpose:** Active development and feature integration

**Characteristics:**
- Latest features
- May contain experimental code
- Requires pre-commit validation
- Updated daily by developers
- Merge PRs frequently

**Tagging:** Never tagged directly

**Distribution:** Internal use only

**Example commit:**
```
Feat: Add Discord notifications
Fix: Correct email body formatting
Refactor: Simplify logging module
```

### 2. prerelease (Beta Testing)

**Purpose:** Test features before stable release

**Characteristics:**
- Merges from develop when feature-complete
- Stabilization phase (bug fixes)
- First public release phase
- Duration: ~1 week
- Release candidates optional

**Tagging:** `v1.1.0-beta.1`, `v1.1.0-beta.2`, `v1.1.0-rc.1`

**Distribution:**
- GitHub Release (ZIP archive)
- GitHub Packages (for opt-in beta testers)

**Installation:**
```powershell
Install-Module -Name IPSCKursWatcher `
  -Repository GitHub `
  -RequiredVersion 1.1.0-beta.1
```

### 3. main (Production)

**Purpose:** Stable, production-ready releases

**Characteristics:**
- Only stable releases
- Long-term support
- Well-documented
- Fully tested
- Backward-compatible (except major versions)

**Tagging:** `v1.1.0`, `v2.0.0`, `v1.0.1` (hotfixes)

**Distribution:**
- GitHub Release
- GitHub Packages
- PowerShell Gallery (official)

**Installation:**
```powershell
Install-Module -Name IPSCKursWatcher  # Defaults to PSGallery
```

---

## Release Timeline

### Example: v1.1.0 Release Cycle

```
Week 1 (Mon-Fri): Development on develop
  - Features added
  - Code reviewed
  - Tests updated

Week 2 (Mon): Merge develop → prerelease
  - Tag: v1.1.0-beta.1
  - GitHub Release created
  - GitHub Packages published
  - Changelog generated

Week 2 (Tue-Fri): Beta Testing
  - User feedback collected
  - Bug fixes in prerelease
  - v1.1.0-beta.2 if needed

Week 3 (Mon): Release Candidate (optional)
  - Tag: v1.1.0-rc.1
  - Final validation

Week 3 (Tue): Merge prerelease → main
  - Tag: v1.1.0
  - GitHub Release created
  - GitHub Packages updated
  - PowerShell Gallery published
  - Announcement sent

Week 3+: Monitoring
  - Watch for critical issues
  - Prepare hotfix if needed
  - Begin v1.2.0 development
```

---

## Version Numbering (Semantic Versioning)

```
MAJOR.MINOR.PATCH[-PRERELEASE]

MAJOR (Breaking Changes)
  v1.0.0 → v2.0.0
  Example: Complete rewrite, incompatible API

MINOR (New Features)
  v1.0.0 → v1.1.0
  Example: Add Discord notifications

PATCH (Bug Fixes)
  v1.0.0 → v1.0.1
  Example: Fix email formatting bug

PRERELEASE (Testing Versions)
  v1.1.0-beta.1     First beta
  v1.1.0-beta.2     Bug fixes
  v1.1.0-rc.1       Release candidate
  v1.1.0            Final release
```

---

## Distribution Channels

### GitHub Releases
- **Purpose:** Version history, download archive, release notes
- **Content:** ZIP archive with all files
- **Audience:** Manual installers, archival
- **URL:** `https://github.com/ZulshiBLN/IPSC-Kurs-Watcher/releases`

### GitHub Packages
- **Purpose:** PowerShell repository for beta + stable
- **Content:** Packaged PowerShell module
- **Audience:** Beta testers (pre-release), early adopters (stable)
- **Setup:** One-time registration (see BETA_TESTING.md)
- **Installation:** `Install-Module -Repository GitHub`

### PowerShell Gallery
- **Purpose:** Official stable releases only
- **Content:** Packaged PowerShell module
- **Audience:** All users
- **Setup:** None (pre-configured in PowerShell)
- **Installation:** `Install-Module -Name IPSCKursWatcher`

---

## Matrix: What Gets Published Where

| Version | Type | GitHub Release | GitHub Packages | PSGallery |
|---------|------|---|---|---|
| v1.1.0-beta.1 | Pre-release | ✅ | ✅ | ❌ |
| v1.1.0-rc.1 | Pre-release | ✅ | ✅ | ❌ |
| v1.1.0 | Stable | ✅ | ✅ | ✅ |
| v1.0.1 | Hotfix | ✅ | ✅ | ✅ |

---

## Developer Workflow

### Creating a Feature

```bash
# 1. On develop branch
git checkout develop
git pull origin develop

# 2. Create feature
# ... code changes ...
git commit -m "Feat: Add new feature"
git push origin develop

# 3. Pre-commit hooks validate automatically
# Build, lint, test run on push
```

### Preparing for Beta

```bash
# 1. Feature-complete on develop
# 2. Maintainer merges to prerelease
git checkout prerelease
git merge develop

# 3. Tag as beta
git tag v1.1.0-beta.1 -m "Beta 1"
git push origin v1.1.0-beta.1

# 4. GitHub Actions handles:
#    - GitHub Release creation
#    - GitHub Packages publishing
#    - Release notes generation
```

### Releasing to Production

```bash
# 1. After beta testing (validate checklist)
# 2. Maintainer merges to main
git checkout main
git merge prerelease

# 3. Tag final release
git tag v1.1.0 -m "Stable release"
git push origin v1.1.0

# 4. GitHub Actions handles:
#    - GitHub Release creation
#    - GitHub Packages publishing
#    - PowerShell Gallery publishing
#    - Merge back to develop (optional)
```

---

## Quality Checklist: Beta → Stable

Before merging `prerelease` → `main`:

- [ ] All beta issues resolved or documented
- [ ] No open "blocker" issues
- [ ] Documentation updated (CHANGELOG, README, guides)
- [ ] v1.1.0-beta.N tested stable for 3+ days
- [ ] No regressions from v1.0.0
- [ ] Security review completed (if applicable)
- [ ] Deployment documented
- [ ] Support plan ready

---

## Hotfix Process (Production Issues)

```bash
# 1. Critical bug found in v1.0.0
# 2. Create hotfix on main
git checkout main
git pull origin main

# 3. Apply fix
# ... code changes ...

# 4. Update version to v1.0.1
# Update: IPSCKursWatcher.psd1, CLAUDE.md, README.md

# 5. Tag and release
git tag v1.0.1 -m "Hotfix: Critical issue"
git push origin v1.0.1
git push origin main

# 6. Merge back to develop
git checkout develop
git merge main
git push origin develop

# 7. Notify users about hotfix
#    - GitHub Release announcement
#    - PowerShell Gallery updated automatically
```

---

## Rollback Procedure

If stable release has critical issues:

```bash
# 1. Document issue
# 2. Create hotfix or revert
# 3. Re-tag with next patch version

# Do NOT delete/overwrite released versions
# Version history should be immutable
```

---

## Documentation References

For detailed information, see:

- **ADR-005** → [DECISIONS.md](DECISIONS.md) — Architectural decision rationale
- **Beta Testing** → [BETA_TESTING.md](BETA_TESTING.md) — How to install & test beta releases
- **Release Automation** → [RELEASE_AUTOMATION.md](RELEASE_AUTOMATION.md) — GitHub Actions workflow
- **Deployment** → [DEPLOYMENT.md](DEPLOYMENT.md) — Installation methods

---

## Summary

**3 Branches:**
- `develop` — Daily development
- `prerelease` — Beta testing (1 week)
- `main` — Production stable

**2 Registries:**
- PowerShell Gallery (stable only)
- GitHub Packages (beta + stable)

**Always available:**
- GitHub Releases (all versions)

This strategy ensures **quality**, **testability**, and **user confidence** while maintaining **developer velocity**. ✅
