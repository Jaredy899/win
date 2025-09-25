# Windows Development Environment Setup Script - One Shot Edition
# This script sets up a complete development environment in one go

# Force admin mode - no options, just run everything
$AdminSetup = $true
$SkipApps = $false
$SkipSSH = $false  # Enable interactive SSH key setup with GitHub import

# Force execution policy change
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
} catch {
    # If that fails, try unrestricted
    try {
        Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force -ErrorAction Stop
    } catch {
        Write-Host "Warning: Could not change execution policy. Script may fail." -ForegroundColor Yellow
    }
}

# Install NuGet provider if needed (will prompt user if required)
Write-Host "Checking NuGet provider..." -ForegroundColor Cyan
try {
    $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    if (-not $nugetProvider -or $nugetProvider.Version -lt [version]"2.8.5.201") {
        Write-Host "Installing NuGet provider..." -ForegroundColor Yellow
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Write-Host "NuGet provider installed" -ForegroundColor Green
    } else {
        Write-Host "NuGet provider is up to date" -ForegroundColor Blue
    }
}
catch {
    Write-Host "Warning: Could not install NuGet provider automatically: $_" -ForegroundColor Yellow
    Write-Host "Module installation may prompt for NuGet setup later" -ForegroundColor Yellow
}

# Set PSGallery as trusted (required for module installation)
try {
    $psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($psGallery -and $psGallery.InstallationPolicy -ne "Trusted") {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Write-Host "PSGallery set as trusted repository" -ForegroundColor Green
    }
}
catch {
    # Silently continue if this fails - module installation will prompt if needed
}

Write-Host @"
##########################################################
#                                                        #
#     Windows Development Environment Setup Script       #
#              Auto Runner Edition                       #
#                                                        #
##########################################################
"@ -ForegroundColor Cyan

Write-Host "Setting up your complete development environment..." -ForegroundColor Yellow
Write-Host "This will install everything automatically - no prompts!" -ForegroundColor Green
Write-Host ""

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Self-elevate for admin setup if needed
if ($AdminSetup -and -not (Test-Administrator)) {
    Write-Output "Administrative setup requested. Requesting administrative privileges..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -AdminSetup" + $(if ($SkipApps) { " -SkipApps" } else { "" }) + $(if ($SkipSSH) { " -SkipSSH" } else { "" }))
    Exit
}

# Load configuration data from GitHub raw URLs
$githubBaseUrl = "https://raw.githubusercontent.com/Jaredy899/win/main/my_powershell"

# Alternative input function that works better in Windows Terminal
function Read-InputWithBackspace {
    param(
        [string]$Prompt = ""
    )

    if ($Prompt) {
        Write-Host $Prompt -NoNewline
    }

    # Use Read-Host with error handling to prevent backspace overflow issues
    $originalErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'SilentlyContinue'
        $result = Read-Host
        $ErrorActionPreference = $originalErrorAction
        return $result
    } catch {
        $ErrorActionPreference = $originalErrorAction
        # If Read-Host fails due to backspace overflow, return empty string
        Write-Host ""
        return ""
    }
}

# Function to load config file from GitHub
function Get-ConfigFile {
    param([string]$filename)

    $configUrl = "$githubBaseUrl/$filename"
    try {
        Write-Host "Downloading config: $filename..." -ForegroundColor Cyan
        $content = Invoke-WebRequest -Uri $configUrl -UseBasicParsing -ErrorAction Stop | Select-Object -ExpandProperty Content

        # Remove UTF-8 BOM if present (causes JSON parsing issues)
        if ($content -and $content.Length -gt 3 -and $content[0] -eq 0xEF -and $content[1] -eq 0xBB -and $content[2] -eq 0xBF) {
            $content = $content.Substring(3)
            Write-Host "Removed UTF-8 BOM from $filename" -ForegroundColor Gray
        }

        Write-Host "✓ Successfully loaded $filename from GitHub" -ForegroundColor Green
        return $content
    }
    catch {
        Write-Host "✗ Failed to download $filename from GitHub" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Note: Some features may not work without config files" -ForegroundColor Yellow
        return $null
    }
}

$configJsonc = Get-ConfigFile "config.jsonc"

$starshipToml = Get-ConfigFile "starship.toml"

$powerShellProfile = Get-ConfigFile "Microsoft.PowerShell_profile.ps1"

$shortcutsAhk = Get-ConfigFile "shortcuts.ahk"

# Winget installation functions
function Get-WingetStatus {
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        $installedVersion = (winget --version).Trim('v')
        $latestVersion = (Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest").tag_name.Trim('v')
        if ([version]$installedVersion -lt [version]$latestVersion) {
            return "outdated"
        } else {
            return "installed"
        }
    } else {
        return "not installed"
    }
}

function Install-Winget {
    Write-Host "=== Checking Winget Installation ===" -ForegroundColor Cyan

    $isWingetInstalled = Get-WingetStatus

    try {
        if ($isWingetInstalled -eq "installed") {
            Write-Host "Winget is already installed and up to date!" -ForegroundColor Green
            return $true
        } elseif ($isWingetInstalled -eq "outdated") {
            Write-Host "Winget is outdated. Proceeding with update..." -ForegroundColor Yellow
        } else {
            Write-Host "Winget is not installed. Starting installation..." -ForegroundColor Yellow
        }

        if ($null -eq $sync.ComputerInfo) {
            $ComputerInfo = Get-ComputerInfo -ErrorAction Stop
        } else {
            $ComputerInfo = $sync.ComputerInfo
        }

        if (($ComputerInfo.WindowsVersion) -lt "1809") {
            Write-Host "Winget is not supported on this version of Windows (Pre-1809)" -ForegroundColor Red
            return $false
        }

        Write-Host "=== Downloading Required Components ===" -ForegroundColor Cyan

        $wingetUrl = "https://aka.ms/getwinget"
        $vclibsUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $xamlUrl = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"

        $wingetPackage = "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $vclibsPackage = "$env:TEMP\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $xamlPackage = "$env:TEMP\Microsoft.UI.Xaml.2.8.x64.appx"

        Write-Host "Downloading Winget and dependencies..." -ForegroundColor Yellow

        Start-BitsTransfer -Source $wingetUrl -Destination $wingetPackage -ErrorAction Stop
        Start-BitsTransfer -Source $vclibsUrl -Destination $vclibsPackage -ErrorAction Stop
        Start-BitsTransfer -Source $xamlUrl -Destination $xamlPackage -ErrorAction Stop

        Write-Host "=== Installing Components ===" -ForegroundColor Cyan

        if (-not (Get-AppxPackage -Name "*VCLibs*" | Where-Object { $_.Version -ge "14.0.33321.0" })) {
            Add-AppxPackage -Path $vclibsPackage
        }

        if (-not (Get-AppxPackage -Name "*UI.Xaml*" | Where-Object { $_.Version -ge "2.8.6.0" })) {
            $storeProcess = Get-Process -Name "WinStore.App" -ErrorAction SilentlyContinue
            if ($storeProcess) {
                Stop-Process -Name "WinStore.App" -Force
            }
            Add-AppxPackage -Path $xamlPackage
        }

        Add-AppxPackage -Path $wingetPackage

        Write-Host "Winget and all dependencies installed successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to install Winget or its dependencies. Error: $_" -ForegroundColor Red
        return $false
    }
}

# App installation functions

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
        # "Neovim.Neovim",  # Regular Neovim - replaced with LazyVim
        "Git.Git"
    )

    Write-Host "=== Starting Application Installation ===" -ForegroundColor Cyan
    Write-Host "Installing all applications (winget will handle duplicates)..." -ForegroundColor Yellow

    # Just install all apps - let winget handle what's already installed
    $appsToInstall = $apps | Where-Object { $_ -notmatch "^#" }  # Filter out commented lines

    Write-Host "Installing $($appsToInstall.Count) applications..." -ForegroundColor Yellow

    # Install all apps (PowerShell 7+ supports parallel processing, PS5 uses sequential)
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Host "Using parallel installation (PowerShell 7+)..." -ForegroundColor Cyan
        $appsToInstall | ForEach-Object -Parallel {
            $app = $_
            Write-Host "Installing $app..." -ForegroundColor Yellow
            try {
                $output = winget install --id $app --accept-package-agreements --accept-source-agreements -e 2>&1
                $outputText = $output | Out-String

                # Check for success indicators
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "$app installed successfully!" -ForegroundColor Green
                }
                elseif ($outputText -match "already installed" -or $outputText -match "No available upgrade found") {
                    Write-Host "$app is already installed and up-to-date." -ForegroundColor Blue
                }
                else {
                    Write-Host "Failed to install $app." -ForegroundColor Red
                    Write-Host "Winget output: $outputText" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "Error installing $app`: $_" -ForegroundColor Red
            }
        } -ThrottleLimit 3
    } else {
        Write-Host "Using sequential installation (PowerShell $($PSVersionTable.PSVersion.Major))..." -ForegroundColor Cyan
        foreach ($app in $appsToInstall) {
            Write-Host "Installing $app..." -ForegroundColor Yellow
            try {
                $output = winget install --id $app --accept-package-agreements --accept-source-agreements -e 2>&1
                $outputText = $output | Out-String

                # Check for success indicators
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "$app installed successfully!" -ForegroundColor Green
                }
                elseif ($outputText -match "already installed" -or $outputText -match "No available upgrade found") {
                    Write-Host "$app is already installed and up-to-date." -ForegroundColor Blue
                }
                else {
                    Write-Host "Failed to install $app." -ForegroundColor Red
                    Write-Host "Winget output: $outputText" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "Error installing $app`: $_" -ForegroundColor Red
            }
        }
    }

    Write-Host "=== Application Installation Complete ===" -ForegroundColor Cyan
}

# LazyVim installation function
function Install-LazyVim {
    param (
        [string]$LazyVimRepo = "LazyVim/starter",
        [string]$ConfigPath = "$env:USERPROFILE\.config\nvim"
    )

    try {
        Write-Host "=== Starting LazyVim Installation ===" -ForegroundColor Cyan

        # First ensure Neovim is installed (should be installed by Install-Apps, but check anyway)
        if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
            Write-Host "Installing Neovim as prerequisite..." -ForegroundColor Yellow
            winget install --id Neovim.Neovim --accept-package-agreements --accept-source-agreements -e 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to install Neovim. Skipping LazyVim installation." -ForegroundColor Red
                return $false
            }
        }

        # Check if LazyVim is already installed
        if (Test-Path -Path $ConfigPath) {
            Write-Host "LazyVim configuration directory already exists at $ConfigPath" -ForegroundColor Blue
            Write-Host "LazyVim appears to already be installed." -ForegroundColor Green
            Write-Host "=== LazyVim Installation Complete ===" -ForegroundColor Cyan
            return $true
        }

        # Create config directory
        $configDir = Split-Path -Path $ConfigPath
        if (-not (Test-Path -Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        # Clone LazyVim starter (use full git path if available)
        Write-Host "Cloning LazyVim starter configuration..." -ForegroundColor Yellow

        # Try to find git in common locations or use PATH
        $gitPath = "git"
        $gitLocations = @(
            "$env:ProgramFiles\Git\bin\git.exe",
            "$env:ProgramFiles(x86)\Git\bin\git.exe",
            "$env:LocalAppData\Microsoft\WindowsApps\git.exe",
            "git"  # fallback to PATH
        )

        foreach ($location in $gitLocations) {
            if (Test-Path $location -ErrorAction SilentlyContinue) {
                $gitPath = $location
                break
            }
        }

        $cloneCmd = "& `"$gitPath`" clone https://github.com/$LazyVimRepo.git `"$ConfigPath`""
        Invoke-Expression $cloneCmd

        if ($LASTEXITCODE -eq 0) {
            Write-Host "LazyVim installed successfully!" -ForegroundColor Green
            Write-Host "LazyVim configuration installed to: $ConfigPath" -ForegroundColor Cyan
            Write-Host "Note: First Neovim launch will install plugins automatically." -ForegroundColor Yellow
        } else {
            Write-Host "Failed to clone LazyVim repository." -ForegroundColor Red
            return $false
        }

        Write-Host "=== LazyVim Installation Complete ===" -ForegroundColor Cyan
        return $true
    }
    catch {
        Write-Host "Failed to install LazyVim: $_" -ForegroundColor Red
        return $false
    }
}

# Font installation function
function Install-FiraCodeFont {
    param (
        [string]$FontRepo = "ryanoasis/nerd-fonts",
        [string]$FontName = "FiraCode",
        [string]$FontDisplayName = "Fira Code Nerd Font"
    )

    try {
        Write-Host "=== Starting Fira Code Nerd Font Installation ===" -ForegroundColor Cyan

        # Check if the font is already installed
        $isFontInstalled = $false
        try {
            [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
            $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families

            foreach ($font in $fontFamilies) {
                if ($font.Name -like "*Fira*Code*" -or $font.Name -like "*FiraCode*") {
                    $isFontInstalled = $true
                    Write-Host "Found installed font: $($font.Name)" -ForegroundColor Gray
                    break
                }
            }

            # Also check Windows Fonts directory for FiraCode files
            if (-not $isFontInstalled) {
                $fontFiles = Get-ChildItem -Path "C:\Windows\Fonts" -Filter "*FiraCode*" -ErrorAction SilentlyContinue
                if ($fontFiles) {
                    $isFontInstalled = $true
                    Write-Host "Found FiraCode font files in Windows Fonts directory" -ForegroundColor Gray
                }
            }
        }
        catch {
            # If we can't check fonts, assume not installed and proceed
            Write-Host "Warning: Could not check installed fonts, proceeding with installation" -ForegroundColor Yellow
            $isFontInstalled = $false
        }

        if (-not $isFontInstalled) {
            $apiUrl = "https://api.github.com/repos/$FontRepo/releases/latest"
            Write-Host "Fetching the latest release information..." -ForegroundColor Yellow

            $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'PowerShell Script' }

            $asset = $releaseInfo.assets | Where-Object { $_.name -like "$FontName*Windows*.zip" -or $_.name -like "$FontName*.zip" }
            if ($null -eq $asset) {
                Write-Host "Could not find a suitable asset for $FontName in the latest release." -ForegroundColor Red
                return
            }

            $fontZipUrl = $asset.browser_download_url
            $zipFilePath = "$env:TEMP\${FontName}.zip"
            $extractPath = "$env:TEMP\${FontName}"

            Write-Host "Downloading Fira Code Nerd Font..." -ForegroundColor Yellow
            Start-BitsTransfer -Source $fontZipUrl -Destination $zipFilePath -ErrorAction Stop

            Write-Host "Extracting Fira Code Nerd Font..." -ForegroundColor Yellow
            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force

            Write-Host "Installing Fira Code Nerd Font..." -ForegroundColor Yellow
            $destination = (New-Object -ComObject Shell.Application).Namespace(0x14)
            Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf" | ForEach-Object {
                If (-not (Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                    try {
                        # Use CopyHere with flags to avoid prompts (0x10 = Yes to all, 0x4 = No progress dialog)
                        $destination.CopyHere($_.FullName, 0x14)
                    }
                    catch {
                        Write-Host "Failed to install font $($_.Name): $_" -ForegroundColor Yellow
                    }
                }
            }

            Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
            Remove-Item -Path $extractPath -Recurse -Force
            Remove-Item -Path $zipFilePath -Force

            Write-Host "Fira Code Nerd Font installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Font ${FontDisplayName} is already installed." -ForegroundColor Blue
        }
        Write-Host "=== Font Installation Complete ===" -ForegroundColor Cyan
    }
    catch {
        Write-Host "Failed to download or install ${FontDisplayName} font. Error: $_" -ForegroundColor Red
    }
}

# Admin setup functions (from setup2.ps1)
function Set-UserPassword {
    param (
        [SecureString]$password
    )
    $username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]
    Try {
        Write-Host "Attempting to change the password for $username..." -ForegroundColor Yellow
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        net user "$username" "$plainPassword" *>$null
        Write-Host "Password for ${username} account set successfully." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to set password for ${username} account: $($_)" -ForegroundColor Red
    }
}

function Set-RemoteDesktop {
    Try {
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0 -PropertyType DWORD -Force *>$null
        Write-Host "Remote Desktop enabled." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to enable Remote Desktop: $($_)" -ForegroundColor Red
    }
}

function Enable-FirewallRule {
    param (
        [string]$ruleGroup,
        [string]$ruleName,
        [string]$protocol = "",
        [string]$localPort = ""
    )
    Try {
        if ($protocol -and $localPort) {
            netsh advfirewall firewall add rule name="$ruleName" protocol="$protocol" dir=in action=allow *>$null
        } else {
            netsh advfirewall firewall set rule group="$ruleGroup" new enable=Yes *>$null
        }
        Write-Host "${ruleName} rule enabled." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to enable ${ruleName} rule: $($_)" -ForegroundColor Red
    }
}

function Install-WindowsCapability {
    param (
        [string]$capabilityName
    )
    if ((Get-WindowsCapability -Online | Where-Object Name -like "$capabilityName*").State -ne 'Installed') {
        Try {
            Add-WindowsCapability -Online -Name $capabilityName *>$null
            Write-Host "${capabilityName} installed successfully." -ForegroundColor Green
        } Catch {
            Write-Host "Failed to install ${capabilityName}: $($_)" -ForegroundColor Red
        }
    } else {
        Write-Host "${capabilityName} is already installed." -ForegroundColor Blue
    }
}

function Set-SSHConfiguration {
    Try {
        Start-Service sshd *>$null
        Set-Service -Name sshd -StartupType 'Automatic' *>$null
        Write-Host "SSH service started and set to start automatically." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to configure SSH service: $($_)" -ForegroundColor Red
    }

    Try {
        $firewallRuleExists = Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue
        if ($null -eq $firewallRuleExists) {
            Try {
                New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 *>$null
                Write-Host "Firewall rule for OpenSSH Server (sshd) created successfully." -ForegroundColor Green
            } Catch {
                Write-Host "Failed to create firewall rule for OpenSSH Server (sshd): $($_)" -ForegroundColor Red
            }
        } else {
            Write-Host "Firewall rule for OpenSSH Server (sshd) already exists." -ForegroundColor Blue
        }
    } Catch {
        Write-Host "Failed to check for existing firewall rule: $($_)" -ForegroundColor Red
    }

    Try {
        New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force *>$null
        Write-Host "Default shell for OpenSSH set to PowerShell 7." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to set default shell for OpenSSH: $($_)" -ForegroundColor Red
    }
}

# Function: Download and parse IANA → Windows timezone mapping
function Get-IanaToWindowsTimeZoneMap {
    param(
        [string]$Url = "https://raw.githubusercontent.com/unicode-org/cldr/main/common/supplemental/windowsZones.xml"
    )

    try {
        Write-Host "Downloading timezone mapping from CLDR..." -ForegroundColor Cyan
        [xml]$xml = Invoke-RestMethod -Uri $Url -UseBasicParsing

        $map = @{}

        foreach ($mapZone in $xml.supplementalData.windowsZones.mapTimezones.mapZone) {
            $windowsTz = $mapZone.other
            $ianaTzs   = $mapZone.type -split " "

            foreach ($iana in $ianaTzs) {
                if (-not $map.ContainsKey($iana)) {
                    $map[$iana] = $windowsTz
                }
            }
        }

        return $map
    }
    catch {
        Write-Host "Failed to download or parse timezone mapping: $_" -ForegroundColor Red
        return $null
    }
}

function Set-TimeSettings {
    Try {
        # Attempt to automatically detect timezone
        Try {
            $timezone = $null

            # Try ipapi.co first
            Try {
                $timezone = (Invoke-RestMethod -Uri "https://ipapi.co/timezone" -Method Get -TimeoutSec 5).Trim()
            } Catch {
                Write-Output "ipapi.co detection failed, trying alternative service..."
            }

            if ($timezone) {
                Write-Host "Detected timezone: $timezone" -ForegroundColor Yellow

                # Load IANA → Windows mapping
                $tzMapping = Get-IanaToWindowsTimeZoneMap

                if ($tzMapping -and $tzMapping.ContainsKey($timezone)) {
                    $windowsTimezone = $tzMapping[$timezone]
                    tzutil /s $windowsTimezone *>$null
                    Write-Host "Time zone automatically set to $windowsTimezone" -ForegroundColor Green
                } else {
                    throw "Could not map timezone"
                }
            } else {
                throw "Could not detect timezone"
            }
        } Catch {
            Write-Host "Automatic timezone detection failed. Falling back to manual selection..." -ForegroundColor Yellow
            # Display options for time zones
            Write-Host "Select a time zone from the options below:" -ForegroundColor Cyan
            $timeZones = (Get-TimeZone -ListAvailable).Id | Sort-Object

            # Display the list of options
            for ($i = 0; $i -lt $timeZones.Count; $i++) {
                Write-Output "$($i + 1). $($timeZones[$i])"
            }

            # Prompt the user to select a time zone
            $selection = Read-InputWithBackspace -Prompt "Enter the number corresponding to your time zone: "

            # Validate input and set the time zone
            if ($selection -match '^\d+$' -and $selection -gt 0 -and $selection -le $timeZones.Count) {
                $selectedTimeZone = $timeZones[$selection - 1]
                tzutil /s "$selectedTimeZone" *>$null
                Write-Host "Time zone set to $selectedTimeZone." -ForegroundColor Green
            } else {
                Write-Host "Invalid selection. Please run the script again and choose a valid number." -ForegroundColor Yellow
                return
            }
        }

        # Configure the time synchronization settings using time.nist.gov
        w32tm /config /manualpeerlist:"time.nist.gov,0x1" /syncfromflags:manual /reliable:YES /update *>$null
        Set-Service -Name w32time -StartupType Automatic *>$null
        Start-Service -Name w32time *>$null
        w32tm /resync *>$null

        Write-Host "Time settings configured and synchronized using time.nist.gov." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to configure time settings or synchronization: $($_)" -ForegroundColor Red
    }
}

function Set-TimeSyncAtStartup {
    Try {
        $taskName = "TimeSyncAtStartup"

        # Check if task already exists and is configured correctly
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            # Verify the task is configured correctly
            $taskCorrect = $true

            # Check action (w32tm.exe /resync)
            if ($existingTask.Actions[0].Execute -ne "w32tm.exe" -or $existingTask.Actions[0].Arguments -ne "/resync") {
                $taskCorrect = $false
            }

            # Check trigger (at startup)
            if (-not ($existingTask.Triggers | Where-Object { $_.PSObject.Properties.Name -contains "AtStartup" -and $_.AtStartup })) {
                $taskCorrect = $false
            }

            # Check principal (SYSTEM account)
            if ($existingTask.Principal.UserId -ne "SYSTEM" -or $existingTask.Principal.LogonType -ne "ServiceAccount") {
                $taskCorrect = $false
            }

            if ($taskCorrect) {
                Write-Host "Time sync task already exists and is properly configured." -ForegroundColor Blue
                return
            } else {
                Write-Host "Existing time sync task is misconfigured, recreating..." -ForegroundColor Yellow
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            }
        }

        Write-Host "Setting up automatic time synchronization at startup..." -ForegroundColor Yellow
        $action = New-ScheduledTaskAction -Execute "w32tm.exe" -Argument "/resync"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal
        Write-Host "Scheduled task for time synchronization at startup has been created." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to create scheduled task for time synchronization: $($_)" -ForegroundColor Red
    }
}

function Disable-WindowsRecall {
    Try {
        DISM /Online /Disable-Feature /FeatureName:Recall *>$null
        Write-Host "Windows Recall feature has been disabled." -ForegroundColor Green
    } Catch {
        Write-Host "Failed to disable Windows Recall feature: $($_)" -ForegroundColor Red
    }
}


# SSH key setup functions (simplified)
function Initialize-SSHKeys {
    if ($SkipSSH) {
        Write-Host "Skipping SSH key setup as requested." -ForegroundColor Blue
        return
    }

    Write-Host "=== SSH Key Setup ===" -ForegroundColor Cyan
    Write-Host "This will help you add SSH keys for secure access." -ForegroundColor Yellow

    $setupSSH = Read-Host "Would you like to set up SSH keys now? (y/n)"
    if ($setupSSH -notmatch '^[Yy]') {
        Write-Host "Skipping SSH key setup." -ForegroundColor Blue
        return
    }

    $programData = $env:ProgramData
    $sshPath = Join-Path $programData "ssh"
    $adminKeys = Join-Path $sshPath "administrators_authorized_keys"

    if (-not (Test-Path -Path $sshPath)) {
        New-Item -ItemType Directory -Path $sshPath -Force
    }

    if (-not (Test-Path -Path $adminKeys)) {
        New-Item -ItemType File -Path $adminKeys -Force
    }

    Write-Host "SSH environment initialized." -ForegroundColor Green

    # Simple SSH key setup - ask for GitHub username
    $githubUser = Read-Host "Enter your GitHub username to import SSH keys (or press Enter to skip)"
    if ($githubUser) {
        try {
            $response = Invoke-RestMethod -Uri "https://api.github.com/users/$githubUser/keys" -ErrorAction Stop
            if ($response -and $response.Count -gt 0) {
                $existingKeys = Get-Content -Path $adminKeys
                $added = 0
                foreach ($key in $response) {
                    if ($existingKeys -notcontains $key.key) {
                        Add-Content -Path $adminKeys -Value $key.key
                        $added++
                    }
                }
                Write-Host "Added $added SSH keys from GitHub user $githubUser." -ForegroundColor Green
            } else {
                Write-Host "No SSH keys found for GitHub user $githubUser." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Failed to fetch SSH keys from GitHub: $_" -ForegroundColor Red
        }
    }

    # Set permissions
    try {
        icacls $adminKeys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
        Write-Host "SSH key permissions configured." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to set SSH key permissions: $_" -ForegroundColor Red
    }

    Write-Host "=== SSH Setup Complete ===" -ForegroundColor Cyan
}

# Main setup functions
function Initialize-ConfigFiles {
    Write-Host "Setting up configuration files..." -ForegroundColor Cyan

    $userConfigDir = "$env:UserProfile\.config"
    $fastfetchConfigDir = "$userConfigDir\fastfetch"

    # Create directories if they don't exist (idempotent)
    if (-not (Test-Path -Path $fastfetchConfigDir)) {
        New-Item -ItemType Directory -Path $fastfetchConfigDir -Force
        Write-Host "Created fastfetch config directory" -ForegroundColor Green
    }

    # Always replace config files with latest versions
    $configJsoncPath = "$fastfetchConfigDir\config.jsonc"
    $configJsonc | Out-File -FilePath $configJsoncPath -Encoding UTF8 -Force
    Write-Host "fastfetch config.jsonc has been updated!" -ForegroundColor Green

    $starshipTomlPath = "$userConfigDir\starship.toml"
    $starshipToml | Out-File -FilePath $starshipTomlPath -Encoding UTF8 -Force
    Write-Host "starship.toml has been updated!" -ForegroundColor Green
}

function Initialize-PowerShellProfile {
    Write-Host "Setting up PowerShell profiles..." -ForegroundColor Cyan

    $ps5ProfilePath = "$env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    $ps7ProfilePath = "$env:UserProfile\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"

    $profileDir5 = Split-Path $ps5ProfilePath
    $profileDir7 = Split-Path $ps7ProfilePath

    # Create directories if they don't exist (idempotent)
    if (-not (Test-Path -Path $profileDir5)) {
        New-Item -ItemType Directory -Path $profileDir5 -Force
    }
    if (-not (Test-Path -Path $profileDir7)) {
        New-Item -ItemType Directory -Path $profileDir7 -Force
    }

    # Always replace PowerShell profiles with latest versions
    $powerShellProfile | Out-File -FilePath $ps5ProfilePath -Encoding UTF8 -Force
    Write-Host "PowerShell 5 profile updated" -ForegroundColor Green

    $powerShellProfile | Out-File -FilePath $ps7ProfilePath -Encoding UTF8 -Force
    Write-Host "PowerShell 7 profile updated" -ForegroundColor Green

    Write-Host "PowerShell profiles have been updated successfully!" -ForegroundColor Green
}

function Install-TerminalIcons {
    if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
        Write-Host "Installing Terminal-Icons module..." -ForegroundColor Yellow

        # PSGallery and NuGet should already be set up at the beginning of the script
        try {
            Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Confirm:$false
            Write-Host "Terminal-Icons module installed successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to install Terminal-Icons: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Terminal-Icons module is already installed." -ForegroundColor Blue
    }
}

function Initialize-WindowsTerminal {
    Write-Host "Configuring Windows Terminal..." -ForegroundColor Cyan

    try {
        # Find Windows Terminal settings path
        $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

        if (-not (Test-Path $wtSettingsPath)) {
            Write-Host "Windows Terminal settings file not found, skipping configuration" -ForegroundColor Yellow
            return
        }

        # Read current settings
        $settings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json

        # Find PowerShell 7 profile
        $ps7Profile = $settings.profiles.list | Where-Object {
            $_.name -match "PowerShell" -and ($_.commandline -match "pwsh" -or $_.name -match "7")
        } | Select-Object -First 1

        if (-not $ps7Profile) {
            Write-Host "PowerShell 7 profile not found in Windows Terminal, skipping configuration" -ForegroundColor Yellow
            return
        }

        # Set Fira Code Nerd Font Mono as the font
        $ps7Profile.fontFace = "FiraCode Nerd Font Mono"

        # Set PowerShell 7 as the default profile
        $settings.defaultProfile = $ps7Profile.guid

        # Save modified settings
        $settings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8

        Write-Host "Windows Terminal configured successfully!" -ForegroundColor Green
        Write-Host "• PowerShell 7 set as default profile" -ForegroundColor Gray
        Write-Host "• Fira Code Nerd Font Mono set as font" -ForegroundColor Gray

    } catch {
        Write-Host "Failed to configure Windows Terminal: $_" -ForegroundColor Red
    }
}

function Initialize-CustomShortcuts {
    $installShortcuts = Read-InputWithBackspace -Prompt "Install AutoHotkey and custom shortcuts? (y/n): "

    if ($installShortcuts -notmatch "^[Yy]$|^yes$") {
        Write-Host "Skipping AutoHotkey shortcuts setup." -ForegroundColor Blue
        return
    }

    Write-Host "Setting up custom keyboard shortcuts..." -ForegroundColor Cyan

    $startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $shortcutsPath = "$startupFolder\shortcuts.ahk"

    # Check if AutoHotkey is installed
    $ahkInstalled = $false
    if (Get-Command "AutoHotkey.exe" -ErrorAction SilentlyContinue) {
        $ahkInstalled = $true
    } elseif (Test-Path "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe") {
        $ahkInstalled = $true
    } elseif (Test-Path "${env:ProgramFiles(x86)}\AutoHotkey\AutoHotkey.exe") {
        $ahkInstalled = $true
    }

    if (-not $ahkInstalled) {
        Write-Host "Installing AutoHotkey..." -ForegroundColor Yellow
        winget install -e --id AutoHotkey.AutoHotkey
        if ($LASTEXITCODE -eq 0) {
            $ahkInstalled = $true
            Write-Host "AutoHotkey installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Failed to install AutoHotkey, skipping shortcuts setup" -ForegroundColor Red
            return
        }
    }

    # Check if shortcuts file already exists
    if (Test-Path $shortcutsPath) {
        Write-Host "AutoHotkey shortcuts already configured, skipping" -ForegroundColor Blue
    } else {
        try {
            $shortcutsAhk | Out-File -FilePath $shortcutsPath -Encoding UTF8
            Write-Host "AutoHotkey shortcuts have been set up successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to create shortcuts file. Error: $_" -ForegroundColor Red
            return
        }
    }

    # Check if desktop shortcut already exists
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = "$desktopPath\Custom Shortcuts.lnk"

    if (Test-Path $shortcutPath) {
        Write-Host "Desktop shortcut already exists, skipping" -ForegroundColor Blue
    } else {
        try {
            $WshShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($shortcutPath)
            $Shortcut.TargetPath = $shortcutsPath
            $Shortcut.WorkingDirectory = $startupFolder
            $Shortcut.Description = "Custom Keyboard Shortcuts"
            $Shortcut.Save()
            Write-Host "Desktop shortcut created successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to create desktop shortcut. Error: $_" -ForegroundColor Red
        }
    }

    # Try to start AutoHotkey if shortcuts file exists
    if (Test-Path $shortcutsPath) {
        try {
            Start-Process $shortcutsPath -ErrorAction SilentlyContinue
            Write-Host "Custom shortcuts are now active!" -ForegroundColor Green
        }
        catch {
            Write-Host "Could not start AutoHotkey automatically" -ForegroundColor Yellow
        }
    }
}

# Main execution logic - continue on errors where possible
try {
    # Install Winget if needed
    Write-Host "=== Installing Winget ===" -ForegroundColor Cyan
    try {
        if (-not (Install-Winget)) {
            Write-Host "Failed to install Winget. Some features may not work." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error installing Winget: $_" -ForegroundColor Red
        Write-Host "Continuing with setup..." -ForegroundColor Yellow
    }

    # Install applications unless skipped
    Write-Host "`n=== Installing Applications ===" -ForegroundColor Cyan
    try {
        if (-not $SkipApps) {
            Install-Apps
        } else {
            Write-Host "Skipping application installation as requested." -ForegroundColor Blue
        }
    }
    catch {
        Write-Host "Error installing applications: $_" -ForegroundColor Red
        Write-Host "Continuing with setup..." -ForegroundColor Yellow
    }

    # Install LazyVim
    Write-Host "`n=== Installing LazyVim ===" -ForegroundColor Cyan
    try {
        Install-LazyVim
    }
    catch {
        Write-Host "Error installing LazyVim: $_" -ForegroundColor Red
        Write-Host "Continuing with setup..." -ForegroundColor Yellow
    }

    # Install font
    Write-Host "`n=== Installing Fonts ===" -ForegroundColor Cyan
    try {
        Install-FiraCodeFont
    }
    catch {
        Write-Host "Error installing fonts: $_" -ForegroundColor Red
        Write-Host "Continuing with setup..." -ForegroundColor Yellow
    }

    # Setup configuration files (always replace with latest versions)
    Write-Host "`n=== Setting up Configuration Files ===" -ForegroundColor Cyan
    try {
        if ($configJsonc -and $starshipToml) {
            Initialize-ConfigFiles
        } else {
            Write-Host "Skipping configuration file setup - config files not available" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error setting up configuration files: $_" -ForegroundColor Red
        Write-Host "Continuing with setup..." -ForegroundColor Yellow
    }

    # Setup PowerShell profiles (always replace with latest versions)
    Write-Host "`n=== Setting up PowerShell Profiles ===" -ForegroundColor Cyan
    try {
        if ($powerShellProfile) {
            Initialize-PowerShellProfile
        } else {
            Write-Host "Skipping PowerShell profile setup - config file not available" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error setting up PowerShell profiles: $_" -ForegroundColor Red
        Write-Host "Continuing with setup..." -ForegroundColor Yellow
    }

    # Configure Windows Terminal
    try {
        Initialize-WindowsTerminal
    }
    catch {
        Write-Host "Error configuring Windows Terminal: $_" -ForegroundColor Red
        Write-Host "Continuing with setup..." -ForegroundColor Yellow
    }

    # Install Terminal-Icons
    Write-Host "`n=== Installing Terminal-Icons ===" -ForegroundColor Cyan
    try {
        Install-TerminalIcons
    }
    catch {
        Write-Host "Error installing Terminal-Icons: $_" -ForegroundColor Red
        Write-Host "Continuing with setup..." -ForegroundColor Yellow
    }

    # Setup custom shortcuts (only if config downloaded successfully)
    Write-Host "`n=== Setting up AutoHotkey Shortcuts ===" -ForegroundColor Cyan
    try {
        if ($shortcutsAhk) {
            Initialize-CustomShortcuts
        } else {
            Write-Host "Skipping AutoHotkey shortcuts setup - config file not available" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error setting up AutoHotkey shortcuts: $_" -ForegroundColor Red
        Write-Host "Continuing with setup..." -ForegroundColor Yellow
    }

    # Admin setup if requested
    if ($AdminSetup) {
        Write-Host "`n=== Administrative Setup ===" -ForegroundColor Cyan
        try {
        # Minimal ANSI colors (PS7/Windows Terminal/TUI)
        $esc   = [char]27
        $Cyan  = "${esc}[36m"
        $Yellow= "${esc}[33m"
        $Green = "${esc}[32m"
        $Red   = "${esc}[31m"
        $Reset = "${esc}[0m"

        Write-Host "${Cyan}=== Administrative Setup ===${Reset}"

        # Password change
        Write-Host "${Cyan}Do you want to change your password? ${Reset}" -NoNewline
        Write-Host "(yes/y/enter for yes, no/n for no)" -ForegroundColor DarkGray
        $changePassword = Read-InputWithBackspace

        if ($changePassword -eq "yes" -or $changePassword -eq "y" -or [string]::IsNullOrEmpty($changePassword)) {
            $passwordsMatch = $false
            while (-not $passwordsMatch) {
                Write-Host "${Yellow}Enter the new password: ${Reset}" -NoNewline
                $password1 = Read-Host -AsSecureString
                Write-Host "${Yellow}Confirm the new password: ${Reset}" -NoNewline
                $password2 = Read-Host -AsSecureString

                $BSTR1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1)
                $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2)
                $plainPassword1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR1)
                $plainPassword2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)

                if ($plainPassword1 -eq $plainPassword2) {
                    $passwordsMatch = $true
                    Set-UserPassword -password $password1
                    Write-Host "${Green}Password changed successfully.${Reset}"
                } else {
                    Write-Host "${Red}Passwords do not match. Please try again or press Ctrl+C to cancel.${Reset}"
                }

                $plainPassword1 = $plainPassword2 = $null
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR1)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR2)
            }
        } else {
            Write-Host "${Cyan}Password change was not performed.${Reset}"
        }

        # Run admin functions
        Set-TimeSettings
        Set-RemoteDesktop
        Enable-FirewallRule -ruleGroup "remote desktop" -ruleName "Remote Desktop"
        Enable-FirewallRule -ruleName "Allow ICMPv4-In" -protocol "icmpv4" -localPort "8,any"
        Install-WindowsCapability -capabilityName "OpenSSH.Client~~~~0.0.1.0"
        Install-WindowsCapability -capabilityName "OpenSSH.Server~~~~0.0.1.0"
        Set-SSHConfiguration
        Set-TimeSyncAtStartup
        Disable-WindowsRecall
        }
        catch {
            Write-Host "Error during administrative setup: $_" -ForegroundColor Red
            Write-Host "Continuing with remaining setup..." -ForegroundColor Yellow
        }
    }

    # SSH setup (can run without admin)
    Write-Host "`n=== Setting up SSH Keys ===" -ForegroundColor Cyan
    try {
        Initialize-SSHKeys
    }
    catch {
        Write-Host "Error setting up SSH keys: $_" -ForegroundColor Red
        Write-Host "Continuing with completion..." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "##########################################################" -ForegroundColor Cyan
    Write-Host "#                                                        #" -ForegroundColor Cyan
    Write-Host "#      Windows Development Environment Setup Complete!   #" -ForegroundColor Green
    Write-Host "#                                                        #" -ForegroundColor Cyan
    Write-Host "##########################################################" -ForegroundColor Cyan
    Write-Host ""

    if ($AdminSetup) {
        Write-Host "Administrative setup completed. Please restart your computer for all changes to take effect." -ForegroundColor Yellow
    }

    Write-Host "Note: This setup will update every time you run the script." -ForegroundColor Yellow
    Write-Host "If you wish to keep your own customizations, create a separate profile.ps1 file." -ForegroundColor Yellow
}
catch {
    Write-Host "An error occurred during setup: $_" -ForegroundColor Red
    Write-Host "Please check the error messages above and try again." -ForegroundColor Red
}
