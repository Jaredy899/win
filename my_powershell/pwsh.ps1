# Function to ensure Scoop is installed and configured
function Install-Scoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Scoop not found. Installing Scoop..."
        Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
    } else {
        Write-Host "Scoop is already installed."
    }

    # Set the Scoop directory to the global path
    $globalScoopDir = "C:\ProgramData\scoop"
    $bucketsDir = "$globalScoopDir\buckets"

    if (-not (Test-Path -Path $globalScoopDir)) {
        Write-Host "Creating Scoop global directory..."
        New-Item -Path $globalScoopDir -ItemType Directory -Force
    }

    if (-not (Test-Path -Path $bucketsDir)) {
        Write-Host "Creating Scoop buckets directory..."
        New-Item -Path $bucketsDir -ItemType Directory -Force
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
    scoop bucket add nerd-fonts
    scoop bucket add versions
}

# Ensure Scoop is installed and configured
Install-Scoop

# Install applications using Scoop
function Install-Apps {
    $apps = @("7zip", "bat", "starship", "oh-my-posh", "tabby", "alacritty", "fzf", "zoxide", "fastfetch", "curl")

    foreach ($app in $apps) {
        Write-Host "Installing $app..."
        scoop install $app -g  # Install apps globally
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to install $app. Please check your internet connection or the app name." -ForegroundColor Red
            exit 1
        }
    }
}

# Run the installation of applications
Install-Apps

# Function to install Cascadia Code Nerd Font using Scoop
function Install-Font {
    $fontName = "CascadiaCode-NF"
    $fontInstallDir = "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Windows\Fonts"

    Write-Host "Installing font '$fontName' using Scoop..."

    # Check if the font is already installed
    if (-not (Test-Path -Path "$fontInstallDir\CaskaydiaCoveNerdFont-Regular.ttf")) {
        scoop install nerd-fonts/$fontName -g  # Install font globally

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Font '$fontName' installed successfully."
        } else {
            Write-Host "Failed to install font '$fontName'. Please check your internet connection or the font name." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Font '$fontName' is already installed. Skipping installation."
    }
}

# Run the font installation
Install-Font

# URLs for config.jsonc and starship.toml in your GitHub repo
$githubBaseUrl = "https://raw.githubusercontent.com/Jaredy899/setup/main/my_powershell"
$configUrl = "$githubBaseUrl/config.jsonc"
$starshipUrl = "$githubBaseUrl/starship.toml"

# Paths for local files (if available)
$localConfigJsonc = "$PSScriptRoot\config.jsonc"
$localStarshipToml = "$PSScriptRoot\starship.toml"

# Function to copy configurations from GitHub or local
function Set-Config {
    $configDir = "$env:UserProfile\.config"

    if (-not (Test-Path -Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force
    }

    # Fastfetch configuration
    $fastfetchConfigDir = "$configDir\fastfetch"
    if (-not (Test-Path -Path $fastfetchConfigDir)) {
        New-Item -ItemType Directory -Path $fastfetchConfigDir -Force
    }

    if (Test-Path -Path $localConfigJsonc) {
        Write-Host "Local config.jsonc found. Using local copy."
        Copy-Item -Path $localConfigJsonc -Destination "$fastfetchConfigDir\config.jsonc" -Force
    } else {
        Write-Host "Local config.jsonc not found. Downloading from GitHub."
        Invoke-WebRequest -Uri $configUrl -OutFile "$fastfetchConfigDir\config.jsonc"
    }

    if (Test-Path -Path $localStarshipToml) {
        Write-Host "Local starship.toml found. Using local copy."
        Copy-Item -Path $localStarshipToml -Destination "$configDir\starship.toml" -Force
    } else {
        Write-Host "Local starship.toml not found. Downloading from GitHub."
        Invoke-WebRequest -Uri $starshipUrl -OutFile "$configDir\starship.toml"
    }

    Write-Host "Configuration files have been updated."
}

# Run the Set-Config function
Set-Config

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
        'Invoke-Expression (& { (zoxide init powershell | Out-String) })',
        'Invoke-Expression (&starship init powershell)',
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

# Instructions for Manual Font Configuration
Write-Host ""
Write-Host "=== Manual Font Configuration ==="
Write-Host "To set the font for Windows Terminal to 'CaskaydiaCove Nerd Font', please follow these steps:"
Write-Host "1. Open Windows Terminal."
Write-Host "2. Go to Settings."
Write-Host "3. Select the 'Windows PowerShell' profile."
Write-Host "4. Under 'Appearance', set the 'Font face' to 'CaskaydiaCove Nerd Font'."
Write-Host "5. Save and close the settings."
Write-Host "==============================="
Write-Host ""