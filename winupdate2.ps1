# Function to install NuGet provider if not installed
function Install-NuGetProvider {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
        Write-Output "NuGet provider not found. Installing NuGet provider..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
    }
}

# Install NuGet provider
Install-NuGetProvider

# Check if PSWindowsUpdate module is installed, if not, install it
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -ErrorAction SilentlyContinue
}

# Import the PSWindowsUpdate module
Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

# Verify if the module was imported successfully
if (-not (Get-Module -Name PSWindowsUpdate)) {
    Write-Output "Failed to import PSWindowsUpdate module."
    exit 1
}

# Check for available updates
Write-Output "Checking for available updates..."
$updates = Get-WindowsUpdate -ErrorAction SilentlyContinue

# Display available updates
if ($updates -and $updates.Count -gt 0) {
    Write-Output "The following updates are available:"
    $updates | Format-Table -AutoSize

    # Install available updates
    Write-Output "Installing updates..."
    Install-WindowsUpdate -AcceptAll -AutoReboot -ErrorAction SilentlyContinue
} else {
    Write-Output "No updates are available."
}

# List installed updates
Write-Output "Listing installed updates..."
Get-WUHistory | Format-Table -AutoSize -ErrorAction SilentlyContinue

# Prompt to start the setup script
$startSetup = Read-Host "Do you want to start the setup script from GitHub? (yes/no)"
if ($startSetup -eq "yes") {
    # Download and run the setup script
    Write-Output "Downloading and running the setup script..."
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Jaredy899/setup/main/setup2.ps1" -OutFile "$env:TEMP\setup2.ps1"
    . "$env:TEMP\setup2.ps1"
} else {
    Write-Output "Setup script was not started."
}

# Prompt to start the winapps script
$startWinApps = Read-Host "Do you want to start the winapps script from GitHub? (yes/no)"
if ($startWinApps -eq "yes") {
    # Download and run the winapps script
    Write-Output "Downloading and running the winapps script..."
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Jaredy899/setup/main/winapps.ps1" -OutFile "$env:TEMP\winapps.ps1"
    . "$env:TEMP\winapps.ps1"
} else {
    Write-Output "Winapps script was not started."
}