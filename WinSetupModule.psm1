#Requires -Version 5.1
<#
.SYNOPSIS
    Windows Setup Module - Common functions for Windows setup and configuration scripts
.DESCRIPTION
    This module provides shared functionality used across Windows setup scripts
.NOTES
    Author: Jared Cervantes
    Version: 1.0.0
#>

# Global variables
$Script:ConfigPath = Join-Path $PSScriptRoot "config.json"
$Script:LogPath = $null
$Script:Config = $null

#region Configuration Functions

function Initialize-Config {
    [CmdletBinding()]
    param (
        [string]$ConfigPath = $Script:ConfigPath
    )
    
    try {
        if (Test-Path -Path $ConfigPath) {
            $Script:Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            Write-Verbose "Configuration loaded from $ConfigPath"
        } else {
            Write-Warning "Configuration file not found at $ConfigPath. Using default values."
            $Script:Config = @{
                general = @{
                    github_base_url = "https://raw.githubusercontent.com/Jaredy899/win/main"
                    version = "1.0.0"
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }
        
        # Initialize logging if enabled
        if ($Script:Config.logging.enabled) {
            Initialize-Logging
        }
        
        return $Script:Config
    }
    catch {
        Write-Error "Failed to initialize configuration: $_"
        throw
    }
}

function Get-ConfigValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [object]$DefaultValue
    )
    
    try {
        if ($null -eq $Script:Config) {
            Initialize-Config
        }
        
        # Use PowerShell's property path resolution
        $pathParts = $Path -split '\.'
        $current = $Script:Config
        
        foreach ($part in $pathParts) {
            if ($null -eq $current.$part) {
                return $DefaultValue
            }
            $current = $current.$part
        }
        
        return $current
    }
    catch {
        Write-Warning "Failed to get config value for path '$Path'. Using default value. Error: $_"
        return $DefaultValue
    }
}

function Test-Administrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Administrator {
    [CmdletBinding()]
    param()
    
    if (-not (Test-Administrator)) {
        Write-Error "This script must be run as Administrator" -Category PermissionDenied
        throw "Administrator privileges required"
    }
}

#endregion

#region Logging Functions

function Initialize-Logging {
    [CmdletBinding()]
    param()
    
    $logDir = Get-ConfigValue -Path "logging.path" -DefaultValue (Join-Path $env:USERPROFILE "AppData\Local\WindowsSetup\logs")
    $logDir = [System.Environment]::ExpandEnvironmentVariables($logDir)
    
    # Create log directory if it doesn't exist
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    # Set log file name based on date
    $Script:LogPath = Join-Path $logDir "setup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    # Create the log file
    New-Item -ItemType File -Path $Script:LogPath -Force | Out-Null
    
    # Log rotation - keep only X most recent logs
    $maxFiles = Get-ConfigValue -Path "logging.max_files" -DefaultValue 5
    $logFiles = Get-ChildItem -Path $logDir -Filter "setup_*.log" | Sort-Object LastWriteTime -Descending
    
    if ($logFiles.Count -gt $maxFiles) {
        $logFiles | Select-Object -Skip $maxFiles | Remove-Item -Force
    }
    
    Write-Log -Message "Logging initialized at $Script:LogPath" -Level "INFO"
}

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",
        
        [Parameter()]
        [switch]$NoConsole
    )
    
    # Check if logging is initialized
    if (-not $Script:LogPath -and (Get-ConfigValue -Path "logging.enabled" -DefaultValue $true)) {
        Initialize-Logging
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Log to file if logging is enabled
    if ($Script:LogPath) {
        Add-Content -Path $Script:LogPath -Value $logEntry
    }
    
    # Output to console with color based on level (unless NoConsole is specified)
    if (-not $NoConsole) {
        $color = switch ($Level) {
            "INFO"    { "White" }
            "WARNING" { "Yellow" }
            "ERROR"   { "Red" }
            "SUCCESS" { "Green" }
            "DEBUG"   { "Gray" }
            default   { "White" }
        }
        
        Write-Host $logEntry -ForegroundColor $color
    }
}

#endregion

#region Network Functions

function Test-InternetConnection {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter()]
        [string]$TestUrl = "https://www.microsoft.com"
    )
    
    try {
        Invoke-WebRequest -Uri $TestUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        return $true
    }
    catch {
        Write-Log -Message "Internet connection test failed: $_" -Level "WARNING"
        return $false
    }
}

function Invoke-FileDownload {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        
        [Parameter(Mandatory)]
        [string]$Destination,
        
        [Parameter()]
        [int]$RetryCount = 3,
        
        [Parameter()]
        [int]$RetryDelaySeconds = 2
    )
    
    $attempt = 0
    $success = $false
    
    while (-not $success -and $attempt -lt $RetryCount) {
        $attempt++
        try {
            Write-Log -Message "Downloading file from $Url to $Destination (Attempt $attempt of $RetryCount)" -Level "INFO"
            
            # Use BitsTransfer if available, fallback to WebRequest
            if (Get-Command -Name Start-BitsTransfer -ErrorAction SilentlyContinue) {
                Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
            } else {
                Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
            }
            
            $success = $true
            Write-Log -Message "Download completed successfully" -Level "INFO"
        }
        catch {
            Write-Log -Message "Download attempt $attempt failed: $_" -Level "WARNING"
            
            if ($attempt -lt $RetryCount) {
                Write-Log -Message "Retrying in $RetryDelaySeconds seconds..." -Level "INFO"
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
    
    if (-not $success) {
        Write-Log -Message "Failed to download file after $RetryCount attempts" -Level "ERROR"
        throw "Download failed after $RetryCount attempts: $Url"
    }
    
    return $Destination
}

#endregion

#region UI Functions

function Show-Menu {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Title,
        
        [Parameter(Mandatory)]
        [string[]]$Options,
        
        [Parameter()]
        [int]$DefaultOption = 0
    )
    
    $selectedIndex = $DefaultOption
    
    do {
        Clear-Host
        Write-Host "`n  $Title`n" -ForegroundColor Cyan
        Write-Host "  Use ↑↓ arrows to select and Enter to confirm:`n" -ForegroundColor Gray
        
        for ($i = 0; $i -lt $Options.Count; $i++) {
            if ($i -eq $selectedIndex) {
                Write-Host "  > " -NoNewline -ForegroundColor Cyan
                Write-Host $Options[$i] -ForegroundColor White -BackgroundColor DarkBlue
            } else {
                Write-Host "    $($Options[$i])" -ForegroundColor Gray
            }
        }
        
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $selectedIndex = ($selectedIndex - 1) % $Options.Count
                if ($selectedIndex -lt 0) { $selectedIndex = $Options.Count - 1 }
            }
            40 { # Down arrow
                $selectedIndex = ($selectedIndex + 1) % $Options.Count
            }
        }
    } while ($key.VirtualKeyCode -ne 13) # Enter key
    
    return $selectedIndex
}

function Show-Progress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Activity,
        
        [Parameter()]
        [int]$PercentComplete,
        
        [Parameter()]
        [string]$Status = "",
        
        [Parameter()]
        [int]$Id = 0
    )
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -Id $Id
    Write-Log -Message "Progress: $Activity - $Status ($PercentComplete%)" -Level "DEBUG" -NoConsole
}

#endregion

#region System Functions

function Set-FirewallRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [string]$DisplayName,
        
        [Parameter()]
        [string]$Description,
        
        [Parameter(Mandatory)]
        [ValidateSet("TCP", "UDP")]
        [string]$Protocol,
        
        [Parameter(Mandatory)]
        [int[]]$LocalPort,
        
        [Parameter()]
        [ValidateSet("Any", "Inbound", "Outbound")]
        [string]$Direction = "Inbound",
        
        [Parameter()]
        [ValidateSet("Allow", "Block")]
        [string]$Action = "Allow",
        
        [Parameter()]
        [switch]$Enable
    )
    
    try {
        Assert-Administrator
        
        # Check if rule exists
        $existingRule = Get-NetFirewallRule -Name $Name -ErrorAction SilentlyContinue
        
        if ($existingRule) {
            Write-Log -Message "Firewall rule '$Name' already exists. Updating..." -Level "INFO"
            
            # Update existing rule
            Set-NetFirewallRule -Name $Name -Enabled ([bool]$Enable) -ErrorAction Stop
            
            if ($DisplayName) {
                Set-NetFirewallRule -Name $Name -DisplayName $DisplayName -ErrorAction Stop
            }
            
            if ($Description) {
                Set-NetFirewallRule -Name $Name -Description $Description -ErrorAction Stop
            }
            
            # Update port and protocol
            Get-NetFirewallPortFilter -AssociatedNetFirewallRule $existingRule | 
                Set-NetFirewallPortFilter -Protocol $Protocol -LocalPort $LocalPort -ErrorAction Stop
        }
        else {
            Write-Log -Message "Creating new firewall rule '$Name'..." -Level "INFO"
            
            # Create new rule
            New-NetFirewallRule -Name $Name `
                -DisplayName ($DisplayName ?? $Name) `
                -Description ($Description ?? "") `
                -Direction $Direction `
                -Protocol $Protocol `
                -LocalPort $LocalPort `
                -Action $Action `
                -Enabled ([bool]$Enable) `
                -ErrorAction Stop | Out-Null
        }
        
        Write-Log -Message "Firewall rule '$Name' configured successfully" -Level "INFO"
    }
    catch {
        Write-Log -Message "Failed to configure firewall rule '$Name': $_" -Level "ERROR"
        throw
    }
}

function Set-ServiceConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        [string]$StartupType,
        
        [Parameter()]
        [switch]$Start,
        
        [Parameter()]
        [switch]$Stop
    )
    
    try {
        Assert-Administrator
        
        # Get current service
        $service = Get-Service -Name $Name -ErrorAction Stop
        
        # Set startup type if specified
        if ($StartupType) {
            Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
            Write-Log -Message "Service '$Name' startup type set to $StartupType" -Level "INFO"
        }
        
        # Start service if requested
        if ($Start) {
            if ($service.Status -ne 'Running') {
                Start-Service -Name $Name -ErrorAction Stop
                Write-Log -Message "Service '$Name' started" -Level "INFO"
            } else {
                Write-Log -Message "Service '$Name' is already running" -Level "INFO"
            }
        }
        
        # Stop service if requested
        if ($Stop) {
            if ($service.Status -ne 'Stopped') {
                Stop-Service -Name $Name -Force -ErrorAction Stop
                Write-Log -Message "Service '$Name' stopped" -Level "INFO"
            } else {
                Write-Log -Message "Service '$Name' is already stopped" -Level "INFO"
            }
        }
    }
    catch {
        Write-Log -Message "Failed to configure service '$Name': $_" -Level "ERROR"
        throw
    }
}

function Set-RegistryValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [object]$Value,
        
        [Parameter()]
        [ValidateSet("String", "ExpandString", "Binary", "DWord", "QWord", "MultiString")]
        [string]$Type = "String",
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        # Create registry path if it doesn't exist
        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -Force:$Force -ErrorAction Stop | Out-Null
            Write-Log -Message "Created registry path: $Path" -Level "INFO"
        }
        
        # Set registry value
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force:$Force -ErrorAction Stop | Out-Null
        Write-Log -Message "Set registry value: $Path\$Name = $Value (Type: $Type)" -Level "INFO"
    }
    catch {
        Write-Log -Message "Failed to set registry value '$Path\$Name': $_" -Level "ERROR"
        throw
    }
}

#endregion

# Export all functions
Export-ModuleMember -Function * -Alias * 