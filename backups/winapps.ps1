function Install-Applications {
    Try {
        # Install or update other applications
        $applications = @(
            @{ id = "Fastfetch-cli.Fastfetch"; name = "Fastfetch" },
            @{ id = "Mozilla.Firefox"; name = "Firefox" },
            @{ id = "7zip.7zip"; name = "7zip" },
            @{ id = "Nushell.Nushell"; name = "Nushell" },
            @{ id = "VideoLAN.VLC"; name = "VLC" },
            @{ id = "gerardog.gsudo"; name = "gsudo" },
            @{ id = "Parsec.Parsec"; name = "Parsec" },
            @{ id = "Tailscale.Tailscale"; name = "Tailscale" },
            @{ id = "Termius.Termius"; name = "Termius" },
            @{ id = "Eugeny.Tabby"; name = "Tabby" },
            @{ id = "Anysphere.Cursor"; name = "Cursor" }
        )
        $totalApps = $applications.Count
        $currentAppIndex = 0

        foreach ($app in $applications) {
            $currentAppIndex++
            Write-Progress -Activity "Installing Applications" -Status "Processing $($app.name)" -PercentComplete (($currentAppIndex / $totalApps) * 100)

            Try {
                $installedApp = winget list --id $app.id --source winget | Select-String -Pattern $app.id
                if ($installedApp) {
                    $updateAvailable = winget upgrade --id $app.id --source winget | Select-String -Pattern $app.id
                    if ($updateAvailable) {
                        winget upgrade --id $app.id --source winget --accept-source-agreements --accept-package-agreements --silent --force *>$null
                    }
                } else {
                    winget install --id $app.id --source winget --accept-source-agreements --accept-package-agreements --silent --force *>$null
                }
            } Catch {
                Write-Output "Failed to install or update $($app.name): $($_)"
            }
        }

        Write-Output "All applications processed."
    } Catch {
        Write-Output "Failed to install applications: $($_)"
    }
}

# Main script execution
Install-Applications

Write-Output "##########################################################"
Write-Output "#                                                        #"
Write-Output "#     APPLICATIONS SUCCESSFULLY INSTALLED OR UPDATED     #"
Write-Output "#                                                        #"
Write-Output "##########################################################"

# Add to PowerShell profile
$profileContent = @"
Set-Alias ff fastfetch
function Invoke-apps {
    winget update --all --include-unknown
}
Set-Alias apps Invoke-apps
function codes {
    Set-Location -Path "G:\My Drive\Codes"
}
"@

$profilePath = [System.IO.Path]::Combine($env:USERPROFILE, 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
if (-not (Test-Path -Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force
}
$existingProfileContent = Get-Content -Path $profilePath -Raw
if ($existingProfileContent -notcontains $profileContent) {
    Add-Content -Path $profilePath -Value $profileContent
    Write-Output "Aliases and functions added to PowerShell profile."
} else {
    Write-Output "Aliases and functions already exist in PowerShell profile."
}

# Reload the PowerShell profile to apply changes
. $profilePath
# SIG # Begin signature block
# MIIb8gYJKoZIhvcNAQcCoIIb4zCCG98CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCUk2zfnUihEUGZ
# eTyyZYcGEueZPkWtZm8NgEDA9/xVLqCCFjEwggMqMIICEqADAgECAhActY9oOxGl
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
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCAR
# qQZarBotBUz5Obd3LnfpyAGAQJIbNqJjNeVxJ1USnjANBgkqhkiG9w0BAQEFAASC
# AQBs9Eq1vBsXGYQTMZro61mp2SQZFFStTMu9bGG9z3fgoNl3XqE0DjTwSYdoAeVy
# jjpWA5GUZgUWQI7aZ3WvcZntKAoX6U3qMBqVBsTwaumsybCJgiOJkNAYkDpzinpk
# KV5xKC4HYZmhz2E4kvhZ3jdS3tet2KQvdrqPgyz+afqxALKgQi+THFEL7B1vpGrr
# ssFQ8gRj+Bg7lpFqye66jDmb/dXQnCR/I5DHvEkiuc+G/7H3W48F9LbuTSd4xygc
# rlZ6j+/KuPqvV+xF6NOj9ejZKGOdyPGngPAHVpEfNJ+8wgAhoRS+/eoWUZOe2GhV
# K7OBXFmAYdBvSh9MC+BxuKEroYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEB
# MHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYD
# VQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFt
# cGluZyBDQQIQC65mvFq6f5WHxvnpBOMzBDANBglghkgBZQMEAgEFAKBpMBgGCSqG
# SIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MDMyODIxNTA1
# NVowLwYJKoZIhvcNAQkEMSIEIH/Ao6VzyZl5lYkBbF8ed7VcH/+7sRioE/sAjKqX
# MJW+MA0GCSqGSIb3DQEBAQUABIICAIjVIVtLxNNUKnUTWS43g5wcyfxJ4dJN2oDN
# y3CEG3MYGM57Rdz1HPp77kNFAuPJPI4+GNr9JB6D52AG2V0q38NIDPHFn8n/t9YW
# Nwq7TKQDhYuE4YG5ecPw31lBcXKAZo9NfuMJ1thfXBje4Vg9gGRtY9TUC9KVta6K
# b7ykhvr6299hnyqnkeBjhBs1U38Sb+AcKhwzfm+cN9IWsiuK4bb+yJHBOTL6mxw7
# nicPa6RifjKx1isVK/mo58rjRkDyAi0T7lmfCJRgrgXyJxIMVKBIIXtDJPAZ3XLG
# rsH83NnmLr6RWx+8nW0TU1z6u/CEa3aasaxyD1QXIgEj6mFryg9NMCJ9vfpaCLwJ
# +mnzWb9LNUTXkeb15x9qLrtN67nAn6njO4pqRYx1wi/L8ZcO/nAqdnCifOjUJPnl
# DerM45aAjFrUcS2BG6j7F75zFTdXzqdJSFMwgZqGPBCEkEog+aIqwIy6BlrIpJ9b
# sM1l7VsRmPNjnNdxfqa3r0Nvz22kn090774x9cTslZYdbNz0gCp4rEWvR7rvOToZ
# 5iKABScAoXaMIITaP2jjjA88BrndoMWU6oLLLnJEsnZEgrFaZxybh42nJ4asVwFM
# H466DY9lJuWsnVD9qSAt2JwLAzvMmZQeeMeeDU+BRN3OexfFeVti0Yg4c89a0PcN
# tTWuA6K7
# SIG # End signature block
