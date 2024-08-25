# scoop_install.ps1

function Install-Scoop {
    # Set Execution Policy to RemoteSigned and accept automatically
    Write-Host "Setting PowerShell Execution Policy to RemoteSigned..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

    # Install Scoop using the simplified method with administrative privileges
    Write-Host "Installing Scoop using the simplified method with admin privileges..."
    Invoke-Expression "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"

    # Ensure Git is installed
    Write-Host "Installing Git..."
    scoop install git

    # Add necessary buckets
    Write-Host "Adding extras and nerd-fonts buckets..."
    scoop bucket add extras
    scoop bucket add nerd-fonts

    Write-Host "Scoop installation and setup complete."
}

# Run the Scoop installation function
Install-Scoop
