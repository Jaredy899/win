# Check if NuGet provider is installed, if not, install it
if (-not (Get-PackageProvider -ListAvailable -Name NuGet)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

# Check if PSWindowsUpdate module is installed, if not, install it
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck
}

# Import the PSWindowsUpdate module
Import-Module PSWindowsUpdate

# Check for available updates
Write-Output "Checking for available updates..."
$updates = Get-WindowsUpdate

# Display available updates
if ($updates) {
    Write-Output "The following updates are available:"
    $updates | Format-Table -AutoSize

    # Install available updates
    Write-Output "Installing updates..."
    Install-WindowsUpdate -AcceptAll -AutoReboot
} else {
    Write-Output "No updates are available."
}

# List installed updates
Write-Output "Listing installed updates..."
Get-WUHistory | Format-Table -AutoSize

# Create a script for daily updates
$updateScriptPath = "C:\Path\To\UpdateScript.ps1"
$updateScriptContent = @"
Import-Module PSWindowsUpdate
Install-WindowsUpdate -AcceptAll -AutoReboot
"@
Set-Content -Path $updateScriptPath -Value $updateScriptContent

# Schedule a task to run the update script daily at 1 AM
$Action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-File `"$updateScriptPath`""
$Trigger = New-ScheduledTaskTrigger -Daily -At 1am
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -TaskName "Daily Windows Update" -Description "Run Windows Update daily at 1 AM"

Write-Output "Scheduled task 'Daily Windows Update' has been created to run daily at 1 AM."
