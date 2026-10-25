#!/usr/bin/env bash
# Lance toute la suite de tests : pgTAP (SQL + RLS), Flutter, pytest (service de documents), Deno (Edge Functions).
# Usage : scripts/test.sh [sql|flutter|python|edge|all]
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cd "$ROOT_DIR"
what="${1:-all}"
status=0

run_sql() {
  echo "== pgTAP (supabase test db) =="
  # La base locale est recréée depuis les migrations avant les tests (SKIP_RESET=1 pour aller plus vite en boucle locale).
  if [ "${SKIP_RESET:-0}" != "1" ]; then supabase db reset --no-seed >/dev/null || { status=1; return; }; fi
  supabase test db || status=1
}
run_flutter() {
  if [ -f app/pubspec.yaml ]; then
    echo "== Flutter : analyze + test =="
    (cd app && flutter analyze && flutter test) || status=1
  else
    echo "== Flutter : pas encore d'application (app/) =="
  fi
}
run_python() {
  if [ -f service-documents/pyproject.toml ]; then
    echo "== pytest : service de documents =="
    (cd service-documents && uv run pytest -q) || status=1
  else
    echo "== pytest : pas encore de service (service-documents/) =="
  fi
}
run_edge() {
  if ls supabase/functions/*/ >/dev/null 2>&1 && ls supabase/functions/**/*_test.ts >/dev/null 2>&1; then
    echo "== Deno : Edge Functions =="
    (cd supabase/functions && deno test --allow-all) || status=1
  else
    echo "== Deno : pas encore de test d'Edge Function =="
  fi
}

case "$what" in
  sql) run_sql ;;
  flutter) run_flutter ;;
  python) run_python ;;
  edge) run_edge ;;
  all) run_sql; run_flutter; run_python; run_edge ;;
  *) echo "Usage : $0 [sql|flutter|python|edge|all]" >&2; exit 2 ;;
esac
if [ $status -eq 0 ]; then echo "Tous les tests sont verts."; else echo "Des tests ont échoué." >&2; fi
exit $status
