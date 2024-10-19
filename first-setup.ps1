# Set the GITPATH variable to the directory where the script is located
$GITPATH = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "GITPATH is set to: $GITPATH"

# GitHub URL base for the necessary configuration files
$GITHUB_BASE_URL = "https://raw.githubusercontent.com/Jaredy899/win/refs/heads/main"

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

# Function to download and extract Nord backgrounds
function Get-NordBackgrounds {
    $documentsPath = [Environment]::GetFolderPath("MyDocuments")
    $backgroundsPath = Join-Path $documentsPath "nord_backgrounds"
    $zipPath = Join-Path $documentsPath "nord_backgrounds.zip"

    # Check if the directory already exists
    if (Test-Path $backgroundsPath) {
        $overwrite = Read-Host "The nord_backgrounds folder already exists. Do you want to overwrite it? (y/n)"
        if ($overwrite -eq 'y') {
            Remove-Item $backgroundsPath -Recurse -Force
        } else {
            Write-Host "Skipping Nord backgrounds download."
            return
        }
    }

    Write-Host "Downloading Nord backgrounds..."
    $url = "https://github.com/ChrisTitusTech/nord-background/archive/refs/heads/main.zip"
    Start-BitsTransfer -Source $url -Destination $zipPath

    Write-Host "Extracting backgrounds..."
    Expand-Archive -Path $zipPath -DestinationPath $documentsPath -Force
    
    # Check if the extracted folder exists before renaming
    $extractedPath = Join-Path $documentsPath "nord-background-main"
    if (Test-Path $extractedPath) {
        # If nord_backgrounds already exists (which it shouldn't at this point), remove it
        if (Test-Path $backgroundsPath) {
            Remove-Item $backgroundsPath -Recurse -Force
        }
        Rename-Item -Path $extractedPath -NewName "nord_backgrounds"
    } else {
        Write-Host "Error: Extracted folder not found. Extraction may have failed."
    }

    # Clean up the zip file
    if (Test-Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }

    if (Test-Path $backgroundsPath) {
        Write-Host "Nord backgrounds have been downloaded and extracted to: $backgroundsPath"
    } else {
        Write-Host "Error: Failed to set up Nord backgrounds."
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
    Write-Host "4) Activate Windows"
    Write-Host "5) Download Nord Backgrounds"
    Write-Host "6) Run ChrisTitusTech's Windows Utility"
    Write-Host "0) Exit"
    Write-Host

    $choice = Read-Host "Enter your choice (0-6)"

    switch ($choice) {
        1 { Invoke-Script -scriptName "Windows-Update.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
        2 { Invoke-Script -scriptName "setup2.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
        3 { Invoke-Script -scriptName "pwsh.ps1" -localPath "$GITPATH\my_powershell" -url "$GITHUB_BASE_URL/my_powershell" }
        4 { Invoke-WindowsActivation }
        5 { Get-NordBackgrounds }
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
