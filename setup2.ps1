function Enable-RemoteDesktop {
    Try {
        New-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" -Name fDenyTSConnections -Value 0 -PropertyType DWORD -Force *>$null
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
            netsh advfirewall firewall add rule name="$ruleName" protocol="$protocol" dir=in action=allow *>$null
        } else {
            netsh advfirewall firewall set rule group="$ruleGroup" new enable=Yes *>$null
        }
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
        net user "$username" "$password" *>$null
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
            Add-WindowsCapability -Online -Name "$capabilityName" *>$null
        } Catch {
            Write-Output "Failed to install ${capabilityName}: $($_)"
        }
    }
}

function Install-Winget {
    Try {
        if (-Not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" *>$null
            Add-AppxPackage -Path "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" *>$null
        }
    } Catch {
        Write-Output "Failed to install winget: $($_)"
    }
}

function Upgrade-PowerShell {
    Try {
        winget install --id Microsoft.Powershell --source winget --silent --accept-package-agreements --accept-source-agreements *>$null
    } Catch {
        Write-Output "Failed to upgrade PowerShell: $($_)"
    }
}

function Configure-SSH {
    Try {
        Start-Service sshd *>$null
        Set-Service -Name sshd -StartupType 'Automatic' *>$null
    } Catch {
        Write-Output "Failed to configure SSH service: $($_)"
    }

    Try {
        $firewallRule = Get-NetFirewallRule -Name 'sshd' -ErrorAction Stop *>$null
    } Catch {
        if ($_.Exception.Message -match "No MSFT_NetFirewallRule objects found with property 'InstanceID' equal to 'sshd'") {
            Try {
                New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 *>$null
            } Catch {
                Write-Output "Failed to create firewall rule for OpenSSH Server (sshd): $($_)"
            }
        } else {
            Write-Output "Failed to check for existing firewall rule: $($_)"
        }
    }

    Try {
        New-ItemProperty -Path "HKLM:\\SOFTWARE\\OpenSSH" -Name DefaultShell -Value "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -PropertyType String -Force *>$null
    } Catch {
        Write-Output "Failed to set default shell for OpenSSH: $($_)"
    }
}

function Configure-TimeSettings {
    Try {
        tzutil /s "Eastern Standard Time" *>$null
        w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update *>$null
        Set-Service -Name w32time -StartupType Automatic *>$null
        Start-Service -Name w32time *>$null
        w32tm /resync *>$null
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
