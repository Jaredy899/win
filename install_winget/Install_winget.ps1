function Install-WinUtilWinget {
    <#

    .SYNOPSIS
        Installs Winget if it is not already installed.

    .DESCRIPTION
        This function will download the latest version of Winget and install it. If Winget is already installed, it will do nothing.
    #>

    # Updated to reference GitHub for checking if Winget is installed
    $isWingetInstalledScript = "https://raw.githubusercontent.com/Jaredy899/setup/main/Test_winget.ps1"
    $isWingetInstalled = Invoke-Expression (Invoke-WebRequest -Uri $isWingetInstalledScript -UseBasicParsing).Content

    try {
        if ($isWingetInstalled -eq "installed") {
            Write-Host "`nWinget is already installed.`r" -ForegroundColor Green
            return
        } elseif ($isWingetInstalled -eq "outdated") {
            Write-Host "`nWinget is Outdated. Continuing with install.`r" -ForegroundColor Yellow
        } else {
            Write-Host "`nWinget is not Installed. Continuing with install.`r" -ForegroundColor Red
        }

        # Gets the computer's information
        if ($null -eq $sync.ComputerInfo) {
            $ComputerInfo = Get-ComputerInfo -ErrorAction Stop
        } else {
            $ComputerInfo = $sync.ComputerInfo
        }

        if (($ComputerInfo.WindowsVersion) -lt "1809") {
            # Checks if Windows Version is too old for Winget
            Write-Host "Winget is not supported on this version of Windows (Pre-1809)" -ForegroundColor Red
            return
        }

        # Install Winget via GitHub method.
        # Used part of my own script with some modification: ruxunderscore/windows-initialization
        Write-Host "Downloading Winget Prerequisites`n"
        
        # Execute Winget_prereq.ps1 script from GitHub
        $wingetPrereqScript = "https://raw.githubusercontent.com/Jaredy899/setup/main/Winget_prereq.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $wingetPrereqScript -UseBasicParsing).Content
        
        Write-Host "Downloading Winget and License File`r"
        
        # Execute Winget_latest.ps1 script from GitHub
        $wingetLatestScript = "https://raw.githubusercontent.com/Jaredy899/setup/main/Winget_latest.ps1"
        Invoke-Expression (Invoke-WebRequest -Uri $wingetLatestScript -UseBasicParsing).Content
        
        Write-Host "Installing Winget w/ Prerequisites`r"
        Add-AppxProvisionedPackage -Online -PackagePath $ENV:TEMP\Microsoft.DesktopAppInstaller.msixbundle -DependencyPackagePath $ENV:TEMP\Microsoft.VCLibs.x64.Desktop.appx, $ENV:TEMP\Microsoft.UI.Xaml.x64.appx -LicensePath $ENV:TEMP\License1.xml
        Write-Host "Manually adding Winget Sources, from Winget CDN."
        Add-AppxPackage -Path https://cdn.winget.microsoft.com/cache/source.msix # Ensure winget repository source is installed
        Write-Host "Winget Installed" -ForegroundColor Green
        Write-Host "Enabling NuGet and Module..."
        Install-PackageProvider -Name NuGet -Force
        Install-Module -Name Microsoft.WinGet.Client -Force
        # Winget only needs a refresh of the environment variables to be used.
        Write-Output "Refreshing Environment Variables...`n"
        $ENV:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } catch {
        Write-Host "Failure detected while installing via GitHub method. Continuing with Chocolatey method as fallback." -ForegroundColor Red
        # In case install fails via GitHub method.
        Write-Host $_ -ForegroundColor Red
    }
}
