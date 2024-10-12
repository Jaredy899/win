# Function to install the latest Fira Code Nerd Font
function Install-FiraCodeFont {
    param (
        [string]$FontRepo = "ryanoasis/nerd-fonts",
        [string]$FontName = "FiraCode",
        [string]$FontDisplayName = "Fira Code Nerd Font"
    )

    try {
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
            Write-Host "Fetching the latest release information from $apiUrl..."
            $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'PowerShell Script' }

            # Find the download URL for the font ZIP file
            $asset = $releaseInfo.assets | Where-Object { $_.name -like "$FontName*Windows*.zip" -or $_.name -like "$FontName*.zip" }
            if ($null -eq $asset) {
                Write-Error "Could not find a suitable asset for $FontName in the latest release."
                return
            }

            $fontZipUrl = $asset.browser_download_url
            $zipFilePath = "$env:TEMP\${FontName}.zip"
            $extractPath = "$env:TEMP\${FontName}"

            Write-Host "Downloading Fira Code Nerd Font from $fontZipUrl..."
            Start-BitsTransfer -Source $fontZipUrl -Destination $zipFilePath -ErrorAction Stop

            Write-Host "Extracting Fira Code Nerd Font..."
            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force

            Write-Host "Installing Fira Code Nerd Font..."
            $destination = (New-Object -ComObject Shell.Application).Namespace(0x14)
            Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf" | ForEach-Object {
                If (-not (Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                    $destination.CopyHere($_.FullName, 0x10)
                }
            }

            Write-Host "Cleaning up temporary files..."
            Remove-Item -Path $extractPath -Recurse -Force
            Remove-Item -Path $zipFilePath -Force

            Write-Host "Fira Code Nerd Font installed successfully."
        } else {
            Write-Host "Font ${FontDisplayName} is already installed."
        }
    }
    catch {
        Write-Error "Failed to download or install ${FontDisplayName} font. Error: $_"
    }
}

# Call the function to install Fira Code Nerd Font
Install-FiraCodeFont
