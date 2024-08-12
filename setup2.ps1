function Enable-RemoteDesktop {
    Try {
        Write-Progress -Activity "Enabling Remote Desktop" -Status "In Progress" -PercentComplete 0
        Write-Output "Enabling Remote Desktop..."  # Progress message
        New-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" -Name fDenyTSConnections -Value 0 -PropertyType DWORD -Force *>$null
        Write-Progress -Activity "Enabling Remote Desktop" -Status "Completed" -PercentComplete 100
    } Catch {
        Write-Output "Failed to enable Remote Desktop: $($_)"
    }
}

function Enable-FirewallRule {
    param (
        [string]$ruleGroup = $(throw "ruleGroup is required"),
        [string]$ruleName = $(throw "ruleName is required"),
        [string]$protocol = "",
        [string]$localPort = ""
    )
    Try {
        Write-Progress -Activity "Enabling firewall rule: $ruleName" -Status "In Progress" -PercentComplete 0
        if ($protocol -and $localPort) {
            Write-Output "Enabling firewall rule: $ruleName for protocol: $protocol on port: $localPort"  # Progress message
            netsh advfirewall firewall add rule name="$ruleName" protocol="$protocol" dir=in action=allow *>$null
        } else {
            Write-Output "Enabling firewall rule group: $ruleGroup"  # Progress message
            netsh advfirewall firewall set rule group="$ruleGroup" new enable=Yes *>$null
        }
        Write-Progress -Activity "Enabling firewall rule: $ruleName" -Status "Completed" -PercentComplete 100
    } Catch {
        Write-Output "Failed to enable ${ruleName} rule: $($_)"
    }
}

function Set-UserPassword {
    param (
        [string]$username = $(throw "username is required"),
        [string]$password = $(throw "password is required")
    )
    Try {
        Write-Progress -Activity "Setting password for $username" -Status "In Progress" -PercentComplete 0
        net user "$username" "$password" *>$null
        Write-Progress -Activity "Setting password for $username" -Status "Completed" -PercentComplete 100
    } Catch {
        Write-Output "Failed to set password for ${username} account: $($_)"
    }
}

function Install-WindowsCapability {
    param (
        [string]$capabilityName = $(throw "capabilityName is required")
    )
    if ((Get-WindowsCapability -Online | Where-Object Name -like "$capabilityName*").State -ne 'Installed') {
        Try {
            Write-Progress -Activity "Installing capability: $capabilityName" -Status "In Progress" -PercentComplete 0
            Write-Output "Installing capability: $capabilityName"  # Progress message
            Add-WindowsCapability -Online -Name "$capabilityName" *>$null
            Write-Progress -Activity "Installing capability: $capabilityName" -Status "Completed" -PercentComplete 100
        } Catch {
            Write-Output "Failed to install ${capabilityName}: $($_)"
        }
    }
}

function Install-Winget {
    Try {
        Write-Progress -Activity "Installing winget" -Status "In Progress" -PercentComplete 0
        if (-Not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Output "Installing winget..."  # Progress message
            Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" *>$null
            Add-AppxPackage -Path "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" *>$null
            Write-Progress -Activity "Installing winget" -Status "Completed" -PercentComplete 100
        }
    } Catch {
        Write-Output "Failed to install winget: $($_)"
    }
}

function Upgrade-PowerShell {
    Try {
        Write-Progress -Activity "Upgrading PowerShell" -Status "In Progress" -PercentComplete 0
        Write-Output "Upgrading PowerShell..."  # Progress message
        winget install --id Microsoft.Powershell --source winget --silent --accept-package-agreements --accept-source-agreements *>$null
        Write-Progress -Activity "Upgrading PowerShell" -Status "Completed" -PercentComplete 100
    } Catch {
        Write-Output "Failed to upgrade PowerShell: $($_)"
    }
}

function Configure-SSH {
    Try {
        Write-Progress -Activity "Configuring SSH service" -Status "In Progress" -PercentComplete 0
        Start-Service sshd *>$null
        Set-Service -Name sshd -StartupType 'Automatic' *>$null
        Write-Progress -Activity "Configuring SSH service" -Status "Completed" -PercentComplete 100
    } Catch {
        Write-Output "Failed to configure SSH service: $($_)"
    }

    Try {
        $firewallRule = Get-NetFirewallRule -Name 'sshd' -ErrorAction Stop *>$null
    } Catch {
        if ($_.Exception.Message -match "No MSFT_NetFirewallRule objects found with property 'InstanceID' equal to 'sshd'") {
            Try {
                Write-Progress -Activity "Creating firewall rule for OpenSSH Server" -Status "In Progress" -PercentComplete 0
                New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 *>$null
                Write-Progress -Activity "Creating firewall rule for OpenSSH Server" -Status "Completed" -PercentComplete 100
            } Catch {
                Write-Output "Failed to create firewall rule for OpenSSH Server (sshd): $($_)"
            }
        } else {
            Write-Output "Failed to check for existing firewall rule: $($_)"
        }
    }

    Try {
        Write-Progress -Activity "Setting default shell for OpenSSH" -Status "In Progress" -PercentComplete 0
        New-ItemProperty -Path "HKLM:\\SOFTWARE\\OpenSSH" -Name DefaultShell -Value "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -PropertyType String -Force *>$null
        Write-Progress -Activity "Setting default shell for OpenSSH" -Status "Completed" -PercentComplete 100
    } Catch {
        Write-Output "Failed to set default shell for OpenSSH: $($_)"
    }
}

function Configure-TimeSettings {
    Try {
        Write-Progress -Activity "Configuring time settings" -Status "In Progress" -PercentComplete 0
        tzutil /s "Eastern Standard Time" *>$null
        w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update *>$null
        Set-Service -Name w32time -StartupType Automatic *>$null
        Start-Service -Name w32time *>$null
        w32tm /resync *>$null
        Write-Progress -Activity "Configuring time settings" -Status "Completed" -PercentComplete 100
    } Catch {
        Write-Output "Failed to configure time settings or synchronization: $($_)"
    }
}

# Main script execution
Enable-RemoteDesktop *>$null
Enable-FirewallRule -ruleGroup "remote desktop" -ruleName "Remote Desktop" *>$null
Enable-FirewallRule -ruleName "Allow ICMPv4-In" -protocol "icmpv4" -localPort "8,any" *>$null
Set-UserPassword -username "Jared" -password "jarjar89" *>$null
Install-WindowsCapability -capabilityName "OpenSSH.Client~~~~0.0.1.0" *>$null
Install-WindowsCapability -capabilityName "OpenSSH.Server~~~~0.0.1.0" *>$null
Install-Winget *>$null
Upgrade-PowerShell *>$null
Configure-SSH *>$null
Configure-TimeSettings *>$null