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
} else {
    # Define minimal required functions if module not available
    function Write-Log {
        param([string]$Message, [string]$Level = "INFO")
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
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

# Create a system restore point before applying updates
function New-SystemRestorePoint {
    [CmdletBinding()]
    param(
        [string]$Description = "Before Windows Updates"
    )
    
    try {
        Write-Log "Creating system restore point before installing updates..." -Level "INFO"
        
        # Check if System Restore is enabled
        $srService = Get-Service -Name "VSS" -ErrorAction SilentlyContinue
        if ($srService.Status -ne "Running") {
            Write-Log "Volume Shadow Copy Service (VSS) is not running. Attempting to start..." -Level "WARNING"
            Start-Service -Name "VSS" -ErrorAction Stop
        }
        
        # Enable System Restore if needed
        $systemDrive = $env:SystemDrive
        $srEnabled = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -ErrorAction SilentlyContinue).RPSessionInterval -ne 0
        
        if (-not $srEnabled) {
            Write-Log "System Restore is not enabled. Enabling for system drive..." -Level "WARNING"
            Enable-ComputerRestore -Drive $systemDrive -ErrorAction Stop
        }
        
        # Create the restore point
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "System restore point created successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to create system restore point: $_" -Level "ERROR"
        return $false
    }
}

# Function to install NuGet provider with error handling and retries
function Install-NuGetProvider {
    [CmdletBinding()]
    param(
        [int]$RetryCount = 3,
        [int]$RetryDelaySeconds = 5
    )
    
    try {
        # Set TLS 1.2 for compatibility with newer repositories
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
            Write-Log "NuGet provider not found. Installing NuGet provider..." -Level "INFO"
            
            $attempt = 0
            $success = $false
            
            while (-not $success -and $attempt -lt $RetryCount) {
                $attempt++
                try {
                    Write-Progress -Activity "Installing NuGet Package Provider" -Status "Attempt $attempt of $RetryCount" -PercentComplete (($attempt / $RetryCount) * 100)
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop
                    Write-Progress -Activity "Installing NuGet Package Provider" -Completed
                    $success = $true
                    Write-Log "NuGet provider installed successfully!" -Level "SUCCESS"
                }
                catch {
                    Write-Log "Attempt $attempt failed: $_" -Level "WARNING"
                    
                    if ($attempt -lt $RetryCount) {
                        Write-Log "Retrying in $RetryDelaySeconds seconds..." -Level "INFO"
                        Start-Sleep -Seconds $RetryDelaySeconds
                    }
                }
            }
            
            if (-not $success) {
                throw "Failed to install NuGet provider after $RetryCount attempts"
            }
        } else {
            Write-Log "NuGet provider is already installed" -Level "INFO"
        }
    }
    catch {
        Write-Log "Failed to install NuGet provider: $_" -Level "ERROR"
        return $false
    }
    
    return $true
}

# Function to install and import PSWindowsUpdate module
function Initialize-PSWindowsUpdate {
    [CmdletBinding()]
    param(
        [int]$RetryCount = 3,
        [int]$RetryDelaySeconds = 5
    )
    
    try {
        # Install NuGet provider first
        if (-not (Install-NuGetProvider -RetryCount $RetryCount -RetryDelaySeconds $RetryDelaySeconds)) {
            throw "Failed to install NuGet provider, cannot continue"
        }
        
        # Check if PSWindowsUpdate module is installed
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Log "Installing PSWindowsUpdate module..." -Level "INFO"
            
            $attempt = 0
            $success = $false
            
            while (-not $success -and $attempt -lt $RetryCount) {
                $attempt++
                try {
                    Write-Progress -Activity "Installing PSWindowsUpdate Module" -Status "Attempt $attempt of $RetryCount" -PercentComplete (($attempt / $RetryCount) * 100)
                    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -SkipPublisherCheck -ErrorAction Stop
                    Write-Progress -Activity "Installing PSWindowsUpdate Module" -Completed
                    $success = $true
                    Write-Log "PSWindowsUpdate module installed successfully!" -Level "SUCCESS"
                }
                catch {
                    Write-Log "Attempt $attempt failed: $_" -Level "WARNING"
                    
                    if ($attempt -lt $RetryCount) {
                        Write-Log "Retrying in $RetryDelaySeconds seconds..." -Level "INFO"
                        Start-Sleep -Seconds $RetryDelaySeconds
                    }
                }
            }
            
            if (-not $success) {
                throw "Failed to install PSWindowsUpdate module after $RetryCount attempts"
            }
        } else {
            Write-Log "PSWindowsUpdate module is already installed" -Level "INFO"
        }
        
        # Import the module
        Write-Log "Importing PSWindowsUpdate module..." -Level "INFO"
        Import-Module PSWindowsUpdate -Force -ErrorAction Stop
        Write-Log "PSWindowsUpdate module imported successfully" -Level "SUCCESS"
        
        return $true
    }
    catch {
        Write-Log "Failed to initialize PSWindowsUpdate: $_" -Level "ERROR"
        return $false
    }
}

# Function to show update details in a formatted table
function Show-UpdateDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Updates
    )
    
    if (-not $Updates -or $Updates.Count -eq 0) {
        Write-Log "No updates available" -Level "INFO"
        return
    }
    
    Write-Log "The following updates are available:" -Level "INFO"
    
    # Create a custom table with the most relevant information
    $updatesFormatted = $Updates | Select-Object @{
        Name = 'KB Article'; 
        Expression = { $_.KB }
    }, @{
        Name = 'Title'; 
        Expression = { if ($_.Title.Length -gt 60) { $_.Title.Substring(0, 57) + "..." } else { $_.Title } }
    }, @{
        Name = 'Size'; 
        Expression = {
            $size = $_.Size
            if ($size -gt 1GB) { "{0:N2} GB" -f ($size / 1GB) }
            elseif ($size -gt 1MB) { "{0:N2} MB" -f ($size / 1MB) }
            elseif ($size -gt 1KB) { "{0:N2} KB" -f ($size / 1KB) }
            else { "{0:N0} bytes" -f $size }
        }
    }, @{
        Name = 'Important'; 
        Expression = { $_.IsImportant }
    }
    
    $updatesFormatted | Format-Table -AutoSize
    
    # Show the total size of updates
    $totalSize = ($Updates | Measure-Object -Property Size -Sum).Sum
    if ($totalSize -gt 1GB) {
        Write-Log "Total download size: $("{0:N2}" -f ($totalSize / 1GB)) GB" -Level "INFO"
    } else {
        Write-Log "Total download size: $("{0:N2}" -f ($totalSize / 1MB)) MB" -Level "INFO"
    }
}

# Main function to install Windows updates
function Install-WindowsUpdatesWithProgress {
    [CmdletBinding()]
    param(
        [switch]$AcceptAll,
        [switch]$AutoReboot
    )
    
    try {
        # Create a system restore point first
        New-SystemRestorePoint -Description "Before Windows Updates $(Get-Date -Format 'yyyy-MM-dd')"
        
        # Show progress
        Write-Progress -Activity "Checking for updates" -Status "Please wait..." -PercentComplete 10
        
        # Get available updates with progress
        Write-Log "Checking for available updates..." -Level "INFO"
        $updates = Get-WindowsUpdate -ErrorAction Stop
        
        Write-Progress -Activity "Checking for updates" -Status "Complete" -PercentComplete 100
        Start-Sleep -Seconds 1
        Write-Progress -Activity "Checking for updates" -Completed
        
        # Show update details
        Show-UpdateDetails -Updates $updates
        
        # If no updates, exit
        if (-not $updates -or $updates.Count -eq 0) {
            Write-Log "No updates are available" -Level "INFO"
            return
        }
        
        # If not auto-accepting all, ask for confirmation
        $installUpdates = $AcceptAll
        if (-not $AcceptAll) {
            $confirmation = Read-Host "Do you want to install these updates? (Y/N)"
            $installUpdates = $confirmation -eq 'Y' -or $confirmation -eq 'y'
        }
        
        if (-not $installUpdates) {
            Write-Log "Update installation cancelled by user" -Level "INFO"
            return
        }
        
        # Determine reboot behavior
        if ($AutoReboot) {
            Write-Log "System will automatically reboot if required" -Level "WARNING"
        } else {
            Write-Log "System will not automatically reboot after updates" -Level "INFO"
        }
        
        # Install updates with progress
        Write-Log "Installing updates..." -Level "INFO"
        Install-WindowsUpdate -AcceptAll -MicrosoftUpdate -IgnoreRebootRequired:(-not $AutoReboot) -ErrorAction Stop
        
        Write-Log "Updates installation completed!" -Level "SUCCESS"
        
        # Check for pending reboot
        $pendingReboot = Get-WURebootStatus -Silent
        if ($pendingReboot) {
            Write-Log "A system reboot is required to complete the installation" -Level "WARNING"
            
            if (-not $AutoReboot) {
                $rebootNow = Read-Host "Do you want to reboot now? (Y/N)"
                if ($rebootNow -eq 'Y' -or $rebootNow -eq 'y') {
                    Write-Log "Initiating system reboot..." -Level "WARNING"
                    Restart-Computer -Force
                } else {
                    Write-Log "Please reboot your system manually to complete the installation" -Level "WARNING"
                }
            }
        }
    }
    catch {
        Write-Log "Error during Windows update installation: $_" -Level "ERROR"
        Write-Log "Please try running the script again or check the Windows Update service" -Level "WARNING"
    }
}

# Main script execution
Clear-Host
Write-Log "==== Windows Update Automation ====" -Level "INFO"

# Initialize the PSWindowsUpdate module
if (-not (Initialize-PSWindowsUpdate)) {
    Write-Log "Failed to initialize PSWindowsUpdate module, cannot continue" -Level "ERROR"
    Read-Host "Press Enter to exit"
    exit 1
}

# Get update history for reference
try {
    Write-Log "Retrieving recent update history..." -Level "INFO"
    $updateHistory = Get-WUHistory -MaxDate (Get-Date).AddDays(-30) -ErrorAction Stop
    
    if ($updateHistory) {
        Write-Log "Recently installed updates:" -Level "INFO"
        $updateHistory | Select-Object -First 5 | Format-Table -Property Date, Title -AutoSize
    } else {
        Write-Log "No recent update history found" -Level "INFO"
    }
}
catch {
    Write-Log "Failed to retrieve update history: $_" -Level "WARNING"
}

# Install Windows updates with progress
$autoReboot = $false
$response = Read-Host "Allow automatic reboot after updates if required? (Y/N)"
if ($response -eq 'Y' -or $response -eq 'y') {
    $autoReboot = $true
}

Install-WindowsUpdatesWithProgress -AcceptAll -AutoReboot:$autoReboot

Write-Log "Windows Update process completed" -Level "SUCCESS"
Read-Host "Press Enter to exit"
