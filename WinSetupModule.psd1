@{
    # Module identity
    RootModule           = 'WinSetupModule.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '2fdcf4de-9023-4c5b-a316-74e95fe0e42d'
    
    # Module information
    Author               = 'Jared Cervantes'
    CompanyName          = ''
    Copyright            = '(c) 2023 Jared Cervantes. All rights reserved.'
    Description          = 'Windows setup and configuration module providing shared functionality for Windows setup scripts'
    
    # Minimum PowerShell version required
    PowerShellVersion    = '5.1'
    
    # Modules that must be imported before this module
    RequiredModules      = @()
    
    # Assemblies that must be loaded before this module
    RequiredAssemblies   = @()
    
    # Script files (.ps1) that should be run in the caller's environment before importing this module
    ScriptsToProcess     = @()
    
    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess       = @()
    
    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess     = @()
    
    # Modules to import as nested modules of this module
    NestedModules        = @()
    
    # Functions to export from this module, for best performance, don't use wildcards
    FunctionsToExport    = @(
        'Initialize-Config',
        'Get-ConfigValue',
        'Test-Administrator',
        'Assert-Administrator',
        'Write-Log',
        'Test-InternetConnection',
        'Invoke-FileDownload',
        'Show-Menu',
        'Show-Progress',
        'Set-FirewallRule',
        'Set-ServiceConfig',
        'Set-RegistryValue'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport      = @()
    
    # Variables to export from this module
    VariablesToExport    = @()
    
    # Aliases to export from this module
    AliasesToExport      = @()
    
    # Private data to pass to the module specified in RootModule
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module
            Tags         = @('Windows', 'Setup', 'Configuration')
            
            # License URI for this module
            LicenseUri   = ''
            
            # Project URI for this module
            ProjectUri   = 'https://github.com/Jaredy899/win'
            
            # Icon URI for this module
            IconUri      = ''
            
            # Release notes for this module
            ReleaseNotes = 'Initial release of the Windows Setup Module'
        }
    }
} 