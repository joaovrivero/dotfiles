#!/usr/bin/env bash
# Reports how this machine relates to the repository: which dotfiles are linked
# into $HOME, which exist but point elsewhere, which are missing, and which
# tools are installed. Read-only.

set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
readonly -a PACKAGES=(zsh tmux starship nvim btop atuin mise ghostty herdr alacritty zed wezterm vscode pwsh)
readonly -a TOOLS=(zsh tmux starship nvim btop atuin mise ghostty herdr alacritty zeditor wezterm code pwsh stow git fzf eza zoxide bat lazygit fastfetch)

green() { printf '\033[32m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }
red() { printf '\033[31m%s\033[0m' "$1"; }
dim() { printf '\033[2m%s\033[0m' "$1"; }

problems=0

# The top-level entries a stow package would create in $HOME. Files directly
# under the package map to $HOME/<file>; .config/<name> maps to
# $HOME/.config/<name>, except nvim-style directories are compared as a whole.
targets_for() {
    local package="$1"
    local dir="$REPO_DIR/$package"
    find "$dir" -mindepth 1 -maxdepth 1 ! -name '.config' -printf '%P\n'
    if [[ -d "$dir/.config" ]]; then
        find "$dir/.config" -mindepth 1 -maxdepth 1 -printf '.config/%P\n'
    fi
}

# True when every file below $1 is reachable from $2 through symlinks.
dir_linked() {
    local source="$1" target="$2" file
    while IFS= read -r file; do
        [[ "$(readlink -f -- "$target/$file" 2>/dev/null || true)" == "$source/$file" ]] || return 1
    done < <(find "$source" -type f -printf '%P\n')
    return 0
}

check_target() {
    local package="$1" rel="$2"
    local target="$HOME/$rel" source="$REPO_DIR/$package/$rel"

    if [[ -L "$target" ]]; then
        local resolved
        resolved="$(readlink -f -- "$target" 2>/dev/null || true)"
        if [[ "$resolved" == "$source" ]]; then
            printf '  %s %s\n' "$(green 'linked ')" "$rel"
        elif [[ "$resolved" == "$REPO_DIR"/* ]]; then
            printf '  %s %s %s\n' "$(green 'linked ')" "$rel" "$(dim "-> ${resolved#"$REPO_DIR"/}")"
        else
            printf '  %s %s %s\n' "$(yellow 'foreign')" "$rel" "$(dim "-> $resolved")"
            problems=$((problems + 1))
        fi
    elif [[ -d "$target" && -d "$source" ]]; then
        # Stow may have folded into an existing directory at any depth, so
        # check that every file in the source is reachable through a link.
        if dir_linked "$source" "$target"; then
            printf '  %s %s %s\n' "$(green 'linked ')" "$rel" "$(dim '(folded)')"
        else
            printf '  %s %s %s\n' "$(yellow 'local  ')" "$rel" "$(dim 'directory exists but is not linked to the repo')"
            problems=$((problems + 1))
        fi
    elif [[ -e "$target" ]]; then
        printf '  %s %s %s\n' "$(yellow 'local  ')" "$rel" "$(dim 'exists but is not linked to the repo')"
        problems=$((problems + 1))
    else
        printf '  %s %s\n' "$(red 'missing')" "$rel"
        problems=$((problems + 1))
    fi
}

printf 'Repository: %s\n' "$REPO_DIR"
printf 'Home:       %s\n\n' "$HOME"

for package in "${PACKAGES[@]}"; do
    [[ -d "$REPO_DIR/$package" ]] || continue
    printf '%s\n' "$package"
    while IFS= read -r rel; do
        check_target "$package" "$rel"
    done < <(targets_for "$package")
done

printf '\nTools\n'
missing=()
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf '  %s %s\n' "$(green 'found  ')" "$tool"
    else
        missing+=("$tool")
    fi
done
if ((${#missing[@]})); then
    printf '  %s %s\n' "$(dim 'absent ')" "$(dim "${missing[*]}")"
fi

printf '\n'
if ((problems)); then
    printf '%s %d item(s) are not linked to the repository. Run the installer with --links-only to link them.\n' "$(yellow 'Note:')" "$problems"
else
    printf '%s everything is linked.\n' "$(green 'OK:')"
fi
