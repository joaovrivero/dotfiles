#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_TIMESTAMP="$(date +%Y.%m.%d-%H.%M.%S)"
readonly REPO_DIR BACKUP_TIMESTAMP
# home/ is stowed into $HOME and .config/ into ~/.config. These .config entries
# belong to desktop applications and are only linked with --gui.
readonly -a GUI_CONFIGS=(alacritty Code powershell spicetify wezterm zed)

DRY_RUN=false
WITH_DOCKER=false
WITH_GUI=false
LINKS_ONLY=false

msg() {
    printf '\n\033[1;34m==>\033[0m %s\n' "$1"
}

warn() {
    printf '\033[1;33mwarning:\033[0m %s\n' "$1" >&2
}

run() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
    "$@"
}

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --docker   Install and enable Docker, then add the current user to its group
  --gui        Install Linux GUI tools and link their configuration
  --links-only Skip package installation and only link the dotfiles
  --dry-run    Print the installation actions without changing the system
  -h, --help Show this help
EOF
}

parse_args() {
    while (($#)); do
        case "$1" in
            --docker) WITH_DOCKER=true ;;
            --gui) WITH_GUI=true ;;
            --links-only) LINKS_ONLY=true ;;
            --dry-run) DRY_RUN=true ;;
            -h|--help) usage; exit 0 ;;
            *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
        esac
        shift
    done
}

require_arch() {
    if ! command -v pacman >/dev/null 2>&1; then
        printf 'This installer supports Arch Linux and Arch-based WSL only.\n' >&2
        exit 1
    fi
}

install_yay() {
    msg "Installing base development tools"
    if $DRY_RUN; then
        printf '  sudo pacman -S --needed git base-devel zsh\n'
    else
        run sudo pacman -S --needed git base-devel zsh
    fi

    if command -v yay >/dev/null 2>&1; then
        return
    fi

    if $DRY_RUN; then
        printf '  build and install yay from the AUR in a temporary directory\n'
        return
    fi

    local yay_tmp
    yay_tmp="$(mktemp -d /tmp/dotfiles-yay.XXXXXX)"
    run git clone https://aur.archlinux.org/yay.git "$yay_tmp/yay"
    (
        cd "$yay_tmp/yay"
        run makepkg -si --noconfirm
    )
    run rm -rf -- "$yay_tmp"
}

install_packages() {
    msg "Installing terminal and development packages"
    local packages=(
        atuin bat btop clang curl eza fastfetch fd fzf git github-cli go
        imagemagick impala inetutils jq lazydocker lazygit llvm luarocks
        mariadb-libs mise neovim openssh postgresql-libs ripgrep
        rust shellcheck starship stow stylua tmux tree-sitter-cli
        ttf-jetbrains-mono-nerd unzip
        wget wl-clipboard xmlstarlet zoxide zsh zsh-autosuggestions
        zsh-completions zsh-syntax-highlighting
    )

    if $WITH_GUI; then
        packages+=(alacritty ghostty powershell-bin spicetify-cli visual-studio-code-bin wezterm zed)
    fi

    if $DRY_RUN; then
        printf '  yay -S --needed %s\n' "${packages[*]}"
    else
        run yay -S --needed "${packages[@]}"
    fi
}

backup_target() {
    local target="$1"

    [[ -e "$target" || -L "$target" ]] || return 0

    if [[ -L "$target" ]]; then
        local resolved
        resolved="$(readlink -m -- "$target")"
        [[ "$resolved" == "$REPO_DIR"/* ]] && return 0
    fi

    local backup="${target}.bak.${BACKUP_TIMESTAMP}"
    warn "Moving existing $target to $backup"
    if ! $DRY_RUN; then
        run mv -- "$target" "$backup"
    fi
}

# Earlier layouts stowed one package per tool (nvim/.config/nvim, tmux/.tmux.conf,
# ...). Their links now dangle and Stow refuses to replace them, so remove them.
prune_stale_links() {
    local link resolved
    while IFS= read -r -d '' link; do
        resolved="$(readlink -m -- "$link")"
        [[ "$resolved" == "$REPO_DIR"/* && ! -e "$resolved" ]] || continue
        warn "Removing stale link $link"
        if ! $DRY_RUN; then
            run rm -- "$link"
        fi
    done < <(
        find "$HOME" -maxdepth 1 -type l -print0
        find "$HOME/.config" -maxdepth 4 -type l -print0 2>/dev/null
    )
}

link_dotfiles() {
    msg "Linking dotfiles with GNU Stow"

    prune_stale_links

    local targets=(
        "$HOME/.zshrc"
        "$HOME/.config/tmux"
        "$HOME/.config/starship.toml"
        "$HOME/.config/nvim"
        "$HOME/.config/btop/themes/pinacoteca.theme"
        "$HOME/.config/atuin/config.toml"
        "$HOME/.config/mise/config.toml"
        "$HOME/.config/ghostty"
        "$HOME/.config/herdr/config.toml"
    )
    if $WITH_GUI; then
        targets+=(
            "$HOME/.config/wezterm"
            "$HOME/.config/alacritty"
            "$HOME/.config/zed"
            "$HOME/.config/spicetify/Themes/Pinacoteca"
            "$HOME/.config/Code/User/settings.json"
            "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
        )
    fi
    local target
    for target in "${targets[@]}"; do
        backup_target "$target"
    done

    local config_stow=(stow --restow --dir="$REPO_DIR" --target="$HOME/.config")
    if ! $WITH_GUI; then
        local ignored
        ignored="$(IFS='|'; printf '%s' "${GUI_CONFIGS[*]}")"
        config_stow+=(--ignore="^($ignored)\$")
    fi

    if $DRY_RUN; then
        printf '  stow --restow --dir=%q --target=%q home\n' "$REPO_DIR" "$HOME"
        printf '  %s .config\n' "${config_stow[*]}"
    else
        run mkdir -p -- "$HOME/.config"
        run stow --restow --dir="$REPO_DIR" --target="$HOME" home
        run "${config_stow[@]}" .config
    fi
}

setup_tpm() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [[ -d "$tpm_dir/.git" ]]; then
        return
    fi

    msg "Installing the tmux plugin manager"
    if $DRY_RUN; then
        printf '  git clone https://github.com/tmux-plugins/tpm %q\n' "$tpm_dir"
    else
        run git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    fi
}

configure_docker() {
    if ! $WITH_DOCKER; then
        return 0
    fi

    msg "Installing and configuring Docker"
    if $DRY_RUN; then
        printf '  yay -S --needed docker docker-compose docker-buildx\n'
        printf '  merge log rotation into /etc/docker/daemon.json\n'
        printf '  enable docker.service and add %q to the docker group\n' "$(id -un)"
        return
    fi

    run yay -S --needed docker docker-compose docker-buildx
    run sudo mkdir -p /etc/docker

    local daemon_file=/etc/docker/daemon.json
    local daemon_tmp
    daemon_tmp="$(mktemp /tmp/dotfiles-docker.XXXXXX)"

    if [[ -f "$daemon_file" ]]; then
        run sudo cp -- "$daemon_file" "${daemon_file}.bak.${BACKUP_TIMESTAMP}"
        if ! sudo jq '. + {
            "log-driver": "json-file",
            "log-opts": ((.["log-opts"] // {}) + {"max-size": "10m", "max-file": "5"})
        }' "$daemon_file" | tee "$daemon_tmp" >/dev/null; then
            rm -f -- "$daemon_tmp"
            printf '%s is not valid JSON; the original file was left unchanged.\n' "$daemon_file" >&2
            exit 1
        fi
    else
        printf '%s\n' '{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"5"}}' >"$daemon_tmp"
    fi

    run sudo install -m 0644 "$daemon_tmp" "$daemon_file"
    run rm -f -- "$daemon_tmp"

    if [[ -d /run/systemd/system ]]; then
        run sudo systemctl enable --now docker.service
    else
        warn "systemd is not running; Docker was installed but not started"
    fi

    if ! id -nG "$(id -un)" | grep -qw docker; then
        run sudo usermod -aG docker "$(id -un)"
        warn "Docker group membership grants root-equivalent access; log out and back in to apply it"
    fi
}

setup_shell() {
    msg "Configuring Zsh as the login shell"
    local zsh_path
    zsh_path="$(command -v zsh)"

    if ! grep -Fxq "$zsh_path" /etc/shells; then
        if $DRY_RUN; then
            printf '  add %q to /etc/shells\n' "$zsh_path"
        else
            printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        fi
    fi

    if [[ "${SHELL:-}" != "$zsh_path" ]]; then
        if $DRY_RUN; then
            printf '  chsh -s %q\n' "$zsh_path"
        else
            run chsh -s "$zsh_path"
        fi
    fi
}

main() {
    parse_args "$@"
    require_arch
    if $LINKS_ONLY; then
        link_dotfiles
        setup_tpm
    else
        install_yay
        install_packages
        link_dotfiles
        setup_tpm
        configure_docker
        setup_shell
    fi

    msg "Setup complete"
    if $DRY_RUN; then
        warn "This was a dry run; no changes were made"
    fi
}

main "$@"
