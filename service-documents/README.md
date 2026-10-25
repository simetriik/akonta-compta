# Akonta — service de documents

Petit service Python (FastAPI) appelé par l'Edge Function Supabase `export-document` : génération PDF (balance, grand livre, journal, balance âgée) et Excel. Au lot 3 : remplissage du modèle Excel DGI (`openpyxl`, `keep_vba`).

Les données arrivent déjà calculées par PostgreSQL (fonctions de consultation) ; le service ne lit jamais la base.

```bash
uv sync                       # dépendances
cp .env.example .env          # puis renseigner AKONTA_SERVICE_KEY
uv run uvicorn app.main:app --reload --port 8100
uv run pytest -q              # tests
```
