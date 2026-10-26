#!/usr/bin/env bash
# Lance le service de documents (exports PDF / Excel / liasse DGI) pour l'instance de RECETTE, sur le port 8101.
# À lancer dans un terminal séparé, après scripts/reset-recette.sh. Arrêt : Ctrl+C.
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/common.sh"
require uv "gestionnaire Python uv"
cd "$ROOT_DIR/service-documents"
export AKONTA_SERVICE_KEY="recette-cle-de-service-locale"          # même valeur que dans scripts/reset-recette.sh
export AKONTA_DGI_TEMPLATE="$ROOT_DIR/inputs/Modèle DGI-Etats-Financiers-SN.xlsm"
exec uv run uvicorn app.main:app --host 0.0.0.0 --port 8101
