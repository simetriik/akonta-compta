#!/usr/bin/env python3
"""Génère la migration de seed des correspondances comptes → postes des états financiers SYCEBNL (bilan, compte de résultat).

Usage : python3 scripts/generate_sycebnl_mappings.py supabase/migrations/20261031100005_seed_sycebnl_statement_mappings.sql

Source : Journal officiel OHADA 2023, acte uniforme relatif au système comptable des entités à but non lucratif, partie 4 :
bilan p. 346, compte de résultat p. 347, tableaux de correspondance p. 395 (bilan) et p. 396 (compte de résultat).
Version de correspondances : `SYCEBNL-2024` (applicable depuis le 1er janvier 2024). Le tableau des flux (p. 348) et les notes
annexes ne sont pas couverts (le texte ne fournit pas de correspondance comptes → postes pour les flux).

Choix d'interprétation (D-024), à faire valider par ABC :
- XA (revenus des activités ordinaires) : somme RA à RH, et non RA à RG comme l'indique le libellé, sinon le résultat ne rejoint
  pas le grand livre dès qu'il existe des comptes 79 ;
- comptes marqués « p » (part) : 2919 → AF, 2939 → AK, 2949 → AL ; le chiffre illisible de la colonne amortissements du poste AG est lu 2951 ;
- 702 (quote-part de fonds d'administration transférés), absent du tableau officiel, est rangé en RG ;
- écarts avec le tableau officiel, pour que tout compte imputable du plan soit repris : 35 (produits et services en cours) en BB, 46 (bailleurs, fonds
  d'administration) en BE ou DI selon le sens du solde, 7054 et 7055 en RE, 2817 en dépréciation de AF ;
- les écarts de conversion (478, 479) ne servent que BY et DY ; les comptes 409 et 419 sont lus à solde net (« any »), les postes
  42 à 47 se répartissent par sens du solde (débiteur → actif, créditeur → passif) ;
- CG reprend 12 et les comptes 13 en instance d'affectation ; le résultat de l'exercice (CH) est calculé par le moteur, comme pour le SYSCOHADA.
"""
import sys

VERSION = "SYCEBNL-2024"


def expand(prefix: str, excluded: tuple[str, ...]) -> list[tuple[str, str]]:
    """Plages [de, à] couvrant `prefix` sans les préfixes exclus (ex. 24 sauf 245 et 2495)."""
    if not any(e.startswith(prefix) for e in excluded) or prefix in excluded:
        return [] if prefix in excluded else [(prefix, prefix)]
    ranges: list[tuple[str, str]] = []
    for d in "0123456789":
        child = prefix + d
        if child in excluded:
            continue
        if any(e.startswith(child) for e in excluded):
            ranges.extend(expand(child, excluded))
        else:
            ranges.append((child, child))
    return ranges


def merge(ranges: list[tuple[str, str]]) -> list[tuple[str, str]]:
    """Fusionne les préfixes consécutifs de même longueur (211,212 → 211-212)."""
    out: list[tuple[str, str]] = []
    for lo, hi in sorted(ranges):
        if out and len(out[-1][1]) == len(lo) and lo[:-1] == out[-1][1][:-1] and int(lo) == int(out[-1][1]) + 1:
            out[-1] = (out[-1][0], hi)
        else:
            out.append((lo, hi))
    return out


def spec(includes: list[str], excluded: tuple[str, ...] = ()) -> list[tuple[str, str]]:
    ranges: list[tuple[str, str]] = []
    for p in includes:
        ranges.extend(expand(p, excluded))
    return merge(ranges)


# (poste, libellé, comptes bruts, amortissements/dépréciations, sens du solde brut)
ASSETS = [
    ("AB", "Immobilisations incorporelles destinées à la vente (dons et legs)", ["201"], [], ["280", "2901"], "any"),
    ("AC", "Immobilisations corporelles et financières destinées à la vente (dons et legs)", ["202", "203", "204", "205"], [], ["2902"], "any"),
    ("AE", "Brevets, licences, logiciels et droits similaires", ["212", "213", "214", "2193"], [], ["2812", "2813", "2814", "2912", "2913", "2914"], "any"),
    ("AF", "Autres immobilisations incorporelles", ["218", "2198"], [], ["2817", "2818", "2918", "2919"], "any"),
    ("AG", "Avances et acomptes versés sur immobilisations incorporelles", ["251"], [], ["2951"], "any"),
    ("AI", "Terrains", ["22"], [], ["282", "292"], "any"),
    ("AJ", "Bâtiments", ["231", "232", "233", "2391", "2392", "2393", "2396"], [], ["2831", "2832", "2833", "2931", "2932", "2933"], "any"),
    ("AK", "Aménagements, agencements et installations", ["234", "235", "238", "2394", "2395", "2398"], [], ["2834", "2835", "2838", "2934", "2935", "2938", "2939"], "any"),
    ("AL", "Matériel, mobilier et actifs biologiques", ["24"], ("245", "2495"), ["284", "294"], "any"),
    ("AM", "Matériel de transport", ["245", "2495"], (), ["2845", "2945"], "any"),
    ("AN", "Avances et acomptes versés sur immobilisations corporelles", ["252"], [], ["2952"], "any"),
    ("AX", "Titres de participation", ["26"], [], ["296"], "any"),
    ("AY", "Autres immobilisations financières", ["27"], [], ["297"], "any"),
    ("BA", "Actif circulant HAO", ["485", "4865"], [], ["498"], "any"),
    ("BB", "Stocks et encours", ["31", "32", "33", "34", "35", "36", "37", "38"], [], ["39"], "any"),
    ("BC", "Fournisseurs débiteurs", ["409"], [], ["490"], "any"),
    ("BD", "Adhérents, clients-usagers", ["41"], ("419",), ["491"], "any"),
    ("BE", "Autres créances", ["42", "43", "44", "45", "46", "47"], ("478", "479"), ["492", "493", "494", "497"], "debit"),
    ("BU", "Titres de placement", ["50"], [], ["590"], "any"),
    ("BV", "Valeurs à encaisser", ["51"], [], ["591"], "any"),
    ("BW", "Banques, établissements financiers, caisses et assimilés", ["52", "53", "55", "57"], [], ["592", "593", "595"], "debit"),
    ("BY", "Écart de conversion-Actif", ["478"], [], [], "any"),
]

# (poste, libellé, comptes, exclusions, sens du solde)
LIABILITIES = [
    ("CA", "Dotation non consomptible sans droit de reprise", ["101"], (), "any"),
    ("CB", "Dotation non consomptible avec droit de reprise", ["102"], (), "any"),
    ("CC", "Droit d'entrée", ["103"], (), "any"),
    ("CD", "Dotation consomptible", ["104"], (), "any"),
    ("CE", "Écarts de réévaluation", ["106"], (), "any"),
    ("CF", "Réserves", ["11"], (), "any"),
    ("CG", "Report à nouveau et résultat en instance", ["12", "13"], (), "any"),
    ("CI", "Subventions d'investissement", ["14"], (), "any"),
    ("CJ", "Provisions réglementées", ["15"], (), "any"),
    ("CW", "Fonds affectés et provenant de dons et legs d'immobilisations", ["16"], (), "any"),
    ("CX", "Fonds reportés", ["17"], (), "any"),
    ("DA", "Emprunts et dettes financières", ["181", "182", "183", "185", "186", "188"], (), "any"),
    ("DB", "Dettes de location-acquisition", ["187"], (), "any"),
    ("DC", "Provisions pour risques et charges", ["19"], (), "any"),
    ("DF", "Dettes circulantes HAO", ["481", "484", "4861", "488", "4998"], (), "any"),
    ("DG", "Adhérents, clients-usagers créditeurs", ["419"], (), "any"),
    ("DH", "Fournisseurs", ["40"], ("409",), "any"),
    ("DI", "Autres dettes", ["42", "43", "44", "45", "46", "47", "499", "599"], ("478", "479", "4998"), "credit"),
    ("DW", "Banques, établissements financiers et crédits de trésorerie", ["56", "52", "53"], (), "credit"),
    ("DY", "Écart de conversion-Passif", ["479"], (), "any"),
]

# Comptes de dépréciation écartés d'une plage (rattachés à un autre poste).
DEP_EXCLUDED = {"AL": ("2845", "2945")}

# (poste, libellé, comptes, exclusions) ; produits au crédit (+), charges au débit (-) : le moteur donne le signe par le sens du solde.
INCOME = [
    ("RA", "Cotisations", ["701"], 1),
    ("RB", "Dotations consomptibles transférées au compte de résultat", ["703"], 1),
    ("RC", "Revenus liés à la générosité", ["704"], 1),
    ("RD", "Ventes de marchandises", ["7051"], 1),
    ("RE", "Ventes de services et produits finis", ["7052", "7053", "7054", "7055"], 1),
    ("RF", "Subventions d'exploitation", ["71"], 1),
    ("RG", "Autres produits et transferts de charges", ["702", "706", "707", "708", "72", "73", "75", "77", "78"], 1),
    ("RH", "Reprises de provisions, dépréciations, subventions et autres reprises", ["79"], 1),
    ("TA", "Achats de biens et services liés à l'activité", ["601"], -1),
    ("TB", "Variation de stocks des achats de biens et services liés à l'activité", ["6031"], -1),
    ("TC", "Achats de marchandises et matières premières", ["602"], -1),
    ("TD", "Autres achats", ["604", "605", "606", "608"], -1),
    ("TE", "Variation de stocks de marchandises, de matières premières et autres", ["6032", "6033", "6034", "6035"], -1),
    ("TF", "Transports", ["61"], -1),
    ("TG", "Services extérieurs", ["62", "63"], -1),
    ("TH", "Impôts et taxes", ["64"], -1),
    ("TI", "Autres charges", ["65"], -1),
    ("TJ", "Charges de personnel", ["66"], -1),
    ("TK", "Frais financiers et charges assimilées", ["67"], -1),
    ("TL", "Dotations aux amortissements, aux provisions, aux dépréciations et autres", ["68", "69"], -1),
    ("TM", "Produits H.A.O.", ["82", "84", "86", "88"], 1),
    ("TN", "Charges H.A.O.", ["81", "83", "85", "87"], -1),
]


def sql(s: str) -> str:
    return s.replace("'", "''")


def row(stmt: str, post: str, label: str, lo: str, hi: str, side: str, sign: int, role: str, order: int) -> str:
    return f"  (null, '{VERSION}', '{stmt}', '{post}', '{sql(label)}', '{lo}', '{hi}', '{side}', {sign}, '{role}', {order})"


def main(dst: str) -> None:
    rows: list[str] = []
    for i, (post, label, gross, excl, dep, side) in enumerate(ASSETS, start=1):
        for lo, hi in spec(gross, tuple(excl)):
            rows.append(row("balance_sheet_assets", post, label, lo, hi, side, 1, "gross", i * 10))
        for lo, hi in spec(dep, DEP_EXCLUDED.get(post, ())):
            rows.append(row("balance_sheet_assets", post, label, lo, hi, "any", -1, "depreciation", i * 10))
    for i, (post, label, accounts, excl, side) in enumerate(LIABILITIES, start=1):
        for lo, hi in spec(accounts, tuple(excl)):
            rows.append(row("balance_sheet_liabilities", post, label, lo, hi, side, 1, "amount", i * 10))
    for i, (post, label, accounts, sign) in enumerate(INCOME, start=1):
        for lo, hi in spec(accounts):
            rows.append(row("income_statement", post, label, lo, hi, "any", sign, "amount", i * 10))
    out = ["-- Généré par scripts/generate_sycebnl_mappings.py — ne pas modifier à la main.",
           "-- Source : Journal officiel OHADA 2023, SYCEBNL, partie 4 (bilan p. 346, compte de résultat p. 347, correspondances p. 395-396).",
           "-- Version SYCEBNL-2024 ; choix d'interprétation en D-024.",
           "insert into public.statement_mappings (cabinet_id, version, statement, post_code, post_label, account_from, account_to, balance_side, sign, column_role, sort_order) values",
           ",\n".join(rows) + ";"]
    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print(f"{len(rows)} règles écrites dans {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
