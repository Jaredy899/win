# Suppress all progress bars and verbose output
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# ANSI color codes for consistent output
$esc   = [char]27
$Cyan  = "${esc}[36m"
$Yellow= "${esc}[33m"
$Green = "${esc}[32m"
$Red   = "${esc}[31m"
$Reset = "${esc}[0m"

# Centralized dotfiles repository
$dotfilesRepo = if ($env:DOTFILES_REPO) { $env:DOTFILES_REPO } else { "https://github.com/Jaredy899/dotfiles.git" }
$dotfilesDir = "$env:USERPROFILE\dotfiles"

# Simple input function that works reliably
function Read-UserInput {
    param([string]$Prompt = "")
    if ($Prompt) { Write-Host $Prompt -NoNewline }
    return Read-Host
}

# Robust download function with fallbacks
function Save-RemoteFile {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    try {
        Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
        return $true
    } catch {
        Write-Host "${Yellow}BITS failed, trying Invoke-WebRequest...${Reset}"
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            return $true
        } catch {
            Write-Host "${Yellow}Invoke-WebRequest failed, trying WebClient...${Reset}"
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

# Clone/update dotfiles repository
function Invoke-CloneDotfiles {
    Write-Host "${Yellow}Cloning/updating dotfiles repository...${Reset}"
    $parentDir = Split-Path $dotfilesDir -Parent
    if (-not (Test-Path -Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    if (Test-Path -Path $dotfilesDir) {
        Write-Host "${Cyan}Dotfiles directory exists. Pulling latest changes...${Reset}"
        try {
            Push-Location $dotfilesDir
            git pull --quiet
            Pop-Location
        } catch {
            Write-Host "${Red}Failed to update dotfiles: $($_.Exception.Message)${Reset}"
        }
    } else {
        Write-Host "${Cyan}Cloning dotfiles repository...${Reset}"
        try {
            git clone --quiet $dotfilesRepo $dotfilesDir
            Write-Host "${Green}Dotfiles cloned successfully!${Reset}"
        } catch {
            Write-Host "${Red}Failed to clone dotfiles: $($_.Exception.Message)${Reset}"
            return
        }
    }
}

# Simplified download and run function
function Invoke-DownloadAndRunScript {
    param([string]$url, [string]$localPath)
    Write-Host "${Yellow}Downloading: $url${Reset}"
    if (Save-RemoteFile -Url $url -Destination $localPath) {
        Write-Host "${Cyan}Running: $localPath${Reset}"
        try { & $localPath } catch { Write-Host "${Red}Script failed: $($_.Exception.Message)${Reset}" }
    } else {
        Write-Host "${Red}Failed to download: $url${Reset}"
    }
}

# Check Winget installation status
function Get-WingetStatus {
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        $installedVersion = (winget --version).Trim('v')
        try {
            $latestVersion = (Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest").tag_name.Trim('v')
            if ([version]$installedVersion -lt [version]$latestVersion) {
                return "outdated"
            } else {
                return "installed"
            }
        } catch {
            return "installed" # Assume installed if can't check latest
        }
    } else {
        return "not installed"
    }
}

# Install or update Winget
function Install-Winget {
    Write-Host "${Cyan}Checking Winget...${Reset}"
    $status = Get-WingetStatus

    if ($status -eq "installed") {
        Write-Host "${Green}Winget is already installed and up to date!${Reset}"
        return
    }

    Write-Host "${Yellow}Installing Winget and dependencies...${Reset}"

    try {
        $ComputerInfo = Get-ComputerInfo
        if (($ComputerInfo.WindowsVersion) -lt "1809") {
            Write-Host "${Red}Winget requires Windows 10 version 1809 or later${Reset}"
            return
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

        Write-Host "${Green}Winget installed successfully!${Reset}"
    } catch {
        Write-Host "${Red}Failed to install Winget: $($_.Exception.Message)${Reset}"
    }
}

# Font installation function
function Install-FiraCodeFont {
    # Check if already installed
    if (Get-ChildItem -Path "C:\Windows\Fonts" -Filter "*FiraCode*" -ErrorAction SilentlyContinue) {
        Write-Host "${Cyan}Fira Code Nerd Font already installed.${Reset}"
        return
    }

    try {
        Write-Host "${Yellow}Installing Fira Code Nerd Font...${Reset}"
        
        # Get latest release
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
        $asset = $release.assets | Where-Object { $_.name -like "FiraCode*.zip" } | Select-Object -First 1
        
        if (-not $asset) {
            Write-Host "${Red}Could not find FiraCode font in latest release.${Reset}"
            return
        }

        # Download and extract
        $zipPath = "$env:TEMP\FiraCode.zip"
        Save-RemoteFile -Url $asset.browser_download_url -Destination $zipPath | Out-Null
        $extractPath = "$env:TEMP\FiraCode"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        # Install fonts (copy directly to Fonts folder)
        Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf" | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination "C:\Windows\Fonts\$($_.Name)" -Force -ErrorAction SilentlyContinue
        }

        # Cleanup
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

        Write-Host "${Green}Fira Code Nerd Font installed!${Reset}"
    }
    catch {
        Write-Host "${Red}Failed to install Fira Code Nerd Font: $_${Reset}"
    }
}

# Install applications
function Install-Apps {
    $apps = @(
        "Starship.Starship",
        "junegunn.fzf",
        "ajeetdsouza.zoxide",
        "Fastfetch-cli.Fastfetch",
        "sharkdp.bat",
        "GNU.Nano",
        "eza-community.eza",
        "sxyazi.yazi",
        "Microsoft.WindowsTerminal",
        "Microsoft.PowerShell",
        "Helix.Helix",
        "Neovim.Neovim",
        "Git.Git",
        "jdx.mise",
        "Gyan.FFmpeg",
        "7zip.7zip",
        "jqlang.jq",
        "oschwartz10612.Poppler",
        "sharkdp.fd",
        "BurntSushi.ripgrep.MSVC",
        "ImageMagick.ImageMagick"
    )

    Write-Host "${Cyan}Installing applications...${Reset}"
    foreach ($app in $apps) {
        Write-Host "${Yellow}Installing $app...${Reset}"
        try {
            # Suppress progress bars and verbose output
            $result = winget install --id $app --accept-package-agreements --accept-source-agreements --silent --disable-interactivity 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -or $result -match "already installed") {
                Write-Host "${Green}$app installed successfully!${Reset}"
            } else {
                Write-Host "${Red}Failed to install $app${Reset}"
            }
        } catch {
            Write-Host "${Red}Error installing ${app}: $($_.Exception.Message)${Reset}"
        }
    }
}

# Install Winget and apps
Install-Winget
Install-Apps
Install-FiraCodeFont

# Refresh environment variables
Write-Host "${Cyan}Refreshing environment variables...${Reset}"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Clone dotfiles repository (now that Git is installed)
Write-Host "${Cyan}Setting up dotfiles...${Reset}"
Invoke-CloneDotfiles

# Set environment variable to suppress mise chpwd warning
$env:MISE_PWSH_CHPWD_WARNING = "0"
[Environment]::SetEnvironmentVariable("MISE_PWSH_CHPWD_WARNING", "0", [EnvironmentVariableTarget]::User)

# Initialize PowerShell profiles using symlinks
function Initialize-Profile {
    param([string]$profilePath)
    Write-Host "${Cyan}Setting up profile: $profilePath${Reset}"
    $profileDir = Split-Path $profilePath
    if (-not (Test-Path -Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    $sourceProfile = Join-Path $dotfilesDir "powershell\Microsoft.PowerShell_profile.ps1"
    if (Test-Path -Path $sourceProfile) {
        if (Test-Path -Path $profilePath) {
            $item = Get-Item $profilePath
            if ($item.LinkType -ne "SymbolicLink") {
                $backupPath = "$profilePath.backup"
                Copy-Item -Path $profilePath -Destination $backupPath -Force
                Write-Host "${Yellow}Backed up existing profile to: $backupPath${Reset}"
            }
            Remove-Item -Path $profilePath -Force
        }
        try {
            New-Item -ItemType SymbolicLink -Path $profilePath -Target $sourceProfile -Force | Out-Null
            Write-Host "${Green}Profile symlinked successfully!${Reset}"
        } catch {
            Write-Host "${Red}Failed to create symlink: $($_.Exception.Message)${Reset}"
        }
    } else {
        Write-Host "${Yellow}PowerShell profile not found in dotfiles at: $sourceProfile${Reset}"
    }
}

$ps5ProfilePath = "$env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$ps7ProfilePath = "$env:UserProfile\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
Initialize-Profile -profilePath $ps5ProfilePath
Initialize-Profile -profilePath $ps7ProfilePath

# Initialize configuration files using symlinks
function Initialize-ConfigFiles {
    Write-Host "${Cyan}Setting up config files...${Reset}"
    $userConfigDir = "$env:UserProfile\.config"
    $fastfetchConfigDir = "$userConfigDir\fastfetch"
    $miseConfigDir = "$userConfigDir\mise"

    if (-not (Test-Path -Path $fastfetchConfigDir)) { New-Item -ItemType Directory -Path $fastfetchConfigDir -Force | Out-Null }
    if (-not (Test-Path -Path $miseConfigDir)) { New-Item -ItemType Directory -Path $miseConfigDir -Force | Out-Null }

    # Symlink fastfetch config
    $sourceFastfetch = Join-Path $dotfilesDir "config\fastfetch\windows.jsonc"
    $targetFastfetch = Join-Path $fastfetchConfigDir 'config.jsonc'
    if (Test-Path -Path $sourceFastfetch) {
        if (Test-Path -Path $targetFastfetch) {
            $item = Get-Item $targetFastfetch
            if ($item.LinkType -ne "SymbolicLink") {
                $backupPath = "$targetFastfetch.bak"
                Copy-Item -Path $targetFastfetch -Destination $backupPath -Force
                Write-Host "${Yellow}Backed up existing fastfetch config${Reset}"
            }
            Remove-Item -Path $targetFastfetch -Force
        }
        try {
            New-Item -ItemType SymbolicLink -Path $targetFastfetch -Target $sourceFastfetch -Force | Out-Null
            Write-Host "${Green}Fastfetch config symlinked!${Reset}"
        } catch {
            Write-Host "${Red}Failed to symlink fastfetch config: $($_.Exception.Message)${Reset}"
        }
    }

    # Symlink starship config
    $sourceStarship = Join-Path $dotfilesDir "config\starship.toml"
    $targetStarship = Join-Path $userConfigDir 'starship.toml'
    if (Test-Path -Path $sourceStarship) {
        if (Test-Path -Path $targetStarship) {
            $item = Get-Item $targetStarship
            if ($item.LinkType -ne "SymbolicLink") {
                $backupPath = "$targetStarship.bak"
                Copy-Item -Path $targetStarship -Destination $backupPath -Force
                Write-Host "${Yellow}Backed up existing starship config${Reset}"
            }
            Remove-Item -Path $targetStarship -Force
        }
        try {
            New-Item -ItemType SymbolicLink -Path $targetStarship -Target $sourceStarship -Force | Out-Null
            Write-Host "${Green}Starship config symlinked!${Reset}"
        } catch {
            Write-Host "${Red}Failed to symlink starship config: $($_.Exception.Message)${Reset}"
        }
    }

    # Symlink mise config
    $sourceMise = Join-Path $dotfilesDir "config\mise\config.toml"
    $targetMise = Join-Path $miseConfigDir 'config.toml'
    if (Test-Path -Path $sourceMise) {
        if (Test-Path -Path $targetMise) {
            $item = Get-Item $targetMise
            if ($item.LinkType -ne "SymbolicLink") {
                $backupPath = "$targetMise.bak"
                Copy-Item -Path $targetMise -Destination $backupPath -Force
                Write-Host "${Yellow}Backed up existing mise config${Reset}"
            }
            Remove-Item -Path $targetMise -Force
        }
        try {
            New-Item -ItemType SymbolicLink -Path $targetMise -Target $sourceMise -Force | Out-Null
            Write-Host "${Green}Mise config symlinked!${Reset}"
        } catch {
            Write-Host "${Red}Failed to symlink mise config: $($_.Exception.Message)${Reset}"
        }
    }
}

Initialize-ConfigFiles

# Install Terminal-Icons
function Install-TerminalIcons {
    if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
        Write-Host "${Yellow}Installing Terminal-Icons...${Reset}"
        Install-Module -Name Terminal-Icons -Repository PSGallery -Force
        Write-Host "${Green}Terminal-Icons installed!${Reset}"
    } else {
        Write-Host "${Cyan}Terminal-Icons already installed.${Reset}"
    }
}

Install-TerminalIcons

# Setup AutoHotkey shortcuts
function Initialize-CustomShortcuts {
    $response = Read-UserInput -Prompt "${Cyan}Set up AutoHotkey shortcuts? (y/n) ${Reset}"
    if ($response.ToLower() -ne 'y') {
        Write-Host "${Yellow}Skipping shortcuts setup.${Reset}"
        return
    }

    $sourceShortcuts = Join-Path $dotfilesDir "ahk\shortcuts.ahk"
    if (-not (Test-Path -Path $sourceShortcuts)) {
        Write-Host "${Yellow}shortcuts.ahk not found in dotfiles repository.${Reset}"
        return
    }

    Write-Host "${Yellow}Installing AutoHotkey and setting up shortcuts...${Reset}"
    winget install -e --id AutoHotkey.AutoHotkey

    $startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $shortcutsPath = Join-Path $startupFolder 'shortcuts.ahk'

    try {
        Copy-Item -Path $sourceShortcuts -Destination $shortcutsPath -Force
        Write-Host "${Green}Shortcuts copied from dotfiles!${Reset}"

        # Create desktop shortcut
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $shortcutPath = Join-Path $desktopPath 'Custom Shortcuts.lnk'
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = $shortcutsPath
        $Shortcut.WorkingDirectory = $startupFolder
        $Shortcut.Description = 'Custom Keyboard Shortcuts'
        $Shortcut.Save()

        if (Test-Path $shortcutsPath) {
            Start-Process $shortcutsPath
            Write-Host "${Green}AutoHotkey shortcuts active!${Reset}"
        }
    } catch {
        Write-Host "${Red}Failed to setup shortcuts: $($_.Exception.Message)${Reset}"
    }
}

Initialize-CustomShortcuts

# Setup Neovim with LazyVim
function Initialize-NeovimConfig {
    Write-Host "${Cyan}Setting up Neovim with LazyVim...${Reset}"
    $nvimConfigDir = "$env:LOCALAPPDATA\nvim"

    # Backup existing config if it exists
    if (Test-Path -Path $nvimConfigDir) {
        $backupDir = "$nvimConfigDir.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $nvimConfigDir -Destination $backupDir -Recurse -Force | Out-Null
        Write-Host "${Yellow}Backed up existing Neovim config to: $backupDir${Reset}"
        Remove-Item -Path $nvimConfigDir -Recurse -Force | Out-Null
    }

    # Create nvim config directory
    New-Item -ItemType Directory -Path $nvimConfigDir -Force | Out-Null

    # Clone LazyVim starter template
    try {
        Write-Host "${Cyan}Cloning LazyVim starter template...${Reset}"
        git clone --quiet https://github.com/LazyVim/starter $nvimConfigDir

        # Remove the .git folder so it can be added to user's own repo later
        $gitDir = Join-Path $nvimConfigDir '.git'
        if (Test-Path $gitDir) {
            Remove-Item -Path $gitDir -Recurse -Force | Out-Null
        }

        Write-Host "${Green}LazyVim installed! Run 'nvim' to start, then ':LazyHealth' to verify.${Reset}"
    } catch {
        Write-Host "${Red}Failed to clone LazyVim: $($_.Exception.Message)${Reset}"
    }
}

Initialize-NeovimConfig

# Clear any remaining progress output and suppress all output
Clear-Host
# Force suppress any remaining progress indicators
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
# Redirect any remaining output to null
$null = Get-Process -Name "winget" -ErrorAction SilentlyContinue

# Small delay to ensure all background processes complete
Start-Sleep -Milliseconds 500

# Final setup complete message
Write-Host ''
Write-Host "${Cyan}🎉 COMPLETE SELF-CONTAINED SETUP!${Reset}"
Write-Host "Everything uses your dotfiles repository - no external downloads needed!" -ForegroundColor White
Write-Host ''
Write-Host "${Cyan}Font setup:${Reset}"
Write-Host "Fira Code Nerd Font is installed. Set it in Windows Terminal." -ForegroundColor White
Write-Host ''
Write-Host "${Cyan}Configuration:${Reset}"
Write-Host '• PowerShell profiles: ~/powershell/Microsoft.PowerShell_profile.ps1' -ForegroundColor White
Write-Host '• Starship config: ~/config/starship.toml' -ForegroundColor White
Write-Host '• Fastfetch config: ~/config/fastfetch/windows.jsonc' -ForegroundColor White
Write-Host '• Mise config: ~/config/mise/config.toml' -ForegroundColor White
Write-Host '• AutoHotkey shortcuts: ~/ahk/shortcuts.ahk' -ForegroundColor White
Write-Host ''
Write-Host "${Cyan}✨ Key Benefits:${Reset}"
Write-Host '• All changes in your dotfiles repository are reflected immediately' -ForegroundColor White
Write-Host '• Version controlled configurations across all your machines' -ForegroundColor White
Write-Host '• No external dependencies - completely self-contained' -ForegroundColor White
Write-Host '• One script transforms any Windows machine into your perfect dev environment' -ForegroundColor White

Write-Host "${Green}`n🚀 Development environment setup complete!${Reset}"
Write-Host "${Yellow}`nPress any key to exit...${Reset}"
$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")