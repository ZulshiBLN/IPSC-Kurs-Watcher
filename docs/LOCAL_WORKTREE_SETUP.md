# Local Worktree Setup – IPSC Kurs Watcher

**Purpose:** Isolated development environments per Git branch using Git Worktrees  
**Version:** v1.0.0  
**Last Updated:** 2026-07-05  
**Audience:** Developers, Maintainers

---

## Overview

IPSC Kurs Watcher uses **Git Worktrees** to maintain separate working directories for each branch. This ensures:

- ✅ Scheduled Task always runs from stable `main/` branch
- ✅ Development work in `develop/` doesn't affect production
- ✅ Beta testing in `prerelease/` is isolated
- ✅ Parallel development on multiple branches simultaneously

---

## Directory Structure

```
C:\Repos\IPSC Kurs Watcher\
│
├─ .git/                              ← Central repository (git-managed)
│
├─ main/                              ← Worktree: Stable (main Branch)
│   ├─ Scheduler.ps1                  ← Scheduled Task runs from HERE
│   ├─ scripts/
│   ├─ src/
│   ├─ config/
│   └─ data/
│
├─ develop/                           ← Worktree: Development (develop Branch)
│   ├─ Scheduler.ps1
│   ├─ scripts/
│   ├─ src/
│   ├─ config/
│   └─ data/
│
└─ prerelease/                        ← Worktree: Beta Testing (prerelease Branch)
    ├─ Scheduler.ps1
    ├─ scripts/
    ├─ src/
    ├─ config/
    └─ data/
```

---

## Git Worktree Basics

### What are Git Worktrees?

Git Worktrees allow multiple working directories for the same repository, each checked out to a different branch. All worktrees share the same `.git` directory, so:

- ✅ One `.git` (no storage duplication)
- ✅ Multiple branches checked out simultaneously
- ✅ Changes in one branch don't affect others
- ✅ Git operations work normally (`push`, `pull`, `commit`, etc.)

### Listing Worktrees

```powershell
cd C:\Repos\IPSC Kurs Watcher
git worktree list

# Output:
# C:/Repos/IPSC Kurs Watcher                42b0e0e (detached HEAD)
# C:/Repos/IPSC Kurs Watcher/main           42b0e0e [main]
# C:/Repos/IPSC Kurs Watcher/develop        42b0e0e [develop]
# C:/Repos/IPSC Kurs Watcher/prerelease     42b0e0e [prerelease]
```

---

## Workflow: Development

### Working on Features (develop/)

```powershell
# Navigate to develop worktree
cd C:\Repos\IPSC Kurs Watcher\develop

# Create feature branch (optional)
git checkout -b feature/my-feature

# Make changes
# ... edit files in develop/ ...

# Commit locally
git commit -m "Feat: Add new feature"

# Push to remote
git push origin develop

# Verify locally
.\Scheduler.ps1 -RunOnce

# Meanwhile, Scheduled Task still runs from main/ (unaffected!)
```

### Key Point
The `main/` worktree remains **unchanged** while you develop. Scheduled Task continues running the stable version.

---

## Workflow: Beta Testing

### Testing Pre-Releases (prerelease/)

```powershell
# Navigate to prerelease worktree
cd C:\Repos\IPSC Kurs Watcher\prerelease

# Merge latest develop (after feature-complete)
git merge origin/develop

# Tag as beta
git tag v1.1.0-beta.1
git push origin v1.1.0-beta.1

# Test in isolation
.\Scheduler.ps1 -Verbose

# Meanwhile:
# - develop/ is still open for new features
# - main/ Scheduled Task runs unaffected
```

---

## Workflow: Production Release

### Releasing to Production (main/)

```powershell
# Navigate to main worktree
cd C:\Repos\IPSC Kurs Watcher\main

# Merge prerelease (after validation)
git merge origin/prerelease

# Tag stable release
git tag v1.1.0
git push origin v1.1.0

# Scheduled Task automatically uses this version:
# (no manual action needed - just runs next cycle)
```

**Important:** After pushing to `main/`, the Scheduled Task will pick up the new version on the next scheduled run (every 30 minutes).

---

## Scheduled Task Configuration

### Current Setup

The Windows Scheduled Task runs:

```
Task: IPSC-Kurs-Watcher
Path: C:\Repos\IPSC Kurs Watcher\main\scripts\Scheduler.ps1
Trigger: Every 30 minutes
Action: PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Repos\IPSC Kurs Watcher\main\Scheduler.ps1"
```

### Why main/?

- **Stable:** Always points to production-ready code
- **Isolated:** Development in `develop/` doesn't affect Scheduled Task
- **Predictable:** Same code runs each cycle (no surprises from branch changes)

---

## Common Tasks

### Update all worktrees to latest remote state

```powershell
cd C:\Repos\IPSC Kurs Watcher\main && git pull
cd C:\Repos\IPSC Kurs Watcher\develop && git pull
cd C:\Repos\IPSC Kurs Watcher\prerelease && git pull
```

### Switch between worktrees

```powershell
# From root
cd main
cd develop
cd prerelease

# Or directly
cd C:\Repos\IPSC Kurs Watcher\main
```

### Create new worktree (if needed)

```powershell
cd C:\Repos\IPSC Kurs Watcher
git worktree add staging origin/staging
```

### Remove worktree (if needed)

```powershell
cd C:\Repos\IPSC Kurs Watcher
git worktree remove staging
```

---

## Integration with Release Strategy

### Release Flow with Worktrees

```
Week 1: Development (develop/)
│
├─ cd develop/
├─ git checkout -b feature/notifications
├─ ... code ...
├─ git commit
├─ git push origin develop
│
└─ Meanwhile: Scheduled Task runs from main/ (stable)

Week 2: Beta Testing (prerelease/)
│
├─ cd prerelease/
├─ git merge origin/develop
├─ git tag v1.1.0-beta.1
├─ ./Scheduler.ps1 -Verbose
│
└─ Meanwhile: Scheduled Task runs from main/ (stable)

Week 3: Production Release (main/)
│
├─ cd main/
├─ git merge origin/prerelease
├─ git tag v1.1.0
├─ git push origin v1.1.0
│
└─ Scheduled Task automatically runs v1.1.0 next cycle ✅
```

---

## File & Directory Isolation

### Each Worktree Has Its Own:

| Directory | Isolation |
|-----------|-----------|
| `config/` | Independent (`.gitignore`d) |
| `data/` | Independent (`.gitignore`d) |
| `logs/` | Independent per branch |
| `src/` | Tracked via Git (auto-synced) |
| `scripts/` | Tracked via Git (auto-synced) |

**Important:** `config/` and `data/` are NOT synced between worktrees (they're in `.gitignore`). Each worktree maintains its own state files.

---

## Troubleshooting

### Problem: "fatal: 'main' is already used by worktree"

**Solution:** Worktree already exists. Use `git worktree list` to see all, then:

```powershell
# Either navigate to existing worktree
cd C:\Repos\IPSC Kurs Watcher\main

# Or remove and recreate
git worktree remove main
git worktree add main origin/main
```

### Problem: Scheduled Task fails after merging to main/

**Solution:** Git merges don't automatically reload in running Scheduled Tasks. The task will pick up changes on the next scheduled run. If urgent:

```powershell
# Manually test new version
cd C:\Repos\IPSC Kurs Watcher\main
git pull
.\Scheduler.ps1 -RunOnce
```

### Problem: "Branch is already checked out elsewhere"

**Solution:** Each branch can only be in ONE worktree at a time. You cannot have two worktrees on the same branch.

```powershell
# This will fail:
git worktree add backup origin/main   # main is already in main/ worktree

# Solution: checkout a different branch or use a detached HEAD
git worktree add backup <commit-hash>
```

---

## Best Practices

### DO:

✅ Always use the correct worktree for your task:
- Development → `develop/`
- Beta testing → `prerelease/`
- Production monitoring → `main/`

✅ Keep worktrees clean:
```powershell
# Before switching worktrees
git status  # verify no uncommitted changes
git pull    # sync with remote
```

✅ Use meaningful branch names:
- Feature branches: `feature/description`
- Bugfix branches: `bugfix/issue-description`
- Hotfix branches: `hotfix/critical-issue`

### DON'T:

❌ Don't manually edit files in `main/` worktree
- Changes should come via Git merges from `prerelease/`

❌ Don't run development from `main/` worktree
- Use `develop/` for feature work
- Use `prerelease/` for pre-release testing

❌ Don't delete `.git` directory
- It's shared by all worktrees
- Deleting it breaks all worktrees

---

## Related Documentation

- [RELEASE_STRATEGY.md](RELEASE_STRATEGY.md) — 3-branch release workflow
- [DEPLOYMENT.md](DEPLOYMENT.md) — How to deploy Scheduled Task
- [OPERATIONAL_GUIDE.md](OPERATIONAL_GUIDE.md) — Day-to-day operations

---

## Summary

Git Worktrees provide **isolated, parallel development environments** for each branch:

- `main/` → Production (Scheduled Task)
- `develop/` → Active development
- `prerelease/` → Beta testing

This eliminates the risk of development code accidentally running in production while enabling parallel work on multiple branches.
