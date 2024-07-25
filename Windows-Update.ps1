# Function to install NuGet provider if not installed
function Install-NuGetProvider {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
        Write-Output "NuGet provider not found. Installing NuGet provider..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    }
}

# Install NuGet provider
Install-NuGetProvider

# Check if PSWindowsUpdate module is installed, if not, install it
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck
}

# Import the PSWindowsUpdate module
Import-Module PSWindowsUpdate

# Check for available updates
Write-Output "Checking for available updates..."
$updates = Get-WindowsUpdate

# Display available updates
if ($updates) {
    Write-Output "The following updates are available:"
    $updates | Format-Table -AutoSize

    # Install available updates
    Write-Output "Installing updates..."
    Install-WindowsUpdate -AcceptAll -AutoReboot
} else {
    Write-Output "No updates are available."
}

# List installed updates
Write-Output "Listing installed updates..."
Get-WUHistory | Format-Table -AutoSize
