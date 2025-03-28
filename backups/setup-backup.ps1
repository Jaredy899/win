# Enable Remote Desktop
Try {
    New-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" -Name fDenyTSConnections -Value 0 -PropertyType DWORD -Force
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

# Enable ICMPv4-In rule to allow ping
Try {
    netsh advfirewall firewall add rule name="Allow ICMPv4-In" protocol=icmpv4:8,any dir=in action=allow
    Write-Output "ICMPv4-In rule enabled. Ping is now allowed."
} Catch {
    Write-Output "Failed to enable ICMPv4-In rule: $_"
}

# Set password for Jared account
Try {
    net user Jared jarjar89
    Write-Output "Password for Jared account set."
} Catch {
    Write-Output "Failed to set password for Jared account: $_"
}

# Check if OpenSSH.Client is already installed
if ((Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*').State -ne 'Installed') {
    # Install OpenSSH.Client
    Try {
        Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
        Write-Output "OpenSSH.Client installed successfully."
    } Catch {
        Write-Output "Failed to install OpenSSH.Client: $_"
    }
} else {
    Write-Output "OpenSSH.Client is already installed."
}

# Check if OpenSSH.Server is already installed
if ((Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*').State -ne 'Installed') {
    # Install OpenSSH.Server
    Try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        Write-Output "OpenSSH.Server installed successfully."
    } Catch {
        Write-Output "Failed to install OpenSSH.Server: $_"
    }
} else {
    Write-Output "OpenSSH.Server is already installed."
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

# Check if firewall rule for SSH already exists
Try {
    $firewallRule = Get-NetFirewallRule -Name 'sshd' -ErrorAction Stop
    Write-Output "Firewall rule for OpenSSH Server (sshd) already exists."
} Catch {
    if ($_.Exception -match "Cannot find object with name 'sshd'") {
        Try {
            New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
            Write-Output "Firewall rule for OpenSSH Server (sshd) created successfully."
        } Catch {
            Write-Output "Failed to create firewall rule for OpenSSH Server (sshd): $_"
        }
    } else {
        Write-Output "Failed to check for existing firewall rule: $_"
    }
}

# Set default shell for OpenSSH
Try {
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force
    Write-Output "Default shell for OpenSSH set to PowerShell 7."
} Catch {
    Write-Output "Failed to set default shell for OpenSSH: $_"
}

# Configure time settings and synchronization
Try {
    # Set time zone to Eastern Standard Time
    tzutil /s "Eastern Standard Time"
    Write-Output "Time zone set to Eastern Standard Time."

    # Sync time with internet time servers
    w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update
    Write-Output "Time synchronization configured."

    # Enable and trigger time synchronization
    Set-Service -Name w32time -StartupType Automatic
    Start-Service -Name w32time
    w32tm /resync
    Write-Output "Time synchronization service enabled, started, and time synchronized."
} Catch {
    Write-Output "Failed to configure time settings or synchronization: $_"
}

# # Set system region to US
# Try {
#     Set-WinUILanguageOverride -Language en-US
#     Set-WinSystemLocale -SystemLocale en-US
#     Set-WinUserLanguageList en-US -Force
#     Set-Culture en-US
#     Set-WinHomeLocation -GeoId 244
#     Set-ItemProperty -Path "HKCU:\\Control Panel\\International" -Name "GeoID" -Value 244
#     Write-Output "System region set to US."
# } Catch {
#     Write-Output "Failed to set system region: $_"
# }

# # Set taskbar alignment to left
# Try {
#     Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced" -Name "TaskbarAl" -Value 0
#     Write-Output "Taskbar alignment set to left."
# } Catch {
#     Write-Output "Failed to set taskbar alignment: $_"
# }

# # Hide Task View button in the taskbar
# Try {
#     Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced" -Name "ShowTaskViewButton" -Value 0
#     Write-Output "Task View button hidden in the taskbar."
# } Catch {
#     Write-Output "Failed to hide Task View button in the taskbar: $_"
# }

# # Hide Widgets in the taskbar
# Try {
#     Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced" -Name "TaskbarDa" -Value 0
#     Write-Output "Widgets hidden in the taskbar."
# } Catch {
#     Write-Output "Failed to hide Widgets in the taskbar: $_"
# }

# Final output message
Write-Output "##########################################################"
Write-Output "#                                                        #"
Write-Output "#     EVERYTHING SUCCESSFULLY INSTALLED AND ENABLED      #"
Write-Output "#                                                        #"
Write-Output "##########################################################"
Pause

# SIG # Begin signature block
# MIIb8gYJKoZIhvcNAQcCoIIb4zCCG98CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCACgwovhT99cOZN
# oIIGgmQJtndZhmeWmA6+phqj1Raa9aCCFjEwggMqMIICEqADAgECAhActY9oOxGl
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
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCBQ
# gmRdoxMTmuCq5ru1G2iG7oZWdlbK/5pQZT/FX6WI1jANBgkqhkiG9w0BAQEFAASC
# AQA4uaQ/XIyhSqd35DfBerwKHbCy46r5QmYpWzSrGOY2fHMsKH7tK4t8MEiZl9dD
# C9uOkEdvUdKj0wiuu8QNTvEVddwkXpBFmZobCocS8D8WTR3Mx1iv1taltHJqWaco
# VHMrPS6yWg2iiI9PLzCPVf/wOmvcGWW8yph2jkkUra1bmtM2bODI4chJ8u4k8bLs
# 6S0hFly4wdKzHcitxWXCIC0V8leUI/7fKwtqtotU8Sh6hMQYnUtviW4U/0z9tLVE
# epW9t82aA8bcXR7qsFBEbssZBOy5BTvQ6qvUAT9hjt/NUclMJC83R1tlZwHdwK8d
# MCYx7MezSnzsRan4rkXdcVadoYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEB
# MHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYD
# VQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFt
# cGluZyBDQQIQC65mvFq6f5WHxvnpBOMzBDANBglghkgBZQMEAgEFAKBpMBgGCSqG
# SIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MDMyODIxNTA1
# NVowLwYJKoZIhvcNAQkEMSIEIK4PmvFK08/1T1vhbX6kxNp/wuOXjhz0dCx4ZCm+
# GDdkMA0GCSqGSIb3DQEBAQUABIICAByGAxH4a0YMlojMAoTmMybRU7EJafTaqmfW
# oN8F9nt0+1NWLc1QBMY8HsNEEZbLFWg09vcrCBlntCctHIgj53qVRskZgYcpy0D6
# lCDXN0//ZSEbplK5nqjZt7wQsFtufep75wxgAhv6H9CRdP5xiHri7UNYAcUoH4eO
# eVxdEAyVGsD29n0nPZVUKDeadn3uy5FekkAwNpxZTNaeja/0WrIYPqrHD+mNkdz7
# guamqpoO5Rg2CldXwvL50OU/r0dP+9a59jRJnPWEd5fCZw5PvqeaY78ZWsoRm9B6
# 3qdDG3IXvIMAHA9gMc6FqGlCjyUmjsjPZklH+bKtV2QrSAxpXlXOJOCyvwfHMs8g
# mMlEiOjKMfuX2SgcOJPgUS6DOahCRsBaqvb46JsUz3h1fTVKc0s9263uaFH29pjD
# 1usqK2u4xhkE4ighLAuFcXeI9pWPubyXu3b+DmlP4hK2cwW0mN+bw+NzwuFTsRJq
# nShClKJFFSy8gTy+IuGcN9ERxuJ3Fp39qRsObGKPL0EawK9QuWCUG1S59UWZ4T1d
# pH/nrAM7BmyzVKrng+XmQkd4HpCB9iFNRLKQ6p1T4dQC0XZ3JxUtGSCQWEsdTS78
# BceG7Pz8/0XAWbq5U/iVyb/v1ZUKw7bEdQ5Uh00UFIlKeWrmfMqGXyYzhXyGfO9q
# 4YgXoVZK
# SIG # End signature block
