# Set up paths
$documentsPath = [Environment]::GetFolderPath("MyDocuments")
$backgroundsPath = Join-Path $documentsPath "nord_backgrounds"
$zipPath = Join-Path $documentsPath "nord_backgrounds.zip"

function Get-NordBackgrounds {
    $url = "https://github.com/ChrisTitusTech/nord-background/archive/refs/heads/main.zip"
    Invoke-WebRequest -Uri $url -OutFile $zipPath
}

function Expand-NordBackgrounds {
    Expand-Archive -Path $zipPath -DestinationPath $documentsPath
    Rename-Item -Path (Join-Path $documentsPath "nord-background-main") -NewName "nord_backgrounds"
    Remove-Item -Path $zipPath
}

function Set-RandomBackground {
    $backgrounds = Get-ChildItem -Path $backgroundsPath -Include @("*.png", "*.jpg", "*.jpeg") -Recurse
    if ($backgrounds) {
        $chosenBackground = $backgrounds | Get-Random
        $wallpaperPath = $chosenBackground.FullName
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wallpaperPath
        rundll32.exe user32.dll, UpdatePerUserSystemParameters
        Write-Host "Background set to: $($chosenBackground.Name)"
    } else {
        Write-Host "No backgrounds found."
    }
}

function Start-BackgroundRotation {
    if (-not (Test-Path $backgroundsPath)) {
        Write-Host "Downloading backgrounds..."
        Get-NordBackgrounds
        Write-Host "Expanding backgrounds..."
        Expand-NordBackgrounds
    }
    
    Write-Host "Setting up background rotation..."
    while ($true) {
        Set-RandomBackground
        Start-Sleep -Seconds 1800  # 30 minutes
    }
}

# Run the main function
Start-BackgroundRotation
