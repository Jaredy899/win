# Variables
$sshDir = "$env:USERPROFILE\.ssh"
$authorizedKeys = "$sshDir\authorized_keys"

# Ensure the .ssh directory exists
if (-Not (Test-Path -Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force
    Write-Output "Created $sshDir."
} else {
    Write-Output "$sshDir already exists."
}

# Ensure the authorized_keys file exists
if (-Not (Test-Path -Path $authorizedKeys)) {
    New-Item -ItemType File -Path $authorizedKeys -Force
    Write-Output "Created $authorizedKeys."
} else {
    Write-Output "$authorizedKeys already exists."
}

# Set the correct permissions
icacls $sshDir /inheritance:r /grant:r "$($env:USERNAME):(F)"
icacls $authorizedKeys /inheritance:r /grant:r "$($env:USERNAME):(F)"
Write-Output "Set permissions for $sshDir and $authorizedKeys."

# Add the public key to the authorized_keys file if not already added
$publicKey = Read-Host -Prompt "Enter the public key to add"

# Read the content of the authorized_keys file
$authorizedKeysContent = Get-Content -Path $authorizedKeys

if ($authorizedKeysContent -contains $publicKey) {
    Write-Output "Public key already exists in $authorizedKeys."
} else {
    Add-Content -Path $authorizedKeys -Value $publicKey
    Write-Output "Public key added to $authorizedKeys."
}

Write-Output "Done."