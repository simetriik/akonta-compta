#!/usr/bin/env bash
# Installation / vérification de l'environnement de développement Akonta.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require podman   "https://podman.io"
require supabase "Supabase CLI : https://supabase.com/docs/guides/cli"
require flutter  "Flutter SDK : https://docs.flutter.dev/get-started/install/linux"
require uv       "uv (Python) : https://docs.astral.sh/uv/"
ensure_podman_socket

echo "== Versions =="
podman --version
supabase --version
flutter --version | head -1
uv --version

echo "== Flutter : dépendances de l'application =="
if [ -f "$ROOT_DIR/app/pubspec.yaml" ]; then (cd "$ROOT_DIR/app" && flutter pub get); fi

echo "== Python : service de documents =="
if [ -f "$ROOT_DIR/service-documents/pyproject.toml" ]; then (cd "$ROOT_DIR/service-documents" && uv sync); fi

echo "== Supabase : téléchargement des images (première fois : plusieurs minutes) =="
(cd "$ROOT_DIR" && supabase start >/dev/null && supabase status)
echo "Environnement prêt. Démarrage : scripts/start.sh — tests : scripts/test.sh"
