# Function to install the latest Fira Code Nerd Font
function Install-FiraCodeFont {
    param (
        [string]$FontRepo = "ryanoasis/nerd-fonts",
        [string]$FontName = "FiraCode",
        [string]$FontDisplayName = "FiraCode Nerd Font"
    )

    try {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name

        # Check if any of the Fira Code Nerd Font variations are already installed
        $isFontInstalled = $false
        $fontNamesToCheck = @(
            "FiraCode Nerd Font",
            "FiraCode Nerd Font Propo",
            "FiraCode Nerd Font Mono"
        )

        foreach ($fontName in $fontNamesToCheck) {
            if ($fontFamilies -contains $fontName) {
                $isFontInstalled = $true
                Write-Host "Font $fontName is already installed."
                break
            }
        }

        if (-not $isFontInstalled) {
            # Fetch the latest release information from GitHub API
            $apiUrl = "https://api.github.com/repos/$FontRepo/releases/latest"
            Write-Host "Fetching the latest release information from $apiUrl..."
            $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'PowerShell Script' }

            # Find the download URL for the FiraCode.zip asset only
            $asset = $releaseInfo.assets | Where-Object { $_.name -eq "$FontName.zip" }
            if ($null -eq $asset) {
                Write-Error "Could not find the asset $FontName.zip in the latest release."
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
            Write-Host "One or more Fira Code Nerd Font variations are already installed."
        }
    }
    catch {
        Write-Error "Failed to download or install ${FontDisplayName} font. Error: $_"
    }
}

# Call the function to install Fira Code Nerd Font
Install-FiraCodeFont