# Define the GitHub base URL for your setup scripts
$githubBaseUrl = "https://raw.githubusercontent.com/Jaredy899/win/main/my_powershell"

# Corrected specific URLs for each setup script
$appsScriptUrl = "$githubBaseUrl/apps_install.ps1"
$configJsoncUrl = "$githubBaseUrl/config.jsonc"
$starshipTomlUrl = "$githubBaseUrl/starship.toml"
$githubProfileUrl = "$githubBaseUrl/Microsoft.PowerShell_profile.ps1"
$fontScriptUrl = "$githubBaseUrl/install_fira_code.ps1"
$wingetScriptUrl = "$githubBaseUrl/install_winget.ps1"

# Local paths where the scripts will be temporarily downloaded
$appsScriptPath = "$env:TEMP\apps_install.ps1"
$fontScriptPath = "$env:TEMP\install_fira_code.ps1"
$wingetScriptPath = "$env:TEMP\install_winget.ps1"

# Function to download and run a script using Start-BitsTransfer
function Invoke-DownloadAndRunScript {
    param (
        [string]$url,
        [string]$localPath
    )

    Write-Host "Downloading script from $url..."
    try {
        Start-BitsTransfer -Source $url -Destination $localPath -ErrorAction Stop
        Write-Host "Running script $localPath..."
        & $localPath
    }
    catch {
        Write-Error "Failed to download or run the script from $url. Error: $_"
    }
}

# Ensure Winget is installed or updated
Invoke-DownloadAndRunScript -url $wingetScriptUrl -localPath $wingetScriptPath

# Always run the applications installation script
Write-Host "Running the applications installation script..."
Invoke-DownloadAndRunScript -url $appsScriptUrl -localPath $appsScriptPath

# Run the font installation script, which includes the font check
Write-Host "Running the Fira Code Nerd Font installation script..."
Invoke-DownloadAndRunScript -url $fontScriptUrl -localPath $fontScriptPath

# URLs for GitHub profile configuration
$githubProfileUrl = "https://raw.githubusercontent.com/Jaredy899/win/main/my_powershell/Microsoft.PowerShell_profile.ps1"

# Function to initialize PowerShell profile
function Initialize-Profile {
    param (
        [string]$profilePath,
        [string]$profileUrl
    )

    Write-Host "Setting up PowerShell profile at $profilePath..."

    $profileDir = Split-Path $profilePath
    if (-not (Test-Path -Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force
    }

    # Check if the GitHub URL for the profile is set and not empty
    if (-not [string]::IsNullOrEmpty($profileUrl)) {
        Start-BitsTransfer -Source $profileUrl -Destination $profilePath -ErrorAction Stop
        Write-Host "PowerShell profile has been set up successfully at $profilePath."
    } else {
        Write-Error "GitHub profile URL is not set or is empty. Cannot set up the PowerShell profile at $profilePath."
    }
}

# Paths for PowerShell 5 and PowerShell 7 profiles
$ps5ProfilePath = "$env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$ps7ProfilePath = "$env:UserProfile\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"

# Initialize PowerShell 5 profile
Initialize-Profile -profilePath $ps5ProfilePath -profileUrl $githubProfileUrl

# Initialize PowerShell 7 profile
Initialize-Profile -profilePath $ps7ProfilePath -profileUrl $githubProfileUrl

# Function to initialize configuration files
function Initialize-ConfigFiles {
    Write-Host "Setting up configuration files..."

    $userConfigDir = "$env:UserProfile\.config"
    $fastfetchConfigDir = "$userConfigDir\fastfetch"

    # Ensure directories exist
    if (-not (Test-Path -Path $fastfetchConfigDir)) {
        New-Item -ItemType Directory -Path $fastfetchConfigDir -Force
    }

    # Download and set up config.jsonc for fastfetch
    $localConfigJsoncPath = "$fastfetchConfigDir\config.jsonc"
    Start-BitsTransfer -Source $configJsoncUrl -Destination $localConfigJsoncPath -ErrorAction Stop
    Write-Host "fastfetch config.jsonc has been set up at $localConfigJsoncPath."

    # Download and set up starship.toml
    $localStarshipTomlPath = "$userConfigDir\starship.toml"
    Start-BitsTransfer -Source $starshipTomlUrl -Destination $localStarshipTomlPath -ErrorAction Stop
    Write-Host "starship.toml has been set up at $localStarshipTomlPath."
}

# Run the Initialize-ConfigFiles function
Initialize-ConfigFiles

# Install Terminal-Icons module if not already installed
function Install-TerminalIcons {
    if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
        Write-Host "Installing Terminal-Icons module..."
        Install-Module -Name Terminal-Icons -Repository PSGallery -Force
        Write-Host "Terminal-Icons module installed successfully."
    } else {
        Write-Host "Terminal-Icons module is already installed."
    }
}

# Run the Install-TerminalIcons function
Install-TerminalIcons

# Instructions for Manual Font Configuration
Write-Host ""
Write-Host "=== Manual Font Configuration ==="
Write-Host "To set the font for Windows Terminal to 'Fira Code Nerd Font', please follow these steps:"
Write-Host "1. Open Windows Terminal."
Write-Host "2. Go to Settings."
Write-Host "3. Select the 'Windows PowerShell' profile."
Write-Host "4. Under 'Appearance', set the 'Font face' to 'Fira Code Nerd Font'."
Write-Host "5. Save and close the settings."
Write-Host "==============================="
Write-Host ""
# Inform the user about automatic updates and custom alias preservation
Write-Host "Note: This profile will update every time you run the script." -ForegroundColor Yellow
Write-Host "If you wish to keep your own aliases or customizations, create a separate profile.ps1 file." -ForegroundColor Yellow
Write-Host "You can use nano to create or edit this file by running the following command:" -ForegroundColor Cyan
Write-Host "`nStart-Process 'nano' -ArgumentList '$HOME\Documents\PowerShell\profile.ps1'`n" -ForegroundColor White
Write-Host "After adding your custom aliases or functions, save the file and restart your shell to apply the changes." -ForegroundColor Magenta