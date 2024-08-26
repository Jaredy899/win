# Ensure the script only runs interactively
if ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Windows Terminal') {
    # Confirm the session is indeed interactive
    if (-not $env:SSH_CLIENT -and -not $env:SSH_TTY) {

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
        
        function jc {
            Invoke-RestMethod jaredcervantes.com/win | Invoke-Expression
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