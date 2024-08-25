# install_winget.ps1

# Define URLs for the Winget package and its dependencies
$wingetUrl = "https://aka.ms/getwinget"
$xamlUrl = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"

# Define local file paths for the downloaded packages
$wingetPackage = "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
$vclibsPackage = "$env:TEMP\Microsoft.VCLibs.x64.14.00.Desktop.appx"
$xamlPackage = "$env:TEMP\Microsoft.UI.Xaml.2.8.x64.appx"

Write-Host "Downloading Winget and dependencies..."

try {
    # Download the required packages using Start-BitsTransfer for reliability and speed
    Start-BitsTransfer -Source $wingetUrl -Destination $wingetPackage -ErrorAction Stop
    Start-BitsTransfer -Source $xamlUrl -Destination $xamlPackage -ErrorAction Stop

    Write-Host "Installing dependencies..."

    # Install the dependencies
    Add-AppxPackage -Path $vclibsPackage
    Add-AppxPackage -Path $xamlPackage

    Write-Host "Installing Winget..."

    # Install Winget
    Add-AppxPackage -Path $wingetPackage

    Write-Host "Winget and dependencies installed successfully."
}
catch {
    Write-Error "Failed to install Winget or its dependencies. Error: $_"
}
