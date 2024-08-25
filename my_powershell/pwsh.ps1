# Set the PowerShell execution policy to RemoteSigned
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

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

# Function to download and run a script
function Invoke-DownloadAndRunScript {
    param (
        [string]$url,
        [string]$localPath
    )

    Write-Host "Downloading script from $url..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $localPath -ErrorAction Stop
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

# Determine the PowerShell profile path based on the PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 6) {
    $localProfilePath = "$env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
} else {
    $localProfilePath = "$env:UserProfile\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
}

# Function to initialize the PowerShell profile
function Initialize-Profile {
    Write-Host "Setting up PowerShell profile..."

    $profileDir = Split-Path $localProfilePath
    if (-not (Test-Path -Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force
    }

    # Check if the GitHub URL for the profile is set and not empty
    if (-not [string]::IsNullOrEmpty($githubProfileUrl)) {
        Invoke-WebRequest -Uri $githubProfileUrl -OutFile $localProfilePath
        Write-Host "PowerShell profile has been set up successfully."
    } else {
        Write-Error "GitHub profile URL is not set or is empty. Cannot set up the PowerShell profile."
    }
}

# Run the Initialize-Profile function
Initialize-Profile

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
    Invoke-WebRequest -Uri $configJsoncUrl -OutFile $localConfigJsoncPath
    Write-Host "fastfetch config.jsonc has been set up at $localConfigJsoncPath."

    # Download and set up starship.toml
    $localStarshipTomlPath = "$userConfigDir\starship.toml"
    Invoke-WebRequest -Uri $starshipTomlUrl -OutFile $localStarshipTomlPath
    Write-Host "starship.toml has been set up at $localStarshipTomlPath."
}

# Run the Initialize-ConfigFiles function
Initialize-ConfigFiles

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
