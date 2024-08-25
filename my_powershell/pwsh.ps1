# Define the GitHub base URL for your setup scripts
$githubBaseUrl = "https://raw.githubusercontent.com/Jaredy899/win/main/my_powershell"

# Corrected specific URLs for each setup script
$scoopScriptUrl = "$githubBaseUrl/scoop_install.ps1"
$appsScriptUrl = "$githubBaseUrl/apps_install.ps1"

# Local paths where the scripts will be temporarily downloaded
$scoopScriptPath = "$env:TEMP\scoop_install.ps1"
$appsScriptPath = "$env:TEMP\apps_install.ps1"

# Function to download and run a script
function DownloadAndRunScript {
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

# Download and run the Scoop installation script if Scoop is not installed
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Scoop is not installed. Proceeding with installation..."
    DownloadAndRunScript -url $scoopScriptUrl -localPath $scoopScriptPath
} else {
    Write-Host "Scoop is already installed."
}

# Function to check if applications are installed
function Check-Apps {
    $apps = @("bat", "starship", "fzf", "zoxide", "fastfetch", "curl", "nano", "yazi")
    $appsNotInstalled = @()

    foreach ($app in $apps) {
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            Write-Error "Scoop is not installed or not in PATH."
            return
        }
        if (-not (scoop list $app -q | Select-String -Pattern $app)) {
            $appsNotInstalled += $app
        }
    }

    return $appsNotInstalled
}

# Get a list of apps that are not installed
$missingApps = Check-Apps

# Download and run the applications installation script if any apps are missing
if ($missingApps.Count -gt 0) {
    Write-Host "The following apps are not installed: $missingApps. Proceeding with installation..."
    DownloadAndRunScript -url $appsScriptUrl -localPath $appsScriptPath
} else {
    Write-Host "All required applications are already installed."
}

# Determine the PowerShell profile path based on the PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 6) {
    $localProfilePath = "$env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
} else {
    $localProfilePath = "$env:UserProfile\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
}

# Example: Setup PowerShell profile and other configurations
$githubProfileUrl = "$githubBaseUrl/Microsoft.PowerShell_profile.ps1"

# Setup PowerShell profile
function Setup-Profile {
    Write-Host "Setting up PowerShell profile..."

    $profileDir = Split-Path $localProfilePath
    if (-not (Test-Path -Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force
    }

    Invoke-WebRequest -Uri $githubProfileUrl -OutFile $localProfilePath
    Write-Host "PowerShell profile has been set up successfully."
}

# Run the Setup-Profile function
Setup-Profile

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
