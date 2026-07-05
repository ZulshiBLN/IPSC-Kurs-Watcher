@{
    RootModule           = 'IPSCKursWatcher.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '5c7e9a2f-b4d1-4e6c-8f3a-9d2e1c5b7f4a'
    Author               = 'Michel Brosche'
    Description          = 'Automated IPSC course monitoring with multi-channel notifications'
    PowerShellVersion    = '5.1'

    FunctionsToExport    = @('Invoke-MonitoringCycle')
    CmdletsToExport      = @()
    AliasesToExport      = @()
    VariablesToExport    = @()

    PrivateData          = @{
        PSData = @{
            Tags       = @('IPSC', 'Monitoring', 'Automation')
            ProjectUri = 'https://github.com/ZulshiBLN/IPSC-Kurs-Watcher'
        }
    }
}
