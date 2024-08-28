# Set the GITPATH variable to the directory where the script is located
$GITPATH = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "GITPATH is set to: $GITPATH"

# GitHub URL base for the necessary configuration files
$GITHUB_BASE_URL = "https://raw.githubusercontent.com/Jaredy899/setup/main"

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

# Function to run a script from local or GitHub
function Run-Script {
    param (
        [string]$scriptName,
        [string]$localPath,
        [string]$url
    )
    if (Test-Path "$localPath\$scriptName") {
        Write-Host "Running $scriptName from local directory..."
        & "$localPath\$scriptName"
    } else {
        Write-Host "Running $scriptName from GitHub..."
        Invoke-RestMethod -Uri "$url/$scriptName" -OutFile "$env:TEMP\$scriptName"
        & "$env:TEMP\$scriptName"
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
    Write-Host "4) Run ChrisTitusTech's Windows Utility"
    Write-Host "0) Exit"
    Write-Host

    $choice = Read-Host "Enter your choice (0-4)"

    switch ($choice) {
        1 { Run-Script -scriptName "Windows-Update.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
        2 { Run-Script -scriptName "setup2.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
        3 { Run-Script -scriptName "pwsh.ps1" -localPath "$GITPATH\my_powershell" -url "$GITHUB_BASE_URL/my_powershell" }
        4 { Run-Script -scriptName "ctt_win.ps1" -localPath $GITPATH -url "irm https://christitus.com/win | iex" }
        0 { Write-Host "Exiting setup script."; break }
        default { Write-Host "Invalid option. Please enter a number between 0 and 4." }
    }
}

Write-Host "#############################"
Write-Host "##                         ##"
Write-Host "## Setup script completed. ##"
Write-Host "##                         ##"
Write-Host "#############################"
