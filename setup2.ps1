function Ensure-Elevation {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Output "Please run this script as an administrator."
        exit
    }
}

function Enable-RemoteDesktop {
    Try {
        New-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" -Name fDenyTSConnections -Value 0 -PropertyType DWORD -Force *>$null
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
            netsh advfirewall firewall add rule name="$ruleName" protocol="$protocol" dir=in action=allow *>$null
        } else {
            netsh advfirewall firewall set rule group="$ruleGroup" new enable=Yes *>$null
        }
        Write-Output "${ruleName} rule enabled."
    } Catch {
        Write-Output "Failed to enable ${ruleName} rule: $($_)"
    }
}

function Install-WindowsCapability {
    param (
        [string]$capabilityName
    )
    if ((Get-WindowsCapability -Online | Where-Object Name -like "$capabilityName*").State -ne 'Installed') {
        Try {
            Add-WindowsCapability -Online -Name "$capabilityName" *>$null
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
        Start-Service sshd *>$null
        Set-Service -Name sshd -StartupType 'Automatic' *>$null
        Write-Output "SSH service started and set to start automatically."
    } Catch {
        Write-Output "Failed to configure SSH service: $($_)"
    }

    Try {
        $firewallRule = Get-NetFirewallRule -Name 'sshd' -ErrorAction Stop *>$null
        Write-Output "Firewall rule for OpenSSH Server (sshd) already exists."
    } Catch {
        if ($_.Exception.Message -match "No MSFT_NetFirewallRule objects found with property 'InstanceID' equal to 'sshd'") {
            Try {
                New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 *>$null
                Write-Output "Firewall rule for OpenSSH Server (sshd) created successfully."
            } Catch {
                Write-Output "Failed to create firewall rule for OpenSSH Server (sshd): $($_)"
            }
        } else {
            Write-Output "Failed to check for existing firewall rule: $($_)"
        }
    }

    Try {
        New-ItemProperty -Path "HKLM:\\SOFTWARE\\OpenSSH" -Name DefaultShell -Value "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -PropertyType String -Force *>$null
        Write-Output "Default shell for OpenSSH set to PowerShell 7."
    } Catch {
        Write-Output "Failed to set default shell for OpenSSH: $($_)"
    }
}

function Configure-TimeSettings {
    Try {
        $currentTimeZone = (Get-TimeZone).Id
        tzutil /s "$currentTimeZone" *>$null
        w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update *>$null
        Set-Service -Name w32time -StartupType Automatic *>$null
        Start-Service -Name w32time *>$null
        w32tm /resync *>$null
        Write-Output "Time settings configured and synchronized to $currentTimeZone."
    } Catch {
        Write-Output "Failed to configure time settings or synchronization: $($_)"
    }
}

# Function to change the user password
function Set-UserPassword {
    param (
        [string]$username,
        [string]$password
    )
    Try {
        Write-Output "Attempting to change the password for $username..."
        net user "$username" "$password" *>$null
        Write-Output "Password for ${username} account set successfully."
    } Catch {
        Write-Output "Failed to set password for ${username} account: $($_)"
    }
}

# Ask if the user wants to change the password
$changePassword = Read-Host "Do you want to change the user password? (yes/y/enter for yes, no/n for no)"
if ($changePassword -eq "yes" -or $changePassword -eq "y" -or [string]::IsNullOrEmpty($changePassword)) {
    $username = Read-Host "Enter the username"
    $password = Read-Host "Enter the new password"
    Set-UserPassword -username $username -password $password
} else {
    Write-Output "Password change was not performed."
}


    Configure-TimeSettings

    Enable-RemoteDesktop
    Enable-FirewallRule -ruleGroup "remote desktop" -ruleName "Remote Desktop"
    Enable-FirewallRule -ruleName "Allow ICMPv4-In" -protocol "icmpv4" -localPort "8,any"
    Install-WindowsCapability -capabilityName "OpenSSH.Client~~~~0.0.1.0"
    Install-WindowsCapability -capabilityName "OpenSSH.Server~~~~0.0.1.0"
    Configure-SSH

    Write-Output "##########################################################"
    Write-Output "#                                                        #"
    Write-Output "#     EVERYTHING SUCCESSFULLY INSTALLED AND ENABLED      #"
    Write-Output "#                                                        #"
    Write-Output "##########################################################"
}

# Execute the main function
Main
