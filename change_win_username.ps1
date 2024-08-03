# Variables
$oldUserName = "Admin"
$newUserName = "Jared"
$tempAdminUser = "TempAdmin"
$tempAdminPassword = "jarjar89"

# Create a temporary admin account
Write-Output "Creating temporary admin account..."
net user $tempAdminUser $tempAdminPassword /add
net localgroup administrators $tempAdminUser /add

# Sign out current user and sign in to the temporary admin account
Write-Output "Please sign out from the current user and sign in to the temporary admin account to proceed."

# Pause the script
Read-Host "Press Enter to continue after signing in to the temporary admin account..."

# Rename the user folder
Write-Output "Renaming user folder..."
Rename-Item "C:\Users\$oldUserName" "C:\Users\$newUserName" -Force

# Update the registry
Write-Output "Updating the registry..."
$profileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
Get-ChildItem $profileListPath | ForEach-Object {
    $profilePath = (Get-ItemProperty $_.PSPath).ProfileImagePath
    if ($profilePath -like "*$oldUserName") {
        $newProfilePath = $profilePath -replace $oldUserName, $newUserName
        Set-ItemProperty -Path $_.PSPath -Name ProfileImagePath -Value $newProfilePath
    }
}

# Sign out temporary admin account and sign back in to the renamed user account
Write-Output "Please sign out from the temporary admin account and sign back in to the renamed user account."

# Pause the script
Read-Host "Press Enter to continue after signing in to the renamed user account..."

# Delete the temporary admin account
Write-Output "Deleting temporary admin account..."
net user $tempAdminUser /delete

# Create a scheduled task to delete the temporary admin account folder after a delay
$taskName = "DeleteTempAdminFolder"
$taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command `"Start-Sleep -Seconds 10; Remove-Item -Path 'C:\Users\$tempAdminUser' -Recurse -Force`""
$taskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger

Write-Output "Scheduled task created to delete the temporary admin account folder after a delay."
Write-Output "User folder renaming process completed successfully."
