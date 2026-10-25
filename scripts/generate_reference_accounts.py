#!/usr/bin/env python3
"""Génère la migration de seed du plan de référence SYSCOHADA révisé à partir du CSV (`Code;Libellé`).

Usage : python3 scripts/generate_reference_accounts.py inputs/plan-comptable-syscohada-revise.csv \
            supabase/migrations/20261025200004_seed_reference_accounts.sql

Attributs dérivés (décision D-003) : classe, niveau, parent (plus long préfixe existant), nature
(bilan / gestion / analytique), sens normal (règle par préfixe, le plus long l'emporte), indicateur collectif
(comptes de tiers auxquels se rattachent les comptes auxiliaires) et caractère lettrable.
"""
import csv
import sys

# Sens normal : préfixe → 'debit' | 'credit'. Le préfixe le plus long qui correspond l'emporte.
NORMAL_SIDE = {
    "1": "credit", "109": "debit", "129": "debit", "139": "debit", "119": "debit",
    "2": "debit", "28": "credit", "29": "credit",
    "3": "debit", "39": "credit",
    "4": "credit",
    "40": "credit", "409": "debit",
    "41": "debit", "419": "credit",
    "42": "credit", "421": "debit",
    "43": "credit", "4387": "debit",
    "44": "credit", "445": "debit", "4449": "debit", "449": "debit", "4499": "credit",
    "46": "credit", "461": "debit", "467": "debit",
    "47": "debit", "4712": "credit", "477": "credit", "479": "credit", "4726": "credit",
    "48": "credit", "485": "debit", "486": "debit", "488": "debit",
    "49": "credit",
    "5": "debit", "56": "credit", "59": "credit",
    "6": "debit",
    "7": "credit", "709": "debit",
    "8": "debit", "82": "credit", "84": "credit", "86": "credit", "88": "credit",
    "9": "debit",
}
# Comptes collectifs de tiers (et leurs subdivisions) : les comptes auxiliaires s'y rattachent.
COLLECTIVE_PREFIXES = ("401", "402", "408", "409", "411", "412", "416", "418", "419",
                       "421", "422", "462", "463", "465", "466", "467", "481", "482", "485", "486")
# Comptes lettrables par défaut en plus des collectifs (§10.7).
LETTERABLE_PREFIXES = COLLECTIVE_PREFIXES + ("471", "472", "476", "477", "585")


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
    out = ["-- Généré par scripts/generate_reference_accounts.py — ne pas modifier à la main.",
           "-- Source : inputs/plan-comptable-syscohada-revise.csv (SYSCOHADA révisé, classes 1 à 9).",
           "insert into public.reference_accounts (code, label, class, level, parent_code, nature, normal_side, is_collective, is_letterable) values"]
    values = []
    for code, label in rows:
        parent = None
        for n in range(len(code) - 1, 0, -1):
            if code[:n] in codes:
                parent = code[:n]
                break
        is_coll = code.startswith(COLLECTIVE_PREFIXES)
        is_lett = code.startswith(LETTERABLE_PREFIXES)
        lab = label.replace("'", "''")
        par = "null" if parent is None else f"'{parent}'"
        values.append(f"  ('{code}', '{lab}', {code[0]}, {len(code)}, {par}, '{nature(code)}', '{normal_side(code)}', {str(is_coll).lower()}, {str(is_lett).lower()})")
    out.append(",\n".join(values) + ";")
    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print(f"{len(rows)} comptes écrits dans {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
