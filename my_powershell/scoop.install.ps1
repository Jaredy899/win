# scoop_install.ps1
function Install-Scoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Scoop not found. Installing Scoop..."
        $scoopInstallPath = "C:\ProgramData\scoop"
        $scoopDownloadUrl = "https://get.scoop.sh"
        $installScript = "$scoopInstallPath\install.ps1"

        if ([System.Security.Principal.WindowsIdentity]::GetCurrent().Groups -match "S-1-5-32-544") {
            Write-Host "Running as administrator. Setting up Scoop for global installation..."
            
            # Ensure the Scoop directory exists
            if (-not (Test-Path -Path $scoopInstallPath)) {
                Write-Host "Creating Scoop global directory..."
                New-Item -Path $scoopInstallPath -ItemType Directory -Force
            }

            # Download and modify the installation script
            Write-Host "Downloading Scoop installation script..."
            (New-Object System.Net.WebClient).DownloadFile($scoopDownloadUrl, $installScript)

            Write-Host "Setting up environment for global Scoop installation..."
            [Environment]::SetEnvironmentVariable('SCOOP', $scoopInstallPath, [System.EnvironmentVariableTarget]::Machine)
            [Environment]::SetEnvironmentVariable('SCOOP_GLOBAL', "$scoopInstallPath\apps", [System.EnvironmentVariableTarget]::Machine)

            # Run the Scoop installation script with adjusted environment
            & $installScript -RunAsAdmin
        } else {
            Write-Host "Installing Scoop in user mode..."
            Invoke-Expression (New-Object System.Net.WebClient).DownloadString($scoopDownloadUrl)
        }
    } else {
        Write-Host "Scoop is already installed."
    }
}

# Run the Scoop installation function
Install-Scoop
