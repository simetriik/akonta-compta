#!/usr/bin/env bash
# Remise à zéro COMPLÈTE de l'instance Supabase de RECETTE (projet « akonta-recette », ports 55xxx), distincte de la pile
# de développement (« akonta », ports 54xxx) et de toute base destinée au cabinet ABC.
# Migrations rejouées, toutes données supprimées ; restent le plan de référence SYSCOHADA (migration) et l'administrateur technique.
# Usage : scripts/reset-recette.sh            remise à zéro (démarre la pile si besoin)
#         scripts/reset-recette.sh --stop     arrête la pile de recette (la CLI sauvegarde la base dans ses volumes)
#         scripts/reset-recette.sh --hard     arrête la pile, supprime ses volumes (y compris les fichiers du Storage), puis remet à zéro
#         --yes                               saute la question de confirmation (la sauvegarde automatique reste faite)
# GARDE-FOU : si la base contient des dossiers ou des écritures, la remise à zéro exige de taper EFFACER (ou --yes) et
# commence par une sauvegarde pg_dump dans extrants/sauvegarde-recette-<date>/ ; sans terminal, elle refuse sans --yes.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require supabase "Supabase CLI"
require psql "client PostgreSQL"
ensure_podman_socket

PROJECT_ID="akonta-recette"
DB_PORT=55322
API_PORT=55321
STACK_DIR="$ROOT_DIR/recette/.stack"
SB=(supabase --workdir "$STACK_DIR")
DB_URL="postgresql://postgres:postgres@127.0.0.1:${DB_PORT}/postgres"

# Génère le dossier de pile : config de développement avec projet et ports décalés, migrations et fonctions partagées par lien.
prepare_stack() {
  mkdir -p "$STACK_DIR/supabase"
  sed -E \
    -e "s/^project_id = .*/project_id = \"${PROJECT_ID}\"/" \
    -e 's/= 54320$/= 55320/; s/= 54321$/= 55321/; s/= 54322$/= 55322/; s/= 54323$/= 55323/; s/= 54324$/= 55324/; s/= 54327$/= 55327/; s/= 54329$/= 55329/; s/= 8083$/= 8183/' \
    -e 's#^site_url = .*#site_url = "http://127.0.0.1:3000"#' \
    -e '/^\[db.seed\]/,/^\[/ s/^enabled = true/enabled = false/' \
    "$ROOT_DIR/supabase/config.toml" > "$STACK_DIR/supabase/config.toml"
  # Les exports PDF / Excel passent par le service de documents de recette (recette/lancer-service-documents.sh, port 8101).
  cat >> "$STACK_DIR/supabase/config.toml" <<'TOML'

[edge_runtime.secrets]
DOCUMENTS_SERVICE_URL = "http://host.containers.internal:8101"
DOCUMENTS_SERVICE_KEY = "recette-cle-de-service-locale"
TOML
  ln -sfn "$ROOT_DIR/supabase/migrations" "$STACK_DIR/supabase/migrations"
  ln -sfn "$ROOT_DIR/supabase/functions" "$STACK_DIR/supabase/functions"
  : > "$STACK_DIR/supabase/seed.sql"
}

# Garde-fou : on ne touche qu'à la base de recette.
check_target() {
  grep -q "^project_id = \"${PROJECT_ID}\"" "$STACK_DIR/supabase/config.toml" || { echo "Erreur : configuration de recette inattendue." >&2; exit 1; }
  grep -qE "^port = ${DB_PORT}$" "$STACK_DIR/supabase/config.toml" || { echo "Erreur : port de base de recette inattendu." >&2; exit 1; }
}

prepare_stack
check_target

# Sauvegarde et confirmation avant tout effacement d'une base qui contient des données.
guard_existing_data() {
  local assume_yes="$1" count dir answer
  count=$(psql "$DB_URL" -At -c "select (select count(*) from public.entities) + (select count(*) from public.entries)" 2>/dev/null || true)
  if [ -z "$count" ] || [ "$count" = "0" ]; then return 0; fi   # base absente ou sans donnée de travail : rien à perdre
  require pg_dump "sauvegarde PostgreSQL"
  dir="$ROOT_DIR/extrants/sauvegarde-recette-$(date +%Y-%m-%d-%H%M%S)"
  mkdir -p "$dir"
  pg_dump "$DB_URL" -Fc -f "$dir/recette.dump" || { echo "Erreur : sauvegarde impossible, remise à zéro annulée." >&2; exit 1; }
  echo "Sauvegarde faite : $dir/recette.dump"
  if [ "$assume_yes" != "1" ]; then
    [ -t 0 ] || { echo "Erreur : la base contient des données ; sans terminal, relancer avec --yes pour les effacer." >&2; exit 1; }
    echo "ATTENTION : la base de recette contient des données (dossiers, écritures). La remise à zéro les EFFACE (voir la sauvegarde ci-dessus)."
    read -r -p "Taper EFFACER pour continuer : " answer
    [ "$answer" = "EFFACER" ] || { echo "Annulé : rien n'a été effacé."; exit 1; }
  fi
}

mode=""; assume_yes=0
for arg in "$@"; do
  case "$arg" in
    --stop|--hard) mode="$arg" ;;
    --yes) assume_yes=1 ;;
    *) echo "Usage : $0 [--stop|--hard] [--yes]" >&2; exit 2 ;;
  esac
done

case "$mode" in
  --stop) "${SB[@]}" stop; echo "Pile de recette arrêtée."; exit 0 ;;
  --hard) guard_existing_data "$assume_yes"; "${SB[@]}" stop --no-backup || true ;;
  "" ) guard_existing_data "$assume_yes" ;;
esac

echo "== Démarrage de la pile de recette ($PROJECT_ID) =="
"${SB[@]}" start >/dev/null || true
echo "== Remise à zéro : migrations rejouées, aucune donnée de démonstration =="
"${SB[@]}" db reset --no-seed >/dev/null
echo "== Amorçage : cabinet-coquille et administrateur technique =="
psql "$DB_URL" -v ON_ERROR_STOP=1 -q -f "$ROOT_DIR/recette/bootstrap-admin.sql"

# Contrôle : base vierge en dehors de l'amorçage.
psql "$DB_URL" -At -v ON_ERROR_STOP=1 <<'SQL' | tr '\n' ' ' | sed 's/^/Contrôle (cabinets, utilisateurs, dossiers, écritures) : /; s/$/\n/'
select (select count(*) from public.cabinets), (select count(*) from auth.users), (select count(*) from public.entities), (select count(*) from public.entries);
SQL
echo
"${SB[@]}" status -o env 2>/dev/null | grep -E '^(API_URL|STUDIO_URL|INBUCKET_URL|PUBLISHABLE_KEY|ANON_KEY)=' || true
echo
echo "Instance de recette prête : API http://127.0.0.1:${API_PORT} · Studio http://127.0.0.1:55323 · boîte mail de test http://127.0.0.1:55324"
echo "Administrateur technique : admin.recette@akonta.test (mot de passe dans recette/LISEZMOI.md)"
