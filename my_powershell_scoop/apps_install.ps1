# apps_install.ps1
function Install-Apps {
    $apps = @("bat", "starship", "fzf", "zoxide", "fastfetch", "curl", "nano", "yazi", "terminal-icons", "FiraCode-NF")

    foreach ($app in $apps) {
        Write-Host "Installing $app..."
        scoop install $app -g  # Install apps globally
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to install $app. Please check your internet connection or the app name." -ForegroundColor Red
            exit 1
        }
    }
}

# Run the applications installation function
Install-Apps
