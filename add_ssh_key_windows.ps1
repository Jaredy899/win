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
