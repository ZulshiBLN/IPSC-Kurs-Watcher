# Phase 7: Tests & CI/CD Pipeline

## Overview

Phase 7 implements comprehensive testing and continuous integration/continuous deployment (CI/CD) infrastructure. This ensures code quality, prevents regressions, and automates deployment to PowerShell Gallery.

## Testing Framework

### Pester v5+

All tests use Pester v5+ for modern test development and reporting capabilities.

**Installation:**
```powershell
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
```

## Test Structure

### Unit Tests

#### Config.Tests.ps1
Tests configuration management module:
- **Read-Config**: Load and parse JSON configuration
- **Save-Config**: Persist configuration with validation
- **Get-ConfigMonitor**: Retrieve monitor by name
- **Get-EnabledMonitors**: Filter enabled monitors
- **Get-EnabledCourseTypes**: Filter enabled course types

**Key Scenarios:**
- Valid config loading and parsing
- Invalid JSON error handling
- Data preservation on save
- Monitor/type filtering

#### Filters.Tests.ps1
Tests filtering pipeline components:
- **FilterByType**: Course type filtering with pattern matching
- **FilterByExclusion**: Regex-based course exclusion
- **Deduplicator**: Course deduplication and availability checking

**Key Scenarios:**
- Exact and partial pattern matching (case-insensitive)
- Exclusion regex patterns
- Duplicate detection
- Availability filtering (0 seats = exclude)

#### State.Tests.ps1
Tests state persistence and tracking:
- **Initialize-State**: Create and manage state file
- **Read-State**: Load persisted state
- **Save-State**: Persist state changes
- **Add-NotifiedCourse**: Track notified courses
- **Test-CourseNotified**: Check notification history
- **Clear-OldStateEntries**: Cleanup old entries

**Key Scenarios:**
- State file creation and initialization
- Course tracking by ID
- Timestamp recording
- Cleanup by age threshold
- Data type preservation

### Running Tests

#### Run All Tests
```powershell
.\tests\Run-Tests.ps1
```

#### Run Specific Tag
```powershell
.\tests\Run-Tests.ps1 -Tag Unit
.\tests\Run-Tests.ps1 -Tag Integration
```

#### Export Results
```powershell
.\tests\Run-Tests.ps1 -OutputFormat NUnitXml -OutputPath results.xml
.\tests\Run-Tests.ps1 -OutputFormat JSON -OutputPath results.json
```

#### Custom Test Path
```powershell
.\tests\Run-Tests.ps1 -Path ".\tests\Unit"
```

### Test Output Example

```
IPSC Kurs Watcher - Test Suite
================================

Found 3 test file(s)

=== Test Summary ===
Total Tests:  42
Passed:       42
Failed:       0
Skipped:      0
Duration:     3.2s

Detailed Results:
Name                          Result      Duration
----                          ------      --------
Read-Config                   Passed      0.234s
Save-Config                   Passed      0.187s
...
```

## CI/CD Pipeline

### GitHub Actions Workflow

**File:** `.github/workflows/ci-cd.yml`

#### Trigger Events
- **Push**: main, develop, prerelease branches
- **Pull Request**: Against main, develop, prerelease
- **Tags**: Version tags (v*) for releases

### Pipeline Jobs

#### 1. Validate - Code Structure Validation
- Run PSScriptAnalyzer
- Check code style (4-space indentation, K&R bracing)
- Validate module manifest
- Verify required functions

**On Failure:** Pipeline stops (no point running tests on invalid code)

#### 2. Test - Unit Test Execution
- Install Pester 5+
- Run all unit tests
- Generate NUnit XML report
- Upload test artifacts
- Publish results to GitHub

**On Failure:** Pipeline continues but marks as failed

#### 3. Analyze - Code Quality Analysis
- Run PSScriptAnalyzer comprehensive check
- Check for code smells
- Verify naming conventions
- Validate comment-based help

**On Failure:** Pipeline continues but marks as failed

#### 4. Security - Secret Scanning
- Check for hardcoded credentials
- Scan for API keys, tokens, passwords
- Exclude examples and placeholders
- Flag suspicious patterns

**On Failure:** Pipeline fails immediately (security issue)

#### 5. Publish-PSGallery - PowerShell Gallery Deployment
- **Only runs:** On version tags (v*) that are NOT beta/rc
- **Requires:** PSGALLERY_KEY secret configured
- **Action:** `Publish-Module` to PowerShell Gallery
- **Delay:** ~4-5 minutes for indexing

**Conditions:**
```yaml
if: startsWith(github.ref, 'refs/tags/v') && 
    !contains(github.ref, '-beta') && 
    !contains(github.ref, '-rc')
```

#### 6. Publish-Release - GitHub Release Creation
- **Runs on:** All version tags
- **Creates:** GitHub Release with auto-generated notes
- **Includes:** ZIP download, release notes
- **Handles:** Pre-releases correctly

#### 7. Notify - Completion Notification
- **Always runs** (success or failure)
- Aggregates all job results
- Provides status summary

### Pipeline Flow

```
Push/PR/Tag
  │
  ├─→ Validate (code structure)
  │   ├─ PASS → continue
  │   └─ FAIL → STOP (exit 1)
  │
  ├─→ Test (unit tests)
  │   ├─ PASS → continue
  │   └─ FAIL → continue (mark failed)
  │
  ├─→ Analyze (code quality)
  │   ├─ PASS → continue
  │   └─ FAIL → continue (mark failed)
  │
  ├─→ Security (secrets scan)
  │   ├─ PASS → continue
  │   └─ FAIL → STOP (exit 1)
  │
  ├─→ [If on version tag]
  │   ├─→ Publish-PSGallery
  │   │   (only if NOT beta/rc)
  │   │
  │   └─→ Publish-Release
  │       (all versions)
  │
  └─→ Notify (always)
      └─ Report status
```

## Configuration

### GitHub Secrets

For PowerShell Gallery publishing, configure:

**Settings → Secrets and variables → Actions**

Add `PSGALLERY_KEY`:
```
Name: PSGALLERY_KEY
Value: [Your PowerShell Gallery API Key]
```

**To get API key:**
1. Sign in to PowerShell Gallery (https://www.powershellgallery.com)
2. Account settings → API Keys
3. Create new key with "Write" permissions
4. Copy to GitHub Secrets

### Build Validation

**File:** `build.ps1`

```powershell
.\build.ps1 -Validate
```

Checks:
- PSScriptAnalyzer rules
- 4-space indentation
- K&R bracing style
- No trailing whitespace
- BOM for script files

## Deployment Strategy

### Version Tags and Releases

#### Beta Release
```powershell
git tag -a v1.12.0-beta.1 -m "Release: v1.12.0-beta.1 - Description"
git push origin v1.12.0-beta.1
git push github v1.12.0-beta.1
```

**Result:**
- ✅ GitHub Release created (Pre-release)
- ❌ NOT published to PowerShell Gallery

#### Stable Release
```powershell
git tag -a v1.12.0 -m "Release: v1.12.0 - Description"
git push origin v1.12.0
git push github v1.12.0
```

**Result:**
- ✅ GitHub Release created
- ✅ Published to PowerShell Gallery (~4-5 min)
- ✅ Becomes public via `Find-Module -Name IPSC-Kurs-Watcher`

### Deployment Timeline

```
Push version tag
  │
  ├─ 0:00 - Validate, Test, Analyze, Security (2-3 min)
  ├─ 3:00 - Publish to PSGallery (begins)
  ├─ 5:00 - PSGallery indexing
  ├─ 7:00 - Find-Module can find it
  └─ [Complete]
```

## Test Scenarios

### Configuration Tests

```powershell
# Load configuration
$config = Read-Config -Path "config/config.json"

# Validate structure
$config.Keys | Should -Contain "monitors"
$config.Keys | Should -Contain "filters"
$config.Keys | Should -Contain "notifiers"

# Get enabled items
$enabled = Get-EnabledMonitors -Config $config
$enabled.Count | Should -BeGreaterThan 0
```

### Filter Tests

```powershell
# Type filtering
$filter = New-CourseTypeFilter -Patterns @("Service Pistol")
$course = @{ type = "Service Pistol" }
Test-CourseType -Course $course -Filter $filter | Should -Be $true

# Deduplication
$dedup = New-Deduplicator -StateFile "state.json"
$isNew = -not (Test-CourseDuplicate -Course $course -Deduplicator $dedup)
$isNew | Should -Be $true
```

### State Tests

```powershell
# Track course
Add-NotifiedCourse -CourseId "course-123" -StateFile "state.json"

# Verify tracking
$notified = Test-CourseNotified -CourseId "course-123" -StateFile "state.json"
$notified | Should -Be $true

# Cleanup old entries (7 days)
Clear-OldStateEntries -DaysToKeep 7 -StateFile "state.json"
```

## Performance Metrics

### Test Execution

- **Total time:** 3-5 seconds (all tests)
- **Unit test time:** ~1-2 seconds
- **Validation time:** ~1 second
- **Analysis time:** ~1-2 seconds

### CI/CD Pipeline

- **On Pull Request:** ~5-10 minutes
  - Validate
  - Test
  - Analyze
  - Security

- **On Version Tag:** ~15-20 minutes
  - All jobs
  - Plus PSGallery publish (4-5 min)
  - Plus GitHub Release (1 min)

## Error Handling

### Test Failures
- Logged with stack trace
- Display expected vs actual
- Point to failing line
- Halt pipeline for validation errors
- Continue for test failures (still marked failed overall)

### Publishing Failures
- PSGallery unreachable: Retry (not automatic in current config)
- Invalid API key: Clear error message
- Module conflicts: Reject with version info
- All errors logged in workflow

## Best Practices

### For Developers

1. **Run tests locally before push:**
   ```powershell
   .\tests\Run-Tests.ps1
   ```

2. **Run validation before commit:**
   ```powershell
   .\build.ps1 -Validate
   ```

3. **View test reports:**
   ```powershell
   .\tests\Run-Tests.ps1 -OutputFormat JSON | ConvertFrom-Json
   ```

### For Maintainers

1. **Always require passing CI before merge**
   - GitHub Branch Protection Rules

2. **Monitor pipeline failures**
   - Check GitHub Actions tab regularly
   - Fix broken tests immediately

3. **Manage secrets carefully**
   - Rotate API keys periodically
   - Audit who has access
   - Never commit secrets

## Phase 7 Status: Complete Testing & CI/CD

**Implemented:**
- Comprehensive Pester test suite (3 test modules, 42 tests)
- Test runner with multiple output formats
- GitHub Actions CI/CD pipeline (7 jobs)
- Security scanning for secrets
- Automated PowerShell Gallery publishing
- GitHub Release creation
- Test result reporting

**Test Coverage:**
- Configuration management
- Filter pipeline components
- State persistence and tracking
- Error scenarios and edge cases

**CI/CD Features:**
- Automated validation on push/PR
- Test execution and reporting
- Code quality analysis
- Security scanning
- Conditional PSGallery publishing
- GitHub Release automation

## File Structure

```
IPSC Kurs Watcher/
├── tests/
│   ├── Run-Tests.ps1               (Test runner)
│   ├── Unit/
│   │   ├── Config.Tests.ps1        (Config tests)
│   │   ├── Filters.Tests.ps1       (Filter tests)
│   │   └── State.Tests.ps1         (State tests)
│   └── Integration/                (Placeholder)
├── .github/
│   └── workflows/
│       └── ci-cd.yml               (GitHub Actions)
├── build.ps1                       (Build validation)
├── PHASE7-TESTS.md                (This file)
└── ...
```

## Next Steps

**Future Enhancements:**
- Integration tests (E2E with mock monitors)
- Performance benchmarks
- Coverage reports (via Pester code coverage)
- Extended security scanning (SARIF format)
- Scheduled nightly test runs
- Deployment to staging environment

## Running Locally

```powershell
# Install Pester
Install-Module -Name Pester -MinimumVersion 5.0 -Force

# Run tests
cd "C:\Repos\IPSC Kurs Watcher"
.\tests\Run-Tests.ps1

# Validate code
.\build.ps1 -Validate

# Check specific tests
.\tests\Run-Tests.ps1 -Tag Unit

# Export results
.\tests\Run-Tests.ps1 -OutputFormat NUnitXml -OutputPath report.xml
```
