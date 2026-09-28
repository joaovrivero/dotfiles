#!/usr/bin/env bash
# Reports how this machine relates to the repository: which dotfiles are linked
# into $HOME, which exist but point elsewhere, which are missing, and which
# tools are installed. Read-only.

set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
readonly -a TOOLS=(zsh tmux starship nvim btop atuin mise ghostty herdr alacritty zeditor spicetify wezterm code pwsh stow git fzf eza zoxide bat lazygit fastfetch)

green() { printf '\033[32m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }
red() { printf '\033[31m%s\033[0m' "$1"; }
dim() { printf '\033[2m%s\033[0m' "$1"; }

problems=0

# home/ is linked into $HOME and .config/ into $HOME/.config. Each top-level
# entry is checked as a whole.
readonly -a ROOTS=("home:$HOME" ".config:$HOME/.config")

# True when every file below $1 is reachable from $2 through symlinks.
dir_linked() {
    local source="$1" target="$2" file
    while IFS= read -r file; do
        [[ "$(readlink -f -- "$target/$file" 2>/dev/null || true)" == "$source/$file" ]] || return 1
    done < <(find "$source" -type f -printf '%P\n')
    return 0
}

check_target() {
    local source="$1" target="$2"
    local rel="${target#"$HOME"/}"

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

for root in "${ROOTS[@]}"; do
    dir="${root%%:*}" target_dir="${root#*:}"
    printf '%s/\n' "$dir"
    while IFS= read -r name; do
        check_target "$REPO_DIR/$dir/$name" "$target_dir/$name"
    done < <(find "$REPO_DIR/$dir" -mindepth 1 -maxdepth 1 -printf '%P\n' | sort -f)
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
