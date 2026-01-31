# Windows Development Environment Setup Script
# Configures apps, fonts, dotfiles, and terminal settings

# Suppress progress bars and verbose output
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# ANSI color codes
$esc = [char]27
$Cyan = "${esc}[36m"
$Yellow = "${esc}[33m"
$Green = "${esc}[32m"
$Red = "${esc}[31m"
$Blue = "${esc}[34m"
$Reset = "${esc}[0m"

# Script directory and dotfiles config
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$githubBaseUrl = "https://raw.githubusercontent.com/Jaredy899/win/main"
$dotfilesRepo = if ($env:DOTFILES_REPO) { $env:DOTFILES_REPO } else { "https://github.com/Jaredy899/dotfiles.git" }
$dotfilesDir = "$env:USERPROFILE\dotfiles"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Read-UserInput {
    param([string]$Prompt = "")
    if ($Prompt) { Write-Host $Prompt -NoNewline }
    return Read-Host
}

function Backup-ConfigFile {
    param([string]$Path, [string]$Description = "config")
    if (Test-Path $Path) {
        $item = Get-Item $Path
        # Don't backup if it's already a symlink
        if ($item.LinkType -eq "SymbolicLink") {
            return $false
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$Path.backup_$timestamp"
        Copy-Item -Path $Path -Destination $backupPath -Force
        Write-Host "${Yellow}Backed up $Description to: $backupPath${Reset}"
        return $true
    }
    return $false
}

function Save-RemoteFile {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    try {
        Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
        return $true
    } catch {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            return $true
        } catch {
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($Url, $Destination)
                return $true
            } catch {
                Write-Host "${Red}All download methods failed for: $Url${Reset}"
                return $false
            }
        }
    }
}

# ============================================================================
# WINGET FUNCTIONS
# ============================================================================

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    # Also add common winget location
    $wingetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    if ($env:Path -notlike "*$wingetPath*") {
        $env:Path += ";$wingetPath"
    }
}

function Get-WingetCmd {
    # Try to find winget
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) { return $wingetCmd.Source }
    
    # Check common locations
    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
    )
    foreach ($p in $paths) {
        $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Get-WingetStatus {
    Refresh-Path
    $wingetCmd = Get-WingetCmd
    if ($wingetCmd) {
        try {
            $installedVersion = (& $wingetCmd --version).Trim('v')
            $latestVersion = (Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest").tag_name.Trim('v')
            if ([version]$installedVersion -lt [version]$latestVersion) {
                return "outdated"
            }
            return "installed"
        } catch {
            return "installed"
        }
    }
    return "not installed"
}

function Install-Winget {
    Write-Host "${Cyan}Checking Winget...${Reset}"
    $status = Get-WingetStatus

    if ($status -eq "installed") {
        Write-Host "${Green}Winget is up to date.${Reset}"
        return $true
    }

    Write-Host "${Yellow}Installing Winget and dependencies...${Reset}"

    try {
        $ComputerInfo = Get-ComputerInfo
        if (($ComputerInfo.WindowsVersion) -lt "1809") {
            Write-Host "${Red}Winget requires Windows 10 version 1809 or later.${Reset}"
            return $false
        }

        $wingetUrl = "https://aka.ms/getwinget"
        $vclibsUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $xamlUrl = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"

        $wingetPackage = "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $vclibsPackage = "$env:TEMP\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $xamlPackage = "$env:TEMP\Microsoft.UI.Xaml.2.8.x64.appx"

        Start-BitsTransfer -Source $wingetUrl -Destination $wingetPackage -ErrorAction Stop
        Start-BitsTransfer -Source $vclibsUrl -Destination $vclibsPackage -ErrorAction Stop
        Start-BitsTransfer -Source $xamlUrl -Destination $xamlPackage -ErrorAction Stop

        if (-not (Get-AppxPackage -Name "*VCLibs*" | Where-Object { $_.Version -ge "14.0.33321.0" })) {
            Add-AppxPackage -Path $vclibsPackage | Out-Null
        }
        if (-not (Get-AppxPackage -Name "*UI.Xaml*" | Where-Object { $_.Version -ge "2.8.6.0" })) {
            Add-AppxPackage -Path $xamlPackage | Out-Null
        }
        Add-AppxPackage -Path $wingetPackage | Out-Null

        # Refresh PATH so winget is available
        Refresh-Path
        Start-Sleep -Seconds 2
        
        Write-Host "${Green}Winget installed successfully.${Reset}"
        return $true
    } catch {
        Write-Host "${Red}Failed to install Winget: $($_.Exception.Message)${Reset}"
        return $false
    }
}

function Install-Apps {
    Write-Host "${Cyan}=== Installing Applications ===${Reset}"
    
    # Find winget
    $winget = Get-WingetCmd
    if (-not $winget) {
        Write-Host "${Red}Winget not found. Please install winget first.${Reset}"
        return $false
    }
    
    # Try local first, then download from GitHub
    $appsJson = $null
    
    # Check local script directory
    if ($scriptDir -and (Test-Path $scriptDir)) {
        $localAppsJson = Join-Path $scriptDir "apps.json"
        if (Test-Path $localAppsJson) {
            $appsJson = $localAppsJson
            Write-Host "${Blue}Using local apps.json${Reset}"
        }
    }
    
    # Download from GitHub if not found locally
    if (-not $appsJson) {
        Write-Host "${Yellow}Downloading apps.json from GitHub...${Reset}"
        $appsJson = "$env:TEMP\apps.json"
        try {
            Invoke-WebRequest -Uri "$githubBaseUrl/apps.json" -OutFile $appsJson -UseBasicParsing -ErrorAction Stop
            Write-Host "${Green}Downloaded apps.json${Reset}"
        } catch {
            Write-Host "${Red}Failed to download apps.json from GitHub.${Reset}"
            Write-Host "${Yellow}URL: $githubBaseUrl/apps.json${Reset}"
            Write-Host "${Yellow}Make sure the file exists on the main branch.${Reset}"
            return $false
        }
    }

    Write-Host "${Yellow}Installing applications from apps.json...${Reset}"
    & $winget import -i $appsJson --accept-package-agreements --accept-source-agreements --ignore-unavailable
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "${Green}Applications installed successfully.${Reset}"
        return $true
    } else {
        Write-Host "${Yellow}Some applications may have failed. Check output above.${Reset}"
        return $true
    }
}

# ============================================================================
# FONT INSTALLATION
# ============================================================================

function Install-FiraCodeFont {
    Write-Host "${Cyan}=== Installing Fira Code Nerd Font ===${Reset}"
    
    # Check if already installed
    $fontInstalled = $false
    try {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families
        foreach ($font in $fontFamilies) {
            if ($font.Name -like "*Fira*Code*" -or $font.Name -like "*FiraCode*") {
                $fontInstalled = $true
                break
            }
        }
    } catch {
        # Check font files directly
        if (Get-ChildItem -Path "C:\Windows\Fonts" -Filter "*FiraCode*" -ErrorAction SilentlyContinue) {
            $fontInstalled = $true
        }
    }

    if ($fontInstalled) {
        Write-Host "${Blue}Fira Code Nerd Font is already installed.${Reset}"
        return $true
    }

    try {
        Write-Host "${Yellow}Downloading Fira Code Nerd Font...${Reset}"
        
        # Get latest release from GitHub
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" -Headers @{ 'User-Agent' = 'PowerShell Script' }
        $asset = $release.assets | Where-Object { $_.name -like "FiraCode*.zip" } | Select-Object -First 1
        
        if (-not $asset) {
            Write-Host "${Red}Could not find FiraCode font in latest release.${Reset}"
            return $false
        }

        $zipPath = "$env:TEMP\FiraCode.zip"
        $extractPath = "$env:TEMP\FiraCode"

        # Download
        if (-not (Save-RemoteFile -Url $asset.browser_download_url -Destination $zipPath)) {
            return $false
        }

        # Extract
        Write-Host "${Yellow}Extracting font files...${Reset}"
        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force
        }
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        # Install fonts using Shell.Application (proper Windows font installation)
        Write-Host "${Yellow}Installing font files...${Reset}"
        $fontsFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
        $fontFiles = Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf"
        $installed = 0
        
        foreach ($fontFile in $fontFiles) {
            if (-not (Test-Path "C:\Windows\Fonts\$($fontFile.Name)")) {
                try {
                    $fontsFolder.CopyHere($fontFile.FullName, 0x14)
                    $installed++
                } catch {
                    # Font may already exist or require admin
                }
            }
        }

        # Cleanup
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

        Write-Host "${Green}Fira Code Nerd Font installed ($installed files).${Reset}"
        return $true
    }
    catch {
        Write-Host "${Red}Failed to install font: $($_.Exception.Message)${Reset}"
        return $false
    }
}

# ============================================================================
# WINDOWS TERMINAL CONFIGURATION
# ============================================================================

function Initialize-WindowsTerminal {
    Write-Host "${Cyan}=== Configuring Windows Terminal ===${Reset}"
    
    $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    
    if (-not (Test-Path $wtSettingsPath)) {
        Write-Host "${Yellow}Windows Terminal settings not found. It may need to be launched first.${Reset}"
        return $false
    }

    try {
        # Backup existing settings
        Backup-ConfigFile -Path $wtSettingsPath -Description "Windows Terminal settings"

        # Read current settings
        $settingsContent = Get-Content $wtSettingsPath -Raw
        $settings = $settingsContent | ConvertFrom-Json

        # Find PowerShell 7 profile
        $ps7Profile = $settings.profiles.list | Where-Object {
            ($_.source -eq "Windows.Terminal.PowershellCore") -or 
            ($_.name -match "PowerShell" -and $_.commandline -match "pwsh")
        } | Select-Object -First 1

        if ($ps7Profile) {
            # Set as default profile
            $settings.defaultProfile = $ps7Profile.guid
            Write-Host "${Green}Set PowerShell 7 as default profile.${Reset}"

            # Set font
            if (-not $ps7Profile.PSObject.Properties['font']) {
                $ps7Profile | Add-Member -NotePropertyName 'font' -NotePropertyValue @{} -Force
            }
            $ps7Profile.font = @{ face = "FiraCode Nerd Font Mono" }
            Write-Host "${Green}Set Fira Code Nerd Font Mono as terminal font.${Reset}"
        } else {
            Write-Host "${Yellow}PowerShell 7 profile not found in Windows Terminal.${Reset}"
        }

        # Save settings
        $settings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
        Write-Host "${Green}Windows Terminal configured.${Reset}"
        return $true
    }
    catch {
        Write-Host "${Red}Failed to configure Windows Terminal: $($_.Exception.Message)${Reset}"
        return $false
    }
}

# ============================================================================
# DOTFILES AND CONFIGURATION
# ============================================================================

function Invoke-CloneDotfiles {
    Write-Host "${Cyan}=== Setting up Dotfiles ===${Reset}"
    
    $parentDir = Split-Path $dotfilesDir -Parent
    if (-not (Test-Path -Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    if (Test-Path -Path $dotfilesDir) {
        Write-Host "${Yellow}Dotfiles directory exists. Pulling latest changes...${Reset}"
        try {
            Push-Location $dotfilesDir
            git pull --quiet 2>&1 | Out-Null
            Pop-Location
            Write-Host "${Green}Dotfiles updated.${Reset}"
        } catch {
            Write-Host "${Red}Failed to update dotfiles: $($_.Exception.Message)${Reset}"
        }
    } else {
        Write-Host "${Yellow}Cloning dotfiles repository...${Reset}"
        try {
            git clone --quiet $dotfilesRepo $dotfilesDir 2>&1 | Out-Null
            Write-Host "${Green}Dotfiles cloned.${Reset}"
        } catch {
            Write-Host "${Red}Failed to clone dotfiles: $($_.Exception.Message)${Reset}"
        }
    }
}

function Initialize-PowerShellProfile {
    param([string]$ProfilePath)
    
    $profileDir = Split-Path $ProfilePath
    if (-not (Test-Path -Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    $sourceProfile = Join-Path $dotfilesDir "powershell\Microsoft.PowerShell_profile.ps1"
    if (-not (Test-Path -Path $sourceProfile)) {
        Write-Host "${Yellow}Source profile not found: $sourceProfile${Reset}"
        return $false
    }

    # Backup if not already a symlink
    if (Test-Path -Path $ProfilePath) {
        $item = Get-Item $ProfilePath
        if ($item.LinkType -ne "SymbolicLink") {
            Backup-ConfigFile -Path $ProfilePath -Description "PowerShell profile"
        }
        Remove-Item -Path $ProfilePath -Force
    }

    try {
        New-Item -ItemType SymbolicLink -Path $ProfilePath -Target $sourceProfile -Force | Out-Null
        Write-Host "${Green}Profile symlinked: $ProfilePath${Reset}"
        return $true
    } catch {
        Write-Host "${Red}Failed to create symlink: $($_.Exception.Message)${Reset}"
        return $false
    }
}

function Initialize-ConfigFiles {
    Write-Host "${Cyan}=== Setting up Config Files ===${Reset}"
    
    $userConfigDir = "$env:UserProfile\.config"
    $fastfetchConfigDir = "$userConfigDir\fastfetch"
    $miseConfigDir = "$userConfigDir\mise"

    # Create directories
    @($fastfetchConfigDir, $miseConfigDir) | ForEach-Object {
        if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
    }

    # Config file mappings: source -> destination
    $configs = @(
        @{ Source = "config\fastfetch\windows.jsonc"; Dest = "$fastfetchConfigDir\config.jsonc"; Name = "Fastfetch" },
        @{ Source = "config\starship.toml"; Dest = "$userConfigDir\starship.toml"; Name = "Starship" },
        @{ Source = "config\mise\config.toml"; Dest = "$miseConfigDir\config.toml"; Name = "Mise" }
    )

    foreach ($config in $configs) {
        $sourcePath = Join-Path $dotfilesDir $config.Source
        $destPath = $config.Dest

        if (-not (Test-Path $sourcePath)) {
            Write-Host "${Yellow}$($config.Name) config not found in dotfiles.${Reset}"
            continue
        }

        if (Test-Path $destPath) {
            $item = Get-Item $destPath
            if ($item.LinkType -ne "SymbolicLink") {
                Backup-ConfigFile -Path $destPath -Description "$($config.Name) config"
            }
            Remove-Item -Path $destPath -Force
        }

        try {
            New-Item -ItemType SymbolicLink -Path $destPath -Target $sourcePath -Force | Out-Null
            Write-Host "${Green}$($config.Name) config symlinked.${Reset}"
        } catch {
            Write-Host "${Red}Failed to symlink $($config.Name) config.${Reset}"
        }
    }
}

# ============================================================================
# ADDITIONAL SETUP
# ============================================================================

function Install-TerminalIcons {
    Write-Host "${Cyan}=== Installing Terminal-Icons ===${Reset}"
    
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Write-Host "${Blue}Terminal-Icons already installed.${Reset}"
        return
    }

    try {
        # Ensure NuGet provider is installed
        if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
            Write-Host "${Yellow}Installing NuGet provider...${Reset}"
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
        }
        
        # Trust PSGallery
        $psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if ($psGallery -and $psGallery.InstallationPolicy -ne "Trusted") {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
        
        Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Scope CurrentUser
        Write-Host "${Green}Terminal-Icons installed.${Reset}"
    } catch {
        Write-Host "${Red}Failed to install Terminal-Icons: $($_.Exception.Message)${Reset}"
    }
}

function Initialize-NeovimConfig {
    Write-Host "${Cyan}=== Setting up Neovim with LazyVim ===${Reset}"
    
    $nvimConfigDir = "$env:LOCALAPPDATA\nvim"

    if (Test-Path -Path $nvimConfigDir) {
        Write-Host "${Blue}Neovim config already exists.${Reset}"
        return $true
    }

    try {
        New-Item -ItemType Directory -Path $nvimConfigDir -Force | Out-Null
        git clone --quiet https://github.com/LazyVim/starter $nvimConfigDir 2>&1 | Out-Null
        
        # Remove .git so user can add to their own repo
        $gitDir = Join-Path $nvimConfigDir '.git'
        if (Test-Path $gitDir) {
            Remove-Item -Path $gitDir -Recurse -Force | Out-Null
        }

        Write-Host "${Green}LazyVim installed. Run 'nvim' to complete setup.${Reset}"
        return $true
    } catch {
        Write-Host "${Red}Failed to install LazyVim: $($_.Exception.Message)${Reset}"
        return $false
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host ""
Write-Host "${Cyan}========================================${Reset}"
Write-Host "${Cyan}  Windows Development Environment Setup ${Reset}"
Write-Host "${Cyan}========================================${Reset}"
Write-Host ""

# Install Winget
Install-Winget

# Install applications
Install-Apps

# Install font
Install-FiraCodeFont

# Refresh PATH
Write-Host "${Yellow}Refreshing environment variables...${Reset}"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Clone/update dotfiles
Invoke-CloneDotfiles

# Set mise environment variable
$env:MISE_PWSH_CHPWD_WARNING = "0"
[Environment]::SetEnvironmentVariable("MISE_PWSH_CHPWD_WARNING", "0", [EnvironmentVariableTarget]::User)

# Setup PowerShell profiles
Write-Host "${Cyan}=== Setting up PowerShell Profiles ===${Reset}"
$ps5ProfilePath = "$env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$ps7ProfilePath = "$env:UserProfile\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
Initialize-PowerShellProfile -ProfilePath $ps5ProfilePath
Initialize-PowerShellProfile -ProfilePath $ps7ProfilePath

# Setup config files
Initialize-ConfigFiles

# Configure Windows Terminal
Initialize-WindowsTerminal

# Install Terminal-Icons
Install-TerminalIcons

# Setup Neovim
Initialize-NeovimConfig

# Final summary
Write-Host ""
Write-Host "${Cyan}========================================${Reset}"
Write-Host "${Green}  Setup Complete!${Reset}"
Write-Host "${Cyan}========================================${Reset}"
Write-Host ""
Write-Host "Installed:"
Write-Host "  - Development applications via winget"
Write-Host "  - Fira Code Nerd Font"
Write-Host "  - PowerShell profiles (symlinked)"
Write-Host "  - Starship, Fastfetch, Mise configs"
Write-Host "  - Windows Terminal configuration"
Write-Host "  - LazyVim for Neovim"
Write-Host ""
Write-Host "Dotfiles location: $dotfilesDir"
Write-Host ""
Write-Host "${Yellow}Restart your terminal to apply all changes.${Reset}"
