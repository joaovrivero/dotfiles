#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPO_DIR

profile="$(id -un)"
dry_run=false
update=false

usage() {
    cat <<'EOF'
Usage: ./platforms/nixos/install.sh [options]

Options:
  --profile NAME  Home Manager profile from platforms/nixos/settings.nix
  --dry-run       Build the Home Manager activation package without switching
  --update        Update flake.lock before building
  -h, --help      Show this help
EOF
}

while (($#)); do
    case "$1" in
        --profile)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            profile="$2"
            shift
            ;;
        --dry-run) dry_run=true ;;
        --update) update=true ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if ! command -v nix >/dev/null 2>&1; then
    printf 'Nix is not installed. Run this from NixOS or install Nix first.\n' >&2
    exit 1
fi

if $update; then
    nix flake update --flake "$REPO_DIR"
fi

if $dry_run; then
    nix build --no-link "$REPO_DIR#homeConfigurations.${profile}.activationPackage"
else
    nix run "$REPO_DIR#home-manager" -- \
        switch --backup-extension backup --flake "$REPO_DIR#$profile"
fi
