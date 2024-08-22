# Function to ensure scoop is installed and configured
function Ensure-Scoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Scoop not found. Installing Scoop..."

        # Install Scoop (without admin privileges)
        Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')

        # Add the main and extras buckets for additional applications
        scoop bucket add extras
        scoop bucket add versions
    } else {
        Write-Host "Scoop is already installed. Adding necessary buckets..."
        
        # Ensure necessary buckets are added
        scoop bucket add extras
        scoop bucket add versions
    }
}

# Ensure Scoop is installed and configured
Ensure-Scoop

# Install applications using Scoop
function Install-Apps {
    $apps = @("git", "7zip", "bat", "starship", "oh-my-posh", "tabby", "alacritty", "fzf", "zoxide", "fastfetch")

    foreach ($app in $apps) {
        Write-Host "Installing $app..."
        scoop install $app
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to install $app. Please check your internet connection or the app name." -ForegroundColor Red
            exit 1
        }
    }
}

# Run the installation of applications
Install-Apps

# Set the GITPATH variable to the directory where the script is located
$scriptPath = $MyInvocation.MyCommand.Path
if (-not $scriptPath) {
    $scriptPath = $PSScriptRoot
}

if (-not $scriptPath) {
    $scriptPath = Get-Location
}

$GITPATH = Split-Path -Parent $scriptPath

Write-Host "GITPATH is set to: $GITPATH"

# Function to copy configurations (no symbolic links)
function Link-Config {
    $configDir = "$env:UserProfile\.config"

    if (-not (Test-Path -Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force
    }

    $fastfetchConfigDir = "$configDir\fastfetch"
    $fastfetchConfig = "$fastfetchConfigDir\config.jsonc"

    if (-not (Test-Path -Path $fastfetchConfigDir)) {
        New-Item -ItemType Directory -Path $fastfetchConfigDir -Force
    }

    Write-Host "Copying config.jsonc to $fastfetchConfig from $GITPATH."
    Copy-Item -Path "$GITPATH\config.jsonc" -Destination $fastfetchConfig -Force

    $starshipConfig = "$configDir\starship.toml"
    if (-not (Test-Path -Path $starshipConfig)) {
        Write-Host "Copying starship.toml to $starshipConfig from $GITPATH."
        Copy-Item -Path "$GITPATH\starship.toml" -Destination $starshipConfig -Force
    } else {
        Write-Host "starship.toml already exists in $configDir."
    }
}

# Run the Link-Config function
Link-Config

# Function to update PowerShell profile
function Update-Profile {
    $profileFile = $PROFILE

    if (-not (Test-Path -Path $profileFile)) {
        New-Item -ItemType File -Path $profileFile -Force
    }

    # Add paths to environment if not already present
    $fastfetchPath = "$(scoop prefix fastfetch)\bin\fastfetch.exe"

    # Read the profile content line-by-line
    $profileContent = Get-Content $profileFile

    # Define the exact lines to add
    $linesToAdd = @(
        'starship init powershell | Out-String | Invoke-Expression',
        'zoxide init powershell | Out-String | Invoke-Expression',
        'fastfetch'
    )

    foreach ($line in $linesToAdd) {
        $found = $false
        foreach ($existingLine in $profileContent) {
            if ($existingLine.Trim() -eq $line.Trim()) {
                $found = $true
                break
            }
        }

        if (-not $found) {
            Add-Content $profileFile -Value "`n$line"
            Write-Host "Added '$line' to PowerShell profile."
        } else {
            Write-Host "'$line' is already in the PowerShell profile. Skipping..."
        }
    }

    Write-Host "PowerShell profile updated."
}

# Run the Update-Profile function
Update-Profile