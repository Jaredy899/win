# Install PSWindowsUpdate module if not installed
if (!(Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue)) {
    Install-Module PSWindowsUpdate -Force
}

# Get all available updates
$updates = Get-WUList

# Install the updates
Install-WindowsUpdate -AcceptAll

# Check for reboot required
$rebootRequired = Get-WURebootStatus

if ($rebootRequired) {
    Write-Host "Reboot required. Restarting system in 5 minutes..."
    Start-Sleep -Seconds 300
    Restart-Computer -Force
}
