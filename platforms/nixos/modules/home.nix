{ dotfilesRoot }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.jojoDotfiles;
in
{
  options.jojoDotfiles = {
    enable = lib.mkEnableOption "Jojo's shared dotfiles";
    gui.enable = lib.mkEnableOption "GUI terminal and editor configuration";
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      (with pkgs; [
        atuin
        bat
        btop
        clang
        curl
        eza
        fastfetch
        fd
        fzf
        gh
        go
        imagemagick
        impala
        inetutils
        jq
        lazydocker
        lazygit
        llvm
        luarocks
        mise
        neovim
        openssh
        ripgrep
        rustup
        shellcheck
        starship
        stylua
        tree-sitter
        unzip
        wget
        wl-clipboard
        xmlstarlet
        zoxide
        zsh
      ])
      ++ lib.optionals cfg.gui.enable (
        with pkgs;
        [
          alacritty
          ghostty
          powershell
          nerd-fonts.jetbrains-mono
          spicetify-cli
          wezterm
          zed-editor
        ]
      );

    fonts.fontconfig.enable = cfg.gui.enable;

    home.file = {
      ".zshrc".source = dotfilesRoot + "/home/.zshrc";

      ".zsh/zsh-autosuggestions/zsh-autosuggestions.zsh".source =
        "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh";
      ".zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh".source =
        "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      ".zsh/zsh-completions/src" = {
        source = "${pkgs.zsh-completions}/share/zsh/site-functions";
        recursive = true;
      };
    };

    xdg.configFile = {
      "nvim" = {
        source = dotfilesRoot + "/.config/nvim";
        recursive = true;
      };
      "starship.toml".source = dotfilesRoot + "/.config/starship.toml";
      "btop/themes/pinacoteca.theme".source = dotfilesRoot + "/.config/btop/themes/pinacoteca.theme";
      "atuin/config.toml".source = dotfilesRoot + "/.config/atuin/config.toml";
      "mise/config.toml".source = dotfilesRoot + "/.config/mise/config.toml";
      "herdr/config.toml".source = dotfilesRoot + "/.config/herdr/config.toml";
      "ghostty" = {
        source = dotfilesRoot + "/.config/ghostty";
        recursive = true;
      };
      # Home Manager writes tmux.conf itself; the status line calls this script.
      "tmux/pinacoteca-git.sh".source = dotfilesRoot + "/.config/tmux/pinacoteca-git.sh";
    }
    // lib.optionalAttrs cfg.gui.enable {
      "Code/User/settings.json".source = dotfilesRoot + "/.config/Code/User/settings.json";
      "powershell/Microsoft.PowerShell_profile.ps1".source =
        dotfilesRoot + "/.config/powershell/Microsoft.PowerShell_profile.ps1";
      "wezterm/wezterm.lua".source = dotfilesRoot + "/.config/wezterm/wezterm.lua";
      "alacritty" = {
        source = dotfilesRoot + "/.config/alacritty";
        recursive = true;
      };
      "zed" = {
        source = dotfilesRoot + "/.config/zed";
        recursive = true;
      };
      "spicetify/Themes/Pinacoteca" = {
        source = dotfilesRoot + "/.config/spicetify/Themes/Pinacoteca";
        recursive = true;
      };
    };

    programs.home-manager.enable = true;

    # Keybindings, prefix and terminal settings come from shared.conf so that
    # Arch and NixOS read the same file.
    programs.tmux = {
      enable = true;
      plugins = with pkgs.tmuxPlugins; [
        sensible
        vim-tmux-navigator
        yank
      ];
      extraConfig =
        builtins.readFile (dotfilesRoot + "/.config/tmux/shared.conf")
        + builtins.readFile (dotfilesRoot + "/.config/tmux/pinacoteca.conf");
    };
  };
}
