# Windows Setup Menu
# Entry point for all setup scripts

# ANSI colors
$esc = [char]27
$Cyan = "${esc}[36m"
$Yellow = "${esc}[33m"
$Green = "${esc}[32m"
$Red = "${esc}[31m"
$Blue = "${esc}[34m"
$Gray = "${esc}[90m"
$Reset = "${esc}[0m"

# ============================================================================
# ADMIN CHECK & SELF-ELEVATION
# ============================================================================

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "${Yellow}Requesting administrator privileges...${Reset}"
    
    # Get the script content and re-run elevated
    $scriptPath = $MyInvocation.MyCommand.Definition
    
    if ($scriptPath -and (Test-Path $scriptPath)) {
        # Running from file - elevate with file path
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    } else {
        # Running from web (irm | iex) - download and run elevated
        $tempScript = "$env:TEMP\win-menu.ps1"
        $menuUrl = "https://raw.githubusercontent.com/Jaredy899/win/main/menu.ps1"
        try {
            Invoke-WebRequest -Uri $menuUrl -OutFile $tempScript -UseBasicParsing
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`""
        } catch {
            Write-Host "${Red}Failed to download menu script for elevation.${Reset}"
            Write-Host "${Yellow}Please run PowerShell as Administrator and try again.${Reset}"
            pause
        }
    }
    exit
}

Clear-Host

# ============================================================================
# CONFIGURATION
# ============================================================================

$GITPATH = Split-Path -Parent $MyInvocation.MyCommand.Definition
$GITHUB_BASE_URL = "https://raw.githubusercontent.com/Jaredy899/win/main"

# ============================================================================
# FUNCTIONS
# ============================================================================

function Invoke-Script {
    param (
        [string]$scriptName,
        [string]$localPath,
        [string]$url
    )
    if ($localPath -and (Test-Path "$localPath\$scriptName")) {
        Write-Host "${Cyan}Running $scriptName...${Reset}"
        & "$localPath\$scriptName"
    } else {
        Write-Host "${Cyan}Downloading and running $scriptName...${Reset}"
        $tempScript = "$env:TEMP\$scriptName"
        Invoke-RestMethod -Uri "$url/$scriptName" -OutFile $tempScript
        & $tempScript
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-ChrisTitusTechUtility {
    Write-Host "${Cyan}Launching Chris Titus Tech's Windows Utility...${Reset}"
    Invoke-RestMethod -Uri "https://christitus.com/win" | Invoke-Expression
}

function Invoke-WindowsActivation {
    Write-Host "${Yellow}This will run the Microsoft Activation Scripts.${Reset}"
    $confirm = Read-Host "Continue? (y/n)"
    if ($confirm -eq 'y') {
        Invoke-RestMethod https://get.activated.win | Invoke-Expression
    } else {
        Write-Host "${Blue}Cancelled.${Reset}"
    }
}

function Get-NordBackgrounds {
    $documentsPath = [Environment]::GetFolderPath("MyDocuments")
    $backgroundsPath = Join-Path $documentsPath "nord_backgrounds"
    $zipPath = Join-Path $documentsPath "nord_backgrounds.zip"
    $url = "https://github.com/ChrisTitusTech/nord-background/archive/refs/heads/main.zip"

    if (Test-Path $backgroundsPath) {
        $overwrite = Read-Host "Nord backgrounds exist. Overwrite? (y/n)"
        if ($overwrite -ne 'y') {
            Write-Host "${Blue}Skipped.${Reset}"
            return
        }
        Remove-Item $backgroundsPath -Recurse -Force
    }

    try {
        Write-Host "${Yellow}Downloading Nord backgrounds...${Reset}"
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $documentsPath -Force
        Rename-Item -Path (Join-Path $documentsPath "nord-background-main") -NewName "nord_backgrounds"
        Remove-Item -Path $zipPath -Force
        Write-Host "${Green}Nord backgrounds installed to: $backgroundsPath${Reset}"
    } catch {
        Write-Host "${Red}Error: $_${Reset}"
    }
}

function Enable-WindowsSudo {
    Write-Host "${Cyan}Enabling Windows Sudo...${Reset}"
    
    # Check Windows version
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 22621) {
        Write-Host "${Red}Windows Sudo requires Windows 11 22H2 or later.${Reset}"
        Write-Host "${Yellow}Your build: $build (need 22621+)${Reset}"
        return
    }
    
    # Check if already enabled
    $sudoEnabled = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" -Name "Enabled" -ErrorAction SilentlyContinue
    if ($sudoEnabled -and $sudoEnabled.Enabled -eq 1) {
        Write-Host "${Blue}Windows Sudo is already enabled.${Reset}"
        return
    }
    
    try {
        # Enable sudo (mode 1 = inline, mode 2 = new window, mode 3 = disable input)
        if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo")) {
            New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" -Name "Enabled" -Value 3 -Type DWord
        Write-Host "${Green}Windows Sudo enabled!${Reset}"
        Write-Host "${Blue}You can now use 'sudo command' in any terminal.${Reset}"
    } catch {
        Write-Host "${Red}Failed to enable sudo: $_${Reset}"
    }
}

# ============================================================================
# MENU
# ============================================================================

$options = @(
    "Windows Update",
    "Admin Setup (SSH, RDP, Firewall, Timezone)",
    "SSH Key Manager",
    "Dev Environment Setup (Apps, Fonts, Configs)",
    "Enable Windows Sudo",
    "Activate Windows",
    "Nord Backgrounds",
    "ChrisTitusTech WinUtil",
    "Exit"
)

$selectedIndex = 0

while ($true) {
    Write-Host ""
    Write-Host "${Cyan}  Windows Setup Menu${Reset}"
    Write-Host "${Gray}  Use arrow keys, Enter to select${Reset}"
    Write-Host ""
    
    for ($i = 0; $i -lt $options.Length; $i++) {
        if ($i -eq $selectedIndex) {
            Write-Host "  ${Green}> $($options[$i])${Reset}"
        } else {
            Write-Host "    $($options[$i])"
        }
    }

    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    switch ($key.VirtualKeyCode) {
        38 { # Up
            $selectedIndex--
            if ($selectedIndex -lt 0) { $selectedIndex = $options.Length - 1 }
        }
        40 { # Down
            $selectedIndex++
            if ($selectedIndex -ge $options.Length) { $selectedIndex = 0 }
        }
        13 { # Enter
            Clear-Host
            switch ($selectedIndex) {
                0 { Invoke-Script -scriptName "windows-update.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
                1 { Invoke-Script -scriptName "admin-setup.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
                2 { Invoke-Script -scriptName "ssh-keys.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
                3 { Invoke-Script -scriptName "dev-setup.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
                4 { Enable-WindowsSudo }
                5 { Invoke-WindowsActivation }
                6 { Get-NordBackgrounds }
                7 { Invoke-ChrisTitusTechUtility }
                8 {
                    Write-Host "${Blue}Goodbye!${Reset}"
                    exit
                }
            }
            
            Write-Host ""
            Write-Host "${Gray}[Enter] Return to menu${Reset}"
            Read-Host | Out-Null
            Clear-Host
        }
    }
    Clear-Host
}
