# Ensure the script only runs interactively
if ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Windows Terminal') {
    # Check if this is a regular SSH session, not SFTP
    if ($env:SSH_CLIENT -and $env:SSH_TTY -or -not $env:SSH_CLIENT) {

        # Place your interactive commands below this line

        # Run fastfetch only in an interactive session
        fastfetch

        # Initialize starship if installed
        if (Get-Command starship -ErrorAction SilentlyContinue) {
            Invoke-Expression (& { starship init powershell })
        }
        
        # Ensure Terminal-Icons module is installed before importing
        if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
            Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
        }
        Import-Module -Name Terminal-Icons

        # Define aliases and functions
        function ff {
            fastfetch -c all
        }

        function Get-PubIP { 
            (Invoke-WebRequest http://ifconfig.me/ip).Content 
        }

        function flushdns {
            Clear-DnsClientCache
            Write-Host "DNS has been flushed"
        }
        
        function apps {
            winget update --all --include-unknown --force
        }
        
        function jc {
            Invoke-RestMethod jaredcervantes.com/win | Invoke-Expression
        }

        function winutil {
            Invoke-RestMethod christitus.com/win | Invoke-Expression
        }

        function bios {
            shutdown.exe /r /fw /f /t 0
        }

        function app {
            param (
                [string]$appName
            )

            try {
                # Search for the app and parse results
                $results = winget search $appName | Out-String
                $lines = $results -split "`r?`n" | Where-Object { $_ -match '\S' }
                
                # Find apps (lines after the separator)
                $separator = $lines | Select-String -Pattern "^-{10,}" | Select-Object -First 1
                if (!$separator) { 
                    Write-Host "No results found for '$appName'."
                    return 
                }
                
                # Get app lines (everything after the separator)
                $apps = $lines[($separator.LineNumber)..($lines.Count-1)] | Where-Object { $_ -match '\S' }
                if ($apps.Count -eq 0) { 
                    Write-Host "No packages found."
                    return 
                }
                
                # Display numbered options
                Write-Host "Found packages:"
                for ($i = 0; $i -lt $apps.Count; $i++) {
                    Write-Host "[$($i+1)] $($apps[$i])"
                }
                
                # Get selection
                $choice = Read-Host "Enter number, ID, or press Enter for default"
                
                if ([string]::IsNullOrWhiteSpace($choice)) {
                    winget install $appName
                }
                elseif ($choice -match '^\d+$' -and [int]$choice -gt 0 -and [int]$choice -le $apps.Count) {
                    $id = ($apps[[int]$choice - 1] -split '\s+', 3)[1]
                    Write-Host "Installing $id..."
                    winget install --id $id
                }
                else {
                    Write-Host "Installing $choice..."
                    winget install --id $choice
                }
            }
            catch {
                Write-Host "Error: $_"
            }
        }

        # Git convenience functions
        function gcom {
            param (
                [Parameter(Mandatory=$true)]
                [string]$message
            )
            git add .
            git commit -m $message
        }

        function lazyg {
            param (
                [Parameter(Mandatory=$true)]
                [string]$message
            )
            git add .
            git commit -m $message
            git push
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

        function rmd {
            param(
                [Parameter(Mandatory=$true)]
                [string]$Path
            )
            Remove-Item -Path $Path -Recurse -Force
        }

        function mkdirg {
            param(
                [Parameter(Mandatory=$true)]
                [string]$Path
            )
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Set-Location $Path
        }

    } # End of inner if block
} # End of outer if block

# Initialize zoxide directly
Invoke-Expression (& { (zoxide init powershell | Out-String) })