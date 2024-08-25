# install_winget.ps1

# Function to install or update Winget using the source.msix package
function Install-Winget {
    param (
        [string]$WingetPackageUrl = "https://cdn.winget.microsoft.com/cache/source.msix",
        [string]$WingetPackagePath = "$env:TEMP\source.msix"
    )

    # Check if Winget is already installed
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Winget is already installed."
        return
    }

    Write-Host "Downloading Winget package from $WingetPackageUrl..."
    try {
        Invoke-WebRequest -Uri $WingetPackageUrl -OutFile $WingetPackagePath -ErrorAction Stop
        Write-Host "Installing Winget package..."
        Start-Process -FilePath "powershell.exe" -ArgumentList "Add-AppxPackage -Path $WingetPackagePath" -Wait
        Write-Host "Winget installation or update completed successfully."
    }
    catch {
        Write-Error "Failed to install Winget. Error: $_"
    }
}

# Call the function to install or update Winget
Install-Winget
