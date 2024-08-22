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
    $apps = @("7zip", "bat", "starship", "oh-my-posh", "tabby", "alacritty", "fzf", "zoxide", "fastfetch", "curl")

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

# Function to check if a font is installed
function Is-FontInstalled {
    param (
        [string]$fontName
    )
    $fontKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    $installedFonts = Get-ItemProperty -Path $fontKey
    return $installedFonts.PSObject.Properties.Name -contains $fontName
}

# Function to install MesloLGS Nerd Font Mono using curl
function Install-Font {
    $fontName = "MesloLGS NF"
    $fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    $fontDir = "$env:UserProfile\Fonts"

    if (-not (Test-Path -Path $fontDir)) {
        New-Item -ItemType Directory -Path $fontDir -Force
    }

    if (-not (Is-FontInstalled $fontName)) {
        Write-Host "Installing font '$fontName' using curl..."
        $tempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("TempDir_" + [System.Guid]::NewGuid().ToString())) -Force
        Start-Process -FilePath "curl.exe" -ArgumentList "-L $fontUrl -o `"$tempDir\Meslo.zip`"" -Wait -NoNewWindow
        Expand-Archive -Path "$tempDir\Meslo.zip" -DestinationPath $fontDir -Force
        Remove-Item -Recurse -Force $tempDir
        Write-Host "Font '$fontName' installed successfully."
    } else {
        Write-Host "Font '$fontName' is already installed."
    }
}

# Run the font installation
Install-Font

# URLs for config.jsonc and starship.toml in your GitHub repo
$githubBaseUrl = "https://raw.githubusercontent.com/Jaredy899/setup/main/my_powershell"
$configUrl = "$githubBaseUrl/config.jsonc"
$starshipUrl = "$githubBaseUrl/starship.toml"

# Function to copy configurations from GitHub
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

    Write-Host "Downloading and saving config.jsonc to $fastfetchConfigDir."
    Invoke-WebRequest -Uri $configUrl -OutFile "$fastfetchConfigDir\config.jsonc"

    # Starship configuration
    Write-Host "Downloading and saving starship.toml to $configDir."
    Invoke-WebRequest -Uri $starshipUrl -OutFile "$configDir\starship.toml"
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