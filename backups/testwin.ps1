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

function Set-UserPassword {
    param (
        [string]$username,
        [string]$password
    )
    Try {
        net user "$username" "$password" *>$null
        Write-Output "Password for ${username} account set."
    } Catch {
        Write-Output "Failed to set password for ${username} account: $($_)"
    }
}

function Main {
    Ensure-Elevation

    $changeUser = Read-Host "Do you want to change the username and password? (y/n)"
    if ($changeUser -eq "y") {
        $username = Read-Host "Enter the new username"
        $password = Read-Host "Enter the new password"
        Set-UserPassword -username $username -password $password
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

# SIG # Begin signature block
# MIIb8gYJKoZIhvcNAQcCoIIb4zCCG98CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBD8R66xVlZIAxc
# A3WFN4uf++JoclTNPGxDNy72O2Fn/KCCFjEwggMqMIICEqADAgECAhActY9oOxGl
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
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCA0
# L8FTDsB9OACxW1UdUlAckppzkfnpqq6J9oWeYuAEUTANBgkqhkiG9w0BAQEFAASC
# AQCB/9xkotyLdsAnfs9QTR911zkz19cqyO6JgOZnGPet2QL9i2dyUYsfa6ScJzI6
# 8W4pdtoUxOq/ZSmpEYJuGLyXItHS+roOvwIxdLcP/MtDSGbMTyJ2lUyH0oaK4CPe
# JvYGgOvmro5Ij6lmp3XiFe+EQE6NX67elVc+M/hn4pt74LfPl/ovkDJ+S1ZXV/qI
# 3iwkUeJEoKEwb0svQCrv8JfGp9Sn1MG1Mj88g3ClVfZlp7Q4/3fP0y5AFpEfH6/T
# 4+n2VmePW8gLvW/wUr6csEE7YN4I8i7mX/6d8Lg0Jjneng119z97lwFKKKQlCbYC
# 89SNlg8R0/ggmbnM5HYUDd1yoYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEB
# MHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYD
# VQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFt
# cGluZyBDQQIQC65mvFq6f5WHxvnpBOMzBDANBglghkgBZQMEAgEFAKBpMBgGCSqG
# SIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MDMyODIxNTA1
# NVowLwYJKoZIhvcNAQkEMSIEII6RRsmXCr6eJuEIK0tmAKblZCKmmg6UgMJL3RCU
# y6qzMA0GCSqGSIb3DQEBAQUABIICAH7QNifFTRs9uP0TLtBvKx0UhQxC9//XftHJ
# tupN3KkEZx/fzMAaXWfJfKJaxoIRiwVC+qycG8t8K38EEh9wVyH2VX26rquhly5s
# aSF5ICthR7HN8S/2x3aRFS95E9dd+fqCzK+v4cC9VLOvWxubWzrjLMnncQl+FWBX
# bATEzUvdsaRjKECCH65E7KjocxCn8zBhRzgYdSOUAdkpZXS70u7r9dM7zWKqXJf7
# QC9U2i/DVyLHvGv1IfZj8U1vnGKNhWSbORvgX3u8t27ya0QbkTCHRj3N0kymLpIU
# C5GOVj2XUkxgHZiuOLZW95MlpcmjIEnotHEvOKebeqadspg/nQZ8sQpOBIMPJ5Wd
# bFFF0vYjKdbjuuthWG1+2G5C4UD4n1YWltwJ5lNywhg5vxEtDF+MRAizc1BJAYin
# BI9bS7mIf5R+f3fnBYeRNI6b9/fyHdeFgmfOouv574rQw6nhh600cPzZo17t/AEG
# JNP0WPQXy5bgeLHtTJCEzq8GLgjHoPfdfqiglCgO1lGxBuJEwgmY5ICsLWMUT4n3
# AbikSxZyjo1YdiY5wemUZ534i+Biy+RazNeK+uZlHbd2UegFU7aveA845Kc4oBTG
# Pvbe2omxfP2aXKT5JnHTva38cpE0H4mSiNe9DriNnSTFqLiZxWKL97eG5JR0vurZ
# 2mVx7m1u
# SIG # End signature block
