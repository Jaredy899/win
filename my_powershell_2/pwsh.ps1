# Define the GitHub base URL for your setup scripts
$githubBaseUrl = "https://raw.githubusercontent.com/Jaredy899/win/main/my_powershell"

# Corrected specific URLs for each setup script
$appsScriptUrl = "$githubBaseUrl/apps_install.ps1"
$configJsoncUrl = "$githubBaseUrl/config.jsonc"
$starshipTomlUrl = "$githubBaseUrl/starship.toml"
$githubProfileUrl = "$githubBaseUrl/Microsoft.PowerShell_profile.ps1"
$fontScriptUrl = "$githubBaseUrl/install_fira_code.ps1"

# Local paths where the scripts will be temporarily downloaded
$appsScriptPath = "$env:TEMP\apps_install.ps1"
$fontScriptPath = "$env:TEMP\install_fira_code.ps1"
$wingetPackageUrl = "https://cdn.winget.microsoft.com/cache/source.msix"
$wingetPackagePath = "$env:TEMP\source.msix"

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

# Function to install or update Winget using the source.msix package
function Install-Winget {
    Write-Host "Downloading Winget package from $wingetPackageUrl..."
    try {
        Invoke-WebRequest -Uri $wingetPackageUrl -OutFile $wingetPackagePath -ErrorAction Stop
        Write-Host "Installing Winget package..."
        Add-AppxPackage -Path $wingetPackagePath -ErrorAction Stop
        Write-Host "Winget installation or update completed successfully."
    }
    catch {
        Write-Error "Failed to install Winget. Error: $_"
    }
}

# Ensure Winget is installed or updated
Install-Winget

# Function to check if applications are installed using Winget
function Test-Apps {
    $apps = @("Starship.Starship", "junegunn.fzf", "ajeetdsouza.zoxide", "Fastfetch-cli.Fastfetch", "GNU.Nano", "sxyazi.yazi")
    $appsNotInstalled = @()

    foreach ($app in $apps) {
        $result = winget list --id $app -q
        if (-not $result) {
            $appsNotInstalled += $app
        }
    }

    return $appsNotInstalled
}

# Check if the required applications are installed
$missingApps = Test-Apps

# Download and run the applications installation script if any apps are missing
if ($missingApps.Count -gt 0) {
    Write-Host "The following apps are not installed: $missingApps. Proceeding with installation..."
    Invoke-DownloadAndRunScript -url $appsScriptUrl -localPath $appsScriptPath
} else {
    Write-Host "All required applications are already installed."
}

# Function to check if Fira Code Nerd Font is installed
function Test-FiraCodeFont {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    return $fontFamilies -contains "FiraCode Nerd Font"
}

# Check if Fira Code Nerd Font is installed and install if not
if (-not (Test-FiraCodeFont)) {
    Write-Host "Fira Code Nerd Font is not installed. Proceeding with installation..."
    Invoke-DownloadAndRunScript -url $fontScriptUrl -localPath $fontScriptPath
} else {
    Write-Host "Fira Code Nerd Font is already installed."
}

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
