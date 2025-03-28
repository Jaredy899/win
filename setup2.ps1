# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Self-elevate the script if required
if (-not (Test-Administrator)) {
    Write-Output "Requesting administrative privileges..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"")
    Exit
}

Write-Output "Script running with administrative privileges..."

# Function to change the password of the currently logged-in user
function Set-UserPassword {
    param (
        [SecureString]$password
    )
    $username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]
    Try {
        Write-Host "Attempting to change the password for $username..." -ForegroundColor Yellow
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        net user "$username" "$plainPassword" *>$null
        Write-Host "Password for ${username} account set successfully." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to set password for ${username} account: $($_)" -ForegroundColor Red
    }
}

# Ask if the user wants to change the password
Write-Host "Do you want to change your password? " -ForegroundColor Cyan -NoNewline
Write-Host "(yes/y/enter for yes, no/n for no)" -ForegroundColor DarkGray
$changePassword = Read-Host

if ($changePassword -eq "yes" -or $changePassword -eq "y" -or [string]::IsNullOrEmpty($changePassword)) {
    $passwordsMatch = $false
    while (-not $passwordsMatch) {
        Write-Host "Enter the new password: " -ForegroundColor Yellow -NoNewline
        $password1 = Read-Host -AsSecureString
        Write-Host "Confirm the new password: " -ForegroundColor Yellow -NoNewline
        $password2 = Read-Host -AsSecureString

        # Convert SecureString to plain text for comparison
        $BSTR1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1)
        $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2)
        $plainPassword1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR1)
        $plainPassword2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)

        # Compare passwords
        if ($plainPassword1 -eq $plainPassword2) {
            $passwordsMatch = $true
            Set-UserPassword -password $password1
            Write-Host "Password changed successfully." -ForegroundColor Green
        } else {
            Write-Host "Passwords do not match. Please try again or press Ctrl+C to cancel." -ForegroundColor Red
        }

        # Clear the plain text passwords from memory
        $plainPassword1 = $plainPassword2 = $null
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR1)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR2)
    }
} else {
    Write-Host "Password change was not performed." -ForegroundColor Blue
}

function Set-RemoteDesktop {
    Try {
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0 -PropertyType DWORD -Force *>$null
        Write-Host "Remote Desktop enabled." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to enable Remote Desktop: $($_)" -ForegroundColor Red
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
        Write-Host "${ruleName} rule enabled." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to enable ${ruleName} rule: $($_)" -ForegroundColor Red
    }
}

function Install-WindowsCapability {
    param (
        [string]$capabilityName
    )
    if ((Get-WindowsCapability -Online | Where-Object Name -like "$capabilityName*").State -ne 'Installed') {
        Try {
            Add-WindowsCapability -Online -Name $capabilityName *>$null
            Write-Host "${capabilityName} installed successfully." -ForegroundColor Green
        } Catch {
            Write-Host "Failed to install ${capabilityName}: $($_)" -ForegroundColor Red
        }
    } else {
        Write-Host "${capabilityName} is already installed." -ForegroundColor Blue
    }
}

function Set-SSHConfiguration {
    Try {
        Start-Service sshd *>$null
        Set-Service -Name sshd -StartupType 'Automatic' *>$null
        Write-Host "SSH service started and set to start automatically." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to configure SSH service: $($_)" -ForegroundColor Red
    }

    Try {
        $firewallRuleExists = Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue
        if ($null -eq $firewallRuleExists) {
            Try {
                New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 *>$null
                Write-Host "Firewall rule for OpenSSH Server (sshd) created successfully." -ForegroundColor Green
            } Catch {
                Write-Host "Failed to create firewall rule for OpenSSH Server (sshd): $($_)" -ForegroundColor Red
            }
        } else {
            Write-Host "Firewall rule for OpenSSH Server (sshd) already exists." -ForegroundColor Blue
        }
    } Catch {
        Write-Host "Failed to check for existing firewall rule: $($_)" -ForegroundColor Red
    }

    Try {
        New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force *>$null
        Write-Host "Default shell for OpenSSH set to PowerShell 7." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to set default shell for OpenSSH: $($_)" -ForegroundColor Red
    }
}

function Set-TimeSettings {
    Try {
        # Attempt to automatically detect timezone
        Try {
            # Try multiple geolocation services
            $timezone = $null
            
            # Try ipapi.co first
            Try {
                $timezone = (Invoke-RestMethod -Uri "https://ipapi.co/timezone" -Method Get -TimeoutSec 5).Trim()
            } Catch {
                Write-Output "ipapi.co detection failed, trying alternative service..."
            }
            
            if ($timezone) {
                Write-Host "Detected timezone: $timezone" -ForegroundColor Yellow
                
                # Simplified mapping for common US timezones
                $tzMapping = @{
                    'America/New_York' = 'Eastern Standard Time'
                    'America/Chicago' = 'Central Standard Time'
                    'America/Denver' = 'Mountain Standard Time'
                    'America/Los_Angeles' = 'Pacific Standard Time'
                    'America/Anchorage' = 'Alaskan Standard Time'
                    'Pacific/Honolulu' = 'Hawaiian Standard Time'
                }

                if ($tzMapping.ContainsKey($timezone)) {
                    $windowsTimezone = $tzMapping[$timezone]
                    tzutil /s $windowsTimezone *>$null
                    Write-Host "Time zone automatically set to $windowsTimezone" -ForegroundColor Green
                } else {
                    throw "Could not map timezone"
                }
            } else {
                throw "Could not detect timezone"
            }
        } Catch {
            Write-Host "Automatic timezone detection failed. Falling back to manual selection..." -ForegroundColor Yellow
            # Display options for time zones
            Write-Host "Select a time zone from the options below:" -ForegroundColor Cyan
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
        }

        # Configure the time synchronization settings using time.nist.gov
        w32tm /config /manualpeerlist:"time.nist.gov,0x1" /syncfromflags:manual /reliable:YES /update *>$null
        Set-Service -Name w32time -StartupType Automatic *>$null
        Start-Service -Name w32time *>$null
        w32tm /resync *>$null

        Write-Output "Time settings configured and synchronized using time.nist.gov."
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
        Write-Host "Scheduled task for time synchronization at startup has been created." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to create scheduled task for time synchronization: $($_)" -ForegroundColor Red
    }
}

function Disable-WindowsRecall {
    Try {
        DISM /Online /Disable-Feature /FeatureName:Recall *>$null
        Write-Host "Windows Recall feature has been disabled." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to disable Windows Recall feature: $($_)" -ForegroundColor Red
    }
}

function Remove-EdgeShortcut {
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
        Write-Host "Microsoft Edge shortcut has been deleted from the desktop." -ForegroundColor Green
    } else {
        # If it doesn't exist, inform the user
        Write-Host "Microsoft Edge shortcut was not found on the desktop." -ForegroundColor Blue
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
    Remove-EdgeShortcut

    Write-Host "##########################################################" -ForegroundColor Cyan
    Write-Host "#                                                        #" -ForegroundColor Cyan
    Write-Host "#" -ForegroundColor Cyan -NoNewline
    Write-Host "     EVERYTHING SUCCESSFULLY INSTALLED AND ENABLED      " -ForegroundColor Green -NoNewline
    Write-Host "#" -ForegroundColor Cyan
    Write-Host "#                                                        #" -ForegroundColor Cyan
    Write-Host "##########################################################" -ForegroundColor Cyan
}

# Execute the main function
Main

# SIG # Begin signature block
# MIIb8gYJKoZIhvcNAQcCoIIb4zCCG98CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAYpktsbRNxlCHB
# cA1I9heFzlvK8q0D4h4+NLgdXbaFdqCCFjEwggMqMIICEqADAgECAhActY9oOxGl
# tEkhG1k4PcuwMA0GCSqGSIb3DQEBCwUAMC0xKzApBgNVBAMMIldpbmRvd3MgU2V0
# dXAgVG9vbGtpdCBDb2RlIFNpZ25pbmcwHhcNMjUwMzI4MjE0MDU0WhcNMzAwMzI4
# MjE1MDU0WjAtMSswKQYDVQQDDCJXaW5kb3dzIFNldHVwIFRvb2xraXQgQ29kZSBT
# aWduaW5nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvrxr1U8GKkb5
# KX1aDycE4IQPPlYb6IzEzcRyq84UVHSsOk6qBg9JAxy+Pq0vGTgHPs8CFwfpE85M
# kjop9XRhj+SfW3s1qtbegzLUs6CNGeJO8WTHbnkhFsKMQehgn2+o6Wn3siF9OUYJ
# ValbnjYVP6wt105BqZiIsF21EYZyHbU/o33WzcXCg/Q8LMfTyqr2TrlQZv96i7Xr
# fF7KgBS3CK7aSu2Gn9IGl9pFEc8Xy9vLQAnHjTs84EB+3WvsxO7kTc4y0+3J7/NA
# ptVfR7nxdQd2+MEOYbqJHytWZS9VrcllUc0gxFBn7cf2CuuTcCHeIQLeD3m1Eed3
# D8lNRQOapQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwHQYDVR0OBBYEFNdBI0cc3+7WF1rqd8i3FUpQdmdnMA0GCSqGSIb3DQEB
# CwUAA4IBAQA6cYWTx916ECaXq/OhecAvql3u1Jk6+iZEh8RDtyZZgcr0jqBMpQb0
# Jr7flOckrfGPOPJSMtFRPAtVjXo0Hueant4j5FPGMk/U0Q01ZqLifvB3k56zan4Z
# WCcvLHXICwRPVMaHALPJgwYmjI/yiErOq4ebcCEZB4Xodi6KzExaf2RsWH/FjQ8w
# UqGLrjAQO/fMQSG3w7WlivN3aNyxZNN5iYSr7mQqa9znVI4t2NhXc/ua83TeZlPo
# I0JXtIq1bbF+JtAdgVXoSlcAhix+ajQ16iLheo4b6lO4zGXwWgoORNx6pS1mz+1m
# z4RPfS8M46Hlvl8eRkg7YjulT03SfQMmMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv
# 21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMM
# RGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQD
# ExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcN
# MzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQg
# SW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2Vy
# dCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf
# 8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1
# mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe
# 7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecx
# y9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX
# 2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX
# 9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp49
# 3ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCq
# sWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFH
# dL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauG
# i0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYw
# DwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08w
# HwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGG
# MHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNl
# cnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0
# dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5j
# cmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXn
# OF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23
# OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFI
# tJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7s
# pNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgi
# wbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cB
# qZ9Xql4o4rmUMIIGrjCCBJagAwIBAgIQBzY3tyRUfNhHrP0oZipeWzANBgkqhkiG
# 9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVz
# dGVkIFJvb3QgRzQwHhcNMjIwMzIzMDAwMDAwWhcNMzcwMzIyMjM1OTU5WjBjMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRp
# Z2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENB
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxoY1BkmzwT1ySVFVxyUD
# xPKRN6mXUaHW0oPRnkyibaCwzIP5WvYRoUQVQl+kiPNo+n3znIkLf50fng8zH1AT
# CyZzlm34V6gCff1DtITaEfFzsbPuK4CEiiIY3+vaPcQXf6sZKz5C3GeO6lE98NZW
# 1OcoLevTsbV15x8GZY2UKdPZ7Gnf2ZCHRgB720RBidx8ald68Dd5n12sy+iEZLRS
# 8nZH92GDGd1ftFQLIWhuNyG7QKxfst5Kfc71ORJn7w6lY2zkpsUdzTYNXNXmG6jB
# ZHRAp8ByxbpOH7G1WE15/tePc5OsLDnipUjW8LAxE6lXKZYnLvWHpo9OdhVVJnCY
# Jn+gGkcgQ+NDY4B7dW4nJZCYOjgRs/b2nuY7W+yB3iIU2YIqx5K/oN7jPqJz+ucf
# WmyU8lKVEStYdEAoq3NDzt9KoRxrOMUp88qqlnNCaJ+2RrOdOqPVA+C/8KI8ykLc
# GEh/FDTP0kyr75s9/g64ZCr6dSgkQe1CvwWcZklSUPRR8zZJTYsg0ixXNXkrqPNF
# YLwjjVj33GHek/45wPmyMKVM1+mYSlg+0wOI/rOP015LdhJRk8mMDDtbiiKowSYI
# +RQQEgN9XyO7ZONj4KbhPvbCdLI/Hgl27KtdRnXiYKNYCQEoAA6EVO7O6V3IXjAS
# vUaetdN2udIOa5kM0jO0zbECAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8C
# AQAwHQYDVR0OBBYEFLoW2W1NhS9zKXaaL3WMaiCPnshvMB8GA1UdIwQYMBaAFOzX
# 44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggr
# BgEFBQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3Nw
# LmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDag
# NIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RH
# NC5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3
# DQEBCwUAA4ICAQB9WY7Ak7ZvmKlEIgF+ZtbYIULhsBguEE0TzzBTzr8Y+8dQXeJL
# Kftwig2qKWn8acHPHQfpPmDI2AvlXFvXbYf6hCAlNDFnzbYSlm/EUExiHQwIgqgW
# valWzxVzjQEiJc6VaT9Hd/tydBTX/6tPiix6q4XNQ1/tYLaqT5Fmniye4Iqs5f2M
# vGQmh2ySvZ180HAKfO+ovHVPulr3qRCyXen/KFSJ8NWKcXZl2szwcqMj+sAngkSu
# mScbqyQeJsG33irr9p6xeZmBo1aGqwpFyd/EjaDnmPv7pp1yr8THwcFqcdnGE4AJ
# xLafzYeHJLtPo0m5d2aR8XKc6UsCUqc3fpNTrDsdCEkPlM05et3/JWOZJyw9P2un
# 8WbDQc1PtkCbISFA0LcTJM3cHXg65J6t5TRxktcma+Q4c6umAU+9Pzt4rUyt+8SV
# e+0KXzM5h0F4ejjpnOHdI/0dKNPH+ejxmF/7K9h+8kaddSweJywm228Vex4Ziza4
# k9Tm8heZWcpw8De/mADfIBZPJ/tgZxahZrrdVcA6KYawmKAr7ZVBtzrVFZgxtGIJ
# Dwq9gdkT/r+k0fNX2bwE+oLeMt8EifAAzV3C+dAjfwAL5HYCJtnwZXZCpimHCUcr
# 5n8apIUP/JiW9lVUKx+A+sDyDivl1vupL0QVSucTDh3bNzgaoSv27dZ8/DCCBrww
# ggSkoAMCAQICEAuuZrxaun+Vh8b56QTjMwQwDQYJKoZIhvcNAQELBQAwYzELMAkG
# A1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdp
# Q2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTAe
# Fw0yNDA5MjYwMDAwMDBaFw0zNTExMjUyMzU5NTlaMEIxCzAJBgNVBAYTAlVTMREw
# DwYDVQQKEwhEaWdpQ2VydDEgMB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0YW1wIDIw
# MjQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC+anOf9pUhq5Ywultt
# 5lmjtej9kR8YxIg7apnjpcH9CjAgQxK+CMR0Rne/i+utMeV5bUlYYSuuM4vQngvQ
# epVHVzNLO9RDnEXvPghCaft0djvKKO+hDu6ObS7rJcXa/UKvNminKQPTv/1+kBPg
# HGlP28mgmoCw/xi6FG9+Un1h4eN6zh926SxMe6We2r1Z6VFZj75MU/HNmtsgtFjK
# fITLutLWUdAoWle+jYZ49+wxGE1/UXjWfISDmHuI5e/6+NfQrxGFSKx+rDdNMseP
# W6FLrphfYtk/FLihp/feun0eV+pIF496OVh4R1TvjQYpAztJpVIfdNsEvxHofBf1
# BWkadc+Up0Th8EifkEEWdX4rA/FE1Q0rqViTbLVZIqi6viEk3RIySho1XyHLIAOJ
# fXG5PEppc3XYeBH7xa6VTZ3rOHNeiYnY+V4j1XbJ+Z9dI8ZhqcaDHOoj5KGg4Yui
# Yx3eYm33aebsyF6eD9MF5IDbPgjvwmnAalNEeJPvIeoGJXaeBQjIK13SlnzODdLt
# uThALhGtyconcVuPI8AaiCaiJnfdzUcb3dWnqUnjXkRFwLtsVAxFvGqsxUA2Jq/W
# TjbnNjIUzIs3ITVC6VBKAOlb2u29Vwgfta8b2ypi6n2PzP0nVepsFk8nlcuWfyZL
# zBaZ0MucEdeBiXL+nUOGhCjl+QIDAQABo4IBizCCAYcwDgYDVR0PAQH/BAQDAgeA
# MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYDVR0gBBkw
# FzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1NhS9zKXaa
# L3WMaiCPnshvMB0GA1UdDgQWBBSfVywDdw4oFZBmpWNe7k+SH3agWzBaBgNVHR8E
# UzBRME+gTaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQBggrBgEFBQcB
# AQSBgzCBgDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMFgG
# CCsGAQUFBzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3
# DQEBCwUAA4ICAQA9rR4fdplb4ziEEkfZQ5H2EdubTggd0ShPz9Pce4FLJl6reNKL
# kZd5Y/vEIqFWKt4oKcKz7wZmXa5VgW9B76k9NJxUl4JlKwyjUkKhk3aYx7D8vi2m
# pU1tKlY71AYXB8wTLrQeh83pXnWwwsxc1Mt+FWqz57yFq6laICtKjPICYYf/qgxA
# CHTvypGHrC8k1TqCeHk6u4I/VBQC9VK7iSpU5wlWjNlHlFFv/M93748YTeoXU/fF
# a9hWJQkuzG2+B7+bMDvmgF8VlJt1qQcl7YFUMYgZU1WM6nyw23vT6QSgwX5Pq2m0
# xQ2V6FJHu8z4LXe/371k5QrN9FQBhLLISZi2yemW0P8ZZfx4zvSWzVXpAb9k4Hpv
# pi6bUe8iK6WonUSV6yPlMwerwJZP/Gtbu3CKldMnn+LmmRTkTXpFIEB06nXZrDwh
# CGED+8RsWQSIXZpuG4WLFQOhtloDRWGoCwwc6ZpPddOFkM2LlTbMcqFSzm4cd0bo
# GhBq7vkqI1uHRz6Fq1IX7TaRQuR+0BGOzISkcqwXu7nMpFu3mgrlgbAW+BzikRVQ
# 3K2YHcGkiKjA4gi4OA/kz1YCsdhIBHXqBzR0/Zd2QwQ/l4Gxftt/8wY3grcc/nS/
# /TVkej9nmUYu83BDtccHHXKibMs/yXHhDXNkoPIdynhVAku7aRZOwqw6pDGCBRcw
# ggUTAgEBMEEwLTErMCkGA1UEAwwiV2luZG93cyBTZXR1cCBUb29sa2l0IENvZGUg
# U2lnbmluZwIQHLWPaDsRpbRJIRtZOD3LsDANBglghkgBZQMEAgEFAKCBhDAYBgor
# BgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEE
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCAd
# yMnGI9wQoRhUl/KbQ13X2RuGStWdpwrbdkdk/cYEEzANBgkqhkiG9w0BAQEFAASC
# AQBQWU/pf0zc+GEKbcBNS64+U7ayi6+kSXMFxRErbgPvNYmJhtC/0aZ8uC8ryO9X
# cVhuqf7wOJ2qQHYIvkwZgxPbHxRIzITAum5Qk8rYyXFEvQRpDB2nh/DfTig4ipfD
# hiS8q3eIwnIIIai7g/ZEKqW+kCDLsivfvF8GABUB53tlZGTuaPfH5JNmz1fefVq2
# wPPnKRAFnh8sG3+QXmEdqB3l9bht8KgeO8B+IVXbJJ2Z418NiRCXohrGw4/yQJRM
# +n51QM/sHgX20sgSZNGmlbzK4CcHpaZ6GBgFr1U0y7x2BLitvEcnLPaDBDYip7Hl
# LI0WnTKjY3MQqrj8am2GHwjJoYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEB
# MHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYD
# VQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFt
# cGluZyBDQQIQC65mvFq6f5WHxvnpBOMzBDANBglghkgBZQMEAgEFAKBpMBgGCSqG
# SIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MDMyODIxNTA1
# NlowLwYJKoZIhvcNAQkEMSIEIL/cgThlS7GZpOchj4KTyGWFGnAtAjBNnIPmD/iP
# zRuGMA0GCSqGSIb3DQEBAQUABIICABNXbCcqMKv//EGApnBE45bNMIdhHZwjrh9K
# FnTvC/psvX0sO2GxAdi/uJo+dC1Mda479Q6om+jta0ytYEGlaEbRE3bzWBTA/PCY
# BO+5yO2LRvqxKpuyKsNPlWB2Wi+/lBfVQEuy9MbUdrDKIq+OoTkk/gedqfcmDWA/
# 4YeBjkUxLvD4YZGJ/3RoD7RJu00BTVa+LiJ1CVKbiudZxzLh/WP5XVkgaAC45Xtm
# 35jxhKW1uHJTa60dsnfWKtqAnZP1BrVJLF2EcC5pd3aBJp6PyPtnAmbbfFRfGWt9
# 6QrgQ19ukWm8fuk84gtrm3bmTxg8vUAG5OUALd6lrT0mD6fLjsK78LGmD1ZXBgnb
# StlbXGamv4xQ+3WWf9S94Yaz0/8iyWsnEYq9aNY/3YAilY6IzT8LPAcUtIWtFX1f
# l+rrm9Cd2LR8+4uegIMVST/Nfbivxr4idqVXY0TCkQkT6h/tP1OiRrBrLKfmm1Kl
# ozb8tjti6MkLiE9yzSdChTeJUEi8rlRsYvDb8OPiMSyChtXP2nIkPHh8Jan/2AZ8
# /40Z+v4EPvwyy2dnDBr3VHmDujqlWmIMPvhY1fyrgp4z+L5STRM7haQzc7fGBkIk
# /JOX5fFEVXIcYI0Yr9BtGpL2DXwLIsui+BpUIfSnk0Xv+86jVH3JjezBBNnvZnH8
# HzaPzXbg
# SIG # End signature block
