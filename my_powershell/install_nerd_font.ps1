# Function to install the latest Fira Code Nerd Font
function Install-FiraCodeFont {
    param (
        [string]$FontRepo = "ryanoasis/nerd-fonts",
        [string]$FontName = "FiraCode",
        [string]$FontDisplayName = "Fira Code Nerd Font"
    )

    try {
        Write-Host "=== Starting Fira Code Nerd Font Installation ===" -ForegroundColor Cyan
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families

        # Check if the font is already installed
        $isFontInstalled = $false
        foreach ($font in $fontFamilies) {
            if ($font.Name -like "*Fira*Code*") {
                $isFontInstalled = $true
                break
            }
        }

        if (-not $isFontInstalled) {
            # Fetch the latest release information from GitHub API
            $apiUrl = "https://api.github.com/repos/$FontRepo/releases/latest"
            Write-Host "`nFetching the latest release information from " -ForegroundColor Yellow -NoNewline
            Write-Host "$apiUrl" -ForegroundColor Blue -NoNewline
            Write-Host "..." -ForegroundColor Yellow

            $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'PowerShell Script' }

            # Find the download URL for the font ZIP file
            $asset = $releaseInfo.assets | Where-Object { $_.name -like "$FontName*Windows*.zip" -or $_.name -like "$FontName*.zip" }
            if ($null -eq $asset) {
                Write-Host "Could not find a suitable asset for $FontName in the latest release." -ForegroundColor Red
                return
            }

            $fontZipUrl = $asset.browser_download_url
            $zipFilePath = "$env:TEMP\${FontName}.zip"
            $extractPath = "$env:TEMP\${FontName}"

            Write-Host "Downloading Fira Code Nerd Font..." -ForegroundColor Yellow
            Start-BitsTransfer -Source $fontZipUrl -Destination $zipFilePath -ErrorAction Stop

            Write-Host "Extracting Fira Code Nerd Font..." -ForegroundColor Yellow
            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force

            Write-Host "Installing Fira Code Nerd Font..." -ForegroundColor Yellow
            $destination = (New-Object -ComObject Shell.Application).Namespace(0x14)
            Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf" | ForEach-Object {
                If (-not (Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                    $destination.CopyHere($_.FullName, 0x10)
                }
            }

            Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
            Remove-Item -Path $extractPath -Recurse -Force
            Remove-Item -Path $zipFilePath -Force

            Write-Host "Fira Code Nerd Font installed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Font ${FontDisplayName} is already installed." -ForegroundColor Blue
        }
        Write-Host "`n=== Font Installation Complete ===" -ForegroundColor Cyan
    }
    catch {
        Write-Host "Failed to download or install ${FontDisplayName} font. Error: $_" -ForegroundColor Red
    }
}

# Call the function to install Fira Code Nerd Font
Install-FiraCodeFont
