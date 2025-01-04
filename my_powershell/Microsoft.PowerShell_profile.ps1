# Ensure the script only runs interactively
if ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Windows Terminal') {
    # Check if this is a regular SSH session, not SFTP
    if ($env:SSH_CLIENT -and $env:SSH_TTY -or -not $env:SSH_CLIENT) {

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

    } # End of inner if block
} # End of outer if block