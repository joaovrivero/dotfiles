# NixOS

The NixOS setup uses Home Manager instead of Stow. Packages and configuration
files are built as one generation, so you can inspect a build before switching
to it and roll back through Home Manager.

## Standalone setup

Edit [settings.nix](./settings.nix) first. Set your username, home directory,
architecture, and whether this machine needs GUI programs.

Then build without activating:

```bash
./install.sh --platform nixos --dry-run
```

Apply the profile:

```bash
./install.sh --platform nixos
```

The installer uses the current username as the Home Manager profile name. Pass
`--profile NAME` if it differs from `settings.nix`. Run with `--update` when you
want to refresh the pinned Nixpkgs and Home Manager inputs.

Flakes must be enabled. On NixOS, add this to your system configuration before
the first build:

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Keep `home.stateVersion` at the version used by your existing Home Manager
profile. It is a compatibility setting, not an update channel.

## Import into an existing NixOS flake

The root flake exports reusable NixOS and Home Manager modules. A host flake can
use them like this:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    dotfiles.url = "github:joaovrivero/dotfiles";
  };

  outputs = { nixpkgs, home-manager, dotfiles, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        dotfiles.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          jojoDotfiles = {
            enable = true;
            user = "yourname";
            docker.enable = false;
          };

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.yourname = {
            imports = [ dotfiles.homeModules.default ];
            jojoDotfiles = {
              enable = true;
              gui.enable = true;
            };
            home.stateVersion = "26.05";
          };
        }
      ];
    };
  };
}
```

The NixOS module enables flakes and Zsh, assigns Zsh to the selected user, and
can enable Docker. The Home Manager module owns packages and files in the home
directory. Keeping those jobs separate makes it possible to use the home module
without adopting the system module.
