# Enable Remote Desktop
Try {
    New-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" -Name fDenyTSConnections -Value 0 -PropertyType DWORD -Force
    Write-Output "Remote Desktop enabled."
} Catch {
    Write-Output "Failed to enable Remote Desktop: $_"
}

# Enable Remote Desktop firewall rule
Try {
    netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
    Write-Output "Firewall rule for Remote Desktop enabled."
} Catch {
    Write-Output "Failed to enable firewall rule for Remote Desktop: $_"
}

# Enable ICMPv4-In rule to allow ping
Try {
    netsh advfirewall firewall add rule name="Allow ICMPv4-In" protocol=icmpv4:8,any dir=in action=allow
    Write-Output "ICMPv4-In rule enabled. Ping is now allowed."
} Catch {
    Write-Output "Failed to enable ICMPv4-In rule: $_"
}

# Set password for Jared account
Try {
    net user Jared jarjar89
    Write-Output "Password for Jared account set."
} Catch {
    Write-Output "Failed to set password for Jared account: $_"
}

# Check if OpenSSH.Client is already installed
if ((Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*').State -ne 'Installed') {
    # Install OpenSSH.Client
    Try {
        Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
        Write-Output "OpenSSH.Client installed successfully."
    } Catch {
        Write-Output "Failed to install OpenSSH.Client: $_"
    }
} else {
    Write-Output "OpenSSH.Client is already installed."
}

# Check if OpenSSH.Server is already installed
if ((Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*').State -ne 'Installed') {
    # Install OpenSSH.Server
    Try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        Write-Output "OpenSSH.Server installed successfully."
    } Catch {
        Write-Output "Failed to install OpenSSH.Server: $_"
    }
} else {
    Write-Output "OpenSSH.Server is already installed."
}

# Start SSH service
Try {
    Start-Service sshd
    Write-Output "SSH service started."
} Catch {
    Write-Output "Failed to start SSH service: $_"
}

# Set SSH service to start automatically
Try {
    Set-Service -Name sshd -StartupType 'Automatic'
    Write-Output "SSH service set to start automatically."
} Catch {
    Write-Output "Failed to set SSH service to start automatically: $_"
}

# Check if firewall rule for SSH already exists
$firewallRule = Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue
if ($firewallRule) {
    Write-Output "Firewall rule for OpenSSH Server (sshd) already exists."
} else {
    Try {
        New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
        Write-Output "Firewall rule for OpenSSH Server (sshd) created successfully."
    } Catch {
        Write-Output "Failed to create firewall rule for OpenSSH Server (sshd): $_"
    }
}

# Set default shell for OpenSSH
Try {
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force
    Write-Output "Default shell for OpenSSH set to PowerShell 7."
} Catch {
    Write-Output "Failed to set default shell for OpenSSH: $_"
}

# Set time zone to Eastern Standard Time
Try {
    tzutil /s "Eastern Standard Time"
    Write-Output "Time zone set to Eastern Standard Time."
} Catch {
    Write-Output "Failed to set time zone: $_"
}

# Sync time with internet time servers
Try {
    w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update
    Write-Output "Time synchronization configured."
} Catch {
    Write-Output "Failed to configure time synchronization: $_"
}

# Ensure W32Time service is running and set to start automatically
Try {
    Set-Service -Name W32Time -Status Running -StartupType Automatic
    Write-Output "W32Time service is running and set to start automatically."
} Catch {
    Write-Output "Failed to configure W32Time service: $_"
}

# Trigger immediate time synchronization
Try {
    w32tm /resync
    Write-Output "Time synchronization triggered immediately."
} Catch {
    Write-Output "Failed to trigger immediate time synchronization: $_"
}

# Set system region to US
Try {
    Set-WinUILanguageOverride -Language en-US
    Set-WinSystemLocale -SystemLocale en-US
    Set-WinUserLanguageList en-US -Force
    Set-Culture en-US
    Set-WinHomeLocation -GeoId 244
    Set-ItemProperty -Path "HKCU:\\Control Panel\\International" -Name "GeoID" -Value 244
    Write-Output "System region set to US."
} Catch {
    Write-Output "Failed to set system region: $_"
}

# Set taskbar alignment to left
Try {
    Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced" -Name "TaskbarAl" -Value 0
    Write-Output "Taskbar alignment set to left."
} Catch {
    Write-Output "Failed to set taskbar alignment: $_"
}

# Hide Task View button in the taskbar
Try {
    Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced" -Name "ShowTaskViewButton" -Value 0
    Write-Output "Task View button hidden in the taskbar."
} Catch {
    Write-Output "Failed to hide Task View button in the taskbar: $_"
}

# Hide Widgets in the taskbar
Try {
    Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced" -Name "TaskbarDa" -Value 0
    Write-Output "Widgets hidden in the taskbar."
} Catch {
    Write-Output "Failed to hide Widgets in the taskbar: $_"
}

# Final output message
Write-Output "##########################################################"
Write-Output "#                                                        #"
Write-Output "#     EVERYTHING SUCCESSFULLY INSTALLED AND ENABLED      #"
Write-Output "#                                                        #"
Write-Output "##########################################################"
Pause
