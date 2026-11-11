#!/usr/bin/env bash
# Relance la pile Supabase de RECETTE (projet « akonta-recette », ports 55xxx) SANS la réinitialiser :
# aucune migration n'est rejouée et aucune donnée n'est effacée par ce script. Si la pile a été arrêtée proprement
# (scripts/reset-recette.sh --stop), la CLI relance la base depuis sa sauvegarde ; le contrôle final montre les effectifs.
# Usage : scripts/start-recette.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require supabase "Supabase CLI"
require psql "client PostgreSQL"
ensure_podman_socket

PROJECT_ID="akonta-recette"
STACK_DIR="$ROOT_DIR/recette/.stack"
CONFIG="$STACK_DIR/supabase/config.toml"
DB_URL="postgresql://postgres:postgres@127.0.0.1:55322/postgres"

# Garde-fou : on ne démarre que la pile de recette, déjà préparée par reset-recette.sh.
[ -f "$CONFIG" ] || { echo "Erreur : pile de recette absente ; lancer d'abord scripts/reset-recette.sh (efface les données)." >&2; exit 1; }
grep -q "^project_id = \"${PROJECT_ID}\"" "$CONFIG" || { echo "Erreur : configuration de recette inattendue." >&2; exit 1; }

echo "== Démarrage de la pile de recette  =="
supabase --workdir "$STACK_DIR" start >/dev/null

echo "== Contrôle (cabinets, utilisateurs, dossiers, écritures) =="
psql "$DB_URL" -At -v ON_ERROR_STOP=1 -c "select (select count(*) from public.cabinets), (select count(*) from auth.users), (select count(*) from public.entities), (select count(*) from public.entries);"
echo
echo "Pile prête : API http://127.0.0.1:55321 · Studio http://127.0.0.1:55323 · boîte mail http://127.0.0.1:55324"
echo "Ensuite : recette/lancer-service-documents.sh (terminal 2) puis recette/lancer-reseau.sh (terminal 3)."
