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
        
        try {
            # Run the Winget install command and capture the output
            $installResult = winget install --id $app --accept-package-agreements --accept-source-agreements -e 2>&1
            
            # Check if the app is already installed and up-to-date
            if ($installResult -match "No available upgrade found" -or $installResult -match "already installed" -or $installResult -match "Up to date") {
                Write-Host "$app is already installed and up to date."
            }
            elseif ($LASTEXITCODE -eq 0) {
                Write-Host "$app installed successfully."
            } else {
                Write-Error "Failed to install $app. Please check your internet connection or the app name."
            }
        }
        catch {
            Write-Error "An error occurred while installing $app. Error: $_"
        }
    }
}

# Run the applications installation function
Install-Apps
