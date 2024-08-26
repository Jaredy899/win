Write-Host "Checking Winget version..."

try {
    # Check the installed version of Winget
    $installedVersion = (winget --version).Trim().TrimStart('v')

    # Fetch the latest version number from GitHub
    $latestVersion = (Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest").tag_name.TrimStart("v")

    # Compare versions and update if necessary
    if ([Version]$installedVersion -lt [Version]$latestVersion) {
        Write-Host "Updating Winget to version $latestVersion..."
        $latestWingetUrl = (Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest").assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1 -ExpandProperty browser_download_url
        $latestWingetPackage = "$env:TEMP\Microsoft.DesktopAppInstaller_latest.msixbundle"
        Start-BitsTransfer -Source $latestWingetUrl -Destination $latestWingetPackage -ErrorAction Stop
        Add-AppxPackage -Path $latestWingetPackage
        Write-Host "Winget updated to version $latestVersion successfully."
    } else {
        Write-Host "Winget is already up-to-date."
    }
}
catch {
    Write-Error "An error occurred: $_"
}