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
    
    # Initialize configuration
    $Config = Initialize-Config
    
    # Get SSH paths from config if available
    $programData = $env:ProgramData
    $sshPath = Get-ConfigValue -Path "paths.ssh_path" -DefaultValue (Join-Path $programData "ssh")
    $sshPath = [System.Environment]::ExpandEnvironmentVariables($sshPath)
    
    $adminKeys = Get-ConfigValue -Path "paths.admin_keys" -DefaultValue (Join-Path $sshPath "administrators_authorized_keys")
    $adminKeys = [System.Environment]::ExpandEnvironmentVariables($adminKeys)
} else {
    # Define required functions and variables if module not available
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
    
    function Test-Administrator {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    
    # Default paths
    $programData = $env:ProgramData
    $sshPath = Join-Path $programData "ssh"
    $adminKeys = Join-Path $sshPath "administrators_authorized_keys"
}

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-Log "This script must be run as Administrator" -Level "ERROR"
    
    # Try to elevate
    try {
        Write-Log "Attempting to elevate privileges..." -Level "INFO"
        Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"")
        exit
    }
    catch {
        Write-Log "Failed to elevate privileges. Please run as Administrator." -Level "ERROR"
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Function to initialize SSH environment
function Initialize-SshEnvironment {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Initializing SSH environment..." -Level "INFO"
        
        # Create SSH directory if it doesn't exist
        if (-not (Test-Path -Path $sshPath)) {
            New-Item -ItemType Directory -Path $sshPath -Force | Out-Null
            Write-Log "Created SSH directory: $sshPath" -Level "SUCCESS"
        }
        
        # Create administrators_authorized_keys file if it doesn't exist
        if (-not (Test-Path -Path $adminKeys)) {
            New-Item -ItemType File -Path $adminKeys -Force | Out-Null
            Write-Log "Created administrators_authorized_keys file: $adminKeys" -Level "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to initialize SSH environment: $_" -Level "ERROR"
        return $false
    }
}

# Function to validate SSH keys
function Test-SshKey {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string]$Key
    )
    
    # Basic validation for SSH key format
    if ($Key -match "^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)\s+[A-Za-z0-9+/]+={0,3}(\s+.+)?$") {
        return $true
    }
    
    return $false
}

# Function to safely get keys from GitHub
function Get-GitHubKeys {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter()]
        [int]$RetryCount = 3,
        
        [Parameter()]
        [int]$RetryDelaySeconds = 2
    )
    
    $attempt = 0
    $success = $false
    $keys = $null
    
    while (-not $success -and $attempt -lt $RetryCount) {
        $attempt++
        try {
            Write-Log "Fetching SSH keys from GitHub for user '$Username' (Attempt $attempt of $RetryCount)..." -Level "INFO"
            
            # Set TLS 1.2 for GitHub API compatibility
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            # Use GitHub API to get public keys
            $response = Invoke-RestMethod -Uri "https://api.github.com/users/$Username/keys" -ErrorAction Stop -UseBasicParsing
            
            if ($response.Count -eq 0) {
                Write-Log "No SSH keys found for GitHub user '$Username'" -Level "WARNING"
                return $null
            }
            
            $success = $true
            $keys = $response
            Write-Log "Successfully retrieved $($keys.Count) keys from GitHub" -Level "SUCCESS"
        }
        catch {
            Write-Log "Failed to fetch keys from GitHub (Attempt $attempt): $_" -Level "WARNING"
            
            if ($attempt -lt $RetryCount) {
                Write-Log "Retrying in $RetryDelaySeconds seconds..." -Level "INFO"
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
    
    if (-not $success) {
        Write-Log "Failed to fetch keys from GitHub after $RetryCount attempts" -Level "ERROR"
        return $null
    }
    
    return $keys
}

# Function to securely add a key to authorized_keys
function Add-UniqueKey {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Key,
        
        [Parameter()]
        [string]$Comment = ""
    )
    
    try {
        # Validate the key format
        if (-not (Test-SshKey -Key $Key)) {
            Write-Log "Invalid SSH key format" -Level "ERROR"
            return $false
        }
        
        # Check if the key already exists
        $existingKeys = Get-Content -Path $adminKeys -ErrorAction Stop
        
        # Extract the key part (without comment) for comparison
        $keyParts = $Key -split " ", 3
        if ($keyParts.Count -lt 2) {
            Write-Log "Invalid SSH key format" -Level "ERROR"
            return $false
        }
        
        $keyType = $keyParts[0]
        $keyData = $keyParts[1]
        $keyPattern = "$keyType\s+$keyData"
        
        if ($existingKeys -match $keyPattern) {
            Write-Log "Key already exists in $adminKeys" -Level "WARNING"
            return $true
        }
        
        # Add the key with comment if provided
        $keyToAdd = if ($Comment -and -not $Key.Contains($Comment)) {
            "$Key $Comment"
        } else {
            $Key
        }
        
        Add-Content -Path $adminKeys -Value $keyToAdd -ErrorAction Stop
        Write-Log "Added new key to $adminKeys" -Level "SUCCESS"
        
        return $true
    }
    catch {
        Write-Log "Failed to add key: $_" -Level "ERROR"
        return $false
    }
}

# Function to handle GitHub key import
function Import-GitHubKeys {
    [CmdletBinding()]
    param()
    
    try {
        # Clear the console and show prompt
        Clear-Host
        Write-Host "`n  Import SSH Keys from GitHub" -ForegroundColor Cyan
        Write-Host "  ============================" -ForegroundColor DarkGray
        
        Write-Host "`nEnter GitHub username: " -ForegroundColor Cyan -NoNewline
        $githubUsername = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($githubUsername)) {
            Write-Log "No GitHub username provided" -Level "WARNING"
            return
        }
        
        Write-Host "`nFetching keys from GitHub..." -ForegroundColor Yellow
        $keys = Get-GitHubKeys -Username $githubUsername
        
        if (-not $keys) {
            Write-Log "No keys found or unable to fetch keys for GitHub user '$githubUsername'" -Level "WARNING"
            return
        }
        
        Write-Host "`nFound $($keys.Count) keys for user " -NoNewline
        Write-Host $githubUsername -ForegroundColor Cyan
        
        $addedCount = 0
        
        foreach ($key in $keys) {
            Write-Host "`nKey ID: " -NoNewline
            Write-Host $key.id -ForegroundColor Cyan
            
            $keyType = $key.key -split " ", 2 | Select-Object -First 1
            $keyPreview = if ($key.key.Length -gt 50) { "$($key.key.Substring(0, 25))....$($key.key.Substring($key.key.Length - 25))" } else { $key.key }
            
            Write-Host "Type: $keyType" -ForegroundColor DarkGray
            Write-Host "Key: $keyPreview" -ForegroundColor DarkGray
            
            $addThis = Read-Host "Add this key? (y/n)"
            if ($addThis -eq 'y') {
                $comment = "github:$githubUsername"
                if (Add-UniqueKey -Key $key.key -Comment $comment) {
                    $addedCount++
                }
            }
        }
        
        Write-Host "`nAdded $addedCount of $($keys.Count) keys from GitHub user '$githubUsername'" -ForegroundColor Green
    }
    catch {
        Write-Log "Error during GitHub key import: $_" -Level "ERROR"
    }
}

# Function to handle manual key entry
function Add-ManualKey {
    [CmdletBinding()]
    param()
    
    try {
        # Clear the console and show prompt
        Clear-Host
        Write-Host "`n  Manually Add SSH Key" -ForegroundColor Cyan
        Write-Host "  ===================" -ForegroundColor DarkGray
        
        Write-Host "`nPaste your public key (format: 'ssh-xxx AAAAB3N...'): " -ForegroundColor Cyan
        $manualKey = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($manualKey)) {
            Write-Log "No key provided" -Level "WARNING"
            return
        }
        
        Write-Host "`nAdd a comment to identify this key (optional): " -ForegroundColor Cyan
        $comment = Read-Host
        
        if (Add-UniqueKey -Key $manualKey -Comment $comment) {
            Write-Host "`nKey added successfully" -ForegroundColor Green
        } else {
            Write-Host "`nFailed to add key" -ForegroundColor Red
        }
    }
    catch {
        Write-Log "Error during manual key entry: $_" -Level "ERROR"
    }
}

# Function to set secure permissions on the keys file
function Set-SecureKeyPermissions {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Setting secure permissions on $adminKeys..." -Level "INFO"
        
        # Remove all existing permissions
        icacls $adminKeys /inheritance:r | Out-Null
        
        # Add permission only for Administrators and SYSTEM
        icacls $adminKeys /grant "Administrators:F" | Out-Null
        icacls $adminKeys /grant "SYSTEM:F" | Out-Null
        
        Write-Log "Secure permissions set on $adminKeys" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to set permissions: $_" -Level "ERROR"
        return $false
    }
}

# Function to restart SSH service
function Restart-SshService {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Checking if SSH service exists..." -Level "INFO"
        $sshService = Get-Service -Name sshd -ErrorAction SilentlyContinue
        
        if (-not $sshService) {
            Write-Log "SSH service (sshd) not found. Please install OpenSSH Server." -Level "WARNING"
            return $false
        }
        
        Write-Log "Restarting SSH service..." -Level "INFO"
        
        Stop-Service sshd -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        Start-Service sshd -ErrorAction Stop
        
        Write-Log "SSH service restarted successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to restart SSH service: $_" -Level "ERROR"
        return $false
    }
}

# Function to fix SSH key permissions
function Repair-SshKeyPermissions {
    [CmdletBinding()]
    param (
        [string]$keyPath = "$env:USERPROFILE\.ssh\id_rsa"
    )
    
    try {
        Write-Log "Checking for private key at $keyPath..." -Level "INFO"
        
        if (-not (Test-Path -Path $keyPath)) {
            Write-Log "No private key found at $keyPath - skipping permissions fix" -Level "WARNING"
            return $false
        }
        
        Write-Log "Setting secure permissions on private key..." -Level "INFO"
        
        # Remove all existing permissions
        icacls $keyPath /inheritance:r | Out-Null
        
        # Add permission only for current user
        icacls $keyPath /grant ${env:USERNAME}:"(R)" | Out-Null
        
        Write-Log "Fixed permissions for $keyPath" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to set key permissions: $_" -Level "ERROR"
        return $false
    }
}

# Function to verify SSH server configuration
function Test-SshServerConfig {
    [CmdletBinding()]
    param()
    
    try {
        $sshConfigPath = Join-Path $sshPath "sshd_config"
        
        if (-not (Test-Path -Path $sshConfigPath)) {
            Write-Log "SSH server config not found at $sshConfigPath" -Level "WARNING"
            return $false
        }
        
        $config = Get-Content -Path $sshConfigPath -Raw
        
        # Check if PubkeyAuthentication is enabled
        if ($config -notmatch "PubkeyAuthentication\s+yes") {
            Write-Log "PubkeyAuthentication is not explicitly enabled in sshd_config" -Level "WARNING"
            
            $confirm = Read-Host "Do you want to enable PubkeyAuthentication in the SSH server config? (y/n)"
            if ($confirm -eq 'y') {
                if ($config -match "PubkeyAuthentication\s+no") {
                    $config = $config -replace "PubkeyAuthentication\s+no", "PubkeyAuthentication yes"
                } else {
                    $config += "`nPubkeyAuthentication yes"
                }
                
                $config | Set-Content -Path $sshConfigPath -Force
                Write-Log "PubkeyAuthentication enabled in SSH server config" -Level "SUCCESS"
                return $true
            }
        } else {
            Write-Log "SSH server is correctly configured for public key authentication" -Level "SUCCESS"
            return $true
        }
    }
    catch {
        Write-Log "Failed to check/update SSH server configuration: $_" -Level "ERROR"
        return $false
    }
    
    return $true
}

# Function to show menu
function Show-Menu {
    [CmdletBinding()]
    param()
    
    $options = @(
        "Import keys from GitHub", 
        "Enter key manually", 
        "Check SSH server configuration", 
        "Repair key permissions",
        "Exit"
    )
    
    $selectedIndex = 0
    
    do {
        Clear-Host
        Write-Host "`n  Windows SSH Key Manager`n" -ForegroundColor Cyan
        Write-Host "  Use ↑↓ arrows to select and Enter to confirm:`n" -ForegroundColor Gray
        
        for ($i = 0; $i -lt $options.Count; $i++) {
            if ($i -eq $selectedIndex) {
                Write-Host "  > " -NoNewline -ForegroundColor Cyan
                Write-Host $options[$i] -ForegroundColor White -BackgroundColor DarkBlue
            } else {
                Write-Host "    $($options[$i])" -ForegroundColor Gray
            }
        }
        
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $selectedIndex = ($selectedIndex - 1) % $options.Count
                if ($selectedIndex -lt 0) { $selectedIndex = $options.Count - 1 }
            }
            40 { # Down arrow
                $selectedIndex = ($selectedIndex + 1) % $options.Count
            }
        }
    } while ($key.VirtualKeyCode -ne 13) # Enter key
    
    return $selectedIndex
}

# Main script
Clear-Host
Write-Host "`n  Windows SSH Key Manager" -ForegroundColor Cyan
Write-Host "  ====================" -ForegroundColor DarkGray

# Initialize SSH environment
if (-not (Initialize-SshEnvironment)) {
    Write-Log "Failed to initialize SSH environment. Exiting." -Level "ERROR"
    Read-Host "Press Enter to exit"
    exit 1
}

# Main menu loop
do {
    $selectedOption = Show-Menu
    
    switch ($selectedOption) {
        0 { Import-GitHubKeys }
        1 { Add-ManualKey }
        2 { Test-SshServerConfig }
        3 { Repair-SshKeyPermissions }
        4 { 
            Write-Host "`nExiting SSH Key Manager" -ForegroundColor Cyan
            $done = $true 
        }
    }
    
    if ($selectedOption -ne 4) {
        Write-Host "`nPress any key to return to menu..." -ForegroundColor Magenta
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
} while (-not $done)

# Set secure permissions before exiting
Set-SecureKeyPermissions

# Restart SSH service to apply changes
if (Restart-SshService) {
    Write-Log "SSH key management completed successfully. SSH service restarted." -Level "SUCCESS"
} else {
    Write-Log "SSH key management completed, but there were issues with the SSH service." -Level "WARNING"
}

Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
Read-Host
