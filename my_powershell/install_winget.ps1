# install_winget.ps1

# Function to check Winget installation status
function Get-WingetStatus {
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        $installedVersion = (winget --version).Trim('v')
        $latestVersion = (Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest").tag_name.Trim('v')
        if ([version]$installedVersion -lt [version]$latestVersion) {
            return "outdated"
        } else {
            return "installed"
        }
    } else {
        return "not installed"
    }
}

Write-Host "=== Checking Winget Installation ===" -ForegroundColor Cyan

# Check Winget installation status
$isWingetInstalled = Get-WingetStatus

try {
    if ($isWingetInstalled -eq "installed") {
        Write-Host "`nWinget is already installed and up to date!" -ForegroundColor Green
        return
    } elseif ($isWingetInstalled -eq "outdated") {
        Write-Host "`nWinget is outdated. Proceeding with update..." -ForegroundColor Yellow
    } else {
        Write-Host "`nWinget is not installed. Starting installation..." -ForegroundColor Yellow
    }

    # Gets the computer's information
    Write-Host "Checking system compatibility..." -ForegroundColor Blue
    if ($null -eq $sync.ComputerInfo) {
        $ComputerInfo = Get-ComputerInfo -ErrorAction Stop
    } else {
        $ComputerInfo = $sync.ComputerInfo
    }

    if (($ComputerInfo.WindowsVersion) -lt "1809") {
        Write-Host "Winget is not supported on this version of Windows (Pre-1809)" -ForegroundColor Red
        return
    }

    # Define URLs and paths
    Write-Host "`n=== Downloading Required Components ===" -ForegroundColor Cyan
    
    $wingetUrl = "https://aka.ms/getwinget"
    $vclibsUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
    $xamlUrl = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"

    $wingetPackage = "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $vclibsPackage = "$env:TEMP\Microsoft.VCLibs.x64.14.00.Desktop.appx"
    $xamlPackage = "$env:TEMP\Microsoft.UI.Xaml.2.8.x64.appx"

    Write-Host "Downloading Winget and dependencies..." -ForegroundColor Yellow

    # Download packages
    Start-BitsTransfer -Source $wingetUrl -Destination $wingetPackage -ErrorAction Stop
    Write-Host "Downloaded Winget package successfully!" -ForegroundColor Green
    
    Start-BitsTransfer -Source $vclibsUrl -Destination $vclibsPackage -ErrorAction Stop
    Write-Host "Downloaded VCLibs package successfully!" -ForegroundColor Green
    
    Start-BitsTransfer -Source $xamlUrl -Destination $xamlPackage -ErrorAction Stop
    Write-Host "Downloaded XAML package successfully!" -ForegroundColor Green

    Write-Host "`n=== Installing Components ===" -ForegroundColor Cyan
    Write-Host "Installing dependencies..." -ForegroundColor Yellow

    # Install VCLibs
    if (-not (Get-AppxPackage -Name "*VCLibs*" | Where-Object { $_.Version -ge "14.0.33321.0" })) {
        Add-AppxPackage -Path $vclibsPackage
        Write-Host "VCLibs installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "A higher version of VCLibs is already installed." -ForegroundColor Blue
    }

    # Install XAML
    if (-not (Get-AppxPackage -Name "*UI.Xaml*" | Where-Object { $_.Version -ge "2.8.6.0" })) {
        $storeProcess = Get-Process -Name "WinStore.App" -ErrorAction SilentlyContinue
        if ($storeProcess) {
            Write-Host "Closing Microsoft Store to proceed with installation..." -ForegroundColor Yellow
            Stop-Process -Name "WinStore.App" -Force
        }

        Add-AppxPackage -Path $xamlPackage
        Write-Host "UI.Xaml installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "A higher version of UI.Xaml is already installed." -ForegroundColor Blue
    }

    Write-Host "Installing Winget..." -ForegroundColor Yellow
    Add-AppxPackage -Path $wingetPackage

    Write-Host "`n=== Installation Complete ===" -ForegroundColor Cyan
    Write-Host "Winget and all dependencies installed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Failed to install Winget or its dependencies. Error: $_" -ForegroundColor Red
}
