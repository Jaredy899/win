# apps_install.ps1

# List of applications to install using exact Winget identifiers
$apps = @(
    "Starship.Starship",
    "junegunn.fzf",
    "ajeetdsouza.zoxide",
    "Fastfetch-cli.Fastfetch",
    "sharkdp.bat",
    "GNU.Nano",
    "eza-community.eza",
    "sxyazi.yazi",
    "Microsoft.WindowsTerminal",
    "Microsoft.PowerShell",
    "Neovim.Neovim",
    "Git.Git"
)

# Function to check if an application is installed
function Test-AppInstalled {
    param([string]$appId)
    try {
        winget list --id $appId 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Function to install applications using Winget with batch processing
function Install-Apps {
    Write-Host "=== Starting Application Installation ===" -ForegroundColor Cyan

    # First, check which apps are already installed
    Write-Host "Checking installed applications..." -ForegroundColor Yellow
    $appsToInstall = @()
    $installedCount = 0

    foreach ($app in $apps) {
        if (Test-AppInstalled -appId $app) {
            Write-Host "$app is already installed." -ForegroundColor Blue
            $installedCount++
        } else {
            $appsToInstall += $app
        }
    }

    $totalApps = $apps.Count
    Write-Host "Found $installedCount of $totalApps apps already installed." -ForegroundColor Green

    # Only install missing apps
    if ($appsToInstall.Count -eq 0) {
        Write-Host "All applications are already installed!" -ForegroundColor Green
        Write-Host "`n=== Application Installation Complete ===" -ForegroundColor Cyan
        return
    }

    Write-Host "`nInstalling $($appsToInstall.Count) missing applications..." -ForegroundColor Yellow

    # Install missing apps (PowerShell 7+ supports parallel processing)
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        # Parallel installation for PowerShell 7+
        Write-Host "Using parallel installation (PowerShell 7+)..." -ForegroundColor Cyan
        $appsToInstall | ForEach-Object -Parallel {
            $app = $_
            Write-Host "Installing $app..." -ForegroundColor Yellow
            try {
                winget install --id $app --accept-package-agreements --accept-source-agreements -e 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "$app installed successfully!" -ForegroundColor Green
                } else {
                    Write-Host "Failed to install $app." -ForegroundColor Red
                }
            }
            catch {
                Write-Host "Error installing $app`: $_" -ForegroundColor Red
            }
        } -ThrottleLimit 3  # Limit parallel jobs to avoid overwhelming the system
    } else {
        # Sequential installation for older PowerShell versions
        Write-Host "Using sequential installation (PowerShell $($PSVersionTable.PSVersion.Major))..." -ForegroundColor Cyan
        foreach ($app in $appsToInstall) {
            Write-Host "Installing $app..." -ForegroundColor Yellow
            try {
                winget install --id $app --accept-package-agreements --accept-source-agreements -e 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "$app installed successfully!" -ForegroundColor Green
                } else {
                    Write-Host "Failed to install $app." -ForegroundColor Red
                }
            }
            catch {
                Write-Host "Error installing $app`: $_" -ForegroundColor Red
            }
        }
    }

    Write-Host "`n=== Application Installation Complete ===" -ForegroundColor Cyan
}

# Run the applications installation function
Install-Apps

