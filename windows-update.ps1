# Windows Update Script
# Checks for and installs Windows updates

# ANSI colors
$esc = [char]27
$Cyan = "${esc}[36m"
$Yellow = "${esc}[33m"
$Green = "${esc}[32m"
$Red = "${esc}[31m"
$Blue = "${esc}[34m"
$Reset = "${esc}[0m"

# Admin check
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "${Red}This script must be run as Administrator.${Reset}"
    exit 1
}

Write-Host ""
Write-Host "${Cyan}========================================${Reset}"
Write-Host "${Cyan}  Windows Update${Reset}"
Write-Host "${Cyan}========================================${Reset}"
Write-Host ""

# Ensure TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install NuGet provider if needed
Write-Host "${Yellow}Checking NuGet provider...${Reset}"
if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
        Write-Host "${Green}NuGet provider installed.${Reset}"
    } catch {
        Write-Host "${Red}Failed to install NuGet provider.${Reset}"
        exit 1
    }
} else {
    Write-Host "${Blue}NuGet provider OK.${Reset}"
}

# Install PSWindowsUpdate module if needed
Write-Host "${Yellow}Checking PSWindowsUpdate module...${Reset}"
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    try {
        Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck
        Write-Host "${Green}PSWindowsUpdate module installed.${Reset}"
    } catch {
        Write-Host "${Red}Failed to install PSWindowsUpdate.${Reset}"
        exit 1
    }
} else {
    Write-Host "${Blue}PSWindowsUpdate module OK.${Reset}"
}

Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

# Check for updates
Write-Host ""
Write-Host "${Cyan}--- Checking for updates ---${Reset}"
Write-Host ""

$updates = Get-WindowsUpdate

if (-not $updates -or $updates.Count -eq 0) {
    Write-Host "${Green}No updates available. System is up to date.${Reset}"
    exit 0
}

# Display updates
Write-Host "${Yellow}Available updates:${Reset}"
Write-Host ""
$updates | Format-Table -Property KB, Size, Title -AutoSize
Write-Host ""

$totalSize = ($updates | Measure-Object -Property MaxDownloadSize -Sum).Sum
$sizeMB = [math]::Round($totalSize / 1MB, 1)
Write-Host "${Blue}Total: $($updates.Count) updates ($sizeMB MB)${Reset}"
Write-Host ""

Write-Host "Install updates? (y/n): " -NoNewline
$install = Read-Host

if ($install -ne 'y' -and $install -ne 'Y') {
    Write-Host "${Yellow}Cancelled.${Reset}"
    exit 0
}

Write-Host ""
Write-Host "${Yellow}Installing updates...${Reset}"

try {
    Install-WindowsUpdate -AcceptAll -IgnoreReboot
    Write-Host ""
    Write-Host "${Green}Updates installed.${Reset}"
} catch {
    Write-Host "${Red}Error: $($_.Exception.Message)${Reset}"
}

# Reboot check
Write-Host ""
$rebootRequired = Get-WURebootStatus -Silent

if ($rebootRequired) {
    Write-Host "${Yellow}A restart is required.${Reset}"
    Write-Host ""
    Write-Host "Restart now? (y/n): " -NoNewline
    $reboot = Read-Host
    
    if ($reboot -eq 'y' -or $reboot -eq 'Y') {
        Write-Host "${Yellow}Restarting in 10 seconds... Ctrl+C to cancel.${Reset}"
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    } else {
        Write-Host "${Blue}Please restart when convenient.${Reset}"
    }
} else {
    Write-Host "${Green}No restart required.${Reset}"
}
