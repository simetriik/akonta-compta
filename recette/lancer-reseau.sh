#!/usr/bin/env bash
# Met Akonta (instance de RECETTE) à disposition des collègues sur le réseau local, dans un navigateur.
# Compile le build web si besoin (SUPABASE_URL=auto : même origine que la page), puis sert page + API sur un seul port.
# Usage : recette/lancer-reseau.sh [--rebuild] [--port 8080]      Arrêt : Ctrl+C
# Prérequis : scripts/reset-recette.sh (pile de recette démarrée) ; pour les exports, recette/lancer-service-documents.sh.
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/common.sh"
rebuild=0; port=8080
while [ $# -gt 0 ]; do
  case "$1" in
    --rebuild) rebuild=1 ;;
    --port) port="$2"; shift ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done
curl -fsS -m 3 "http://127.0.0.1:55321/auth/v1/health" -H "apikey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH" >/dev/null \
  || { echo "La pile de recette ne répond pas : lancer scripts/reset-recette.sh d'abord." >&2; exit 1; }
if [ "$rebuild" = 1 ] || [ ! -f "$ROOT_DIR/app/build/web/index.html" ]; then
  echo "== Compilation du build web (1 à 2 minutes) =="
  (cd "$ROOT_DIR/app" && flutter build web --release --no-wasm-dry-run \
     --dart-define=SUPABASE_URL=auto \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH) || exit 1
fi
ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.' || true)
echo
echo "Akonta de recette, à donner aux collègues (même réseau) :"
for ip in $ips; do echo "   http://$ip:$port"; done
echo "Boîte mail de test et base (Studio) : réservées à ce poste (http://127.0.0.1:55324 et :55323)."
echo "Si une page ne s'ouvre pas depuis un autre poste : pare-feu à ouvrir sur le port $port."
echo
exec python3 "$ROOT_DIR/recette/serveur-reseau.py" --port "$port"
