# Function to check if the script is running with administrator privileges
function Ensure-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "You do not have Administrator rights to run this script! Please re-run this script as an Administrator."
        exit 1
    } else {
        Write-Host "Running with administrator privileges."
    }
}

# Ensure the script is running with administrator privileges
Ensure-Admin

# Function to display a console prompt
function Show-Prompt {
    param (
        [string]$text
    )

    Write-Host "$text (y/n)"
    $response = Read-Host "Type 'y' to proceed or 'n' to skip"
    if ($response.ToLower() -eq 'y') {
        return 'Yes'
    } else {
        return 'No'
    }
}

# Prompt to update Windows
$question = "Do you want to update Windows?"
$response = Show-Prompt -text $question

if ($response -eq 'Yes') {
    # Run the Windows update script from the URL
    Write-Output "Downloading and running the Windows update script..."
    Invoke-RestMethod -Uri https://raw.githubusercontent.com/Jaredy899/setup/main/Windows-Update.ps1 -OutFile "$env:TEMP\setup2.ps1"
    powershell -File "$env:TEMP\setup2.ps1"
} else {
    Write-Output "Skipping Windows update."
}

# Prompt to start the setup script
$question = "Do you want to start the Setup script?"
$response = Show-Prompt -text $question

if ($response -eq 'Yes') {
    # Download and run the setup script
    Write-Output "Downloading and running the setup script..."
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Jaredy899/setup/main/setup2.ps1" -OutFile "$env:TEMP\setup2.ps1"
    powershell -File "$env:TEMP\setup2.ps1"
} else {
    Write-Output "Setup script was not started."
}

# Prompt to start My Powershell config
$question = "Do you want to start My Powershell config?"
$response = Show-Prompt -text $question

if ($response -eq 'Yes') {
    # Download and run the My Powershell config script
    Write-Output "Downloading and running My Powershell config script..."
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Jaredy899/setup/main/my_powershell/pwsh.ps1" -OutFile "$env:TEMP\pwsh.ps1"
    . "$env:TEMP\pwsh.ps1"
} else {
    Write-Output "My Powershell config script was not started."
}

# Prompt to start ChrisTitusTech's Windows Utility
$question = "Do you want to start ChrisTitusTech's Windows Utility?"
$response = Show-Prompt -text $question

if ($response -eq 'Yes') {
    # Download and run ChrisTitusTech's Windows Utility script
    Write-Output "Downloading ChrisTitusTech's Windows Utility script..."
    Invoke-RestMethod -Uri "https://christitus.com/win" -OutFile "$env:TEMP\ctt_win.ps1"
    Write-Output "Running ChrisTitusTech's Windows Utility script..."
    powershell -File "$env:TEMP\ctt_win.ps1"
} else {
    Write-Output "ChrisTitusTech's Windows Utility was not started."
}