# Windows Development Environment Setup

This repository contains a comprehensive one-shot setup script for Windows development environments.

## 🚀 Quick Start

### Basic Setup (User Level)
```powershell
.\setup.ps1
```

### Full Admin Setup (Recommended)
```powershell
.\setup.ps1 -AdminSetup
```

### Custom Options
```powershell
# Skip application installation
.\setup.ps1 -AdminSetup -SkipApps

# Skip SSH key setup
.\setup.ps1 -AdminSetup -SkipSSH

# Show help
.\setup.ps1 -Help
```

## 🚀 Usage & Portability

### Running the Script
```batch
# Easiest way - just double-click (handles everything automatically)
setup.bat

# Or run manually if needed
powershell -ExecutionPolicy Bypass -File "setup.ps1"
```

### Standalone Setup
To use the script anywhere:

1. **Download the script**: Just `setup.ps1` - that's it!
2. **Run from anywhere**: Script automatically downloads latest configs from GitHub
3. **Offline fallback**: Uses embedded defaults if internet unavailable

### Config Loading Process
1. **Download from GitHub**: `https://raw.githubusercontent.com/Jaredy899/win/main/my_powershell/`
2. **Skip features**: If download fails, related features are disabled
3. **Internet required**: Script cannot function without internet access

### First Time Usage
After running the setup script:

1. **LazyVim**: First time you open Neovim, it will automatically download and install all plugins
2. **Starship**: Your shell prompt will be enhanced with the custom configuration
3. **Fastfetch**: System information tool is configured and ready to use
4. **PowerShell Profile**: Custom aliases and functions are available

## 📦 What Gets Installed

### Applications
- **Starship** - Cross-shell prompt
- **fzf** - Fuzzy finder
- **zoxide** - Smarter cd command
- **Fastfetch** - System information tool
- **bat** - Cat clone with syntax highlighting
- **Nano** - Text editor
- **eza** - Modern ls replacement
- **yazi** - Terminal file manager
- **Windows Terminal** - Modern terminal emulator
- **PowerShell** - Latest PowerShell
- **LazyVim** - Modern Neovim distribution with batteries included
- **Git** - Version control

### Fonts
- **Fira Code Nerd Font** - Programming font with ligatures and icons

### Configurations
- **PowerShell Profile** - Custom aliases, functions, and settings
- **Starship Config** - Beautiful shell prompt
- **Fastfetch Config** - System information display
- **Terminal Icons** - Icons in PowerShell

### Optional (Admin Setup)
- **Remote Desktop** - Enable RDP access
- **OpenSSH** - SSH server and client
- **Firewall Rules** - RDP and SSH access
- **Timezone Sync** - Automatic timezone detection and NTP sync
- **Windows Recall** - Disable AI feature
- **Edge Shortcut** - Remove desktop shortcut

## 🎯 Features

### Simple Installation
- **Installs all apps** - Let winget handle duplicates automatically
- **Parallel installation** - Uses PowerShell 7+ parallel processing
- **No pre-checking** - Faster and more reliable on fresh systems

### Self-Elevating
- **Automatic UAC** - Elevates to admin when needed
- **Parameter preservation** - Maintains flags during elevation

### Pure GitHub-Sourced Configs
- **Completely standalone** - Single script file with zero embedded configs
- **GitHub dependent** - Downloads all configs from repository at runtime
- **Fail gracefully** - Skips features when configs unavailable
- **Always current** - Gets latest config updates from GitHub

### Interactive Options
- **Password change** - Optional secure password update
- **SSH key import** - Import keys from GitHub
- **AutoHotkey shortcuts** - Custom keyboard shortcuts
- **Timezone selection** - Automatic or manual timezone setup

## 🔧 Usage Examples

### Fresh Windows Install
```powershell
# Run as regular user first
.\setup.ps1

# Then run admin setup
.\setup.ps1 -AdminSetup
```

### Development Machine Setup
```powershell
# Full setup with everything
.\setup.ps1 -AdminSetup
```

### Minimal Setup
```powershell
# Just apps and configs, skip admin features
.\setup.ps1 -SkipSSH
```

### Update Existing Setup
```powershell
# Re-run to update apps and configs
.\setup.ps1
```

## 📋 Requirements

- **Windows 10/11**
- **PowerShell 5.1+** (PowerShell 7+ recommended for parallel installation)
- **Internet connection** (for downloads)
- **Administrator privileges** (for admin setup)

## 🛠 Troubleshooting

### Winget Installation Issues
If Winget fails to install, you may need to:
1. Manually install Winget from the Microsoft Store
2. Run Windows Update
3. Restart and try again

### Permission Issues
- Run PowerShell as Administrator for admin setup
- The script will automatically request elevation when needed

### Network Issues
- Ensure internet connectivity
- Some corporate networks may block downloads
- Try running from a different network

## 📁 File Structure

```
├── setup.bat              # Auto-runner (handles permissions automatically)
├── setup.ps1              # Main one-shot setup script
├── my_powershell/         # Configuration files (used by setup.ps1)
│   ├── apps_install.ps1   # Legacy app installer (functionality in setup.ps1)
│   ├── install_winget.ps1 # Legacy winget installer (functionality in setup.ps1)
│   ├── install_nerd_font.ps1 # Legacy font installer (functionality in setup.ps1)
│   ├── Microsoft.PowerShell_profile.ps1 # PowerShell profile (read by setup.ps1)
│   ├── starship.toml      # Starship configuration (read by setup.ps1)
│   ├── config.jsonc       # Fastfetch configuration (read by setup.ps1)
│   └── shortcuts.ahk      # AutoHotkey shortcuts (read by setup.ps1)
├── setup2.ps1            # Legacy admin setup (functionality in setup.ps1)
├── add_ssh_key_windows.ps1 # Legacy SSH setup (simplified in setup.ps1)
└── first-setup.ps1       # Legacy first-time setup
```

## 🔄 Migration from Legacy Scripts

If you were using the separate scripts, simply run:
```powershell
.\setup.ps1 -AdminSetup
```

The new script combines all functionality and is much faster due to:
- Embedded configurations (no external downloads)
- Smart pre-checking (skips already installed apps)
- Parallel installation (PowerShell 7+)

## 🤝 Contributing

Feel free to submit issues or pull requests to improve the setup script!