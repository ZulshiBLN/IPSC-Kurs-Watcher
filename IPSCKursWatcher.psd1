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
            ReleaseNotes = 'v1.0.0 - Production release with automated monitoring, multi-channel notifications, and comprehensive documentation. See https://github.com/ZulshiBLN/IPSC-Kurs-Watcher for details.'

            Tags = @(
                'IPSC'
                'CourseMonitoring'
                'Notifications'
                'Automation'
                'Windows'
            )

            ProjectUri = 'https://github.com/ZulshiBLN/IPSC-Kurs-Watcher'
            Prerelease = $false
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
