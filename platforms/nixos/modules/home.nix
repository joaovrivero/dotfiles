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
          wezterm
          zed-editor
        ]
      );

    fonts.fontconfig.enable = cfg.gui.enable;

    home.file = {
      ".zshrc".source = dotfilesRoot + "/zsh/.zshrc";

      ".zsh/zsh-autosuggestions/zsh-autosuggestions.zsh".source =
        "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh";
      ".zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh".source =
        "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      ".zsh/zsh-completions/src" = {
        source = "${pkgs.zsh-completions}/share/zsh/site-functions";
        recursive = true;
      };
    }
    // lib.optionalAttrs cfg.gui.enable {
      ".wezterm.lua".source = dotfilesRoot + "/wezterm/.wezterm.lua";
      ".config/powershell/Microsoft.PowerShell_profile.ps1".source =
        dotfilesRoot + "/pwsh/.config/powershell/Microsoft.PowerShell_profile.ps1";
    };

    xdg.configFile = {
      "nvim" = {
        source = dotfilesRoot + "/nvim/.config/nvim";
        recursive = true;
      };
      "starship.toml".source = dotfilesRoot + "/starship/.config/starship.toml";
      "btop/themes/pinacoteca.theme".source = dotfilesRoot + "/btop/.config/btop/themes/pinacoteca.theme";
      "atuin/config.toml".source = dotfilesRoot + "/atuin/.config/atuin/config.toml";
      "mise/config.toml".source = dotfilesRoot + "/mise/.config/mise/config.toml";
      "herdr/config.toml".source = dotfilesRoot + "/herdr/.config/herdr/config.toml";
      "ghostty" = {
        source = dotfilesRoot + "/ghostty/.config/ghostty";
        recursive = true;
      };
    }
    // lib.optionalAttrs cfg.gui.enable {
      "Code/User/settings.json".source = dotfilesRoot + "/vscode/.config/Code/User/settings.json";
      "alacritty" = {
        source = dotfilesRoot + "/alacritty/.config/alacritty";
        recursive = true;
      };
      "zed" = {
        source = dotfilesRoot + "/zed/.config/zed";
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
        builtins.readFile (dotfilesRoot + "/tmux/.config/tmux/shared.conf")
        + builtins.readFile (dotfilesRoot + "/tmux/.config/tmux/pinacoteca.conf");
    };
  };
}
