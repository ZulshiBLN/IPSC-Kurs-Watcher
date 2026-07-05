@{
    RootModule           = 'IPSCKursWatcher.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '5c7e9a2f-b4d1-4e6c-8f3a-9d2e1c5b7f4a'
    Author               = 'ZulshiBLN'
    CompanyName          = 'IPSC Kurs Watcher'
    Copyright            = '(c) 2026 ZulshiBLN. All rights reserved.'
    Description          = 'Automated IPSC course monitoring and notifications for shooting-store.ch. Detects new courses, availability changes, and sends alerts via Windows Toast, Email (OAuth2), and Discord webhooks.'

    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop')

    FunctionsToExport    = @(
        'Invoke-MonitoringCycle'
    )

    # Scripts to execute when the module is imported
    ScriptsToProcess     = @(
        'src/core/Helpers.ps1'
        'src/core/Logging.ps1'
        'src/core/Config.ps1'
        'src/core/State.ps1'
    )

    PrivateData          = @{
        PSData = @{
            # Release notes
            ReleaseNotes = @'
# IPSC Kurs Watcher v1.0.0 Release

## What's New
- Complete modular architecture with zero external dependencies
- Multi-channel notifications: Windows Toast, Email (OAuth2), Discord webhooks
- Comprehensive security: DPAPI encryption, URL validation, credential isolation
- Full documentation: 7 guides covering architecture, security, deployment, operations
- Production-ready: 75-80% test coverage with Pester test suite

## Features
✓ Automated course monitoring from shooting-store.ch
✓ Real-time change detection (NEW, REDUCED, SOLD_OUT)
✓ State persistence and deduplication
✓ Windows Scheduled Task integration
✓ Structured JSON logging with 30-day auto-rotation
✓ Flexible filtering (type, exclusion, availability threshold)

## Installation
Install-Module -Name IPSCKursWatcher -RequiredVersion 1.0.0

## Quick Start
https://github.com/ZulshiBLN/IPSC-Kurs-Watcher#quick-start-5-minutes

## Documentation
- Architecture: https://github.com/ZulshiBLN/IPSC-Kurs-Watcher/blob/main/docs/ARCHITECTURE.md
- Deployment: https://github.com/ZulshiBLN/IPSC-Kurs-Watcher/blob/main/docs/DEPLOYMENT.md
- Configuration: https://github.com/ZulshiBLN/IPSC-Kurs-Watcher/blob/main/docs/CONFIG_SCHEMA.md
- Operations: https://github.com/ZulshiBLN/IPSC-Kurs-Watcher/blob/main/docs/OPERATIONAL_GUIDE.md

## Repository
https://github.com/ZulshiBLN/IPSC-Kurs-Watcher

## License
(To be determined)
'@

            # Tags for gallery discovery
            Tags = @(
                'IPSC'
                'Shooting'
                'CourseMonitoring'
                'Notifications'
                'Automation'
                'Windows'
                'PowerShell'
                'Windows-Toast'
                'Email-Notifications'
                'Discord-Webhooks'
                'OAuth2'
                'ScheduledTask'
            )

            # Project URI for gallery
            ProjectUri = 'https://github.com/ZulshiBLN/IPSC-Kurs-Watcher'

            # Prerelease flag
            Prerelease = $false

            # External dependencies
            ExternalModuleDependencies = @()
        }
    }

    # Required modules
    RequiredModules      = @()

    # Functions to export
    CmdletsToExport      = @()

    # Aliases to export
    AliasesToExport      = @()

    # Variables to export
    VariablesToExport    = @()
}
