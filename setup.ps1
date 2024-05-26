# Enable Remote Desktop
Try {
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0 -PropertyType DWORD -Force
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

# Install OpenSSH.Client
Try {
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
    Write-Output "OpenSSH.Client installed successfully."
} Catch {
    Write-Output "Failed to install OpenSSH.Client: $_"
}

# Install OpenSSH.Server
Try {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Write-Output "OpenSSH.Server installed successfully."
} Catch {
    Write-Output "Failed to install OpenSSH.Server: $_"
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

# Set time zone to Eastern Standard Time
Try {
    tzutil /s "Eastern Standard Time"
    Write-Output "Time zone set to Eastern Standard Time."
} Catch {
    Write-Output "Failed to set time zone: $_"
}

# Set time synchronization to update every 24 hours
Try {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" /v SpecialPollInterval /t REG_DWORD /d 86400 /f
    Restart-Service w32time
    Write-Output "Time synchronization set to update every 24 hours."
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

# Set system region to US
Try {
    Set-WinUILanguageOverride -Language en-US
    Set-WinSystemLocale -SystemLocale en-US
    Set-WinUserLanguageList en-US -Force
    Set-Culture en-US
    Set-WinHomeLocation -GeoId 244
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "GeoID" -Value 244
    Write-Output "System region set to US."
} Catch {
    Write-Output "Failed to set system region: $_"
}

# Set taskbar alignment to left
Try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0
    Write-Output "Taskbar alignment set to left."
} Catch {
    Write-Output "Failed to set taskbar alignment: $_"
}

# Hide Task View button in the taskbar
Try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
    Write-Output "Task View button hidden in the taskbar."
} Catch {
    Write-Output "Failed to hide Task View button in the taskbar: $_"
}

# Hide Widgets in the taskbar
Try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
    Write-Output "Widgets hidden in the taskbar."
} Catch {
    Write-Output "Failed to hide Widgets in the taskbar: $_"
}

# Final output message
Write-Output "Everything successfully installed and enabled."
Pause
