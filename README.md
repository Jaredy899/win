# Jared's Windows Setup Toolkit

A comprehensive Windows setup and configuration toolkit that automates various tasks for a fresh Windows installation. This toolkit provides an interactive menu to perform common setup operations, install applications, configure settings, and customize your Windows environment.

## ✨ Features

- **Interactive Menu Interface**: Navigate with arrow keys and enter to select options
- **Windows Update**: Easily update your Windows installation
- **First-time Setup**: Configure essential Windows settings
- **SSH Key Management**: Add and configure SSH keys for secure authentication
- **PowerShell Configuration**: Install and set up a customized PowerShell environment
- **Windows Activation**: Simplified Windows activation process
- **Nord Backgrounds**: Download and set up Nord-themed wallpapers
- **Integration with Chris Titus Tech's Windows Utility**: Access additional applications and tweaks

## 🚀 Installation

To get started, open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
irm jaredcervantes.com/win | iex
```

## 🛠️ Components

- **first-setup.ps1**: Main interactive menu for all toolkit features
- **Windows-Update.ps1**: Handles Windows update functionality
- **setup2.ps1**: Configures initial Windows settings
- **add_ssh_key_windows.ps1**: Manages SSH key setup
- **my_powershell/**: PowerShell customization and configuration
  - Custom profile with useful aliases and functions
  - Automatic setup of terminal enhancements
  - Starship prompt configuration
  - Nerd Font installation

## 📝 Usage

After running the installation command, you'll be presented with an interactive menu. Use the up and down arrow keys to navigate, and press Enter to select an option:

1. **Update Windows**: Check for and install Windows updates
2. **Start Setup Script**: Run the initial Windows configuration
3. **Add SSH Keys**: Setup SSH keys for secure connections
4. **Run My PowerShell Config**: Install and configure a custom PowerShell environment
5. **Activate Windows**: Perform Windows activation
6. **Download Nord Backgrounds**: Get Nord-themed wallpapers
7. **Run ChrisTitusTech's Windows Utility**: Access additional applications and tweaks
8. **Exit**: Close the toolkit

## 🙏 Acknowledgements

- [Chris Titus Tech](https://christitus.com/) for Windows utility integration
- [Nord Theme](https://www.nordtheme.com/) for the background themes
