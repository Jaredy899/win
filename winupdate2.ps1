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

# Function to check if Git is installed
function Check-GitInstalled {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Output "Git is not installed or not found in PATH."
        $installGit = Read-Host "Do you want to install Git? (yes/no)"
        if ($installGit -eq "yes") {
            Write-Output "Installing Git..."
            $gitInstaller = "https://github.com/git-for-windows/git/releases/download/v2.33.0.windows.2/Git-2.33.0-64-bit.exe"
            $gitInstallerPath = "$env:TEMP\Git-2.33.0-64-bit.exe"
            Invoke-WebRequest -Uri $gitInstaller -OutFile $gitInstallerPath
            Start-Process -FilePath $gitInstallerPath -ArgumentList "/VERYSILENT" -Wait
            Remove-Item -Path $gitInstallerPath
            Write-Output "Git installed. Please restart the script."
            exit 1
        } else {
            Write-Output "Please install Git and try again."
            exit 1
        }
    }
}

# Prompt to start the setup script
$startSetup = Read-Host "Do you want to start the setup script from GitHub? (yes/no)"
if ($startSetup -eq "yes") {
    Check-GitInstalled

    # Clone the repository
    Write-Output "Cloning the repository..."
    git clone https://github.com/Jaredy899/setup.git

    # Navigate to the repository directory
    Set-Location setup

    # Run the setup script
    Write-Output "Running the setup script..."
    .\setup2.ps1
} else {
    Write-Output "Setup script was not started."
}

# Prompt to start the winapps script
$startWinApps = Read-Host "Do you want to start the winapps script from GitHub? (yes/no)"
if ($startWinApps -eq "yes") {
    Check-GitInstalled

    # Clone the repository if not already cloned
    if (-not (Test-Path -Path "./setup")) {
        Write-Output "Cloning the repository..."
        git clone https://github.com/Jaredy899/setup.git
    }

    # Navigate to the repository directory
    Set-Location setup

    # Run the winapps script
    Write-Output "Running the winapps script..."
    .\winapps.ps1
} else {
    Write-Output "Winapps script was not started."
}