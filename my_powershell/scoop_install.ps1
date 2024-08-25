# scoop_install.ps1
function Install-Scoop {
    # Install Scoop using the simplified method with administrative privileges
    Write-Host "Installing Scoop using the simplified method..."
    Invoke-Expression "& {$(Invoke-RestMethod 'https://get.scoop.sh')} -RunAsAdmin"
    
    # Ensure Git is installed before adding any buckets
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is required for managing Scoop buckets. Installing Git..."
        scoop install git
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install Git. Please check your internet connection or try installing Git manually."
            exit 1
        }
    }

    # Add necessary buckets
    Write-Host "Adding Scoop buckets..."
    scoop bucket add main
    scoop bucket add extras
    scoop bucket add nerd-fonts
}

# Run the Scoop installation function
Install-Scoop
