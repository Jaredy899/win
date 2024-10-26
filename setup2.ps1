# Function to change the password of the currently logged-in user
function Set-UserPassword {
    param (
        [SecureString]$password
    )
    $username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]
    Try {
        Write-Output "Attempting to change the password for $username..."
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        net user "$username" "$plainPassword" *>$null
        Write-Output "Password for ${username} account set successfully."
    } Catch {
        Write-Output "Failed to set password for ${username} account: $($_)"
    }
}

# Ask if the user wants to change the password
$changePassword = Read-Host "Do you want to change your password? (yes/y/enter for yes, no/n for no)"
if ($changePassword -eq "yes" -or $changePassword -eq "y" -or [string]::IsNullOrEmpty($changePassword)) {
    $passwordsMatch = $false
    while (-not $passwordsMatch) {
        $password1 = Read-Host "Enter the new password" -AsSecureString
        $password2 = Read-Host "Confirm the new password" -AsSecureString

        # Convert SecureString to plain text for comparison
        $BSTR1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1)
        $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2)
        $plainPassword1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR1)
        $plainPassword2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)

        # Compare passwords
        if ($plainPassword1 -eq $plainPassword2) {
            $passwordsMatch = $true
            Set-UserPassword -password $password1
            Write-Output "Password changed successfully."
        } else {
            Write-Output "Passwords do not match. Please try again or press Ctrl+C to cancel."
        }

        # Clear the plain text passwords from memory
        $plainPassword1 = $plainPassword2 = $null
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR1)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR2)
    }
} else {
    Write-Output "Password change was not performed."
}

function Set-RemoteDesktop {
    Try {
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0 -PropertyType DWORD -Force *>$null
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

function Set-SSHConfiguration {
    Try {
        Start-Service sshd *>$null
        Set-Service -Name sshd -StartupType 'Automatic' *>$null
        Write-Output "SSH service started and set to start automatically."
    } Catch {
        Write-Output "Failed to configure SSH service: $($_)"
    }

    Try {
        $firewallRuleExists = Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue
        if ($null -eq $firewallRuleExists) {
            Try {
                New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 *>$null
                Write-Output "Firewall rule for OpenSSH Server (sshd) created successfully."
            } Catch {
                Write-Output "Failed to create firewall rule for OpenSSH Server (sshd): $($_)"
            }
        } else {
            Write-Output "Firewall rule for OpenSSH Server (sshd) already exists."
        }
    } Catch {
        Write-Output "Failed to check for existing firewall rule: $($_)"
    }

    Try {
        New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force *>$null
        Write-Output "Default shell for OpenSSH set to PowerShell 7."
    } Catch {
        Write-Output "Failed to set default shell for OpenSSH: $($_)"
    }
}

function Set-TimeSettings {
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

        # Configure the time synchronization settings using time.nist.gov
        w32tm /config /manualpeerlist:"time.nist.gov,0x1" /syncfromflags:manual /reliable:YES /update *>$null
        Set-Service -Name w32time -StartupType Automatic *>$null
        Start-Service -Name w32time *>$null
        w32tm /resync *>$null

        Write-Output "Time settings configured and synchronized to $selectedTimeZone using time.nist.gov."
    } Catch {
        Write-Output "Failed to configure time settings or synchronization: $($_)"
    }
}

# Function to create a scheduled task for time synchronization at startup
function Set-TimeSyncAtStartup {
    Try {
        $taskName = "TimeSyncAtStartup"
        $action = New-ScheduledTaskAction -Execute "w32tm.exe" -Argument "/resync"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        # Check if the task already exists
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }

        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal
        Write-Output "Scheduled task for time synchronization at startup has been created."
    } Catch {
        Write-Output "Failed to create scheduled task for time synchronization: $($_)"
    }
}

function Disable-WindowsRecall {
    Try {
        DISM /Online /Disable-Feature /FeatureName:Recall *>$null
        Write-Output "Windows Recall feature has been disabled."
    } Catch {
        Write-Output "Failed to disable Windows Recall feature: $($_)"
    }
}

function Delete-EdgeShortcut {
    # Get the path to the current user's desktop
    $desktopPath = [Environment]::GetFolderPath("Desktop")

    # Define the name of the Edge shortcut
    $edgeShortcutName = "Microsoft Edge.lnk"

    # Construct the full path to the Edge shortcut
    $edgeShortcutPath = Join-Path -Path $desktopPath -ChildPath $edgeShortcutName

    # Check if the shortcut exists
    if (Test-Path $edgeShortcutPath) {
        # If it exists, delete the shortcut
        Remove-Item -Path $edgeShortcutPath -Force
        Write-Output "Microsoft Edge shortcut has been deleted from the desktop."
    } else {
        # If it doesn't exist, inform the user
        Write-Output "Microsoft Edge shortcut was not found on the desktop."
    }
}

# Main function to execute all tasks
function Main {
    Set-TimeSettings
    Set-RemoteDesktop
    Enable-FirewallRule -ruleGroup "remote desktop" -ruleName "Remote Desktop"
    Enable-FirewallRule -ruleName "Allow ICMPv4-In" -protocol "icmpv4" -localPort "8,any"
    Install-WindowsCapability -capabilityName "OpenSSH.Client~~~~0.0.1.0"
    Install-WindowsCapability -capabilityName "OpenSSH.Server~~~~0.0.1.0"
    Set-SSHConfiguration
    Set-TimeSyncAtStartup
    Disable-WindowsRecall
    Delete-EdgeShortcut

    Write-Output "##########################################################"
    Write-Output "#                                                        #"
    Write-Output "#     EVERYTHING SUCCESSFULLY INSTALLED AND ENABLED      #"
    Write-Output "#                                                        #"
    Write-Output "##########################################################"
}

# Execute the main function
Main
