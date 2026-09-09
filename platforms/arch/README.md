# Arch Linux and WSL

This installer is for Arch Linux, Arch-based distributions, and Arch running
under WSL. It installs packages with `pacman` and `yay`, then links the shared
configuration with GNU Stow.

From the repository root:

```bash
./install.sh --platform arch --dry-run
./install.sh --platform arch
```

On Arch, `./install.sh` detects the platform, so `--platform arch` is optional.

The default setup is terminal-only, which also fits WSL. On a Linux desktop,
add WezTerm, PowerShell, VS Code, and their shared configuration with:

```bash
./install.sh --platform arch --gui
```

Docker is opt-in because the installer enables its service and adds your user
to the `docker` group:

```bash
./install.sh --platform arch --docker
```

Existing configuration files are moved to timestamped backup paths before Stow
creates links. The script is safe to rerun.

## What Arch manages

- CLI and development packages from the official repositories and AUR.
- Zsh as the login shell.
- TPM for tmux plugins.
- Shared Zsh, Neovim, Starship, tmux, and Zellij files.
- Linux GUI applications and their files only when `--gui` is supplied.
- Docker only when `--docker` is supplied.
