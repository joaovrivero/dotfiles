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
    enable = lib.mkEnableOption "Jojo's system defaults";
    user = lib.mkOption {
      type = lib.types.str;
      description = "Existing NixOS user that should use Zsh.";
      example = "jojo";
    };
    docker.enable = lib.mkEnableOption "Docker";
  };

  config = lib.mkIf cfg.enable {
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    programs.zsh.enable = true;
    users.users.${cfg.user}.shell = pkgs.zsh;
    virtualisation.docker.enable = cfg.docker.enable;
  };
}
