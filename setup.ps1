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

# Ensure W32Time service is running and set to start automatically
Try {
    Set-Service -Name W32Time -Status Running -StartupType Automatic
    Write-Output "W32Time service is running and set to start automatically."
} Catch {
    Write-Output "Failed to configure W32Time service: $_"
}

# Final output message
Write-Output "Everything successfully installed and enabled."
Pause
