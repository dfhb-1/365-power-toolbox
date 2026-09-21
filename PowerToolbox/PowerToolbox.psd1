@{
    RootModule           = 'PowerToolbox.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '6f65242f-f64d-40fc-822c-9037197ffaeb'
    Author               = 'PowerToolbox contributors'
    CompanyName          = ''
    Copyright            = '(c) 2026 PowerToolbox contributors.'
    Description          = 'Microsoft 365 administration tools for Exchange Online calendars and Microsoft Entra ID group membership.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport    = @(
        'Add-CalendarPermission',
        'Add-EntraGroupMember',
        'Remove-EntraGroupMember',
        'Update-PowerToolbox'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('Microsoft365', 'ExchangeOnline', 'Entra', 'AzureAD', 'Graph', 'Groups', 'Calendar')
            ProjectUri = 'https://github.com/dfhb-1/365-power-toolbox'

            # Declared as external, not RequiredModules: importing PowerToolbox must succeed on a
            # machine with neither SDK installed. The Connect-Pt* helpers check at call time.
            ExternalModuleDependencies = @(
                'ExchangeOnlineManagement',
                'Microsoft.Graph.Groups',
                'Microsoft.Graph.Users'
            )
        }
    }
}
