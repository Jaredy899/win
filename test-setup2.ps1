# Function to change the password of the currently logged-in user
function Set-UserPassword {
    param (
        [string]$password
    )
    $username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]
    Try {
        Write-Output "Attempting to change the password for $username..."
        net user "$username" "$password" *>$null
        Write-Output "Password for ${username} account set successfully."
    } Catch {
        Write-Output "Failed to set password for ${username} account: $($_)"
    }
}

# Ask if the user wants to change the password
$changePassword = Read-Host "Do you want to change your password? (yes/y/enter for yes, no/n for no)"
if ($changePassword -eq "yes" -or $changePassword -eq "y" -or [string]::IsNullOrEmpty($changePassword)) {
    $password = Read-Host "Enter the new password"
    Set-UserPassword -password $password
} else {
    Write-Output "Password change was not performed."
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
        [string]$capabilityName,
        [string]$cabUrl,
        [string]$cabPath
    )

    # Download OpenSSH .cab file if not already installed
    if ((Get-WindowsCapability -Online | Where-Object Name -like "$capabilityName*").State -ne 'Installed') {
        Write-Output "Downloading $capabilityName package from GitHub..."
        Start-BitsTransfer -Source $cabUrl -Destination $cabPath -ErrorAction Stop
        Write-Output "$capabilityName package downloaded successfully."

        Write-Output "Installing $capabilityName from .cab file..."
        Add-WindowsCapability -Online -Name "$capabilityName" -Source $cabPath -LimitAccess -ErrorAction Stop
        Write-Output "$capabilityName installed successfully from .cab file."
    } else {
        Write-Output "$capabilityName is already installed."
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
        # Display options for time zones
        Write-Output "Select a time zone from the options below:"
        $timeZones = @(
            "Eastern Standard Time",
            "Central Standard Time",
            "Mountain Standard Time",
            "Pacific Standard Time",
            "Greenwich Standard Time",
            "UTC",
            "Hawaiian Standard Time",
            "Alaskan Standard Time"
        )
        
        # Display the list of options
        for ($i = 0; $i -lt $timeZones.Count; $i++) {
            Write-Output "$($i + 1). $($timeZones[$i])"
        }

        # Prompt the user to select a time zone
        $selection = Read-Host "Enter the number corresponding to your time zone"

        # Validate input and set the time zone
        if ($selection -match '^\d+$' -and $selection -gt 0 -and $selection -le $timeZones.Count) {
            $selectedTimeZone = $timeZones[$selection - 1]
            tzutil /s "$selectedTimeZone" *>$null
            Write-Output "Time zone set to $selectedTimeZone."
        } else {
            Write-Output "Invalid selection. Please run the script again and choose a valid number."
            return
        }

        # Configure the time synchronization settings
        w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update *>$null
        Set-Service -Name w32time -StartupType Automatic *>$null
        Start-Service -Name w32time *>$null
        w32tm /resync *>$null

        Write-Output "Time settings configured and synchronized to $selectedTimeZone."
    } Catch {
        Write-Output "Failed to configure time settings or synchronization: $($_)"
    }
}

# Main function to execute all tasks
function Main {
    Configure-TimeSettings
    Enable-RemoteDesktop
    Enable-FirewallRule -ruleGroup "remote desktop" -ruleName "Remote Desktop"
    Enable-FirewallRule -ruleName "Allow ICMPv4-In" -protocol "icmpv4" -localPort "8,any"
    
    # URLs and paths for OpenSSH .cab files
    $sshClientCabUrl = "https://github.com/Jaredy899/win/raw/main/OpenSSH/OpenSSH-Client-Package~31bf3856ad364e35~amd64~~.cab"
    $sshServerCabUrl = "https://github.com/Jaredy899/win/raw/main/OpenSSH/OpenSSH-Server-Package~31bf3856ad364e35~amd64~~.cab"
    $sshClientCabPath = "$env:TEMP\OpenSSH-Client-Package~31bf3856ad364e35~amd64~~.cab"
    $sshServerCabPath = "$env:TEMP\OpenSSH-Server-Package~31bf3856ad364e35~amd64~~.cab"

    Install-WindowsCapability -capabilityName "OpenSSH.Client~~~~0.0.1.0" -cabUrl $sshClientCabUrl -cabPath $sshClientCabPath
    Install-WindowsCapability -capabilityName "OpenSSH.Server~~~~0.0.1.0" -cabUrl $sshServerCabUrl -cabPath $sshServerCabPath

    Configure-SSH

    Write-Output "##########################################################"
    Write-Output "#                                                        #"
    Write-Output "#     EVERYTHING SUCCESSFULLY INSTALLED AND ENABLED      #"
    Write-Output "#                                                        #"
    Write-Output "##########################################################"
}

# Execute the main function
Main