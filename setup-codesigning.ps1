#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Sets up code signing for PowerShell scripts
.DESCRIPTION
    Creates a self-signed certificate for code signing and signs all PowerShell scripts in the current directory
.NOTES
    Version: 1.0.0
#>

# Import custom module if available
if (Test-Path -Path "$PSScriptRoot\WinSetupModule.psm1") {
    Import-Module "$PSScriptRoot\WinSetupModule.psm1" -Force
} else {
    # Define minimal required functions if module not available
    function Write-Log {
        param([string]$Message, [string]$Level = "INFO")
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                "INFO"    { "White" }
                "WARNING" { "Yellow" }
                "ERROR"   { "Red" }
                "SUCCESS" { "Green" }
                default   { "White" }
            }
        )
    }
}

# Function to check prerequisites
function Test-CodeSigningPrerequisites {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    try {
        # Check if running as admin
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Log "This script must be run as Administrator" -Level "ERROR"
            return $false
        }
        
        # Check PowerShell version
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            Write-Log "PowerShell 5.0 or higher is required" -Level "ERROR"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Log "Error checking prerequisites: ${_}" -Level "ERROR"
        return $false
    }
}

# Function to create a self-signed certificate for code signing
function New-CodeSigningCertificate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$CertificateName,
        
        [Parameter(Mandatory)]
        [string]$CertificateStoreName
    )
    
    try {
        # Check if certificate already exists
        $existingCert = Get-ChildItem -Path "Cert:\LocalMachine\$CertificateStoreName" | 
            Where-Object { $_.Subject -match "CN=$CertificateName" -and $_.NotAfter -gt (Get-Date) }
            
        if ($existingCert) {
            Write-Log "Certificate '$CertificateName' already exists and is valid" -Level "INFO"
            return $existingCert
        }
        
        Write-Log "Creating new code signing certificate: $CertificateName" -Level "INFO"
        
        $cert = New-SelfSignedCertificate -Subject "CN=$CertificateName" `
            -CertStoreLocation "Cert:\LocalMachine\$CertificateStoreName" `
            -Type CodeSigningCert `
            -KeyUsage DigitalSignature `
            -KeyLength 2048 `
            -KeyAlgorithm RSA `
            -HashAlgorithm SHA256 `
            -NotAfter (Get-Date).AddYears(5)
            
        Write-Log "Certificate created successfully with thumbprint: $($cert.Thumbprint)" -Level "SUCCESS"
        return $cert
    }
    catch {
        Write-Log "Failed to create certificate: ${_}" -Level "ERROR"
        return $null
    }
}

# Function to sign a PowerShell script
function Set-ScriptSignature {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$FilePath,
        
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        
        [Parameter()]
        [string]$TimeStampServer = "http://timestamp.digicert.com"
    )
    
    try {
        if (-not (Test-Path -Path $FilePath)) {
            Write-Log "File not found: $FilePath" -Level "ERROR"
            return $false
        }
        
        # Check file extension
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        if ($extension -notin @('.ps1', '.psm1', '.psd1', '.ps1xml')) {
            Write-Log "File is not a PowerShell script: $FilePath" -Level "WARNING"
            return $false
        }
        
        # Sign the script
        $result = Set-AuthenticodeSignature -FilePath $FilePath `
            -Certificate $Certificate `
            -TimestampServer $TimeStampServer `
            -HashAlgorithm SHA256 `
            -IncludeChain All
            
        if ($result.Status -eq "Valid") {
            Write-Log "Successfully signed: $FilePath" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Failed to sign file: $FilePath. Status: $($result.Status)" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error signing file ${FilePath}: ${_}" -Level "ERROR"
        return $false
    }
}

# Function to sign all PowerShell scripts in a directory
function Set-DirectorySignatures {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DirectoryPath,
        
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        
        [Parameter()]
        [switch]$Recursive,
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        if (-not (Test-Path -Path $DirectoryPath -PathType Container)) {
            Write-Log "Directory not found: $DirectoryPath" -Level "ERROR"
            return
        }
        
        # Get all PowerShell scripts
        $scriptFiles = Get-ChildItem -Path $DirectoryPath -Include @("*.ps1", "*.psm1", "*.psd1") -File -Recurse:($Recursive)
        
        if (-not $scriptFiles -or $scriptFiles.Count -eq 0) {
            Write-Log "No PowerShell scripts found in $DirectoryPath" -Level "INFO"
            return
        }
        
        $totalFiles = $scriptFiles.Count
        $signedCount = 0
        $skippedCount = 0
        $failedCount = 0
        
        Write-Log "Found $totalFiles PowerShell scripts to process" -Level "INFO"
        
        foreach ($file in $scriptFiles) {
            $fileSignature = Get-AuthenticodeSignature -FilePath $file.FullName
            
            if ($fileSignature.Status -eq "Valid" -and -not $Force) {
                Write-Log "Skipping already signed file: $($file.FullName)" -Level "INFO"
                $skippedCount++
                continue
            }
            
            if (Set-ScriptSignature -FilePath $file.FullName -Certificate $Certificate) {
                $signedCount++
            } else {
                $failedCount++
            }
        }
        
        Write-Log "Code signing complete. Signed: $signedCount, Skipped: $skippedCount, Failed: $failedCount" -Level "INFO"
    }
    catch {
        Write-Log "Error processing directory ${DirectoryPath}: ${_}" -Level "ERROR"
    }
}

# Function to export the certificate to a .pfx file
function Export-CodeSigningCertificate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        
        [Parameter(Mandatory)]
        [string]$FilePath,
        
        [Parameter(Mandatory)]
        [SecureString]$Password
    )
    
    try {
        # Create directory if it doesn't exist
        $directory = [System.IO.Path]::GetDirectoryName($FilePath)
        if (-not (Test-Path -Path $directory -PathType Container)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }
        
        # Export the certificate with private key
        $certBytes = $Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $Password)
        [System.IO.File]::WriteAllBytes($FilePath, $certBytes)
        
        Write-Log "Certificate exported to: $FilePath" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to export certificate: ${_}" -Level "ERROR"
        return $false
    }
}

# Main function to set up code signing
function Initialize-CodeSigning {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$CertificateName = "PowerShell Code Signing",
        
        [Parameter()]
        [string]$DirectoryPath = $PSScriptRoot,
        
        [Parameter()]
        [switch]$Recursive,
        
        [Parameter()]
        [switch]$ExportCertificate,
        
        [Parameter()]
        [string]$ExportPath,
        
        [Parameter()]
        [SecureString]$ExportPassword
    )
    
    try {
        # Check prerequisites
        if (-not (Test-CodeSigningPrerequisites)) {
            Write-Log "Prerequisites check failed. Cannot continue." -Level "ERROR"
            return
        }
        
        # Create or get the certificate
        $cert = New-CodeSigningCertificate -CertificateName $CertificateName -CertificateStoreName "My"
        if (-not $cert) {
            Write-Log "Failed to create or retrieve certificate. Cannot continue." -Level "ERROR"
            return
        }
        
        # Sign all scripts in the directory
        Set-DirectorySignatures -DirectoryPath $DirectoryPath -Certificate $cert -Recursive:$Recursive
        
        # Export the certificate if requested
        if ($ExportCertificate) {
            if (-not $ExportPath) {
                $ExportPath = Join-Path $env:USERPROFILE "Documents\$CertificateName.pfx"
            }
            
            if (-not $ExportPassword) {
                Write-Log "Enter a password to protect the certificate:" -Level "INFO"
                $ExportPassword = Read-Host -AsSecureString
            }
            
            if (Export-CodeSigningCertificate -Certificate $cert -FilePath $ExportPath -Password $ExportPassword) {
                Write-Log "Certificate exported successfully. Keep it in a secure location." -Level "WARNING"
            }
        }
        
        Write-Log "Code signing setup completed successfully" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error during code signing setup: ${_}" -Level "ERROR"
    }
}

# Run the main function
try {
    Write-Host "`n  Windows Code Signing Setup" -ForegroundColor Cyan
    Write-Host "  =========================" -ForegroundColor DarkGray
    
    $setupParams = @{
        CertificateName = "Windows Setup Toolkit Code Signing"
        DirectoryPath = $PSScriptRoot
        Recursive = $true
    }
    
    $exportCert = Read-Host "Do you want to export the certificate to a PFX file? (y/n)"
    if ($exportCert -eq 'y') {
        $setupParams['ExportCertificate'] = $true
        $setupParams['ExportPath'] = Join-Path $env:USERPROFILE "Documents\WinSetupCodeSigning.pfx"
        Write-Host "Enter a password to protect the certificate:" -ForegroundColor Yellow
        $setupParams['ExportPassword'] = Read-Host -AsSecureString
    }
    
    Initialize-CodeSigning @setupParams
}
catch {
    Write-Log "Unhandled error in script: ${_}" -Level "ERROR"
}
finally {
    Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
    Read-Host
} 