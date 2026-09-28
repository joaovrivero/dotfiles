#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR

cd "$REPO_DIR"

bash -n \
    install.sh \
    platforms/arch/install.sh \
    platforms/nixos/install.sh
shellcheck \
    install.sh \
    platforms/arch/install.sh \
    platforms/nixos/install.sh \
    .config/tmux/pinacoteca-git.sh
zsh -n home/.zshrc

jq empty \
    .config/Code/User/settings.json \
    .config/zed/settings.json \
    .config/zed/themes/pinacoteca.json \
    theme/pinacoteca/windows-terminal.json \
    theme/pinacoteca/t3code.json \
    .config/nvim/.neoconf.json \
    .config/nvim/lazy-lock.json \
    .config/nvim/lazyvim.json

if ! jq -er 'to_entries | all(.value.commit | length == 40)' \
    .config/nvim/lazy-lock.json >/dev/null; then
    printf 'lazy-lock.json contains an invalid commit hash\n' >&2
    exit 1
fi

python3 - <<'PY'
import tomllib

for filename in (
    ".config/starship.toml",
    ".config/nvim/stylua.toml",
    "theme/pinacoteca/colors.toml",
    ".config/alacritty/alacritty.toml",
    ".config/alacritty/pinacoteca.toml",
    ".config/atuin/config.toml",
    ".config/mise/config.toml",
    ".config/herdr/config.toml",
):
    with open(filename, "rb") as config_file:
        tomllib.load(config_file)
PY

python3 theme/pinacoteca/tools/build.py --check

mapfile -t lua_files < <(find .config/nvim .config/wezterm -type f -name '*.lua' -print)
luac -p "${lua_files[@]}"
stylua --check .config/nvim

stow_target="$(mktemp -d /tmp/dotfiles-stow-check.XXXXXX)"
trap 'rm -rf -- "$stow_target"' EXIT
mkdir -p "$stow_target/.config"
stow --no --dir="$REPO_DIR" --target="$stow_target" home
stow --no --dir="$REPO_DIR" --target="$stow_target/.config" .config

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

python3 -m py_compile media/configure.py media/janitor.py

if command -v docker >/dev/null 2>&1; then
    docker compose --file media/compose.yml --profile server --profile manga config --quiet
fi

git diff --check
printf 'All dotfile checks passed.\n'
