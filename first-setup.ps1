# Set the GITPATH variable to the directory where the script is located
$GITPATH = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "GITPATH is set to: $GITPATH"

# GitHub URL base for the necessary configuration files
$GITHUB_BASE_URL = "https://raw.githubusercontent.com/Jaredy899/setup/main/win"

# Function to check if the script is running with administrator privileges
function Test-AdminRights {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "You do not have Administrator rights to run this script! Please re-run this script as an Administrator."
        exit 1
    } else {
        Write-Host "Running with administrator privileges."
    }
}

# Ensure the script is running with administrator privileges
Test-AdminRights

# Function to invoke a script from local or GitHub
function Invoke-Script {
    param (
        [string]$scriptName,
        [string]$localPath,
        [string]$url
    )
    if (Test-Path "$localPath\$scriptName") {
        Write-Host "Invoking $scriptName from local directory..."
        & "$localPath\$scriptName"
    } else {
        Write-Host "Invoking $scriptName from GitHub..."
        $tempScript = "$env:TEMP\$scriptName"
        Invoke-RestMethod -Uri "$url/$scriptName" -OutFile $tempScript
        & $tempScript
        Remove-Item $tempScript -Force
    }
}

# Special function to invoke Chris Titus Tech's Windows Utility directly from URL
function Invoke-ChrisTitusTechUtility {
    Write-Host "Invoking Chris Titus Tech's Windows Utility..."
    Invoke-RestMethod -Uri "https://christitus.com/win" | Invoke-Expression
}

# Function to set up Nord backgrounds
function Set-NordBackgrounds {
    $backgroundPath = "$GITPATH\nord-background"
    if (Test-Path $backgroundPath) {
        Write-Host "Setting up Nord backgrounds..."
        
        # Set up slideshow
        if (Test-Path $backgroundPath) {
            # Enable slideshow
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value ""
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value 10
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value 0
            
            # Set slideshow properties
            Set-ItemProperty -Path "HKCU:\Control Panel\Personalization\Desktop Slideshow" -Name Interval -Value 1800
            Set-ItemProperty -Path "HKCU:\Control Panel\Personalization\Desktop Slideshow" -Name Shuffle -Value 1
            Set-ItemProperty -Path "HKCU:\Control Panel\Personalization\Desktop Slideshow" -Name SlideshowDirectoryPath -Value $backgroundPath
            
            # Refresh the desktop
            RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters ,1 ,True
            
            Write-Host "Wallpaper slideshow set up successfully. It will change every 30 minutes using all images in $backgroundPath."
        } else {
            Write-Host "Background folder not found at $backgroundPath"
        }
        
        # Set lock screen image (if a specific file is desired)
        $lockScreenPath = "$backgroundPath\lockscreen.jpg"
        if (Test-Path $lockScreenPath) {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name LockScreenImagePath -Value $lockScreenPath
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name LockScreenImageUrl -Value $lockScreenPath
            Write-Host "Lock screen image set successfully."
        } else {
            Write-Host "No specific lock screen image (lockscreen.jpg) found in $backgroundPath. The lock screen will use the default behavior."
        }
        
        Write-Host "Nord backgrounds setup complete."
    } else {
        Write-Host "Nord background folder not found at $backgroundPath"
    }
}

# Function to activate Windows
function Invoke-WindowsActivation {
    Write-Host "Activating Windows..."
    $confirmation = Read-Host "Are you sure you want to activate Windows? (y/n)"
    if ($confirmation -eq 'y') {
        Invoke-RestMethod https://get.activated.win | Invoke-Expression
    } else {
        Write-Host "Windows activation cancelled."
    }
}

# Menu loop
while ($true) {
    Write-Host "###########################"
    Write-Host "##   Select an option:   ##"
    Write-Host "###########################"
    Write-Host "1) Update Windows"
    Write-Host "2) Start Setup Script"
    Write-Host "3) Run My PowerShell Config"
    Write-Host "4) Set up Nord Backgrounds"
    Write-Host "5) Activate Windows"
    Write-Host "6) Run ChrisTitusTech's Windows Utility"
    Write-Host "0) Exit"
    Write-Host

    $choice = Read-Host "Enter your choice (0-6)"

    switch ($choice) {
        1 { Invoke-Script -scriptName "Windows-Update.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
        2 { Invoke-Script -scriptName "setup2.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
        3 { Invoke-Script -scriptName "pwsh.ps1" -localPath "$GITPATH\my_powershell" -url "$GITHUB_BASE_URL/my_powershell" }
        4 { Set-NordBackgrounds }
        5 { Invoke-WindowsActivation }
        6 { Invoke-ChrisTitusTechUtility }
        0 { 
            Write-Host "Exiting setup script."
            exit 0  # Exit the script immediately
        }
        default { Write-Host "Invalid option. Please enter a number between 0 and 6." }
    }
}

Write-Host "#############################"
Write-Host "##                         ##"
Write-Host "## Setup script completed. ##"
Write-Host "##                         ##"
Write-Host "#############################"
