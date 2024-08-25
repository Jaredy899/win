# install_winget.ps1

# Function to install or update Winget using the required packages
function Install-Winget {
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
        # Download the required packages
        Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetPackage -ErrorAction Stop
        Invoke-WebRequest -Uri $vclibsUrl -OutFile $vclibsPackage -ErrorAction Stop
        Invoke-WebRequest -Uri $xamlUrl -OutFile $xamlPackage -ErrorAction Stop

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
}

# Call the function to install or update Winget
Install-Winget
