# Jared's Windows Installs

The script starts with asking if you want to update Windows, then if you want to do certain setup items including allowing Remote Desktop, allowing SSH, and configuring time settings. Then the script asks if you want to install mypowershell, which is based on ChrisTitusTech's mybash. Finally it asks if you want to open ChrisTitusTech's WinUtil for additional applications and tweaks.

## 🚀 Features

- **Windows Updates**: Automated Windows update installation
- **System Configuration**: Configure Remote Desktop, SSH, time settings
- **SSH Key Management**: Easy GitHub SSH key import and configuration
- **PowerShell Enhancement**: Custom PowerShell profile with improved productivity
- **Visual Customization**: Terminal themes, fonts, and Nord backgrounds
- **Security Features**: System hardening options

## 💡 Usage

To get started, open your terminal and run the following command:
```ps1
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
irm jaredcervantes.com/win | iex
```

## 📋 Components

- **first-setup.ps1**: Interactive menu for all setup operations
- **setup2.ps1**: Core system configuration script
- **Windows-Update.ps1**: Windows update automation
- **add_ssh_key_windows.ps1**: SSH key management
- **my_powershell/**: PowerShell profile customization
