#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows Update automation script
.DESCRIPTION
    Automates the process of checking for and installing Windows updates
    using the PSWindowsUpdate module.
.NOTES
    Version: 2.0.0
#>

# Import custom module if available
if (Test-Path -Path "$PSScriptRoot\WinSetupModule.psm1") {
    Import-Module "$PSScriptRoot\WinSetupModule.psm1" -Force
    
    # Use module's logging
    function Write-Log {
        param([string]$Message, [string]$Level = "INFO")
        Microsoft.PowerShell.Utility\Write-Host "[$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                "INFO"    { "White" }
                "WARNING" { "Yellow" }
                "ERROR"   { "Red" }
                "SUCCESS" { "Green" }
                default   { "White" }
            }
        )
    }
}

# Function to install NuGet provider if not installed
function Install-NuGetProvider {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
        Write-Log "NuGet provider not found. Installing NuGet provider..." -Level "WARNING"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Write-Log "NuGet provider installed successfully!" -Level "SUCCESS"
    } else {
        Write-Log "NuGet provider is already installed." -Level "INFO"
    }
}

# Install NuGet provider
Install-NuGetProvider

# Check if PSWindowsUpdate module is installed
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Log "Installing PSWindowsUpdate module..." -Level "WARNING"
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck
    Write-Log "PSWindowsUpdate module installed successfully!" -Level "SUCCESS"
} else {
    Write-Log "PSWindowsUpdate module is already installed." -Level "INFO"
}

# Import the PSWindowsUpdate module
try {
    Import-Module PSWindowsUpdate -ErrorAction Stop
    Write-Log "PSWindowsUpdate module imported successfully!" -Level "SUCCESS"
} catch {
    Write-Log "Failed to import PSWindowsUpdate module: $_" -Level "ERROR"
    exit 1
}

# Function to install Windows updates
function Install-WindowsUpdates {
    param (
        [switch]$AcceptAll,
        [switch]$SkipReboot
    )

    try {
        Write-Log "Checking for Windows updates..." -Level "INFO"
        
        $updates = Get-WindowsUpdate

        if (-not $updates) {
            Write-Log "No updates found. Your system is up to date!" -Level "SUCCESS"
            return
        }

        Write-Log "Found $($updates.Count) update(s)" -Level "INFO"
        $updates | ForEach-Object { Write-Log "- $($_.Title)" -Level "INFO" }

        if ($AcceptAll) {
            Write-Log "Installing all updates..." -Level "INFO"
            if ($SkipReboot) {
                Install-WindowsUpdate -AcceptAll -IgnoreReboot
            } else {
                Install-WindowsUpdate -AcceptAll
            }
        } else {
            $confirmation = Read-Host "Do you want to install these updates? (y/n)"
            if ($confirmation -eq 'y') {
                Write-Log "Installing updates..." -Level "INFO"
                if ($SkipReboot) {
                    Install-WindowsUpdate -AcceptAll -IgnoreReboot
                } else {
                    Install-WindowsUpdate -AcceptAll
                }
            } else {
                Write-Log "Update installation cancelled by user." -Level "WARNING"
            }
        }
    } catch {
        Write-Log "Error installing Windows updates: $_" -Level "ERROR"
    }
}

# Main execution
Write-Log "Starting Windows Update process..." -Level "INFO"

$skipRebootFlag = $false
$confirmation = Read-Host "Do you want to skip automatic reboots after updates? (y/n)"
if ($confirmation -eq 'y') {
    $skipRebootFlag = $true
    Write-Log "Automatic reboots will be skipped." -Level "INFO"
}

# Install Windows updates
Install-WindowsUpdates -SkipReboot:$skipRebootFlag

Write-Log "Windows Update process completed." -Level "SUCCESS"
