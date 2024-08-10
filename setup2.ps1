function Enable-RemoteDesktop {
    Try {
        New-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" -Name fDenyTSConnections -Value 0 -PropertyType DWORD -Force
        Write-Output "Remote Desktop enabled."
    } Catch {
        Write-Output "Failed to enable Remote Desktop: $($_)"
    }
}

function Enable-FirewallRule {
    param (
        [string]$ruleGroup,
        [string]$ruleName,
        [string]$protocol = "",
        [string]$localPort = ""
    )
    Try {
        if ($protocol -and $localPort) {
            netsh advfirewall firewall add rule name="$ruleName" protocol="$protocol" dir=in action=allow
        } else {
            netsh advfirewall firewall set rule group="$ruleGroup" new enable=Yes
        }
        Write-Output "${ruleName} rule enabled."
    } Catch {
        Write-Output "Failed to enable ${ruleName} rule: $($_)"
    }
}

function Set-UserPassword {
    param (
        [string]$username,
        [string]$password
    )
    Try {
        net user "$username" "$password"
        Write-Output "Password for ${username} account set."
    } Catch {
        Write-Output "Failed to set password for ${username} account: $($_)"
    }
}

function Install-WindowsCapability {
    param (
        [string]$capabilityName
    )
    if ((Get-WindowsCapability -Online | Where-Object Name -like "$capabilityName*").State -ne 'Installed') {
        Try {
            Add-WindowsCapability -Online -Name "$capabilityName"
            Write-Output "${capabilityName} installed successfully."
        } Catch {
            Write-Output "Failed to install ${capabilityName}: $($_)"
        }
    } else {
        Write-Output "${capabilityName} is already installed."
    }
}

function Configure-SSH {
    Try {
        Start-Service sshd
        Set-Service -Name sshd -StartupType 'Automatic'
        Write-Output "SSH service started and set to start automatically."
    } Catch {
        Write-Output "Failed to configure SSH service: $($_)"
    }

    Try {
        $firewallRule = Get-NetFirewallRule -Name 'sshd' -ErrorAction Stop
        Write-Output "Firewall rule for OpenSSH Server (sshd) already exists."
    } Catch {
        if ($_.Exception -match "Cannot find object with name 'sshd'") {
            Try {
                New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
                Write-Output "Firewall rule for OpenSSH Server (sshd) created successfully."
            } Catch {
                Write-Output "Failed to create firewall rule for OpenSSH Server (sshd): $($_)"
            }
        } else {
            Write-Output "Failed to check for existing firewall rule: $($_)"
        }
    }

    Try {
        New-ItemProperty -Path "HKLM:\\SOFTWARE\\OpenSSH" -Name DefaultShell -Value "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -PropertyType String -Force
        Write-Output "Default shell for OpenSSH set to PowerShell 7."
    } Catch {
        Write-Output "Failed to set default shell for OpenSSH: $($_)"
    }
}

function Configure-TimeSettings {
    Try {
        tzutil /s "Eastern Standard Time"
        w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update
        Set-Service -Name w32time -StartupType Automatic
        Start-Service -Name w32time
        w32tm /resync
        Write-Output "Time settings configured and synchronized."
    } Catch {
        Write-Output "Failed to configure time settings or synchronization: $($_)"
    }
}

# Main script execution
Enable-RemoteDesktop
Enable-FirewallRule -ruleGroup "remote desktop" -ruleName "Remote Desktop"
Enable-FirewallRule -ruleName "Allow ICMPv4-In" -protocol "icmpv4:8,any"
Set-UserPassword -username "Jared" -password "jarjar89"
Install-WindowsCapability -capabilityName "OpenSSH.Client~~~~0.0.1.0"
Install-WindowsCapability -capabilityName "OpenSSH.Server~~~~0.0.1.0"
Configure-SSH
Configure-TimeSettings

Write-Output "##########################################################"
Write-Output "#                                                        #"
Write-Output "#     EVERYTHING SUCCESSFULLY INSTALLED AND ENABLED      #"
Write-Output "#                                                        #"
Write-Output "##########################################################"
Pause