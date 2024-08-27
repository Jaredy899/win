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

# Function to display the menu and handle user choices
function Show-Menu {
    param (
        [string]$menuTitle,
        [array]$options
    )

    Write-Host "###################################"
    Write-Host "##           $menuTitle          ##"
    Write-Host "###################################"
    Write-Host

    for ($i = 0; $i -lt $options.Length; $i++) {
        Write-Host "$($i + 1)) $($options[$i])"
    }
    Write-Host "0) Exit"
    Write-Host

    $selection = Read-Host "Please choose an option"
    return $selection
}

# Function to update Windows
function Update-Windows {
    Write-Output "Downloading and running the Windows update script..."
    Invoke-RestMethod -Uri https://raw.githubusercontent.com/Jaredy899/setup/main/Windows-Update.ps1 -OutFile "$env:TEMP\setup2.ps1"
    powershell -File "$env:TEMP\setup2.ps1"
}

# Function to start the setup script
function Start-SetupScript {
    Write-Output "Downloading and running the setup script..."
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Jaredy899/setup/main/setup2.ps1" -OutFile "$env:TEMP\setup2.ps1"
    powershell -File "$env:TEMP\setup2.ps1"
}

# Function to run My PowerShell config
function Run-MyPowerShellConfig {
    Write-Output "Downloading and running My PowerShell config script..."
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Jaredy899/setup/main/my_powershell/pwsh.ps1" -OutFile "$env:TEMP\pwsh.ps1"
    . "$env:TEMP\pwsh.ps1"
}

# Function to run ChrisTitusTech's Windows Utility
function Run-ChrisTitusTechUtility {
    Write-Output "Downloading ChrisTitusTech's Windows Utility script..."
    Invoke-RestMethod -Uri "https://christitus.com/win" -OutFile "$env:TEMP\ctt_win.ps1"
    Write-Output "Running ChrisTitusTech's Windows Utility script..."
    powershell -File "$env:TEMP\ctt_win.ps1"
}

# Menu loop
while ($true) {
    $menuTitle = "Select an option"
    $options = @(
        "Update Windows",
        "Start Setup Script",
        "Run My PowerShell Config",
        "Run ChrisTitusTech's Windows Utility"
    )
    $selection = Show-Menu -menuTitle $menuTitle -options $options

    switch ($selection) {
        1 {
            Update-Windows
        }
        2 {
            Start-SetupScript
        }
        3 {
            Run-MyPowerShellConfig
        }
        4 {
            Run-ChrisTitusTechUtility
        }
        0 {
            Write-Host "Exiting setup script."
            break
        }
        default {
            Write-Host "Invalid option. Please enter a number between 0 and 4."
        }
    }
}

Write-Host "#############################"
Write-Host "##                         ##"
Write-Host "## Setup script completed. ##"
Write-Host "##                         ##"
Write-Host "#############################"
