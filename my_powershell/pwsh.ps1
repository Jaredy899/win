# Set the GITPATH variable to the directory where the script is located
$scriptPath = $MyInvocation.MyCommand.Path
if (-not $scriptPath) {
    # Alternative method if MyInvocation is not available or $scriptPath is empty
    $scriptPath = $PSScriptRoot
}

if (-not $scriptPath) {
    # If $scriptPath is still empty, use the current directory as a last resort
    $scriptPath = Get-Location
}

$GITPATH = Split-Path -Parent $scriptPath

# Debugging output to verify GITPATH
Write-Host "GITPATH is set to: $GITPATH"

# Function to install dependencies
function Install-Depend {
    $dependencies = @(
        @{Name="Git.Git"; Type="Package"}, 
        @{Name="7zip.7zip"; Type="Package"}, 
        @{Name="sharkdp.bat"; Type="Package"},
        @{Name="Starship.Starship"; Type="Package"},
        @{Name="JanDeDobbeleer.OhMyPosh"; Type="Package"},
        @{Name="Eugeny.Tabby"; Type="Package"},
        @{Name="Alacritty.Alacritty"; Type="Package"},
        @{Name="junegunn.fzf"; Type="Package"},
        @{Name="ajeetdsouza.zoxide"; Type="Package"}
    )

    foreach ($dependency in $dependencies) {
        $name = $dependency.Name
        Write-Host "Installing $name..."

        # Check if the package is already installed
        $installed = winget list --id $name | Select-String $name

        if ($installed) {
            Write-Host "$name is already installed. Skipping..."
        } else {
            # Install the package if not installed
            winget install --id $name --silent -e
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to install $name. Please check your package manager." -ForegroundColor Red
                exit 1
            }
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
        $tempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("TempDir_" + [System.Guid]::NewGuid().ToString())) -Force
        Invoke-WebRequest -Uri $fontUrl -OutFile "$tempDir\Meslo.zip"
        Expand-Archive -Path "$tempDir\Meslo.zip" -DestinationPath $fontDir -Force
        Remove-Item -Recurse -Force $tempDir
        Write-Host "Font '$fontName' installed successfully."
    } else {
        Write-Host "Font '$fontName' is already installed."
    }
}

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

    # Debugging output to check the expected location of config.jsonc
    Write-Host "Looking for config.jsonc in: $GITPATH"

    if (-not (Test-Path -Path "$GITPATH\config.jsonc")) {
        Write-Host "config.jsonc not found in $GITPATH." -ForegroundColor Red
        exit 1
    } else {
        New-Item -ItemType SymbolicLink -Path $fastfetchConfig -Target "$GITPATH\config.jsonc" -Force
        Write-Host "Linked config.jsonc to $fastfetchConfig."
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

    # Read the profile content line-by-line
    $profileContent = Get-Content $profileFile

    # Define the exact lines to add
    $linesToAdd = @(
        'starship init powershell | Out-String | Invoke-Expression',
        'zoxide init powershell | Out-String | Invoke-Expression',
        'fastfetch'
    )

    foreach ($line in $linesToAdd) {
        $found = $false
        foreach ($existingLine in $profileContent) {
            if ($existingLine.Trim() -eq $line.Trim()) {
                $found = $true
                break
            }
        }

        if (-not $found) {
            Add-Content $profileFile -Value "`n$line"
            Write-Host "Added '$line' to PowerShell profile."
        } else {
            Write-Host "'$line' is already in the PowerShell profile. Skipping..."
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
