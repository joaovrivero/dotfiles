#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
readonly -a STOW_PACKAGES=(zsh tmux starship nvim btop atuin mise ghostty herdr alacritty zed wezterm vscode pwsh)

cd "$REPO_DIR"

bash -n \
    install.sh \
    platforms/arch/install.sh \
    platforms/nixos/install.sh
shellcheck \
    install.sh \
    platforms/arch/install.sh \
    platforms/nixos/install.sh
zsh -n zsh/.zshrc

jq empty \
    vscode/.config/Code/User/settings.json \
    zed/.config/zed/settings.json \
    zed/.config/zed/themes/pinacoteca.json \
    theme/pinacoteca/windows-terminal.json \
    nvim/.config/nvim/.neoconf.json \
    nvim/.config/nvim/lazy-lock.json \
    nvim/.config/nvim/lazyvim.json

if ! jq -er 'to_entries | all(.value.commit | length == 40)' \
    nvim/.config/nvim/lazy-lock.json >/dev/null; then
    printf 'lazy-lock.json contains an invalid commit hash\n' >&2
    exit 1
fi

python3 - <<'PY'
import tomllib

for filename in (
    "starship/.config/starship.toml",
    "nvim/.config/nvim/stylua.toml",
    "theme/pinacoteca/colors.toml",
    "alacritty/.config/alacritty/alacritty.toml",
    "alacritty/.config/alacritty/pinacoteca.toml",
    "atuin/.config/atuin/config.toml",
    "mise/.config/mise/config.toml",
    "herdr/.config/herdr/config.toml",
):
    with open(filename, "rb") as config_file:
        tomllib.load(config_file)
PY

python3 theme/pinacoteca/tools/build.py --check

mapfile -t lua_files < <(find nvim/.config/nvim wezterm -type f -name '*.lua' -print)
luac -p "${lua_files[@]}"
stylua --check nvim/.config/nvim

stow_target="$(mktemp -d /tmp/dotfiles-stow-check.XXXXXX)"
trap 'rm -rf -- "$stow_target"' EXIT
stow --no --dir="$REPO_DIR" --target="$stow_target" "${STOW_PACKAGES[@]}"

if command -v nix >/dev/null 2>&1; then
    nix flake check --no-build --no-write-lock-file "path:$REPO_DIR"
fi

if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -Command '
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            "platforms/windows/install.ps1", [ref]$tokens, [ref]$errors
        )
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            "theme/pinacoteca/windows-accent.ps1", [ref]$tokens, [ref]$errors
        )
        if ($errors.Count) {
            $errors | Out-String | Write-Error
            exit 1
        }
    '
fi

git diff --check
printf 'All dotfile checks passed.\n'
