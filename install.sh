#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Helper Functions ---
msg() {
    echo "🚀  $1"
}

# --- Main Setup Functions ---

install_yay() {
    msg "Installing build tools and yay..."
    sudo pacman -S --needed --noconfirm git base-devel
    if ! command -v yay &> /dev/null; then
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ~
    else
        msg "yay is already installed."
    fi
}

configure_pacman() {
    msg "Adding color and fun to pacman..."
    if ! grep -q "ILoveCandy" /etc/pacman.conf; then
        sudo sed -i '/^\[options\]/a Color\nILoveCandy' /etc/pacman.conf
    fi
}

install_packages() {
    msg "Installing terminal, dev, and system tools..."
    yay -S --noconfirm --needed \
        wget curl unzip zsh inetutils impala \
        fd eza fzf ripgrep zoxide bat jq xmlstarlet \
        wl-clipboard fastfetch btop starship openssh tmux \
        cargo clang llvm mise \
        imagemagick \
        mariadb-libs postgresql-libs \
        github-cli \
        lazygit lazydocker-bin
}

setup_neovim() {
    msg "Setting up LazyVim..."
    yay -S --noconfirm --needed nvim luarocks tree-sitter-cli

    # Backup existing config if it exists
    [ -d ~/.config/nvim ] && mv ~/.config/nvim ~/.config/nvim.bak_$(date +%Y.%m.%d-%H.%M.%S)
    [ -d ~/.local/share/nvim ] && mv ~/.local/share/nvim ~/.local/share/nvim.bak

    msg "Cloning LazyVim starter..."
    git clone https://github.com/LazyVim/starter ~/.config/nvim
    
    # This is crucial: By removing the .git dir, your dotfile manager (like stow)
    # can symlink your custom configs without git conflicts.
    rm -rf ~/.config/nvim/.git
    
    msg "LazyVim starter installed. Your custom configs will be linked by your dotfiles."
}

setup_docker() {
    msg "Setting up Docker..."
    yay -S --noconfirm --needed docker docker-compose docker-buildx

    msg "Configuring Docker log rotation..."
    sudo mkdir -p /etc/docker
    echo '{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"5"}}' | sudo tee /etc/docker/daemon.json > /dev/null

    msg "Enabling and starting Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker

    msg "Adding current user to the 'docker' group..."
    sudo usermod -aG docker ${USER}
}

setup_shell() {
    msg "Cloning dotfiles..."
    # This assumes the script is run from within the cloned dotfiles directory
    # If using stow, you would run it here.
    # For now, we'll assume manual linking or a stow command in the README.
    
    msg "Changing default shell to Zsh..."
    if [ "$(basename "$SHELL")" != "zsh" ]; then
        chsh -s $(which zsh)
        msg "Shell changed to Zsh. Please log out and back in for the change to take effect."
    else
        msg "Default shell is already Zsh."
    fi
}


# --- Main Execution ---
main() {
    install_yay
    configure_pacman
    install_packages
    setup_neovim
    setup_docker
    setup_shell
    
    echo ""
    echo "✅  Setup complete!"
    echo "IMPORTANT: Please reboot your system or log out and log back in to apply Docker group and shell changes."
}

main
