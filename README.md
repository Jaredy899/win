# Jared's Windows Installs

The script starts with asking if you want to update Windows, then if you want to do certain setup items including allowing Remote Desktop, allowing SSH, and configuring time settings. Then the script asks if you want to install mypowershell, which is based on ChrisTitusTech's mybash. Finally it asks if you want to open ChrisTitusTech's WinUtil for additional applications and tweaks. 

This script uses scoop to install certain required features so you can run mypowershell in an unelevated shell, while asking to elevate for the rest of the scripts. 

## 💡 Usage

To get started, open your terminal and run the following command:
```ps1
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
irm jaredcervantes.com/win | iex
```
