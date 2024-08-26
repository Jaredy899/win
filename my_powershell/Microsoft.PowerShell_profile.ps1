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

        # Function to check for Profile Updates
        function Update-Profile {
            if (-not $global:canConnectToGitHub) {
                Write-Host "Skipping profile update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
                return
            }

            try {
                # Determine which profile to update based on the PowerShell version
                if ($PSVersionTable.PSEdition -eq "Core") {
                    $profileFile = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
                    $url = "https://raw.githubusercontent.com/Jaredy899/win/main/my_powershell/Microsoft.PowerShell_profile.ps1"
                } else {
                    $profileFile = "$HOME\Documents\WindowsPowerShell\profile.ps1"
                    $url = "https://raw.githubusercontent.com/Jaredy899/win/main/my_powershell/profile.ps1"
                }

                # Check if profile file exists and compare hashes
                if (Test-Path $profileFile) {
                    $oldhash = Get-FileHash $profileFile
                } else {
                    $oldhash = $null
                }

                Invoke-RestMethod $url -OutFile "$env:temp\profile_update.ps1"
                $newhash = Get-FileHash "$env:temp\profile_update.ps1"

                if ($null -eq $oldhash -or $newhash.Hash -ne $oldhash.Hash) {
                    Write-Host "Profile update found. Updating profile..." -ForegroundColor Cyan
                    Copy-Item -Path "$env:temp\profile_update.ps1" -Destination $profileFile -Force
                    Write-Host "Profile has been updated. Please restart your shell to reflect changes." -ForegroundColor Magenta
                } else {
                    Write-Host "Profile is already up to date." -ForegroundColor Green
                }
            } catch {
                Write-Error "Unable to check for profile updates. Error: $_"
            } finally {
                # Clean up the temporary file
                Remove-Item "$env:temp\profile_update.ps1" -ErrorAction SilentlyContinue
            }

            # Check if a custom user profile exists for aliases and personal functions
            $customProfilePath = "$HOME\Documents\PowerShell\profile.ps1"
            if ($PSVersionTable.PSEdition -ne "Core") {
                $customProfilePath = "$HOME\Documents\WindowsPowerShell\profile.ps1"
            }

            if (-not (Test-Path $customProfilePath)) {
                Write-Host "No custom profile.ps1 found. Would you like to create one for your own aliases and settings? (Y/N)" -ForegroundColor Yellow
                $response = Read-Host

                if ($response -eq 'Y' -or $response -eq 'y') {
                    # Create an empty custom profile file
                    New-Item -Path $customProfilePath -ItemType File -Force

                    # Provide instructions for editing the profile
                    Write-Host "An empty custom profile.ps1 has been created at $customProfilePath." -ForegroundColor Green
                    Write-Host "To add your own aliases or functions, you can use a text editor to edit this file." -ForegroundColor Cyan
                    Write-Host "For example, you can use nano by running the following command:" -ForegroundColor Cyan
                    Write-Host "`nStart-Process 'nano' -ArgumentList '$customProfilePath'`n" -ForegroundColor White
                    Write-Host "After adding your custom aliases or functions, save the file and restart your shell to apply the changes." -ForegroundColor Magenta
                } else {
                    Write-Host "No custom profile will be created. You can manually create one later at $customProfilePath if needed." -ForegroundColor Yellow
                }
            } else {
                Write-Host "A custom profile.ps1 already exists. You can add your own aliases and settings there." -ForegroundColor Green
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