function Install-Applications {
    Try {
        # Install or update other applications
        $applications = @(
            @{ id = "fastfetch"; name = "Fastfetch" },
            @{ id = "Mozilla.Firefox"; name = "Firefox" },
            @{ id = "7zip.7zip"; name = "7zip" },
            @{ id = "Nushell.Nushell"; name = "Nushell" },
            @{ id = "VideoLAN.VLC"; name = "VLC" },
            @{ id = "gerardog.gsudo"; name = "gsudo" },
            @{ id = "AnyBurn.AnyBurn"; name = "AnyBurn" },
            @{ id = "Parsec.Parsec"; name = "Parsec" },
            @{ id = "Tailscale.Tailscale"; name = "Tailscale" },
            @{ id = "Termius.Termius"; name = "Termius" },
            @{ id = "Tabby.Tabby"; name = "Tabby" },
            @{ id = "Anysphere.Cursor"; name = "Cursor" }
        )

        foreach ($app in $applications) {
            Try {
                Write-Output "Installing or updating $($app.name)..."
                winget install --id $app.id --source winget --accept-source-agreements --accept-package-agreements --silent --force *>$null
                Write-Output "$($app.name) installed or updated successfully."
            } Catch {
                Write-Output "Failed to install or update $($app.name): $($_)"
            }
        }

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
Add-Content -Path $profilePath -Value $profileContent
Write-Output "Aliases and functions added to PowerShell profile."