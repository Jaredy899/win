# scoop_install.ps1
function Install-Scoop {
    $scoopInstallPath = "C:\ProgramData\scoop"
    $scoopUserInstallPath = "$env:USERPROFILE\scoop"
    $scoopDownloadUrl = "https://get.scoop.sh"

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Scoop not found. Installing Scoop..."
        
        # Check if running as administrator for global install
        if ([System.Security.Principal.WindowsIdentity]::GetCurrent().Groups -match "S-1-5-32-544") {
            Write-Host "Running as administrator. Setting up Scoop for global installation..."
            
            # Ensure the Scoop directory exists
            if (-not (Test-Path -Path $scoopInstallPath)) {
                Write-Host "Creating Scoop global directory..."
                New-Item -Path $scoopInstallPath -ItemType Directory -Force
            }

            # Set the environment variable for global install
            [Environment]::SetEnvironmentVariable('SCOOP', $scoopInstallPath, [System.EnvironmentVariableTarget]::Machine)

            # Download and install Scoop
            Invoke-Expression (New-Object System.Net.WebClient).DownloadString($scoopDownloadUrl)
        } else {
            Write-Host "Installing Scoop in user mode..."
            Invoke-Expression (New-Object System.Net.WebClient).DownloadString($scoopDownloadUrl)
        }
    } else {
        Write-Host "Scoop is already installed."
    }

    # Ensure Git is installed before adding any buckets
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is required for managing Scoop buckets. Installing Git..."
        scoop install git
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install Git. Please check your internet connection or try installing Git manually."
            exit 1
        }
    }

    # Add necessary buckets
    Write-Host "Adding Scoop buckets..."
    scoop bucket add main
    scoop bucket add extras
    scoop bucket add nerd-fonts
}

# Run the Scoop installation function
Install-Scoop
