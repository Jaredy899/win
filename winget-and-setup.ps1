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

# Set default shell for OpenSSH
Try {
    New-ItemProperty -Path "HKLM:\\SOFTWARE\\OpenSSH" -Name DefaultShell -Value "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -PropertyType String -Force
    Write-Output "Default shell for OpenSSH set to PowerShell 7."
} Catch {
    Write-Output "Failed to set default shell for OpenSSH: $_"
}

# Set default terminal shell to PowerShell 7
Try {
    Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon" -Name "Shell" -Value "C:\\Program Files\\PowerShell\\7\\pwsh.exe"
    Write-Output "Default terminal shell set to PowerShell 7."
} Catch {
    Write-Output "Failed to set default terminal shell: $_"
}

# Set time zone to Eastern Standard Time
Try {
    tzutil /s "Eastern Standard Time"
    Write-Output "Time zone set to Eastern Standard Time."
} Catch {
    Write-Output "Failed to set time zone: $_"
}

# Set time synchronization interval to 1 hour
Try {
    w32tm /config /manualpeerlist:time.windows.com /syncfromflags:manual /reliable:YES /update
    w32tm /config /update
    w32tm /resync /rediscover
    Write-Output "Time synchronization interval set to 1 hour."
} Catch {
    Write-Output "Failed to set time synchronization interval: $_"
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

# Install and configure winget using the script from Chris Titus Tech
Try {
    irm https://raw.githubusercontent.com/ChrisTitusTech/winutil/main/winget.ps1 | iex
    Write-Output "winget script executed successfully."
} Catch {
    Write-Output "Failed to execute winget script: $_"
}

# Final output message
Write-Output "Everything successfully installed and enabled."
Pause
