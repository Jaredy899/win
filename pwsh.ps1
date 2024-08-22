# Set the GITPATH variable to the directory where the script is located
$scriptPath = $MyInvocation.MyCommand.Path
if (-not $scriptPath) {
    # Alternative method if MyInvocation is not available
    $scriptPath = $PSScriptRoot
}
$GITPATH = Split-Path -Parent $scriptPath

# Function to install dependencies
function Install-Depend {
    $dependencies = @(
        @{Name="Git.Git"; Type="Package"}, 
        @{Name="7zip.7zip"; Type="Package"}, 
        @{Name="BurntSushi.Bat"; Type="Package"},
        @{Name="Starship.Starship"; Type="Package"},
        @{Name="JanDeDobbeleer.OhMyPosh"; Type="Package"},
        @{Name="Tabby.Tabby"; Type="Package"},
        @{Name="Alacritty.Alacritty"; Type="Package"},
        @{Name="junegunn.fzf"; Type="Package"},
        @{Name="ajeetdsouza.zoxide"; Type="Package"}
    )

    foreach ($dependency in $dependencies) {
        $name = $dependency.Name
        Write-Host "Installing $name..."
        if ($dependency.Type -eq "Package") {
            winget install --id $name --silent -e
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to install $name. Please check your package manager." -ForegroundColor Red
            exit 1
        }
    }
}

# Function to install a font
function Install-Font {
    $fontName = "MesloLGS NF"
    $fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    $fontDir = "$env:UserProfile\Fonts"

    if (-not (Test-Path -Path $fontDir)) {
        New-Item -ItemType Directory -Path $fontDir -Force
    }

    if (-not (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" | Where-Object { $_.PSChildName -like "*$fontName*" })) {
        Write-Host "Installing font '$fontName'..."
        $tempDir = New-TemporaryFile -ItemType Directory
        Invoke-WebRequest -Uri $fontUrl -OutFile "$tempDir\Meslo.zip"
        Expand-Archive -Path "$tempDir\Meslo.zip" -DestinationPath $fontDir -Force
        Remove-Item -Recurse -Force $tempDir
        Write-Host "Font '$fontName' installed successfully."
    } else {
        Write-Host "Font '$fontName' is already installed."
    }
}

# Function to link configurations
function Link-Config {
    $configDir = "$env:UserProfile\.config"

    # Ensure the config directory exists
    if (-not (Test-Path -Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force
    }

    # Fastfetch configuration
    $fastfetchConfigDir = "$configDir\fastfetch"
    $fastfetchConfig = "$fastfetchConfigDir\config.jsonc"

    if (-not (Test-Path -Path $fastfetchConfigDir)) {
        New-Item -ItemType Directory -Path $fastfetchConfigDir -Force
    }

    if (-not (Test-Path -Path $fastfetchConfig)) {
        if (Test-Path -Path "$GITPATH\config.jsonc") {
            New-Item -ItemType SymbolicLink -Path $fastfetchConfig -Target "$GITPATH\config.jsonc" -Force
            Write-Host "Linked config.jsonc to $fastfetchConfig."
        } else {
            Write-Host "config.jsonc not found in $GITPATH." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "config.jsonc already exists in $fastfetchConfigDir."
    }

    # Starship configuration
    $starshipConfig = "$configDir\starship.toml"
    if (-not (Test-Path -Path $starshipConfig)) {
        if (Test-Path -Path "$GITPATH\starship.toml") {
            New-Item -ItemType SymbolicLink -Path $starshipConfig -Target "$GITPATH\starship.toml" -Force
            Write-Host "Linked starship.toml to $starshipConfig."
        } else {
            Write-Host "starship.toml not found in $GITPATH." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "starship.toml already exists in $configDir."
    }
}

# Function to update PowerShell profile
function Update-Profile {
    $profileFile = $PROFILE

    if (-not (Test-Path -Path $profileFile)) {
        New-Item -ItemType File -Path $profileFile -Force
    }

    # Add lines to the profile
    $profileContent = Get-Content $profileFile -Raw
    $linesToAdd = @(
        'starship init powershell | Out-String | Invoke-Expression'
        'Import-Module Zoxide'
        'fastfetch'
    )

    foreach ($line in $linesToAdd) {
        if ($profileContent -notcontains $line) {
            Add-Content $profileFile -Value $line
        }
    }

    Write-Host "PowerShell profile updated."
}

# Run all functions
Install-Depend
Install-Font
Link-Config
Update-Profile

Write-Host "Setup completed successfully."
