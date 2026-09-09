{
  description = "Jojo's cross-platform development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      settings = import ./platforms/nixos/settings.nix;
      pkgs = nixpkgs.legacyPackages.${settings.system};
    in
    {
      homeModules.default = import ./platforms/nixos/modules/home.nix {
        dotfilesRoot = self.outPath;
      };
      nixosModules.default = import ./platforms/nixos/modules/nixos.nix;

      homeConfigurations.${settings.username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          self.homeModules.default
          {
            jojoDotfiles = {
              enable = true;
              gui.enable = settings.enableGui;
            };

            home = {
              username = settings.username;
              homeDirectory = settings.homeDirectory;
              stateVersion = settings.stateVersion;
            };
          }
        ];
      };

      checks.${settings.system}.home = self.homeConfigurations.${settings.username}.activationPackage;

      apps.${settings.system}.home-manager = {
        type = "app";
        program = "${home-manager.packages.${settings.system}.home-manager}/bin/home-manager";
        meta.description = "Apply the locked Home Manager configuration";
      };

      formatter.${settings.system} = pkgs.nixfmt;
    };
}
