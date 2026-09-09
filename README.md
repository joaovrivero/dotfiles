# Jojo's dotfiles

A development environment for Arch Linux, NixOS, and Windows. The shell,
editor, prompt, and terminal settings are shared; each platform has its own
package manager and installation path.

## Pick your platform

| Platform | Package/config manager | Start here |
| --- | --- | --- |
| Arch Linux or Arch on WSL | `pacman`, `yay`, GNU Stow | [Arch guide](./platforms/arch/README.md) |
| NixOS | Nix flakes and Home Manager | [NixOS guide](./platforms/nixos/README.md) |
| Windows 10 or 11 | PowerShell and optional WinGet | [Windows guide](./platforms/windows/README.md) |

Linux users can start with the dispatcher:

```bash
git clone https://github.com/joaovrivero/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh --dry-run
./install.sh
```

It reads `/etc/os-release` and selects Arch or NixOS. You can override detection
with `--platform arch` or `--platform nixos`.

Windows uses PowerShell from a Windows clone of the repository:

```powershell
pwsh -File .\platforms\windows\install.ps1 -DryRun
pwsh -File .\platforms\windows\install.ps1
```

## What is shared

```text
.
├── alacritty/  terminal settings and colours
├── atuin/      shell history
├── btop/       system monitor theme
├── ghostty/    terminal settings and colours
├── herdr/      agent workspace manager settings and colours
├── mise/       tool versions
├── nvim/       Neovim and LazyVim
├── pwsh/       PowerShell profile
├── starship/   prompt
├── theme/      Pinacoteca: the palette, its provenance, and Windows extras
├── tmux/       shared bindings plus the TPM entry point
├── vscode/     editor settings
├── wezterm/    terminal settings
├── zed/        editor settings and theme
└── zsh/        shell aliases, history, and tool initialization
```

All of them use the [Pinacoteca](./theme/pinacoteca/README.md) theme, a palette
sampled from the paintings in the wallpaper slideshow. `theme/pinacoteca/colors.toml`
is the source of truth; each tool carries its own copy of the colours.

Arch links these directories with Stow. NixOS points Home Manager at the same
files. Windows links the subset used by native Windows applications. There are
no copied platform variants to keep in sync.

## Nix flake outputs

The root [flake.nix](./flake.nix) provides:

- `homeConfigurations.<username>` for the ready-to-run profile in
  `platforms/nixos/settings.nix`.
- `homeModules.default` for an existing Home Manager configuration.
- `nixosModules.default` for system settings such as Zsh and optional Docker.

## Make it yours

Everything personal is isolated so a fork only needs to touch a few places:

- `platforms/nixos/settings.nix` holds the username, home directory and state
  version for Home Manager.
- Machine-specific settings that should not be committed go in files the
  configs load when present: `~/.zshrc.local`, `~/.tmux.local.conf`,
  `~/.wezterm.local.lua` (return a function that receives the config), and on
  Windows `%APPDATA%\alacritty\local.toml`.
- `zsh/.zshrc` aliases, `mise/` tool versions and `herdr/` are my daily
  drivers; replace them freely.
- The colours live in [theme/pinacoteca](./theme/pinacoteca/README.md). Change
  `colors.toml`, run `python3 theme/pinacoteca/tools/build.py`, and every
  terminal, editor and prompt config is rendered from it.

To see how a machine relates to the repository, run the doctor. It reports what
is linked, what exists locally but points elsewhere, what is missing, and which
tools are installed:

```bash
./scripts/doctor.sh
```

On Arch, `./install.sh --links-only` links the dotfiles without installing
packages; add `--gui` to include the desktop applications.

## Check changes

```bash
./scripts/check.sh
```

The check script validates shell and Lua syntax, formatting, JSON, TOML, Stow
layout, and the Nix flake when Nix is installed. GitHub Actions runs the same
checks on every push and pull request.
