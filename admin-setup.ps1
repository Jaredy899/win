# Windows Admin Setup Script
# Configures SSH, RDP, firewall, timezone, and system settings
# Must be run as administrator

# Suppress progress bars
$ProgressPreference = 'SilentlyContinue'

# ANSI color codes
$esc = [char]27
$Cyan = "${esc}[36m"
$Yellow = "${esc}[33m"
$Green = "${esc}[32m"
$Red = "${esc}[31m"
$Blue = "${esc}[34m"
$Reset = "${esc}[0m"

# ============================================================================
# ADMIN CHECK
# ============================================================================

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "${Yellow}Requesting administrative privileges...${Reset}"
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"")
    Exit
}

Write-Host ""
Write-Host "${Cyan}========================================${Reset}"
Write-Host "${Cyan}  Windows Admin Setup${Reset}"
Write-Host "${Cyan}========================================${Reset}"
Write-Host ""

# ============================================================================
# PASSWORD CHANGE
# ============================================================================

function Set-UserPassword {
    param ([SecureString]$password)
    $username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]
    Try {
        Write-Host "${Yellow}Changing password for $username...${Reset}"
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        net user "$username" "$plainPassword" *>$null
        Write-Host "${Green}Password changed successfully.${Reset}"
    } Catch {
        Write-Host "${Red}Failed to change password: $($_)${Reset}"
    }
}

Write-Host "${Cyan}Do you want to change your password?${Reset} (y/n, default: n)"
$changePassword = Read-Host

if ($changePassword -eq "yes" -or $changePassword -eq "y") {
    $passwordsMatch = $false
    while (-not $passwordsMatch) {
        Write-Host "${Yellow}Enter new password: ${Reset}" -NoNewline
        $password1 = Read-Host -AsSecureString
        Write-Host "${Yellow}Confirm password: ${Reset}" -NoNewline
        $password2 = Read-Host -AsSecureString

        $BSTR1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1)
        $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2)
        $plainPassword1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR1)
        $plainPassword2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)

        if ($plainPassword1 -eq $plainPassword2) {
            $passwordsMatch = $true
            Set-UserPassword -password $password1
        } else {
            Write-Host "${Red}Passwords do not match. Try again.${Reset}"
        }

        $plainPassword1 = $plainPassword2 = $null
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR1)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR2)
    }
} else {
    Write-Host "${Blue}Skipping password change.${Reset}"
}

# ============================================================================
# REMOTE DESKTOP
# ============================================================================

function Enable-RemoteDesktop {
    Write-Host "${Yellow}Enabling Remote Desktop...${Reset}"
    Try {
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0 -PropertyType DWORD -Force *>$null
        netsh advfirewall firewall set rule group="remote desktop" new enable=Yes *>$null
        Write-Host "${Green}Remote Desktop enabled.${Reset}"
    } Catch {
        Write-Host "${Red}Failed to enable Remote Desktop: $($_)${Reset}"
    }
}

# ============================================================================
# FIREWALL RULES
# ============================================================================

function Enable-ICMPv4 {
    Write-Host "${Yellow}Enabling ICMPv4 (ping)...${Reset}"
    Try {
        netsh advfirewall firewall add rule name="Allow ICMPv4-In" protocol="icmpv4" dir=in action=allow *>$null
        Write-Host "${Green}ICMPv4 enabled.${Reset}"
    } Catch {
        Write-Host "${Red}Failed to enable ICMPv4: $($_)${Reset}"
    }
}

# ============================================================================
# OPENSSH
# ============================================================================

function Get-WingetCmd {
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    $wingetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    if ($env:Path -notlike "*$wingetPath*") {
        $env:Path += ";$wingetPath"
    }
    
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) { return $wingetCmd.Source }
    
    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
    )
    foreach ($p in $paths) {
        $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Install-OpenSSH {
    Write-Host "${Yellow}Installing OpenSSH...${Reset}"
    
    # Check if already installed
    $sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if ($sshdService) {
        Write-Host "${Blue}OpenSSH Server already installed.${Reset}"
    } else {
        $installed = $false
        
        # Try winget first (faster)
        $winget = Get-WingetCmd
        if ($winget) {
            Write-Host "${Yellow}Installing OpenSSH via winget...${Reset}"
            & $winget install Microsoft.OpenSSH.Preview --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $installed = $true
            }
        }
        
        # Fallback to Windows Capability
        if (-not $installed) {
            Write-Host "${Yellow}Using Windows Capability to install OpenSSH...${Reset}"
            Add-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0" *>$null
            Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0" *>$null
        }
    }
    
    # Configure SSH service
    $sshConfigured = $false
    Try {
        $svc = Get-Service -Name sshd -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -ne 'Running') {
                Start-Service sshd -ErrorAction Stop
            }
            Set-Service -Name sshd -StartupType 'Automatic' -ErrorAction Stop
            $sshConfigured = $true
            Write-Host "${Green}SSH service configured.${Reset}"
        }
    } Catch {
        if ($_.Exception.Message -match "marked for deletion") {
            Write-Host "${Yellow}SSH is working but auto-start config failed (pending reboot).${Reset}"
            Write-Host "${Yellow}SSH will work now, but may not auto-start until you reboot.${Reset}"
        } else {
            Write-Host "${Red}Failed to configure SSH service: $($_.Exception.Message)${Reset}"
        }
    }
    
    # Firewall rule
    $firewallRuleExists = Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue
    if (-not $firewallRuleExists) {
        Try {
            New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 *>$null
            Write-Host "${Green}SSH firewall rule created.${Reset}"
        } Catch {
            Write-Host "${Red}Failed to create SSH firewall rule: $($_)${Reset}"
        }
    } else {
        Write-Host "${Blue}SSH firewall rule already exists.${Reset}"
    }
    
    # Set default shell to PowerShell 7 if available
    $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    if (Test-Path $pwshPath) {
        Try {
            if (-not (Test-Path "HKLM:\SOFTWARE\OpenSSH")) {
                New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force | Out-Null
            }
            New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value $pwshPath -PropertyType String -Force *>$null
            Write-Host "${Green}Default SSH shell set to PowerShell 7.${Reset}"
        } Catch {
            Write-Host "${Yellow}Could not set default shell: $($_)${Reset}"
        }
    }
}

# ============================================================================
# TIMEZONE
# ============================================================================

function Get-IanaToWindowsTimeZoneMap {
    param([string]$Url = "https://raw.githubusercontent.com/unicode-org/cldr/main/common/supplemental/windowsZones.xml")
    
    try {
        [xml]$xml = Invoke-RestMethod -Uri $Url -UseBasicParsing -TimeoutSec 10
        $map = @{}
        foreach ($mapZone in $xml.supplementalData.windowsZones.mapTimezones.mapZone) {
            $windowsTz = $mapZone.other
            $ianaTzs = $mapZone.type -split " "
            foreach ($iana in $ianaTzs) {
                if (-not $map.ContainsKey($iana)) {
                    $map[$iana] = $windowsTz
                }
            }
        }
        return $map
    }
    catch {
        return $null
    }
}

function Set-TimeSettings {
    Write-Host "${Yellow}Configuring time settings...${Reset}"
    
    Try {
        # Auto-detect timezone
        $timezone = $null
        Try {
            $timezone = (Invoke-RestMethod -Uri "https://ipapi.co/timezone" -Method Get -TimeoutSec 5).Trim()
        } Catch { }
        
        if ($timezone) {
            Write-Host "${Blue}Detected timezone: $timezone${Reset}"
            $tzMapping = Get-IanaToWindowsTimeZoneMap
            
            if ($tzMapping -and $tzMapping.ContainsKey($timezone)) {
                $windowsTimezone = $tzMapping[$timezone]
                tzutil /s $windowsTimezone *>$null
                Write-Host "${Green}Timezone set to $windowsTimezone${Reset}"
            } else {
                Write-Host "${Yellow}Could not map timezone, skipping.${Reset}"
            }
        } else {
            Write-Host "${Yellow}Could not detect timezone, skipping.${Reset}"
        }
        
        # Configure time sync
        w32tm /config /manualpeerlist:"time.nist.gov,0x1" /syncfromflags:manual /reliable:YES /update *>$null
        Set-Service -Name w32time -StartupType Automatic *>$null
        Start-Service -Name w32time -ErrorAction SilentlyContinue
        w32tm /resync *>$null
        Write-Host "${Green}Time sync configured.${Reset}"
    } Catch {
        Write-Host "${Red}Failed to configure time: $($_)${Reset}"
    }
}

function Set-TimeSyncAtStartup {
    Write-Host "${Yellow}Setting up time sync scheduled task...${Reset}"
    
    $taskName = "TimeSyncAtStartup"
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if ($existingTask) {
        Write-Host "${Blue}Time sync task already exists.${Reset}"
        return
    }
    
    Try {
        $action = New-ScheduledTaskAction -Execute "w32tm.exe" -Argument "/resync"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
        Write-Host "${Green}Time sync task created.${Reset}"
    } Catch {
        Write-Host "${Red}Failed to create time sync task: $($_)${Reset}"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host ""
Write-Host "${Cyan}--- Configuring System ---${Reset}"
Write-Host ""

# Run tasks (these are fast, no need for parallel)
Enable-RemoteDesktop
Enable-ICMPv4
Set-TimeSettings
Set-TimeSyncAtStartup

# OpenSSH (potentially slow, but winget version is much faster)
Install-OpenSSH

# Summary
Write-Host ""
Write-Host "${Cyan}========================================${Reset}"
Write-Host "${Green}  Admin Setup Complete${Reset}"
Write-Host "${Cyan}========================================${Reset}"
Write-Host ""
Write-Host "Configured:"
Write-Host "  - Remote Desktop enabled"
Write-Host "  - ICMPv4 (ping) enabled"
Write-Host "  - OpenSSH Server installed and configured"
Write-Host "  - Timezone auto-detected and set"
Write-Host "  - Time sync scheduled task created"
Write-Host ""
Write-Host "${Yellow}A restart may be required for all changes to take effect.${Reset}"
Write-Host ""
