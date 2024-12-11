# Function to install NuGet provider if not installed
function Install-NuGetProvider {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
        Write-Host "NuGet provider not found. Installing NuGet provider..." -ForegroundColor Yellow
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Write-Host "NuGet provider installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "NuGet provider is already installed." -ForegroundColor Blue
    }
}

# Install NuGet provider
Install-NuGetProvider

# Check if PSWindowsUpdate module is installed
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "Installing PSWindowsUpdate module..." -ForegroundColor Yellow
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck
    Write-Host "PSWindowsUpdate module installed successfully!" -ForegroundColor Green
} else {
    Write-Host "PSWindowsUpdate module is already installed." -ForegroundColor Blue
}

# Import the PSWindowsUpdate module
Write-Host "Importing PSWindowsUpdate module..." -ForegroundColor Cyan
Import-Module PSWindowsUpdate

# Check for available updates
Write-Host "`n=== Checking for available updates... ===" -ForegroundColor Cyan
$updates = Get-WindowsUpdate

# Display available updates
if ($updates) {
    Write-Host "`nThe following updates are available:" -ForegroundColor Yellow
    $updates | Format-Table -AutoSize

    Write-Host "`nInstalling updates..." -ForegroundColor Yellow
    Install-WindowsUpdate -AcceptAll -AutoReboot
    Write-Host "Updates installation process initiated!" -ForegroundColor Green
} else {
    Write-Host "No updates are available." -ForegroundColor Blue
}

# List installed updates
Write-Host "`n=== Recently installed updates ===" -ForegroundColor Cyan
Get-WUHistory | Format-Table -AutoSize
