REM Remote Desktop
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
if %ERRORLEVEL% EQU 0 Echo Remote Desktop enabled.
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
if %ERRORLEVEL% EQU 0 Echo Firewall disabled.
REM OpenSSH.Client
powershell Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
if %ERRORLEVEL% EQU 0 Echo OpenSSH.Client installed successfully.
REM OpenSSH.Server
powershell Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
if %ERRORLEVEL% EQU 0 Echo OpenSSH.Server installed successfully.
REM Start SSH
powershell Start-Service sshd
if %ERRORLEVEL% EQU 0 Echo SSH service enabled.
REM SSH Server Auto
powershell Set-Service -Name sshd -StartupType 'Automatic'
if %ERRORLEVEL% EQU 0 Echo SSH service enabled.   %ERRORLEVEL%
pause
Set-Service -Name W32Time -Status running -StartupType automatic
Echo Everything successfully installed and enabled.
