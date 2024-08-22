# Function to install Scoop and gsudo
function Install-ScoopAndGsudo {
    Write-Output "Checking if Scoop is installed..."
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Output "Scoop not found. Installing Scoop..."
        Invoke-RestMethod -Uri "https://get.scoop.sh" -OutFile "$env:TEMP\installScoop.ps1"
        . "$env:TEMP\installScoop.ps1"
    } else {
        Write-Output "Scoop is already installed."
    }

    Write-Output "Installing gsudo using Scoop..."
    scoop install gsudo
}

# Install Scoop and gsudo
Install-ScoopAndGsudo

# Prompt to update Windows
$updateWindows = Read-Host "Do you want to update Windows? (yes/y/enter for yes, no/n for no)"
if ($updateWindows -eq "yes" -or $updateWindows -eq "y" -or [string]::IsNullOrEmpty($updateWindows)) {
    # Run the Windows update script from the URL
    Write-Output "Downloading and running the Windows update script..."
    Invoke-RestMethod -Uri https://raw.githubusercontent.com/Jaredy899/setup/main/Windows-Update.ps1 -OutFile "$env:TEMP\setup2.ps1"
    gsudo powershell -File "$env:TEMP\setup2.ps1"
} else {
    Write-Output "Skipping Windows update."
}

# Prompt to start the setup script
$startSetup = Read-Host "Do you want to start the Setup script? (yes/y/enter for yes, no/n for no)"
if ($startSetup -eq "yes" -or $startSetup -eq "y" -or [string]::IsNullOrEmpty($startSetup)) {
    # Download and run the setup script
    Write-Output "Downloading and running the setup script..."
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Jaredy899/setup/main/setup2.ps1" -OutFile "$env:TEMP\setup2.ps1"
    gsudo powershell -File "$env:TEMP\setup2.ps1"
} else {
    Write-Output "Setup script was not started."
}

# Prompt to start the winapps script
$startWinApps = Read-Host "Do you want to install and update apps? (yes/y/enter for yes, no/n for no)"
if ($startWinApps -eq "yes" -or $startWinApps -eq "y" -or [string]::IsNullOrEmpty($startWinApps)) {
    # Download and run the winapps script
    Write-Output "Downloading and running the winapps script..."
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Jaredy899/setup/main/winapps.ps1" -OutFile "$env:TEMP\winapps.ps1"
    gsudo powershell -File "$env:TEMP\winapps.ps1"
} else {
    Write-Output "Winapps script was not started."
}

# Prompt to start My Powershell config
$startMyPowershell = Read-Host "Do you want to start My Powershell config? (yes/y/enter for yes, no/n for no)"
if ($startMyPowershell -eq "yes" -or $startMyPowershell -eq "y" -or [string]::IsNullOrEmpty($startMyPowershell)) {
    # Download and run the My Powershell config script
    Write-Output "Downloading and running My Powershell config script..."
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Jaredy899/setup/main/my_powershell/pwsh.ps1" -OutFile "$env:TEMP\pwsh.ps1"
    gsudo powershell -File "$env:TEMP\pwsh.ps1"
} else {
    Write-Output "My Powershell config script was not started."
}
