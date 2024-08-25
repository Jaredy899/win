# Define base URL for the required scripts
$baseUrl = "https://raw.githubusercontent.com/Jaredy899/win/main/install_winget/"

# Define URLs for each script
$isWingetInstalledScriptUrl = "${baseUrl}Test_winget.ps1"
$wingetPrereqScriptUrl = "${baseUrl}Winget_prereq.ps1"
$wingetLatestScriptUrl = "${baseUrl}Winget_latest.ps1"

try {
    # Check if Winget is installed by executing the Test_winget.ps1 script from GitHub
    if ((Invoke-WebRequest -Uri $isWingetInstalledScriptUrl -UseBasicParsing -ErrorAction Stop).StatusCode -eq 200) {
        $isWingetInstalled = Invoke-Expression (Invoke-WebRequest -Uri $isWingetInstalledScriptUrl -UseBasicParsing).Content
    } else {
        Write-Host "Failed to fetch the Test_winget.ps1 script." -ForegroundColor Red
        return
    }

    if ($isWingetInstalled -eq "installed") {
        Write-Host "`nWinget is already installed.`r" -ForegroundColor Green
        return
    } elseif ($isWingetInstalled -eq "outdated") {
        Write-Host "`nWinget is Outdated. Continuing with install.`r" -ForegroundColor Yellow
    } else {
        Write-Host "`nWinget is not Installed. Continuing with install.`r" -ForegroundColor Red
    }

    # Gets the computer's information
    $ComputerInfo = Get-ComputerInfo -ErrorAction Stop

    if (($ComputerInfo.WindowsVersion) -lt "1809") {
        # Checks if Windows Version is too old for Winget
        Write-Host "Winget is not supported on this version of Windows (Pre-1809)" -ForegroundColor Red
        return
    }

    Write-Host "Downloading Winget Prerequisites`n"

    # Execute Winget_prereq.ps1 script from GitHub
    if ((Invoke-WebRequest -Uri $wingetPrereqScriptUrl -UseBasicParsing -ErrorAction Stop).StatusCode -eq 200) {
        Invoke-Expression (Invoke-WebRequest -Uri $wingetPrereqScriptUrl -UseBasicParsing).Content
    } else {
        Write-Host "Failed to fetch the Winget_prereq.ps1 script." -ForegroundColor Red
        return
    }

    Write-Host "Downloading Winget and License File`r"

    # Execute Winget_latest.ps1 script from GitHub
    if ((Invoke-WebRequest -Uri $wingetLatestScriptUrl -UseBasicParsing -ErrorAction Stop).StatusCode -eq 200) {
        Invoke-Expression (Invoke-WebRequest -Uri $wingetLatestScriptUrl -UseBasicParsing).Content
    } else {
        Write-Host "Failed to fetch the Winget_latest.ps1 script." -ForegroundColor Red
        return
    }

    Write-Host "Installing Winget with Prerequisites`r"
    Add-AppxProvisionedPackage -Online -PackagePath $ENV:TEMP\Microsoft.DesktopAppInstaller.msixbundle -DependencyPackagePath $ENV:TEMP\Microsoft.VCLibs.x64.Desktop.appx, $ENV:TEMP\Microsoft.UI.Xaml.x64.appx -LicensePath $ENV:TEMP\License1.xml
    Write-Host "Manually adding Winget Sources, from Winget CDN."
    Add-AppxPackage -Path https://cdn.winget.microsoft.com/cache/source.msix # Ensure winget repository source is installed
    Write-Host "Winget Installed" -ForegroundColor Green
    Write-Host "Enabling NuGet and Module..."
    Install-PackageProvider -Name NuGet -Force
    Install-Module -Name Microsoft.WinGet.Client -Force
    Write-Output "Refreshing Environment Variables...`n"
    $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
} catch {
    Write-Host "Failure detected while installing via GitHub method. Continuing with Chocolatey method as fallback." -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
}
