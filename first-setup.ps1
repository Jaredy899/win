# Clear the screen at script start
Clear-Host

# Set the GITPATH variable to the directory where the script is located
$GITPATH = Split-Path -Parent $MyInvocation.MyCommand.Definition
# GitHub URL base for the necessary configuration files
$GITHUB_BASE_URL = "https://raw.githubusercontent.com/Jaredy899/win/refs/heads/main"

# Function to invoke a script from local or GitHub
function Invoke-Script {
    param (
        [string]$scriptName,
        [string]$localPath,
        [string]$url
    )
    if (Test-Path "$localPath\$scriptName") {
        Write-Host "Invoking $scriptName from local directory..."
        & "$localPath\$scriptName"
    } else {
        Write-Host "Invoking $scriptName from GitHub..."
        $tempScript = "$env:TEMP\$scriptName"
        Invoke-RestMethod -Uri "$url/$scriptName" -OutFile $tempScript
        & $tempScript
        Remove-Item $tempScript -Force
    }
}

# Special function to invoke Chris Titus Tech's Windows Utility directly from URL
function Invoke-ChrisTitusTechUtility {
    Write-Host "Invoking Chris Titus Tech's Windows Utility..."
    Invoke-RestMethod -Uri "https://christitus.com/win" | Invoke-Expression
}

# Function to activate Windows
function Invoke-WindowsActivation {
    Write-Host "Activating Windows..."
    $confirmation = Read-Host "Are you sure you want to activate Windows? (y/n)"
    if ($confirmation -eq 'y') {
        Invoke-RestMethod https://get.activated.win | Invoke-Expression
    } else {
        Write-Host "Windows activation cancelled."
    }
}

# Function to download and extract Nord backgrounds
function Get-NordBackgrounds {
    $documentsPath = [Environment]::GetFolderPath("MyDocuments")
    $backgroundsPath = Join-Path $documentsPath "nord_backgrounds"
    $zipPath = Join-Path $documentsPath "nord_backgrounds.zip"
    $url = "https://github.com/ChrisTitusTech/nord-background/archive/refs/heads/main.zip"

    if (Test-Path $backgroundsPath) {
        if ((Read-Host "Nord backgrounds folder exists. Overwrite? (y/n)") -ne 'y') {
            Write-Host "Skipping Nord backgrounds download."; return
        }
        Remove-Item $backgroundsPath -Recurse -Force
    }

    try {
        Write-Host "Downloading and extracting Nord backgrounds..."
        Invoke-WebRequest -Uri $url -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $documentsPath -Force
        Rename-Item -Path (Join-Path $documentsPath "nord-background-main") -NewName "nord_backgrounds"
        Remove-Item -Path $zipPath -Force
        Write-Host "Nord backgrounds set up in: $backgroundsPath"
    }
    catch {
        Write-Host "Error setting up Nord backgrounds: $_"
    }
}

# Menu loop
$options = @(
    "Update Windows",
    "Start Setup Script",
    "Add SSH Keys",
    "Run My PowerShell Config",
    "Activate Windows",
    "Download Nord Backgrounds",
    "Run ChrisTitusTech's Windows Utility",
    "Exit"
)
$selectedIndex = 0

while ($true) {
    Write-Host "Select an option:" -ForegroundColor Cyan
    Write-Host
    
    # Display all options
    for ($i = 0; $i -lt $options.Length; $i++) {
        if ($i -eq $selectedIndex) {
            Write-Host ">" -ForegroundColor Green -NoNewline
            Write-Host " $($options[$i])" -ForegroundColor Green
        } else {
            Write-Host "  $($options[$i])"
        }
    }

    # Handle key input
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    switch ($key.VirtualKeyCode) {
        38 { # Up arrow
            $selectedIndex--
            if ($selectedIndex -lt 0) { $selectedIndex = $options.Length - 1 }
        }
        40 { # Down arrow
            $selectedIndex++
            if ($selectedIndex -ge $options.Length) { $selectedIndex = 0 }
        }
        13 { # Enter key
            Clear-Host
            switch ($selectedIndex) {
                0 { Invoke-Script -scriptName "Windows-Update.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
                1 { Invoke-Script -scriptName "setup2.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
                2 { Invoke-Script -scriptName "add_ssh_key_windows.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
                3 { Invoke-Script -scriptName "pwsh.ps1" -localPath $GITPATH -url $GITHUB_BASE_URL }
                4 { Invoke-WindowsActivation }
                5 { Get-NordBackgrounds }
                6 { Invoke-ChrisTitusTechUtility }
                7 { 
                    Write-Host "Exiting setup script."
                    return
                }
            }
            # Clear the screen after action completion
            Write-Host "`nPress any key to return to menu..." -ForegroundColor Magenta
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-Host
        }
    }
    Clear-Host
}
