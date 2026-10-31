#!/usr/bin/env python3
"""Génère la migration de seed du plan de référence SYCEBNL à partir du CSV (`Code;Libellé`).

Usage : python3 scripts/generate_sycebnl_accounts.py outputs/sycebnl/plan-sycebnl.csv \
            supabase/migrations/20261031100002_seed_sycebnl_accounts.sql

Source du CSV : https://plan-comptable-ohada.com/sycebnl/comptes.html (1 130 comptes, classes 1 à 9, acte uniforme
OHADA relatif au SYCEBNL, adopté le 22 déc. 2022, applicable depuis le 1er janv. 2024). Site tiers, à rapprocher
du Journal officiel OHADA avant la mise en production (décision D-022).

La liste ne contient pas de ligne de classe (1 à 9) : les comptes à 2 chiffres sont la racine (niveau 1).
Attributs dérivés comme pour le SYSCOHADA (D-003) : classe, niveau (nombre de chiffres moins 1), parent (plus long
préfixe existant), nature, sens normal (règle par préfixe, le plus long l'emporte), collectif et lettrable.
Le sens normal est une hypothèse à faire valider par ABC (Q-017).
"""
import csv
import sys

# Sens normal : préfixe → 'debit' | 'credit'. Le préfixe le plus long qui correspond l'emporte.
NORMAL_SIDE = {
    "1": "credit", "129": "debit", "139": "debit", "169": "debit",
    "2": "debit", "28": "credit", "29": "credit",
    "3": "debit", "39": "credit",
    "4": "credit",
    "409": "debit", "4098": "debit",
    "41": "debit", "419": "credit",
    "421": "debit", "4287": "debit",
    "4387": "debit", "445": "debit", "4487": "debit", "4491": "debit",
    "4692": "debit", "4693": "debit", "4694": "debit",
    "47": "debit", "4712": "credit", "4713": "credit", "477": "credit", "479": "credit",
    "481": "credit", "485": "debit", "486": "credit", "4881": "credit", "488": "debit",
    "5": "debit", "56": "credit", "59": "credit",
    "6": "debit",
    "6019": "credit", "6029": "credit", "6049": "credit", "6059": "credit", "6089": "credit",
    "619": "credit", "649": "credit", "669": "credit",
    "7": "credit",
    "81": "debit", "82": "credit", "83": "debit", "84": "credit", "85": "debit", "86": "credit",
    "87": "debit", "88": "credit",
    "9": "debit",
}
# Comptes collectifs de tiers (et leurs subdivisions) : les comptes auxiliaires s'y rattachent.
COLLECTIVE_PREFIXES = ("401", "402", "408", "409", "411", "412", "416", "418", "419", "421", "422",
                       "451", "452", "453", "454", "455", "456", "457", "458", "462", "463", "464",
                       "481", "485", "486")
# Comptes lettrables par défaut en plus des collectifs (§10.7).
LETTERABLE_PREFIXES = COLLECTIVE_PREFIXES + ("471", "473", "475", "476", "477", "585")


def normal_side(code: str) -> str:
    for n in range(len(code), 0, -1):
        side = NORMAL_SIDE.get(code[:n])
        if side:
            return side
    return "debit"


def nature(code: str) -> str:
    c = int(code[0])
    return "balance_sheet" if c <= 5 else ("income" if c <= 8 else "analytic")


def main(src: str, dst: str) -> None:
    with open(src, encoding="utf-8-sig", newline="") as f:
        rows = [(r[0].strip(), r[1].strip()) for r in csv.reader(f, delimiter=";")][1:]
    codes = {c for c, _ in rows}
    out = ["-- Généré par scripts/generate_sycebnl_accounts.py — ne pas modifier à la main.",
           "-- Source : outputs/sycebnl/plan-sycebnl.csv (SYCEBNL, classes 1 à 9, 1 130 comptes ; site tiers, D-022).",
           "insert into public.reference_accounts (system, code, label, class, level, parent_code, nature, normal_side, is_collective, is_letterable) values"]
    values = []
    for code, label in rows:
        parent = next((code[:n] for n in range(len(code) - 1, 1, -1) if code[:n] in codes), None)
        is_coll = code.startswith(COLLECTIVE_PREFIXES)
        is_lett = code.startswith(LETTERABLE_PREFIXES)
        lab = label.replace("'", "''")
        par = "null" if parent is None else f"'{parent}'"
        values.append(f"  ('sycebnl', '{code}', '{lab}', {code[0]}, {len(code) - 1}, {par}, '{nature(code)}', '{normal_side(code)}', {str(is_coll).lower()}, {str(is_lett).lower()})")
    out.append(",\n".join(values) + ";")
    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print(f"{len(rows)} comptes écrits dans {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
