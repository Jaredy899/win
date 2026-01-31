# Windows Setup

One command to set up a complete Windows dev environment.

```powershell
irm jaredcervantes.com/os | iex
```

---

## What's Included

**Dev Tools**
- PowerShell 7, Windows Terminal, Git
- Neovim (LazyVim), Helix, Nano
- Starship prompt, fzf, zoxide, eza, bat, ripgrep, fd
- mise (version manager), yazi (file manager), fastfetch

**Fonts & Config**
- Fira Code Nerd Font (auto-installed)
- Windows Terminal auto-configured
- Dotfiles symlinked from your repo

**Admin Setup**
- OpenSSH Server (fast install via winget)
- Remote Desktop + firewall rules
- Automatic timezone detection
- Time sync scheduled task

---

## Scripts

| Script | What it does |
|--------|--------------|
| `menu.ps1` | Interactive menu (entry point) |
| `dev-setup.ps1` | Apps, fonts, configs, dotfiles |
| `admin-setup.ps1` | SSH, RDP, firewall, timezone |
| `ssh-keys.ps1` | Import/manage SSH keys |
| `windows-update.ps1` | Windows Update helper |

---

## Requirements

- Windows 10 (1809+) or Windows 11
- Run as Administrator
