# Script to add SSH keys to Windows administrators authorized_keys
# Must be run as administrator

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script must be run as Administrator" -ForegroundColor Red
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
        Write-Host "✓ Created $sshPath" -ForegroundColor Green
    }

    if (-not (Test-Path -Path $adminKeys)) {
        New-Item -ItemType File -Path $adminKeys -Force
        Write-Host "✓ Created $adminKeys" -ForegroundColor Green
    }
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

# Main script
Initialize-SshEnvironment

# Menu navigation
$selectedIndex = 0
$options = @("Import keys from GitHub", "Enter key manually")

do {
    Show-Menu -selectedIndex $selectedIndex
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    switch ($key.VirtualKeyCode) {
        38 { # Up arrow
            $selectedIndex = ($selectedIndex - 1) % $options.Count
            if ($selectedIndex -lt 0) { $selectedIndex = $options.Count - 1 }
        }
        40 { # Down arrow
            $selectedIndex = ($selectedIndex + 1) % $options.Count
        }
        13 { # Enter
            switch ($selectedIndex) {
                0 { Import-GitHubKeys }
                1 { Add-ManualKey }
            }
            break
        }
    }
} while ($key.VirtualKeyCode -ne 13)

# Set correct permissions
Write-Host "`nSetting permissions..." -ForegroundColor Yellow
icacls $adminKeys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
Write-Host "✓ Set permissions for $adminKeys" -ForegroundColor Green

# Restart SSH service
Restart-SshService

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
