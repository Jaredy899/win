# Function to install NuGet provider if not installed
function Install-NuGetProvider {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
        Write-Output "NuGet provider not found. Installing NuGet provider..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
    }
}

# Install NuGet provider
Install-NuGetProvider

# Check if PSWindowsUpdate module is installed, if not, install it
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -ErrorAction SilentlyContinue
}

# Import the PSWindowsUpdate module
Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

# Verify if the module was imported successfully
if (-not (Get-Module -Name PSWindowsUpdate)) {
    Write-Output "Failed to import PSWindowsUpdate module."
    exit 1
}

# Check for available updates
Write-Output "Checking for available updates..."
$updates = Get-WindowsUpdate -ErrorAction SilentlyContinue | Where-Object { $_.IsInstalled -eq $false }

# Display available updates
if ($updates -and $updates.Count -gt 0) {
    Write-Output "The following updates are available:"
    $updates | Format-Table -AutoSize

    # Install available updates
    Write-Output "Installing updates..."
    $totalUpdates = $updates.Count
    $counter = 0

    foreach ($update in $updates) {
        # Use -UpdateId instead of -Update
        Install-WindowsUpdate -AcceptAll -AutoReboot -ErrorAction SilentlyContinue -UpdateId $update.Id
        $counter++
        Write-Progress -PercentComplete (($counter / $totalUpdates) * 100) -Status "Installing updates..." -CurrentOperation "Installing $($update.Title)"
    }

    # Wait until the system is ready after potential reboots
    while (Test-Path "C:\Windows\System32\shutdown.exe") {
        Write-Output "Waiting for system to finish updating and rebooting..."
        Start-Sleep -Seconds 60
    }

    # Verify if updates were installed
    $updatesAfterInstall = Get-WindowsUpdate -ErrorAction SilentlyContinue | Where-Object { $_.IsInstalled -eq $false }
    if ($updatesAfterInstall) {
        Write-Output "Some updates failed to install."
        exit 1
    } else {
        Write-Output "All updates installed successfully."
        # Show recently installed updates
        $recentUpdates = Get-WindowsUpdate -ErrorAction SilentlyContinue | Where-Object { $_.Date -gt (Get-Date).AddDays(-7) -and $_.IsInstalled -eq $true }
        if ($recentUpdates) {
            Write-Output "Recently installed updates:"
            $recentUpdates | Format-Table -AutoSize
        }
    }
} else {
    Write-Output "No updates are available."
}