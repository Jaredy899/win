# Function to ensure scoop is installed and configured
function Ensure-Scoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Scoop not found. Installing Scoop..."

        # Install Scoop (without admin privileges)
        Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
    } else {
        Write-Host "Scoop is already installed."
    }

    # Ensure Git is installed before adding buckets
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is required for Scoop buckets. Installing Git..."
        scoop install git
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to install Git. Please check your internet connection or the app name." -ForegroundColor Red
            exit 1
        }
    }

    # Add the main and extras buckets for additional applications
    Write-Host "Adding Scoop buckets..."
    scoop bucket add main
    scoop bucket add extras
    scoop bucket add versions
}

# Ensure Scoop is installed and configured
Ensure-Scoop

# Install applications using Scoop
function Install-Apps {
    $apps = @("7zip", "bat", "starship", "oh-my-posh", "tabby", "alacritty", "fzf", "zoxide", "fastfetch")

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
$scriptPath = $PSScriptRoot
if (-not $scriptPath -or $scriptPath -eq "") {
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

    # Fastfetch configuration
    $fastfetchConfigDir = "$configDir\fastfetch"
    if (-not (Test-Path -Path $fastfetchConfigDir)) {
        New-Item -ItemType Directory -Path $fastfetchConfigDir -Force
    }

    if (Test-Path "$GITPATH\config.jsonc") {
        Write-Host "Copying config.jsonc to $fastfetchConfigDir from $GITPATH."
        Copy-Item -Path "$GITPATH\config.jsonc" -Destination "$fastfetchConfigDir\config.jsonc" -Force
    } else {
        Write-Host "config.jsonc not found in $GITPATH." -ForegroundColor Red
    }

    # Starship configuration
    $starshipConfig = "$configDir\starship.toml"
    if (Test-Path "$GITPATH\starship.toml") {
        Write-Host "Copying starship.toml to $configDir from $GITPATH."
        Copy-Item -Path "$GITPATH\starship.toml" -Destination "$configDir\starship.toml" -Force
    } else {
        Write-Host "starship.toml not found in $GITPATH." -ForegroundColor Red
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