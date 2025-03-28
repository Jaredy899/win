#Requires -Version 5.1

<#
.SYNOPSIS
    Windows Setup Main Menu
.DESCRIPTION
    Interactive menu for Windows setup and configuration tasks
.NOTES
    Version: 2.0.0
#>

# Import custom module if available
if (Test-Path -Path "$PSScriptRoot\WinSetupModule.psm1") {
    Import-Module "$PSScriptRoot\WinSetupModule.psm1" -Force
} else {
    # Define minimal required functions if module not available
    function Write-Log {
        param([string]$Message, [string]$Level = "INFO")
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                "INFO"    { "White" }
                "WARNING" { "Yellow" }
                "ERROR"   { "Red" }
                "SUCCESS" { "Green" }
                default   { "White" }
            }
        )
    }
}

# Set the GITPATH variable to the directory where the script is located
$GITPATH = Split-Path -Parent $MyInvocation.MyCommand.Definition

# GitHub URL base for configuration files
$GITHUB_BASE_URL = "https://raw.githubusercontent.com/Jaredy899/win/main"

# Create progress container for tracking multi-step operations
$Global:Progress = @{
    CurrentStep = 0
    TotalSteps = 0
    StepName = ""
    Cancelled = $false
}

# Function to initialize system restore point
function New-SetupRestorePoint {
    [CmdletBinding()]
    param(
        [string]$Description = "Before Windows Setup"
    )
    
    try {
        Write-Log "Creating system restore point..." -Level "INFO"
        
        # Check if System Restore is enabled
        $srService = Get-Service -Name "VSS" -ErrorAction SilentlyContinue
        if ($srService.Status -ne "Running") {
            Write-Log "Volume Shadow Copy Service (VSS) is not running. Attempting to start..." -Level "WARNING"
            Start-Service -Name "VSS" -ErrorAction Stop
        }
        
        # Enable System Restore if needed
        $systemDrive = $env:SystemDrive
        $srEnabled = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -ErrorAction SilentlyContinue).RPSessionInterval -ne 0
        
        if (-not $srEnabled) {
            Write-Log "System Restore is not enabled. Enabling for system drive..." -Level "WARNING"
            Enable-ComputerRestore -Drive $systemDrive -ErrorAction Stop
        }
        
        # Create the restore point
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "System restore point created successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to create system restore point: $_" -Level "ERROR"
        return $false
    }
}

# Function to invoke a script from local or GitHub with improved error handling
function Invoke-Script {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ScriptName,
        
        [Parameter(Mandatory)]
        [string]$LocalPath,
        
        [Parameter(Mandatory)]
        [string]$Url,
        
        [Parameter()]
        [switch]$UseTemp,
        
        [Parameter()]
        [int]$RetryCount = 3,
        
        [Parameter()]
        [int]$RetryDelaySeconds = 3
    )
    
    try {
        $localScriptPath = Join-Path $LocalPath $ScriptName
        
        if (Test-Path $localScriptPath) {
            Write-Log "Invoking $ScriptName from local directory..." -Level "INFO"
            & $localScriptPath
            return $true
        } else {
            Write-Log "Script not found locally. Attempting to download from GitHub..." -Level "INFO"
            
            $attempt = 0
            $success = $false
            $tempScript = if ($UseTemp) { Join-Path $env:TEMP $ScriptName } else { $localScriptPath }
            
            while (-not $success -and $attempt -lt $RetryCount) {
                $attempt++
                try {
                    Write-Log "Downloading script (Attempt $attempt of $RetryCount)..." -Level "INFO"
                    
                    # Set TLS 1.2 for compatibility
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    
                    # Download script
                    Invoke-WebRequest -Uri "$Url/$ScriptName" -OutFile $tempScript -UseBasicParsing -ErrorAction Stop
                    
                    # Validate downloaded file
                    if (-not (Test-Path $tempScript) -or (Get-Item $tempScript).Length -eq 0) {
                        throw "Downloaded file is empty or not found"
                    }
                    
                    $success = $true
                    Write-Log "Script downloaded successfully" -Level "SUCCESS"
                }
                catch {
                    Write-Log "Download attempt $attempt failed: $_" -Level "WARNING"
                    
                    if ($attempt -lt $RetryCount) {
                        Write-Log "Retrying in $RetryDelaySeconds seconds..." -Level "INFO"
                        Start-Sleep -Seconds $RetryDelaySeconds
                    }
                }
            }
            
            if (-not $success) {
                Write-Log "Failed to download script after $RetryCount attempts" -Level "ERROR"
                return $false
            }
            
            # Execute script
            try {
                Write-Log "Executing downloaded script..." -Level "INFO"
                & $tempScript
                
                # Clean up temp file if used
                if ($UseTemp) {
                    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
                }
                
                return $true
            }
            catch {
                Write-Log "Failed to execute script: $_" -Level "ERROR"
                return $false
            }
        }
    }
    catch {
        Write-Log "Error in Invoke-Script: $_" -Level "ERROR"
        return $false
    }
}

# Special function to invoke Chris Titus Tech's Windows Utility
function Invoke-ChrisTitusTechUtility {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Invoking Chris Titus Tech's Windows Utility..." -Level "INFO"
        
        # Set TLS 1.2 for compatibility
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        try {
            Invoke-RestMethod -Uri "https://christitus.com/win" -UseBasicParsing | Invoke-Expression
            Write-Log "Chris Titus Tech's Windows Utility completed" -Level "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Failed to invoke Chris Titus Tech's Windows Utility: $_" -Level "ERROR"
            
            # Fallback to manual download and execution
            $tempScript = Join-Path $env:TEMP "ctt_win.ps1"
            Invoke-WebRequest -Uri "https://christitus.com/win" -OutFile $tempScript -UseBasicParsing
            
            if (Test-Path $tempScript) {
                & $tempScript
                Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
                return $true
            }
            
            return $false
        }
    }
    catch {
        Write-Log "Error in Invoke-ChrisTitusTechUtility: $_" -Level "ERROR"
        return $false
    }
}

# Function to activate Windows
function Invoke-WindowsActivation {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Windows Activation" -Level "INFO"
        
        $confirmation = Read-Host "Are you sure you want to activate Windows? (y/n)"
        if ($confirmation -eq 'y') {
            try {
                # Set TLS 1.2 for compatibility
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                
                Invoke-RestMethod https://get.activated.win -UseBasicParsing | Invoke-Expression
                Write-Log "Windows activation initiated" -Level "SUCCESS"
                return $true
            }
            catch {
                Write-Log "Windows activation failed: $_" -Level "ERROR"
                return $false
            }
        } else {
            Write-Log "Windows activation cancelled" -Level "INFO"
            return $false
        }
    }
    catch {
        Write-Log "Error in Invoke-WindowsActivation: $_" -Level "ERROR"
        return $false
    }
}

# Function to download and extract Nord backgrounds
function Get-NordBackgrounds {
    [CmdletBinding()]
    param()
    
    try {
        $documentsPath = [Environment]::GetFolderPath("MyDocuments")
        $backgroundsPath = Join-Path $documentsPath "nord_backgrounds"
        $zipPath = Join-Path $documentsPath "nord_backgrounds.zip"
        $url = "https://github.com/ChrisTitusTech/nord-background/archive/refs/heads/main.zip"
        
        if (Test-Path $backgroundsPath) {
            $overwrite = Read-Host "Nord backgrounds folder exists. Overwrite? (y/n)"
            if ($overwrite -ne 'y') {
                Write-Log "Skipping Nord backgrounds download" -Level "INFO"
                return $false
            }
            Remove-Item $backgroundsPath -Recurse -Force
        }
        
        try {
            Write-Log "Downloading Nord backgrounds..." -Level "INFO"
            
            # Set TLS 1.2 for compatibility
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            # Download and extract
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
            
            Write-Log "Extracting Nord backgrounds..." -Level "INFO"
            Expand-Archive -Path $zipPath -DestinationPath $documentsPath -Force
            
            # Rename folder
            Rename-Item -Path (Join-Path $documentsPath "nord-background-main") -NewName "nord_backgrounds"
            
            # Clean up zip file
            Remove-Item -Path $zipPath -Force
            
            Write-Log "Nord backgrounds set up in: $backgroundsPath" -Level "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Error setting up Nord backgrounds: $_" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error in Get-NordBackgrounds: $_" -Level "ERROR"
        return $false
    }
}

# Function to handle the menu loop with improved UI
function Show-SetupMenu {
    [CmdletBinding()]
    param()
    
    $options = @(
        "Create System Restore Point",
        "Update Windows",
        "Start Setup Script",
        "Add SSH Keys",
        "Run My PowerShell Config",
        "Setup Code Signing",
        "Activate Windows",
        "Download Nord Backgrounds",
        "Run ChrisTitusTech's Windows Utility",
        "Exit"
    )
    $selectedIndex = 0
    
    while ($true) {
        Clear-Host
        
        Write-Host "`n  Windows Setup Toolkit" -ForegroundColor Cyan
        Write-Host "  Select an option:" -ForegroundColor Cyan
        Write-Host ""
        
        # Display all options
        for ($i = 0; $i -lt $options.Length; $i++) {
            if ($i -eq $selectedIndex) {
                Write-Host "  ► " -ForegroundColor Green -NoNewline
                Write-Host $options[$i] -ForegroundColor Green
            } else {
                Write-Host "    $($options[$i])"
            }
        }
        
        # Display navigation help
        Write-Host "`n  " -NoNewline
        Write-Host "↑↓" -ForegroundColor Cyan -NoNewline
        Write-Host " to navigate, " -NoNewline
        Write-Host "Enter" -ForegroundColor Cyan -NoNewline
        Write-Host " to select"
        
        # Handle key input
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $selectedIndex--
                if ($selectedIndex -lt 0) { $selectedIndex = $options.Length - 1 }
            }
            40 { # Down arrow
                $selectedIndex++
                if ($selectedIndex -ge $options.Length) { $selectedIndex = 0 }
            }
            13 { # Enter key
                Clear-Host
                
                # Handle option selection
                switch ($selectedIndex) {
                    0 { New-SetupRestorePoint }
                    1 { Invoke-Script -ScriptName "Windows-Update.ps1" -LocalPath $GITPATH -Url $GITHUB_BASE_URL }
                    2 { Invoke-Script -ScriptName "setup2.ps1" -LocalPath $GITPATH -Url $GITHUB_BASE_URL }
                    3 { Invoke-Script -ScriptName "add_ssh_key_windows.ps1" -LocalPath $GITPATH -Url $GITHUB_BASE_URL }
                    4 { Invoke-Script -ScriptName "pwsh.ps1" -LocalPath "$GITPATH\my_powershell" -Url "$GITHUB_BASE_URL/my_powershell" }
                    5 { Invoke-Script -ScriptName "setup-codesigning.ps1" -LocalPath $GITPATH -Url $GITHUB_BASE_URL }
                    6 { Invoke-WindowsActivation }
                    7 { Get-NordBackgrounds }
                    8 { Invoke-ChrisTitusTechUtility }
                    9 { 
                        Write-Host "`nExiting setup script." -ForegroundColor Cyan
                        return
                    }
                }
                
                # Clear the screen after action completion
                Write-Host "`nPress any key to return to menu..." -ForegroundColor Magenta
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                Clear-Host
            }
        }
        Clear-Host
    }
}

# Main script execution
try {
    # Start the main menu
    Show-SetupMenu
}
catch {
    Write-Log "Error in main script execution: $_" -Level "ERROR"
    Write-Host "`nAn error occurred. Press any key to exit..." -ForegroundColor Red
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
finally {
    Clear-Host
    Write-Host "Thank you for using the Windows Setup Toolkit!" -ForegroundColor Cyan
    Write-Host "For more information, visit: https://github.com/Jaredy899/win" -ForegroundColor Gray
}
