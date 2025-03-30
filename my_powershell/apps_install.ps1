# apps_install.ps1

# List of applications to install using exact Winget identifiers
$apps = @(
    "Starship.Starship",
    "junegunn.fzf",
    "ajeetdsouza.zoxide",
    "Fastfetch-cli.Fastfetch",
    "sharkdp.bat",
    "GNU.Nano",
    "sxyazi.yazi",
    "Microsoft.WindowsTerminal",
    "Microsoft.PowerShell",
    "Neovim.Neovim",
    "Git.Git"
)

# Function to install applications using Winget
function Install-Apps {
    Write-Host "=== Starting Application Installation ===" -ForegroundColor Cyan
    foreach ($app in $apps) {
        Write-Host "`nInstalling " -ForegroundColor Yellow -NoNewline
        Write-Host "$app" -ForegroundColor Blue -NoNewline
        Write-Host " using Winget..." -ForegroundColor Yellow
        
        try {
            # Run the Winget install command and capture the output
            $installResult = winget install --id $app --accept-package-agreements --accept-source-agreements -e 2>&1
            
            # Check if the app is already installed and up-to-date
            if ($installResult -match "No available upgrade found" -or $installResult -match "already installed" -or $installResult -match "Up to date") {
                Write-Host "$app is already installed and up to date." -ForegroundColor Blue
            }
            elseif ($LASTEXITCODE -eq 0) {
                Write-Host "$app installed successfully!" -ForegroundColor Green
            } else {
                Write-Host "Failed to install $app. Please check your internet connection or the app name." -ForegroundColor Red
            }
        }
        catch {
            Write-Host "An error occurred while installing $app. Error: $_" -ForegroundColor Red
        }
    }
    Write-Host "`n=== Application Installation Complete ===" -ForegroundColor Cyan
}

# Run the applications installation function
Install-Apps
