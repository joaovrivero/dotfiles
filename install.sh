#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR

usage() {
    cat <<'EOF'
Usage: ./install.sh [--platform arch|nixos] [platform options]

Without --platform, the installer reads /etc/os-release and selects Arch or
NixOS. Windows setup runs from PowerShell instead:

  ./platforms/windows/install.ps1

Examples:
  ./install.sh --dry-run
  ./install.sh --platform arch --docker
  ./install.sh --platform nixos --dry-run
EOF
}

platform=""
if [[ "${1:-}" == "--platform" ]]; then
    [[ $# -ge 2 ]] || { usage >&2; exit 2; }
    platform="$2"
    shift 2
elif [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ -z "$platform" && -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
        *" nixos "*) platform="nixos" ;;
        *" arch "*) platform="arch" ;;
    esac
fi

case "$platform" in
    arch) exec "$REPO_DIR/platforms/arch/install.sh" "$@" ;;
    nixos) exec "$REPO_DIR/platforms/nixos/install.sh" "$@" ;;
    *)
        printf 'Could not detect Arch or NixOS. Choose one with --platform.\n' >&2
        usage >&2
        exit 1
        ;;
esac
