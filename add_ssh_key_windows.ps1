#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows SSH Key Management
.DESCRIPTION
    Script to securely add and manage SSH keys on Windows
    Supports GitHub key import and manual key entry
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

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "This script must be run as Administrator" -Level "ERROR"
    exit 1
}

# Variables
$programData = $env:ProgramData
$sshPath = Join-Path $programData "ssh"
$adminKeys = Join-Path $sshPath "administrators_authorized_keys"

# Function to create necessary directories and files
function Initialize-SshEnvironment {
    if (-not (Test-Path -Path $sshPath)) {
        New-Item -ItemType Directory -Path $sshPath -Force
        Write-Log "Created $sshPath" -Level "SUCCESS"
    }

    if (-not (Test-Path -Path $adminKeys)) {
        New-Item -ItemType File -Path $adminKeys -Force
        Write-Log "Created $adminKeys" -Level "SUCCESS"
    }

    # Secure the administrators_authorized_keys file
    $acl = Get-Acl -Path $adminKeys
    $acl.SetAccessRuleProtection($true, $false)
    $administratorsRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "Allow")
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")
    $acl.AddAccessRule($administratorsRule)
    $acl.AddAccessRule($systemRule)
    Set-Acl -Path $adminKeys -AclObject $acl
    Write-Log "Secured $adminKeys with proper permissions" -Level "SUCCESS"
}

# Function to get keys from GitHub
function Get-GitHubKeys {
    param (
        [string]$username
    )
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/users/$username/keys" -ErrorAction Stop
        return $response
    }
    catch {
        Write-Host "✗ Failed to fetch keys from GitHub: $_" -ForegroundColor Red
        return $null
    }
}

# Function to add a key if it doesn't exist
function Add-UniqueKey {
    param (
        [string]$key
    )
    
    $existingKeys = Get-Content -Path $adminKeys
    if ($existingKeys -contains $key) {
        Write-Host "! Key already exists in $adminKeys" -ForegroundColor Yellow
        return
    }
    
    Add-Content -Path $adminKeys -Value $key
    Write-Host "✓ Added new key to $adminKeys" -ForegroundColor Green
}

# Function to draw menu
function Show-Menu {
    param (
        [int]$selectedIndex
    )
    Clear-Host
    Write-Host "`n  Windows SSH Key Manager`n" -ForegroundColor Cyan
    Write-Host "  Use ↑↓ arrows to select and Enter to confirm:`n" -ForegroundColor Gray
    
    $options = @("Import keys from GitHub", "Enter key manually")
    
    for ($i = 0; $i -lt $options.Count; $i++) {
        if ($i -eq $selectedIndex) {
            Write-Host "  > " -NoNewline -ForegroundColor Cyan
            Write-Host $options[$i] -ForegroundColor White -BackgroundColor DarkBlue
        } else {
            Write-Host "    $($options[$i])" -ForegroundColor Gray
        }
    }
}

# Function to handle GitHub key import
function Import-GitHubKeys {
    Write-Host "`nEnter GitHub username: " -ForegroundColor Cyan -NoNewline
    $githubUsername = Read-Host
    
    Write-Host "`nFetching keys from GitHub..." -ForegroundColor Yellow
    $keys = Get-GitHubKeys -username $githubUsername
    
    if ($keys) {
        Write-Host "`nFound $($keys.Count) keys for user " -NoNewline
        Write-Host $githubUsername -ForegroundColor Cyan
        
        foreach ($key in $keys) {
            Write-Host "`nKey ID: " -NoNewline
            Write-Host $key.id -ForegroundColor Cyan
            $addThis = Read-Host "Add this key? (y/n)"
            if ($addThis -eq 'y') {
                Add-UniqueKey -key $key.key
            }
        }
    }
}

# Function to handle manual key entry
function Add-ManualKey {
    Write-Host "`nPaste your public key: " -ForegroundColor Cyan
    $manualKey = Read-Host
    if ($manualKey) {
        Add-UniqueKey -key $manualKey
    }
}

# Function to restart SSH service
function Restart-SshService {
    Write-Host "`nRestarting SSH service..." -ForegroundColor Yellow
    try {
        Stop-Service sshd -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        Start-Service sshd -ErrorAction Stop
        Write-Host "✓ SSH service restarted successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to restart SSH service: $_" -ForegroundColor Red
    }
}

# Function to fix SSH key permissions
function Repair-SshKeyPermissions {
    param (
        [string]$keyPath = "$env:USERPROFILE\.ssh\id_rsa"
    )

    Write-Host "`nChecking private key permissions..." -ForegroundColor Yellow
    
    if (-not (Test-Path -Path $keyPath)) {
        Write-Host "! No private key found at $keyPath - skipping permissions fix" -ForegroundColor Yellow
        return
    }

    try {
        # Remove all existing permissions
        icacls $keyPath /inheritance:r
        # Add permission only for current user
        icacls $keyPath /grant ${env:USERNAME}:"(R)"
        Write-Host "✓ Fixed permissions for $keyPath" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to set key permissions: $_" -ForegroundColor Red
    }
}

# Function to add SSH key manually
function Add-SshKeyManually {
    Write-Log "Adding SSH key manually..." -Level "INFO"
    
    Write-Host "`nPlease paste your SSH public key below (ending with your email):"
    $key = Read-Host
    
    if (-not $key.Trim()) {
        Write-Log "No key entered. Operation cancelled." -Level "WARNING"
        return
    }
    
    Add-Content -Path $adminKeys -Value $key
    Write-Log "SSH key added successfully" -Level "SUCCESS"
}

# Function to add SSH key from GitHub
function Add-SshKeyFromGitHub {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username
    )
    
    try {
        Write-Log "Fetching SSH keys for GitHub user $Username..." -Level "INFO"
        
        # Fetch GitHub keys
        $uri = "https://github.com/$Username.keys"
        $keys = Invoke-RestMethod -Uri $uri -ErrorAction Stop
        
        if (-not $keys) {
            Write-Log "No SSH keys found for GitHub user $Username" -Level "WARNING"
            return
        }
        
        # Count the keys
        $keyCount = ($keys -split '\r?\n').Where({ $_ -ne '' }).Count
        Write-Log "Found $keyCount SSH key(s) for GitHub user $Username" -Level "INFO"
        
        # Add each key
        $keyArray = $keys -split '\r?\n'
        foreach ($key in $keyArray) {
            if ($key.Trim()) {
                Add-Content -Path $adminKeys -Value $key
            }
        }
        
        Write-Log "GitHub SSH keys added successfully" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to fetch SSH keys from GitHub: $_" -Level "ERROR"
    }
}

# Function to list current SSH keys
function Show-CurrentSshKeys {
    Write-Log "Current SSH keys:" -Level "INFO"
    
    if (Test-Path -Path $adminKeys) {
        $keys = Get-Content -Path $adminKeys
        if ($keys) {
            $keyCount = $keys.Count
            Write-Log "Found $keyCount SSH key(s)" -Level "INFO"
            
            for ($i = 0; $i -lt $keys.Count; $i++) {
                $key = $keys[$i]
                # Display a truncated version of the key for readability
                $keyParts = $key -split ' '
                $keyType = $keyParts[0]
                $keyFingerprint = $keyParts[1].Substring(0, 20) + "..." + $keyParts[1].Substring($keyParts[1].Length - 20)
                $keyEmail = if ($keyParts.Count -gt 2) { $keyParts[2] } else { "N/A" }
                
                Write-Host "[$i] $keyType $keyFingerprint $keyEmail"
            }
        } else {
            Write-Log "No SSH keys found" -Level "WARNING"
        }
    } else {
        Write-Log "SSH key file not found" -Level "WARNING"
    }
}

# Function to remove all SSH keys
function Remove-AllSshKeys {
    $confirmation = Read-Host "Are you sure you want to delete all SSH keys? (y/n)"
    
    if ($confirmation -eq 'y') {
        if (Test-Path -Path $adminKeys) {
            Set-Content -Path $adminKeys -Value ""
            Write-Log "All SSH keys have been removed" -Level "SUCCESS"
        } else {
            Write-Log "SSH key file not found" -Level "WARNING"
        }
    } else {
        Write-Log "Operation cancelled" -Level "INFO"
    }
}

# Main script execution
try {
    # Initialize SSH environment
    Initialize-SshEnvironment
    
    # Ensure SSH service is installed
    if (-not (Get-Service -Name sshd -ErrorAction SilentlyContinue)) {
        Write-Log "OpenSSH Server is not installed. Installing..." -Level "WARNING"
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        Start-Service sshd
        Set-Service -Name sshd -StartupType 'Automatic'
        Write-Log "OpenSSH Server installed and configured" -Level "SUCCESS"
    } else {
        Write-Log "OpenSSH Server is already installed" -Level "INFO"
    }
    
    # Update sshd_config to use administrators_authorized_keys
    $sshdConfigPath = "$env:ProgramData\ssh\sshd_config"
    $configContent = Get-Content -Path $sshdConfigPath
    
    if ($configContent -notcontains "AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys") {
        Add-Content -Path $sshdConfigPath -Value "`nAuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys"
        Write-Log "Updated sshd_config to use administrators_authorized_keys" -Level "SUCCESS"
        Restart-Service sshd
    }
    
    # Main menu
    $exitRequested = $false
    
    while (-not $exitRequested) {
        Clear-Host
        Write-Log "SSH Key Management Menu" -Level "INFO"
        Write-Host "`n1. Add SSH key manually"
        Write-Host "2. Import SSH key from GitHub"
        Write-Host "3. List current SSH keys"
        Write-Host "4. Delete all SSH keys"
        Write-Host "5. Exit"
        Write-Host ""
        
        $choice = Read-Host "Enter your choice (1-5)"
        
        switch ($choice) {
            "1" { Add-SshKeyManually }
            "2" { 
                $githubUsername = Read-Host "Enter GitHub username"
                Add-SshKeyFromGitHub -Username $githubUsername 
            }
            "3" { Show-CurrentSshKeys }
            "4" { Remove-AllSshKeys }
            "5" { $exitRequested = $true }
            default { Write-Log "Invalid choice. Please try again." -Level "WARNING" }
        }
        
        if (-not $exitRequested) {
            Write-Host "`nPress any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
} catch {
    Write-Log "An error occurred: $_" -Level "ERROR"
}

Write-Log "SSH key management completed" -Level "SUCCESS"

# SIG # Begin signature block
# MIIb8gYJKoZIhvcNAQcCoIIb4zCCG98CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA3nN0e8nfQr5kt
# Ddnsy7k5pPcnocVV/T9y0+JObNzPrKCCFjEwggMqMIICEqADAgECAhActY9oOxGl
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
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDV
# ED95ppk93z3cPQOV8nD9KoT50WfXVpWwA99y/SC4uzANBgkqhkiG9w0BAQEFAASC
# AQC1/1gZVD2T2VivAxeTL6IJNXBeX79kMC7K++bzgEvZ3SS11OonKbmE64p72KkF
# CcP0rXidCiQOf4qPJnKBD7VyOC6+mN332m2TAF7v3LBtA4B6r0FzvsEdju47IMao
# rTjUwe93mZGml3eXCf3Md3YFjtgEPXHgZFe43kPlbwp/ga0MJeC64HNvEGEwP8f1
# a62hQdXQIuBqGwzJTV/uVvv+H5UKqOkjvJ9A2CbIARjxpQKq1MYwRG5yw1+OIQmj
# DjQ7KrwrIZJEbTJEUBHKat+CyfHNWTLNqgk2hTIUejZgXB1so+/HfXYwx5Ebn56i
# CwOtzmQGI9ArU2AuPhwmxUxFoYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEB
# MHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYD
# VQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFt
# cGluZyBDQQIQC65mvFq6f5WHxvnpBOMzBDANBglghkgBZQMEAgEFAKBpMBgGCSqG
# SIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MDMyODIxNTA1
# NlowLwYJKoZIhvcNAQkEMSIEIFTkDlJFSmAjRxO5DHOJbgi0pAbRYg9PW7rkcT85
# LPNvMA0GCSqGSIb3DQEBAQUABIICAKsiHAe7emUf2lV9XQ+icWVNBTRLIil8Q5SP
# k1yzHpeGUYPy2D/dn+csneAv79N8U2vZ3UGVPu3iISiWvB/og/X2Odydn3rt0m8n
# YB1KNEw8gAz110M0JW0GO3ApJ5k7Q81lHGBfU6DXLztpVE07knlgBtFwCUIaEfTu
# AM7BOA++7z1kq5kWMWRZZOi07h0XvMoM3ZMgnX1w/pNSgXiShee2lB6xPLoSuLf7
# bK1e/wstComO9fdBrco/s+uyWKl+YTloAe6FGhtBzbH+yEkn3nqM/9jaXbDcHlTo
# jvaduzQ9bjAAMbN66yLvrwN9cyBDtl227lPUi5ANJH8GMJH3llt6iBt/H91LLD9j
# yfYibbkhMPhz6egL44Fw1dqfHj2Eg62Xz8yn/hII4uwHLEBNnf1+Qxp81x/cu6nf
# 8/o+bRLY+xzd3XBXXmymIhQIKEkmdgi1aXFHRq71we7a2L9GVD5ELt8XzVR18FBq
# J3lqwjjdyysgpOEasQg+TOXN/WB8qVu2VLoUmf5XpxSYYgaFy741dUinVARE4Fc1
# a/GkVK736Cpd8VSj1XFN7jP+j7ltYOaKIjNRmNVaky+4pItGqB6XvTYypm4BWkM7
# g+fpy5VaI3Q7QNOAdKnl2o9Yiaa2VQkjUtxxiUqwM4lgSjmKHfjNQVEPv7qBQTvr
# vEIobm9h
# SIG # End signature block
