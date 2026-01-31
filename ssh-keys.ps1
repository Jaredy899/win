# Windows SSH Key Manager
# Manage SSH keys in administrators_authorized_keys
# Must be run as administrator

# ANSI color codes
$esc = [char]27
$Cyan = "${esc}[36m"
$Yellow = "${esc}[33m"
$Green = "${esc}[32m"
$Red = "${esc}[31m"
$Blue = "${esc}[34m"
$Gray = "${esc}[90m"
$Reset = "${esc}[0m"

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "${Red}This script must be run as Administrator${Reset}"
    exit 1
}

# Variables
$programData = $env:ProgramData
$sshPath = Join-Path $programData "ssh"
$adminKeys = Join-Path $sshPath "administrators_authorized_keys"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Initialize-SshEnvironment {
    if (-not (Test-Path -Path $sshPath)) {
        New-Item -ItemType Directory -Path $sshPath -Force | Out-Null
        Write-Host "${Green}Created $sshPath${Reset}"
    }
    if (-not (Test-Path -Path $adminKeys)) {
        New-Item -ItemType File -Path $adminKeys -Force | Out-Null
        Write-Host "${Green}Created $adminKeys${Reset}"
    }
}

function Get-KeyCount {
    if (-not (Test-Path $adminKeys)) { return 0 }
    $keys = Get-Content -Path $adminKeys | Where-Object { $_.Trim() -ne "" }
    return @($keys).Count
}

function Get-KeyFingerprint {
    param([string]$key)
    $tmp = [IO.Path]::GetTempFileName()
    try {
        Set-Content -Path $tmp -Value $key
        $fp = (& ssh-keygen -lf $tmp 2>$null) -split '\s+' | Select-Object -Index 1
        return $fp
    } catch {
        return "(unknown)"
    } finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

function Get-GitHubKeys {
    param([string]$username)
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/users/$username/keys" -ErrorAction Stop
        return $response
    } catch {
        Write-Host "${Red}Failed to fetch keys from GitHub: $_${Reset}"
        return $null
    }
}

function Add-UniqueKey {
    param([string]$key)
    $existingKeys = @(Get-Content -Path $adminKeys -ErrorAction SilentlyContinue)
    if ($existingKeys -contains $key) {
        Write-Host "${Yellow}Key already exists.${Reset}"
        return $false
    }
    Add-Content -Path $adminKeys -Value $key
    Write-Host "${Green}Key added successfully.${Reset}"
    return $true
}

function Set-KeyPermissions {
    icacls $adminKeys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" *>$null
}

function Restart-SshService {
    try {
        Restart-Service sshd -Force -ErrorAction Stop
        Write-Host "${Green}SSH service restarted.${Reset}"
    } catch {
        Write-Host "${Yellow}Could not restart SSH service (may not be installed).${Reset}"
    }
}

# ============================================================================
# MENU FUNCTIONS
# ============================================================================

function Show-Menu {
    param([int]$selectedIndex)
    
    Clear-Host
    $keyCount = Get-KeyCount
    
    Write-Host ""
    Write-Host "${Cyan}  Windows SSH Key Manager${Reset}"
    Write-Host "${Gray}  Keys in authorized_keys: $keyCount${Reset}"
    Write-Host ""
    Write-Host "${Gray}  Use arrow keys to navigate, Enter to select${Reset}"
    Write-Host ""
    
    $options = @(
        "Import ALL keys from GitHub username",
        "Import keys from GitHub (select individually)",
        "Enter key manually",
        "View existing keys",
        "Remove a key",
        "Exit"
    )
    
    for ($i = 0; $i -lt $options.Count; $i++) {
        if ($i -eq $selectedIndex) {
            Write-Host "  ${Cyan}> $($options[$i])${Reset}"
        } else {
            Write-Host "    $($options[$i])"
        }
    }
    
    return $options.Count
}

function Import-AllGitHubKeys {
    Write-Host ""
    Write-Host "${Cyan}Enter GitHub username: ${Reset}" -NoNewline
    $username = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "${Yellow}No username entered.${Reset}"
        return
    }
    
    Write-Host "${Yellow}Fetching keys from GitHub...${Reset}"
    $keys = Get-GitHubKeys -username $username
    
    if (-not $keys -or $keys.Count -eq 0) {
        Write-Host "${Yellow}No keys found for user $username.${Reset}"
        return
    }
    
    Write-Host "${Blue}Found $($keys.Count) keys for $username${Reset}"
    $added = 0
    
    foreach ($entry in $keys) {
        if (Add-UniqueKey -key $entry.key) {
            $added++
        }
    }
    
    Write-Host "${Green}Added $added new keys.${Reset}"
}

function Import-GitHubKeysSelective {
    Write-Host ""
    Write-Host "${Cyan}Enter GitHub username: ${Reset}" -NoNewline
    $username = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "${Yellow}No username entered.${Reset}"
        return
    }
    
    Write-Host "${Yellow}Fetching keys from GitHub...${Reset}"
    $keys = Get-GitHubKeys -username $username
    
    if (-not $keys -or $keys.Count -eq 0) {
        Write-Host "${Yellow}No keys found for user $username.${Reset}"
        return
    }
    
    Write-Host "${Blue}Found $($keys.Count) keys${Reset}"
    Write-Host ""
    
    foreach ($entry in $keys) {
        $keyType = ($entry.key -split ' ')[0]
        $fp = Get-KeyFingerprint -key $entry.key
        
        Write-Host "${Cyan}Key ID: $($entry.id)${Reset}"
        Write-Host "  Type: $keyType"
        Write-Host "  Fingerprint: $fp"
        Write-Host ""
        Write-Host "Add this key? (y/n): " -NoNewline
        $add = Read-Host
        
        if ($add -eq 'y' -or $add -eq 'Y') {
            Add-UniqueKey -key $entry.key | Out-Null
        }
        Write-Host ""
    }
}

function Add-ManualKey {
    Write-Host ""
    Write-Host "${Cyan}Paste your public key:${Reset}"
    $key = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($key)) {
        Write-Host "${Yellow}No key entered.${Reset}"
        return
    }
    
    Add-UniqueKey -key $key | Out-Null
}

function Show-ExistingKeys {
    Write-Host ""
    
    if (-not (Test-Path $adminKeys)) {
        Write-Host "${Yellow}No keys file found.${Reset}"
        return
    }
    
    $keys = @(Get-Content -Path $adminKeys | Where-Object { $_.Trim() -ne "" })
    
    if ($keys.Count -eq 0) {
        Write-Host "${Yellow}No keys in authorized_keys.${Reset}"
        return
    }
    
    Write-Host "${Cyan}Existing keys ($($keys.Count)):${Reset}"
    Write-Host ""
    
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $key = $keys[$i]
        $keyType = ($key -split ' ')[0]
        $fp = Get-KeyFingerprint -key $key
        
        Write-Host "${Blue}[$($i + 1)]${Reset} $keyType"
        Write-Host "    Fingerprint: $fp"
        Write-Host ""
    }
}

function Remove-KeyByIndex {
    Write-Host ""
    
    if (-not (Test-Path $adminKeys)) {
        Write-Host "${Yellow}No keys file found.${Reset}"
        return
    }
    
    $keys = @(Get-Content -Path $adminKeys | Where-Object { $_.Trim() -ne "" })
    
    if ($keys.Count -eq 0) {
        Write-Host "${Yellow}No keys to remove.${Reset}"
        return
    }
    
    Write-Host "${Cyan}Current keys:${Reset}"
    Write-Host ""
    
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $key = $keys[$i]
        $keyType = ($key -split ' ')[0]
        $fp = Get-KeyFingerprint -key $key
        Write-Host "${Blue}[$($i + 1)]${Reset} $keyType - $fp"
    }
    
    Write-Host ""
    Write-Host "Enter key number to remove (or 0 to cancel): " -NoNewline
    $input = Read-Host
    
    if ($input -match '^\d+$') {
        $index = [int]$input - 1
        if ($index -ge 0 -and $index -lt $keys.Count) {
            $newKeys = @()
            for ($i = 0; $i -lt $keys.Count; $i++) {
                if ($i -ne $index) {
                    $newKeys += $keys[$i]
                }
            }
            Set-Content -Path $adminKeys -Value $newKeys
            Write-Host "${Green}Key removed.${Reset}"
        } elseif ($index -eq -1) {
            Write-Host "${Blue}Cancelled.${Reset}"
        } else {
            Write-Host "${Red}Invalid selection.${Reset}"
        }
    } else {
        Write-Host "${Yellow}Invalid input.${Reset}"
    }
}

# ============================================================================
# MAIN LOOP
# ============================================================================

Initialize-SshEnvironment

$selectedIndex = 0
$running = $true

while ($running) {
    $optionCount = Show-Menu -selectedIndex $selectedIndex
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    switch ($key.VirtualKeyCode) {
        38 { # Up arrow
            $selectedIndex--
            if ($selectedIndex -lt 0) { $selectedIndex = $optionCount - 1 }
        }
        40 { # Down arrow
            $selectedIndex++
            if ($selectedIndex -ge $optionCount) { $selectedIndex = 0 }
        }
        13 { # Enter
            Clear-Host
            switch ($selectedIndex) {
                0 { Import-AllGitHubKeys }
                1 { Import-GitHubKeysSelective }
                2 { Add-ManualKey }
                3 { Show-ExistingKeys }
                4 { Remove-KeyByIndex }
                5 { $running = $false }
            }
            
            if ($running -and $selectedIndex -ne 5) {
                Write-Host ""
                Write-Host "${Gray}[Enter] Return to menu${Reset}"
                Read-Host | Out-Null
            }
        }
    }
}

# Final cleanup
Write-Host ""
Write-Host "${Yellow}Setting permissions and restarting SSH...${Reset}"
Set-KeyPermissions
Restart-SshService

Write-Host ""
Write-Host "${Green}Done.${Reset}"
