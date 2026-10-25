#!/usr/bin/env python3
"""Génère la migration de cartographie des cellules du modèle Excel DGI à partir de sa feuille « champs fixes ».

Usage : service-documents/.venv/bin/python scripts/generate_dgi_mappings.py \
            "inputs/Modèle DGI-Etats-Financiers-SN.xlsm" supabase/migrations/20261025200014_dgi_mappings.sql

Pour chaque champ des tableaux ACTIF, PASSIF, RESULTAT, TFT, FR1A, FR2A : la cellule du modèle est suivie à travers
les formules de renvoi (ex. ACTIF!F12 = BILAN!F12) jusqu'à la cellule de saisie ; les cellules calculées (totaux)
sont ignorées. Décision D-012.
"""
import re
import sys

from openpyxl import load_workbook

VERSION = "SN-2025"
TABLE_SHEET = {"NO_ACTIF": "ACTIF", "NO_PASSIF": "PASSIF", "NO_RESULTAT": "RESULTAT", "NO_TFT": "TFT", "NO_FR1A": "FICHE R1", "NO_FR2A": "FICHE R2"}
COLUMN_ROLE = {"BRUT": ("gross", "N"), "AMORT et DEPREC.": ("depreciation", "N"), "NET": ("net", "N"), "NET (N-1)": ("net", "N-1"),
               "EXERCICE N": ("amount", "N"), "EXERCICE N-1": ("amount", "N-1"), "Libellés": ("field", "none")}
# Champs d'identification alimentés par Akonta (code ligne → champ)
FIELDS = {
    "NO_FR1_ZA1": "fiscal_year.start_date", "NO_FR1_ZA2": "fiscal_year.end_date", "NO_FR1_ZB": "fiscal_year.end_date",
    "NO_FR1_ZC": "previous_year.end_date", "NO_FR1_ZD": "previous_year.months", "NO_FR1_ZE1": "entity.registry_office",
    "NO_FR1_ZE2": "entity.trade_register", "NO_FR1_ZF": "entity.tax_id", "NO_FR1_ZI": "entity.activity_code",
    "NO_FR1_ZL": "entity.address", "NO_FR1_ZO1": "director.name", "NO_FR1_ZO2": "director.address", "NO_FR1_ZO5": "director.position",
    "NO_FR2A_ZX": "entity.legal_form", "NO_FR2A_ZY": "entity.tax_regime", "NO_FR2A_ZZ1": "entity.country", "NO_FR2A_ZZ2": "entity.establishments_count",
    "NO_FR2A_ZZ4": "entity.incorporation_year", "NO_FR2A_1": "entity.control",
}
REF = re.compile(r"^='?([^'!]+)'?!([A-Z]+\d+)$")


def resolve(wb, sheet: str, cell: str, depth: int = 0):
    """Suit les formules de renvoi simples ; renvoie (feuille, cellule, est_formule_de_calcul)."""
    v = wb[sheet][cell].value
    if isinstance(v, str) and v.startswith("="):
        m = REF.match(v.strip())
        if m and depth < 5 and m.group(1) in wb.sheetnames:
            return resolve(wb, m.group(1), m.group(2), depth + 1)
        return sheet, cell, True
    return sheet, cell, False


def main(src: str, dst: str) -> None:
    wb = load_workbook(src, keep_vba=True, data_only=False)
    ws = wb["champs fixes"]
    rows = []
    for r in ws.iter_rows(min_row=29, max_row=ws.max_row, max_col=9, values_only=True):
        if not r[0] or not r[7] or r[0] not in TABLE_SHEET:
            continue
        table, line_code, line_label, col_label, _, _, _, cell = [("" if v is None else str(v).replace("\n", " ").strip()) for v in r[:8]]
        role, year = COLUMN_ROLE.get(col_label, (None, None))
        if role is None:
            continue
        sheet, target, is_formula = resolve(wb, TABLE_SHEET[table], cell)
        if is_formula:
            continue  # total calculé par le modèle
        post = line_code.split("_")[-1] if table in ("NO_ACTIF", "NO_PASSIF", "NO_RESULTAT", "NO_TFT") else None
        field = FIELDS.get(line_code) if table in ("NO_FR1A", "NO_FR2A") else None
        if table in ("NO_FR1A", "NO_FR2A") and field is None:
            continue
        rows.append((sheet, target, post, field, role, year, f"{table} {line_code} · {line_label[:60]} · {col_label}"))
    out = ["-- =============================================================================",
           "-- Akonta — Migration 0014 : cartographie des cellules du modèle Excel DGI (D-012)",
           "-- Généré par scripts/generate_dgi_mappings.py depuis la feuille « champs fixes » du modèle ; ne pas éditer à la main.",
           "-- =============================================================================",
           "alter table public.dgi_cell_mappings add column if not exists column_role text not null default 'amount';",
           "insert into public.dgi_cell_mappings (version, sheet_name, cell_ref, post_code, field_code, column_role, column_year, note) values"]
    vals = []
    for sheet, cell, post, field, role, year, note in rows:
        q = lambda s: "null" if s is None else "'" + s.replace("'", "''") + "'"
        vals.append(f"  ('{VERSION}', {q(sheet)}, '{cell}', {q(post)}, {q(field)}, '{role}', '{year}', {q(note)})")
    out.append(",\n".join(vals) + "\non conflict (version, sheet_name, cell_ref) do nothing;")
    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print(f"{len(rows)} cellules cartographiées → {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
