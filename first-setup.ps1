# Function to install Scoop and gsudo
function Install-ScoopAndGsudo {
    Write-Output "Checking if Scoop is installed..."
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Output "Scoop not found. Installing Scoop..."
        Invoke-RestMethod -Uri "https://get.scoop.sh" -OutFile "$env:TEMP\installScoop.ps1"
        . "$env:TEMP\installScoop.ps1"
    } else {
        Write-Output "Scoop is already installed."
    }

    Write-Output "Checking if gsudo is installed..."
    if (-not (scoop list gsudo -ErrorAction SilentlyContinue)) {
        Write-Output "gsudo not found. Installing gsudo..."
        scoop install gsudo
    } else {
        Write-Output "gsudo is already installed."
    }
}

# Install Scoop and gsudo
Install-ScoopAndGsudo

# Function to display a message box with a Yes/No question
function Show-MessageBox {
    param (
        [string]$text,
        [string]$caption
    )

    Add-Type -AssemblyName PresentationFramework
    $result = [System.Windows.MessageBox]::Show($text, $caption, [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question, [System.Windows.MessageBoxResult]::None, [System.Windows.MessageBoxOptions]::ServiceNotification)
    return $result
}


# Prompt to update Windows with a message box
$question = "Do you want to update Windows? By saying yes, it will ask for administrator privileges."
$caption = "Windows Update"

$response = Show-MessageBox -text $question -caption $caption

if ($response -eq 'Yes') {
    # Run the Windows update script from the URL
    Write-Output "Downloading and running the Windows update script..."
    Invoke-RestMethod -Uri https://raw.githubusercontent.com/Jaredy899/setup/main/Windows-Update.ps1 -OutFile "$env:TEMP\setup2.ps1"
    gsudo powershell -File "$env:TEMP\setup2.ps1"
} else {
    Write-Output "Skipping Windows update."
}

# Prompt to start the setup script with a message box
$question = "Do you want to start the Setup script? By saying yes, it will ask for administrator privileges."
$caption = "Setup Script"

$response = Show-MessageBox -text $question -caption $caption

if ($response -eq 'Yes') {
    # Download and run the setup script
    Write-Output "Downloading and running the setup script..."
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Jaredy899/setup/main/setup2.ps1" -OutFile "$env:TEMP\setup2.ps1"
    gsudo powershell -File "$env:TEMP\setup2.ps1"
} else {
    Write-Output "Setup script was not started."
}

# Prompt to start My Powershell config with a message box
$question = "Do you want to start My Powershell config?"
$caption = "My Powershell Config"

$response = Show-MessageBox -text $question -caption $caption

if ($response -eq 'Yes') {
    # Download and run the My Powershell config script
    Write-Output "Downloading and running My Powershell config script..."
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Jaredy899/setup/main/my_powershell/pwsh.ps1" -OutFile "$env:TEMP\pwsh.ps1"
    . "$env:TEMP\pwsh.ps1"
} else {
    Write-Output "My Powershell config script was not started."
}

# Prompt to start ChrisTitusTech's Windows Utility with a message box
$question = "Do you want to start ChrisTitusTech's Windows Utility? By saying yes, it will ask for administrator privileges."
$caption = "ChrisTitusTech's Windows Utility"

$response = Show-MessageBox -text $question -caption $caption

if ($response -eq 'Yes') {
    # Download and run ChrisTitusTech's Windows Utility script using gsudo
    Write-Output "Downloading ChrisTitusTech's Windows Utility script..."
    Invoke-RestMethod -Uri "https://christitus.com/win" -OutFile "$env:TEMP\ctt_win.ps1"
    Write-Output "Running ChrisTitusTech's Windows Utility script..."
    gsudo powershell -File "$env:TEMP\ctt_win.ps1"
} else {
    Write-Output "ChrisTitusTech's Windows Utility was not started."
}
