# apps_install.ps1

# List of applications to install using exact Winget identifiers
$apps = @(
    "Starship.Starship",
    "junegunn.fzf",
    "ajeetdsouza.zoxide",
    "Fastfetch-cli.Fastfetch",
    "GNU.Nano",
    "sxyazi.yazi"
)

# Function to install applications using Winget
function Install-Apps {
    foreach ($app in $apps) {
        Write-Host "Installing $app using Winget..."
        winget install --id $app -e
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install $app. Please check your internet connection or the app name."
        }
    }
}

# Run the applications installation function
Install-Apps
