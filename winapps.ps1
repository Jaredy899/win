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
        foreach ($app in $applications) {
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