function Install-Applications {
    Try {
        # Ensure winget is installed
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Output "winget not found. Installing winget..."
            Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" *>$null
            Add-AppxPackage -Path "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" *>$null
            Write-Output "winget installed successfully."
        } else {
            Write-Output "winget is already installed."
        }

        # Ensure PowerShell is installed
        if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
            Write-Output "PowerShell not found. Installing PowerShell..."
            winget install --id Microsoft.Powershell --source winget --accept-source-agreements --accept-package-agreements *>$null
            Write-Output "PowerShell installed successfully."
        } else {
            Write-Output "PowerShell is already installed."
        }

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
Pause