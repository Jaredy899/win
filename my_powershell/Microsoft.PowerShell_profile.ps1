# Start of PowerShell Profile Script

# Ensure the script only runs interactively
if ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Windows Terminal') {
    # Confirm the session is indeed interactive
    if (-not $env:SSH_CLIENT -and -not $env:SSH_TTY) {

        # Check for internet connectivity (only if the session is interactive)
        $global:canConnectToGitHub = $false
        try {
            $response = Invoke-WebRequest -Uri "https://www.github.com" -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                $global:canConnectToGitHub = $true
            }
        } catch {
            # If there's an exception, we assume no connectivity
            Write-Host "Unable to reach GitHub. Skipping updates due to connectivity issues." -ForegroundColor Yellow
        }

        # Place your interactive commands below this line

        # Run fastfetch only in an interactive session
        fastfetch

        # Initialize zoxide if installed
        if (Get-Command zoxide -ErrorAction SilentlyContinue) {
            Invoke-Expression (& { (zoxide init powershell | Out-String) })
        }

        # Initialize starship if installed
        if (Get-Command starship -ErrorAction SilentlyContinue) {
            Invoke-Expression (& { starship init powershell })
        }

        # Define aliases and functions
        function Invoke-ff {
            fastfetch -c all
        }
        Set-Alias ff Invoke-ff

        function Invoke-apps {
            winget update --all --include-unknown
        }
        Set-Alias apps Invoke-apps

        function codes {
            Set-Location -Path "G:\My Drive\Codes"
        }

        # Define directory navigation aliases
        function home {
            Set-Location ~
        }
        Set-Alias home home

        function cd.. {
            Set-Location ..
        }
        Set-Alias cd.. cd..

        function .. {
            Set-Location ..
        }

        function ... {
            Set-Location ../..
        }

        function .... {
            Set-Location ../../..
        }

        function ..... {
            Set-Location ../../../..
        }

        # Function to check for PowerShell updates
        function Update-PowerShell {
            if (-not $global:canConnectToGitHub) {
                Write-Host "Skipping PowerShell update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
                return
            }

            try {
                Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
                $updateNeeded = $false
                $currentVersion = $PSVersionTable.PSVersion.ToString()
                $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
                $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
                $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
                if ($currentVersion -lt $latestVersion) {
                    $updateNeeded = $true
                }

                if ($updateNeeded) {
                    Write-Host "Updating PowerShell..." -ForegroundColor Yellow
                    winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements
                    Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
                } else {
                    Write-Host "Your PowerShell is up to date." -ForegroundColor Green
                }
            } catch {
                Write-Error "Failed to update PowerShell. Error: $_"
            }
        }

        # Function to check for Profile Updates (only Microsoft.PowerShell_profile.ps1)
        function Update-Profile {
            if (-not $global:canConnectToGitHub) {
                Write-Host "Skipping profile update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
                return
            }

            try {
                # Define the profile file and update URL
                $profileFile = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
                $url = "https://raw.githubusercontent.com/Jaredy899/win/main/my_powershell/Microsoft.PowerShell_profile.ps1"

                # Download the profile update
                Invoke-RestMethod $url -OutFile "$env:temp\profile_update.ps1"
                
                # Ensure the file is ready and not locked by another process
                Start-Sleep -Seconds 1  # Add a short delay to allow the file system to stabilize

                if (Test-Path "$env:temp\profile_update.ps1") {
                    $newhash = Get-FileHash "$env:temp\profile_update.ps1" -ErrorAction SilentlyContinue

                    # Check if the original profile file exists and compare hashes
                    if (Test-Path $profileFile) {
                        $oldhash = Get-FileHash $profileFile -ErrorAction SilentlyContinue
                    } else {
                        $oldhash = $null
                    }

                    if ($null -eq $oldhash -or $newhash.Hash -ne $oldhash.Hash) {
                        Write-Host "Profile update found. Updating profile..." -ForegroundColor Cyan
                        Copy-Item -Path "$env:temp\profile_update.ps1" -Destination $profileFile -Force
                        Write-Host "Profile has been updated. Please restart your shell to reflect changes." -ForegroundColor Magenta
                    } else {
                        Write-Host "Profile is already up to date." -ForegroundColor Green
                    }
                } else {
                    Write-Host "Profile update file not found after download. Skipping update." -ForegroundColor Yellow
                }
            } catch {
                Write-Error "Unable to check for profile updates. Error: $_"
            } finally {
                # Clean up the temporary file
                Remove-Item "$env:temp\profile_update.ps1" -ErrorAction SilentlyContinue
            }
        }

        # Check for updates to PowerShell and Profile (only in interactive sessions)
        if ($global:canConnectToGitHub) {
            Update-PowerShell
            Update-Profile
        } else {
            Write-Host "Skipping updates due to connectivity issues." -ForegroundColor Yellow
        }

    } # End of inner if block
} # End of outer if block