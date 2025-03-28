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
        
        # Local cache path
        $cacheDir = Join-Path $env:TEMP "WinSetupCache"
        $cacheFile = Join-Path $cacheDir "ctt_winutil.ps1"
        $cacheMaxAgeHours = 24 # Cache valid for 24 hours
        
        # Create cache directory if it doesn't exist
        if (-not (Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            Write-Log "Created cache directory" -Level "INFO"
        }
        
        $useCache = $false
        
        # Check if we have a valid cached version
        if (Test-Path $cacheFile) {
            $fileAge = (Get-Date) - (Get-Item $cacheFile).LastWriteTime
            if ($fileAge.TotalHours -lt $cacheMaxAgeHours) {
                $useCache = $true
                Write-Log "Using cached version of ChrisTitusTech utility (age: $([math]::Round($fileAge.TotalHours, 1)) hours)" -Level "INFO"
            } else {
                Write-Log "Cache expired, downloading fresh copy" -Level "INFO"
            }
        }
        
        # Set TLS 1.2 for compatibility
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        if ($useCache) {
            # Use cached version
            & $cacheFile
        } else {
            # Download fresh copy
            try {
                $scriptContent = Invoke-RestMethod -Uri "https://christitus.com/win" -UseBasicParsing
                
                # Save to cache
                Set-Content -Path $cacheFile -Value $scriptContent -Force
                Write-Log "Downloaded and cached ChrisTitusTech utility" -Level "INFO"
                
                # Execute
                Invoke-Expression $scriptContent
            }
            catch {
                Write-Log "Failed to download ChrisTitusTech utility: $_" -Level "ERROR"
                
                # Try using cached version even if expired as fallback
                if (Test-Path $cacheFile) {
                    Write-Log "Falling back to cached version" -Level "WARNING"
                    & $cacheFile
                } else {
                    throw "Failed to download and no cache available"
                }
            }
        }
        
        Write-Log "Chris Titus Tech's Windows Utility completed" -Level "SUCCESS"
        return $true
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
                    5 { Invoke-WindowsActivation }
                    6 { Get-NordBackgrounds }
                    7 { Invoke-ChrisTitusTechUtility }
                    8 { 
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

# SIG # Begin signature block
# MIIb8gYJKoZIhvcNAQcCoIIb4zCCG98CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBlQVnXo79vp5T+
# o4bV3sa4d1FPi2WMYBvA9UMD+sf34aCCFjEwggMqMIICEqADAgECAhActY9oOxGl
# tEkhG1k4PcuwMA0GCSqGSIb3DQEBCwUAMC0xKzApBgNVBAMMIldpbmRvd3MgU2V0
# dXAgVG9vbGtpdCBDb2RlIFNpZ25pbmcwHhcNMjUwMzI4MjE0MDU0WhcNMzAwMzI4
# MjE1MDU0WjAtMSswKQYDVQQDDCJXaW5kb3dzIFNldHVwIFRvb2xraXQgQ29kZSBT
# aWduaW5nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvrxr1U8GKkb5
# KX1aDycE4IQPPlYb6IzEzcRyq84UVHSsOk6qBg9JAxy+Pq0vGTgHPs8CFwfpE85M
# kjop9XRhj+SfW3s1qtbegzLUs6CNGeJO8WTHbnkhFsKMQehgn2+o6Wn3siF9OUYJ
# ValbnjYVP6wt105BqZiIsF21EYZyHbU/o33WzcXCg/Q8LMfTyqr2TrlQZv96i7Xr
# fF7KgBS3CK7aSu2Gn9IGl9pFEc8Xy9vLQAnHjTs84EB+3WvsxO7kTc4y0+3J7/NA
# ptVfR7nxdQd2+MEOYbqJHytWZS9VrcllUc0gxFBn7cf2CuuTcCHeIQLeD3m1Eed3
# D8lNRQOapQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwHQYDVR0OBBYEFNdBI0cc3+7WF1rqd8i3FUpQdmdnMA0GCSqGSIb3DQEB
# CwUAA4IBAQA6cYWTx916ECaXq/OhecAvql3u1Jk6+iZEh8RDtyZZgcr0jqBMpQb0
# Jr7flOckrfGPOPJSMtFRPAtVjXo0Hueant4j5FPGMk/U0Q01ZqLifvB3k56zan4Z
# WCcvLHXICwRPVMaHALPJgwYmjI/yiErOq4ebcCEZB4Xodi6KzExaf2RsWH/FjQ8w
# UqGLrjAQO/fMQSG3w7WlivN3aNyxZNN5iYSr7mQqa9znVI4t2NhXc/ua83TeZlPo
# I0JXtIq1bbF+JtAdgVXoSlcAhix+ajQ16iLheo4b6lO4zGXwWgoORNx6pS1mz+1m
# z4RPfS8M46Hlvl8eRkg7YjulT03SfQMmMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv
# 21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMM
# RGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQD
# ExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcN
# MzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQg
# SW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2Vy
# dCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf
# 8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1
# mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe
# 7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecx
# y9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX
# 2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX
# 9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp49
# 3ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCq
# sWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFH
# dL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauG
# i0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYw
# DwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08w
# HwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGG
# MHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNl
# cnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0
# dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5j
# cmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXn
# OF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23
# OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFI
# tJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7s
# pNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgi
# wbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cB
# qZ9Xql4o4rmUMIIGrjCCBJagAwIBAgIQBzY3tyRUfNhHrP0oZipeWzANBgkqhkiG
# 9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVz
# dGVkIFJvb3QgRzQwHhcNMjIwMzIzMDAwMDAwWhcNMzcwMzIyMjM1OTU5WjBjMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRp
# Z2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENB
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxoY1BkmzwT1ySVFVxyUD
# xPKRN6mXUaHW0oPRnkyibaCwzIP5WvYRoUQVQl+kiPNo+n3znIkLf50fng8zH1AT
# CyZzlm34V6gCff1DtITaEfFzsbPuK4CEiiIY3+vaPcQXf6sZKz5C3GeO6lE98NZW
# 1OcoLevTsbV15x8GZY2UKdPZ7Gnf2ZCHRgB720RBidx8ald68Dd5n12sy+iEZLRS
# 8nZH92GDGd1ftFQLIWhuNyG7QKxfst5Kfc71ORJn7w6lY2zkpsUdzTYNXNXmG6jB
# ZHRAp8ByxbpOH7G1WE15/tePc5OsLDnipUjW8LAxE6lXKZYnLvWHpo9OdhVVJnCY
# Jn+gGkcgQ+NDY4B7dW4nJZCYOjgRs/b2nuY7W+yB3iIU2YIqx5K/oN7jPqJz+ucf
# WmyU8lKVEStYdEAoq3NDzt9KoRxrOMUp88qqlnNCaJ+2RrOdOqPVA+C/8KI8ykLc
# GEh/FDTP0kyr75s9/g64ZCr6dSgkQe1CvwWcZklSUPRR8zZJTYsg0ixXNXkrqPNF
# YLwjjVj33GHek/45wPmyMKVM1+mYSlg+0wOI/rOP015LdhJRk8mMDDtbiiKowSYI
# +RQQEgN9XyO7ZONj4KbhPvbCdLI/Hgl27KtdRnXiYKNYCQEoAA6EVO7O6V3IXjAS
# vUaetdN2udIOa5kM0jO0zbECAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8C
# AQAwHQYDVR0OBBYEFLoW2W1NhS9zKXaaL3WMaiCPnshvMB8GA1UdIwQYMBaAFOzX
# 44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggr
# BgEFBQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3Nw
# LmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDag
# NIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RH
# NC5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3
# DQEBCwUAA4ICAQB9WY7Ak7ZvmKlEIgF+ZtbYIULhsBguEE0TzzBTzr8Y+8dQXeJL
# Kftwig2qKWn8acHPHQfpPmDI2AvlXFvXbYf6hCAlNDFnzbYSlm/EUExiHQwIgqgW
# valWzxVzjQEiJc6VaT9Hd/tydBTX/6tPiix6q4XNQ1/tYLaqT5Fmniye4Iqs5f2M
# vGQmh2ySvZ180HAKfO+ovHVPulr3qRCyXen/KFSJ8NWKcXZl2szwcqMj+sAngkSu
# mScbqyQeJsG33irr9p6xeZmBo1aGqwpFyd/EjaDnmPv7pp1yr8THwcFqcdnGE4AJ
# xLafzYeHJLtPo0m5d2aR8XKc6UsCUqc3fpNTrDsdCEkPlM05et3/JWOZJyw9P2un
# 8WbDQc1PtkCbISFA0LcTJM3cHXg65J6t5TRxktcma+Q4c6umAU+9Pzt4rUyt+8SV
# e+0KXzM5h0F4ejjpnOHdI/0dKNPH+ejxmF/7K9h+8kaddSweJywm228Vex4Ziza4
# k9Tm8heZWcpw8De/mADfIBZPJ/tgZxahZrrdVcA6KYawmKAr7ZVBtzrVFZgxtGIJ
# Dwq9gdkT/r+k0fNX2bwE+oLeMt8EifAAzV3C+dAjfwAL5HYCJtnwZXZCpimHCUcr
# 5n8apIUP/JiW9lVUKx+A+sDyDivl1vupL0QVSucTDh3bNzgaoSv27dZ8/DCCBrww
# ggSkoAMCAQICEAuuZrxaun+Vh8b56QTjMwQwDQYJKoZIhvcNAQELBQAwYzELMAkG
# A1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdp
# Q2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTAe
# Fw0yNDA5MjYwMDAwMDBaFw0zNTExMjUyMzU5NTlaMEIxCzAJBgNVBAYTAlVTMREw
# DwYDVQQKEwhEaWdpQ2VydDEgMB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0YW1wIDIw
# MjQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC+anOf9pUhq5Ywultt
# 5lmjtej9kR8YxIg7apnjpcH9CjAgQxK+CMR0Rne/i+utMeV5bUlYYSuuM4vQngvQ
# epVHVzNLO9RDnEXvPghCaft0djvKKO+hDu6ObS7rJcXa/UKvNminKQPTv/1+kBPg
# HGlP28mgmoCw/xi6FG9+Un1h4eN6zh926SxMe6We2r1Z6VFZj75MU/HNmtsgtFjK
# fITLutLWUdAoWle+jYZ49+wxGE1/UXjWfISDmHuI5e/6+NfQrxGFSKx+rDdNMseP
# W6FLrphfYtk/FLihp/feun0eV+pIF496OVh4R1TvjQYpAztJpVIfdNsEvxHofBf1
# BWkadc+Up0Th8EifkEEWdX4rA/FE1Q0rqViTbLVZIqi6viEk3RIySho1XyHLIAOJ
# fXG5PEppc3XYeBH7xa6VTZ3rOHNeiYnY+V4j1XbJ+Z9dI8ZhqcaDHOoj5KGg4Yui
# Yx3eYm33aebsyF6eD9MF5IDbPgjvwmnAalNEeJPvIeoGJXaeBQjIK13SlnzODdLt
# uThALhGtyconcVuPI8AaiCaiJnfdzUcb3dWnqUnjXkRFwLtsVAxFvGqsxUA2Jq/W
# TjbnNjIUzIs3ITVC6VBKAOlb2u29Vwgfta8b2ypi6n2PzP0nVepsFk8nlcuWfyZL
# zBaZ0MucEdeBiXL+nUOGhCjl+QIDAQABo4IBizCCAYcwDgYDVR0PAQH/BAQDAgeA
# MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYDVR0gBBkw
# FzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1NhS9zKXaa
# L3WMaiCPnshvMB0GA1UdDgQWBBSfVywDdw4oFZBmpWNe7k+SH3agWzBaBgNVHR8E
# UzBRME+gTaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQBggrBgEFBQcB
# AQSBgzCBgDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMFgG
# CCsGAQUFBzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3
# DQEBCwUAA4ICAQA9rR4fdplb4ziEEkfZQ5H2EdubTggd0ShPz9Pce4FLJl6reNKL
# kZd5Y/vEIqFWKt4oKcKz7wZmXa5VgW9B76k9NJxUl4JlKwyjUkKhk3aYx7D8vi2m
# pU1tKlY71AYXB8wTLrQeh83pXnWwwsxc1Mt+FWqz57yFq6laICtKjPICYYf/qgxA
# CHTvypGHrC8k1TqCeHk6u4I/VBQC9VK7iSpU5wlWjNlHlFFv/M93748YTeoXU/fF
# a9hWJQkuzG2+B7+bMDvmgF8VlJt1qQcl7YFUMYgZU1WM6nyw23vT6QSgwX5Pq2m0
# xQ2V6FJHu8z4LXe/371k5QrN9FQBhLLISZi2yemW0P8ZZfx4zvSWzVXpAb9k4Hpv
# pi6bUe8iK6WonUSV6yPlMwerwJZP/Gtbu3CKldMnn+LmmRTkTXpFIEB06nXZrDwh
# CGED+8RsWQSIXZpuG4WLFQOhtloDRWGoCwwc6ZpPddOFkM2LlTbMcqFSzm4cd0bo
# GhBq7vkqI1uHRz6Fq1IX7TaRQuR+0BGOzISkcqwXu7nMpFu3mgrlgbAW+BzikRVQ
# 3K2YHcGkiKjA4gi4OA/kz1YCsdhIBHXqBzR0/Zd2QwQ/l4Gxftt/8wY3grcc/nS/
# /TVkej9nmUYu83BDtccHHXKibMs/yXHhDXNkoPIdynhVAku7aRZOwqw6pDGCBRcw
# ggUTAgEBMEEwLTErMCkGA1UEAwwiV2luZG93cyBTZXR1cCBUb29sa2l0IENvZGUg
# U2lnbmluZwIQHLWPaDsRpbRJIRtZOD3LsDANBglghkgBZQMEAgEFAKCBhDAYBgor
# BgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEE
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCu
# FXeoA9ZazfdDQbdCfYCgVFuYa48sXDn13Wnq397DTTANBgkqhkiG9w0BAQEFAASC
# AQBPl2k+LNLN3G4pEjzEoyKShLRQNM2YLS9X9UCl/tmftfkBQLcU11M+pO+n5Les
# RU9j609r/K3kGRESSznoJPJ+6VCwy5fYgXithOWW6ffIgPNGho4mcUounRh4oSjv
# MoZhq2AoZ47rRqFJfnKECsqej0oAjqdIlahega+MV4ouGzUrgIJCkIJnCk0BCfTR
# 80Z9+bbQFwbg2dizZzsOB7to3OFTR63Ct0Gf0qu8rCCQdX0me7XvEOzJJoaXPqeA
# PFJqL9xIaNBE6Rs1RQC6YbWnNBDxi7/sbfPy1dBmMVRyZc1g62dINNRYa/bFS0Yy
# p2EmescO9dcxcVqN1CNMiLPVoYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEB
# MHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYD
# VQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFt
# cGluZyBDQQIQC65mvFq6f5WHxvnpBOMzBDANBglghkgBZQMEAgEFAKBpMBgGCSqG
# SIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MDMyODIxNTA1
# NlowLwYJKoZIhvcNAQkEMSIEIHgXxaEAafsUVUB2dxj9N4zo41MUl8HVugQhKlfO
# gs27MA0GCSqGSIb3DQEBAQUABIICADM+lINsBEr9KELVj0QAu00Q96Lnw/OQLBA0
# NDy4aYPu8UUKZzdQszspI2kL6uD1+74+vC/YVZLmNN3Qq5gZyBbX3+JmgVJhgjgt
# ul1EjoQHrPFAkxOn/703N/8Gf9nZMDs+ZpVyjTQmZSddSXisq/XYzbCd1l6prh6u
# 7q4gOqEyduqVjJBK2wC/bitZUNIgnDYDhPbjVyXYTM1fOpZ4V+7YfxD9jiKz603T
# oG/FzJUH4Br8ClkJL3+43UifBgjBe8DHKL76Z0RUY6db4nn6Lx20uh8xtllQXe7H
# wS1Z+hE5poQTMRKTlC0tjMQI/DFh/fVA+Zn+s8tj9bUlLuMm/ext5W9YfQ+LLxCl
# b9M8/AAful2tnJczrPzLsT6U/Jib5Vr1Lpr34qsQTthAhwKwQO8ALIbu7XShHWcE
# VWj7T6yW8xK9bYtXJ22UCrR8OFw2fe0em21hx3fBqDyK2IOcaUgfVsC7jQU36nUB
# i156JubXi7U4OIAD5wkrLV+NsvRp/mDa91bhNepR5z3tZGJarg2Oz9ayPDENqGU+
# eyL72HcYg1EiamnIk1XZGekQBLkHvpIjekGeaNMgwEAKtCysgIUXUDFEfI6c2Z5C
# NHxdfMlZHaoY7Y4vZRpcA5TvKgdYs7HcGkWloeWm0Up6mNLvBRbsiOpF0ZkIOWQS
# hzUkkvAh
# SIG # End signature block
