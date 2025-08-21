# My Arch Linux Development Environment

This repository contains my personal dotfiles and an automated setup script to provision a complete development environment on a fresh Arch Linux (or Arch-based WSL) instance.

It includes configurations for **Zsh**, **Tmux**, and **Neovim (LazyVim)**.

## 🚀 One-Command Installation

**Prerequisite:** A fresh Arch Linux installation with `git` installed.
If `git` is not installed, run: `sudo pacman -Syu --noconfirm git`

Then, run this single command to clone the repository and start the setup:

```bash
git clone [https://github.com/joaovrivero/dotfiles.git](https://github.com/joaovrivero/dotfiles.git) ~/.dotfiles && cd ~/.dotfiles && ./install.sh
```

The script will:
- Install `yay` as an AUR helper.
- Install all terminal tools, development languages, and utilities.
- Configure and enable Docker.
- Set up Neovim with the LazyVim starter.
- Change your default shell to Zsh.

After the script finishes, you need to **reboot or log out** for all changes (like the Docker group and default shell) to take effect.

## 📦 What's Included?

-   **Shell:** Zsh with plugins managed by the `.zshrc` config.
-   **Terminal Tools:** `eza`, `fzf`, `ripgrep`, `btop`, `starship`, `tmux`, and more.
-   **Editor:** Neovim with LazyVim. Your custom configs from this repo will be automatically applied.
-   **Development:** `mise` (for managing tool versions), `cargo`, `clang`, Docker, `lazygit`, and `lazydocker`.

## Symlinking Configurations

After the script runs, your configurations need to be linked. If you use `stow`, you can do it with:

```bash
# First, install stow
sudo pacman -S stow

# From within the ~/.dotfiles directory, run:
stow */
```