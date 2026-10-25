#!/usr/bin/env bash
# Variables communes aux scripts Akonta : Podman expose le socket Docker attendu par la Supabase CLI.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PODMAN_SOCK="/run/user/$(id -u)/podman/podman.sock"
export DOCKER_HOST="${DOCKER_HOST:-unix://$PODMAN_SOCK}"

ensure_podman_socket() {
  if [ ! -S "$PODMAN_SOCK" ]; then
    echo "Activation du socket Podman utilisateur…"
    systemctl --user enable --now podman.socket
  fi
  if [ ! -S "$PODMAN_SOCK" ]; then
    echo "Erreur : socket Podman introuvable ($PODMAN_SOCK)." >&2
    exit 1
  fi
}

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Erreur : '$1' est requis ($2)." >&2; exit 1; }
}
