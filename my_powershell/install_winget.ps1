# install_winget.ps1

# Define URLs for the Winget package and its dependencies
$wingetUrl = "https://aka.ms/getwinget"
$vclibsUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
$xamlUrl = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"

# Define local file paths for the downloaded packages
$wingetPackage = "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
$vclibsPackage = "$env:TEMP\Microsoft.VCLibs.x64.14.00.Desktop.appx"
$xamlPackage = "$env:TEMP\Microsoft.UI.Xaml.2.8.x64.appx"

Write-Host "Downloading Winget and dependencies..."

try {
    # Download the required packages using Start-BitsTransfer for reliability and speed
    Start-BitsTransfer -Source $wingetUrl -Destination $wingetPackage -ErrorAction Stop
    Start-BitsTransfer -Source $vclibsUrl -Destination $vclibsPackage -ErrorAction Stop
    Start-BitsTransfer -Source $xamlUrl -Destination $xamlPackage -ErrorAction Stop

    Write-Host "Installing dependencies..."

    # Install the dependencies if they are not already installed or if a higher version is not present
    if (-not (Get-AppxPackage -Name "*VCLibs*" | Where-Object { $_.Version -ge "14.0.33321.0" })) {
        Add-AppxPackage -Path $vclibsPackage
    } else {
        Write-Host "A higher version of VCLibs is already installed. Skipping installation."
    }

    if (-not (Get-AppxPackage -Name "*UI.Xaml*" | Where-Object { $_.Version -ge "2.8.6.0" })) {
        # Attempt to close Microsoft Store if it's open
        $storeProcess = Get-Process -Name "WinStore.App" -ErrorAction SilentlyContinue
        if ($storeProcess) {
            Write-Host "Closing Microsoft Store to proceed with the installation..."
            Stop-Process -Name "WinStore.App" -Force
        }

        Add-AppxPackage -Path $xamlPackage
    } else {
        Write-Host "A higher version of UI.Xaml is already installed. Skipping installation."
    }

    Write-Host "Installing Winget..."

    # Install Winget
    Add-AppxPackage -Path $wingetPackage

    Write-Host "Winget and dependencies installed successfully."
}
catch {
    Write-Error "Failed to install Winget or its dependencies. Error: $_"
}
