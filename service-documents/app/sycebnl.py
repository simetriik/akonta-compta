"""Mise en page des états financiers SYCEBNL (bilan, compte de résultat) d'après les modèles du Journal officiel OHADA 2023,
partie 4 (bilan p. 346, compte de résultat p. 347). Les montants par poste arrivent déjà calculés par PostgreSQL ;
ce module n'ajoute que les totaux de présentation (AZ, BT, BX, BZ, CK, CY, CZ, DD, DE, DV, DX, DZ, XA à XE).

Le total XA est la somme RA à RH (reprises incluses) : choix d'interprétation D-024, le libellé officiel disant RA à RG."""
from dataclasses import dataclass, field

from .models import StatementPostRow


@dataclass
class Row:
    kind: str                       # section | post | total
    ref: str
    label: str
    note: str = ""
    values: list[int] = field(default_factory=list)   # colonnes de montants, dans l'ordre d'affichage


# (type, référence, libellé officiel, note, références additionnées pour un total)
ASSETS = [
    ("section", "AA", "IMMOBILISATIONS DESTINÉES À LA VENTE PROVENANT DE DONS ET LEGS NON ENCORE REÇUS ET USUFRUIT TEMPORAIRE", "5", None),
    ("post", "AB", "Immobilisations incorporelles", "", None),
    ("post", "AC", "Immobilisations corporelles et financières", "", None),
    ("section", "AD", "IMMOBILISATIONS INCORPORELLES", "5", None),
    ("post", "AE", "Brevets, licences, logiciels et droits similaires", "", None),
    ("post", "AF", "Autres immobilisations incorporelles", "", None),
    ("post", "AG", "Avances et acomptes versés sur immobilisations incorporelles", "", None),
    ("section", "AH", "IMMOBILISATIONS CORPORELLES", "5", None),
    ("post", "AI", "Terrains", "", None),
    ("post", "AJ", "Bâtiments", "", None),
    ("post", "AK", "Aménagements, agencements et installations", "", None),
    ("post", "AL", "Matériel, mobilier et actifs biologiques", "", None),
    ("post", "AM", "Matériel de transport", "", None),
    ("post", "AN", "Avances et acomptes versés sur immobilisations corporelles", "", None),
    ("section", "AO", "IMMOBILISATIONS FINANCIÈRES", "6", None),
    ("post", "AX", "Titres de participation", "", None),
    ("post", "AY", "Autres immobilisations financières", "", None),
    ("total", "AZ", "TOTAL ACTIF IMMOBILISÉ", "", ["AB", "AC", "AE", "AF", "AG", "AI", "AJ", "AK", "AL", "AM", "AN", "AX", "AY"]),
    ("post", "BA", "Actif circulant HAO", "7", None),
    ("post", "BB", "Stocks et encours", "8", None),
    ("post", "BC", "Fournisseurs débiteurs", "19", None),
    ("post", "BD", "Adhérents, clients-usagers", "9", None),
    ("post", "BE", "Autres créances", "10", None),
    ("total", "BT", "TOTAL ACTIF CIRCULANT", "", ["BA", "BB", "BC", "BD", "BE"]),
    ("post", "BU", "Titres de placement", "11", None),
    ("post", "BV", "Valeurs à encaisser", "12", None),
    ("post", "BW", "Banques, établissements financiers et assimilés", "13", None),
    ("total", "BX", "TOTAL TRÉSORERIE-ACTIF", "", ["BU", "BV", "BW"]),
    ("post", "BY", "Écart de conversion-Actif", "14", None),
    ("total", "BZ", "TOTAL GÉNÉRAL", "", ["AZ", "BT", "BX", "BY"]),
]

LIABILITIES = [
    ("post", "CA", "Dotation non consomptible sans droit de reprise", "15", None),
    ("post", "CB", "Dotation non consomptible avec droit de reprise", "15", None),
    ("post", "CC", "Droit d'entrée", "15", None),
    ("post", "CD", "Dotation consomptible", "15", None),
    ("post", "CE", "Écarts de réévaluation", "5F", None),
    ("post", "CF", "Réserves", "16", None),
    ("post", "CG", "Report à nouveau (+ ou -)", "16", None),
    ("post", "CH", "Résultat net de l'exercice (excédent + ou déficit -)", "", None),
    ("post", "CI", "Subventions d'investissement", "17A", None),
    ("post", "CJ", "Provisions réglementées", "17A", None),
    ("total", "CK", "TOTAL FONDS PROPRES ET ASSIMILÉS", "", ["CA", "CB", "CC", "CD", "CE", "CF", "CG", "CH", "CI", "CJ"]),
    ("post", "CW", "Fonds affectés et provenant de dons et legs d'immobilisations", "17B", None),
    ("post", "CX", "Fonds reportés", "17B", None),
    ("total", "CY", "TOTAL FONDS AFFECTÉS ET REPORTÉS", "", ["CW", "CX"]),
    ("total", "CZ", "TOTAL RESSOURCES PROPRES ET ASSIMILÉES", "", ["CK", "CY"]),
    ("post", "DA", "Emprunts et dettes financières", "18A", None),
    ("post", "DB", "Dettes de location-acquisition", "18A", None),
    ("post", "DC", "Provisions pour risques et charges", "18A", None),
    ("total", "DD", "TOTAL DETTES FINANCIÈRES ET RESSOURCES ASSIMILÉES", "", ["DA", "DB", "DC"]),
    ("total", "DE", "TOTAL RESSOURCES STABLES", "", ["CZ", "DD"]),
    ("post", "DF", "Dettes circulantes HAO", "7", None),
    ("post", "DG", "Adhérents, clients-usagers créditeurs", "9", None),
    ("post", "DH", "Fournisseurs", "19", None),
    ("post", "DI", "Autres dettes", "20 et 21", None),
    ("total", "DV", "TOTAL PASSIF CIRCULANT", "", ["DF", "DG", "DH", "DI"]),
    ("post", "DW", "Banques, établissements financiers et crédits de trésorerie", "22", None),
    ("total", "DX", "TOTAL TRÉSORERIE-PASSIF", "", ["DW"]),
    ("post", "DY", "Écart de conversion-Passif", "14", None),
    ("total", "DZ", "TOTAL GÉNÉRAL", "", ["DE", "DV", "DX", "DY"]),
]

# Compte de résultat : lignes de produits (R*), de charges (T*) ; les charges sont présentées en positif, comme dans le modèle.
INCOME_PRODUCTS = [
    ("RA", "Cotisations", "23"), ("RB", "Dotations consomptibles transférées au compte de résultat", "23"), ("RC", "Revenus liés à la générosité", "23"),
    ("RD", "Ventes de marchandises", "23"), ("RE", "Ventes de services et produits finis", "23"), ("RF", "Subventions d'exploitation", "23"),
    ("RG", "Autres produits et transferts de charges", "23"), ("RH", "Reprises de provisions, dépréciations, subventions et autres reprises", "5D et 30"),
]
INCOME_CHARGES = [
    ("TA", "Achats de biens et services liés à l'activité", "24"), ("TB", "Variation de stocks des achats de biens et services liés à l'activité", "8"),
    ("TC", "Achats de marchandises et matières premières", "24"), ("TD", "Autres achats", "24"),
    ("TE", "Variation de stocks de marchandises, de matières premières et autres", "8"), ("TF", "Transports", "25"), ("TG", "Services extérieurs", "26"),
    ("TH", "Impôts et taxes", "27"), ("TI", "Autres charges", "28"), ("TJ", "Charges de personnel", "29"), ("TK", "Frais financiers et charges assimilées", "31"),
    ("TL", "Dotations aux amortissements, aux provisions, aux dépréciations et autres", "5D et 30"),
]
HAO_PRODUCTS = ("TM", "Produits H.A.O.", "32")
HAO_CHARGES = ("TN", "Charges H.A.O.", "32")


def _by_code(rows: list[StatementPostRow]) -> dict[str, dict[str, int]]:
    out: dict[str, dict[str, int]] = {}
    for r in rows:
        e = out.setdefault(r.post_code, {"gross": 0, "dep": 0, "amount": 0})
        key = {"gross": "gross", "depreciation": "dep"}.get(r.column_role, "amount")
        e[key] = r.amount
    return out


def unknown_codes(posts: list[StatementPostRow], layout: list) -> list[str]:
    """Postes fournis par la base qui ne figurent pas dans la mise en page (ils échapperaient aux totaux)."""
    known = {ref for _, ref, _, _, _ in layout}
    return sorted({p.post_code for p in posts} - known)


def balance_sheet_assets(current: list[StatementPostRow], previous: list[StatementPostRow], with_previous: bool) -> list[Row]:
    """Actif : brut, amortissements et dépréciations, net N, (net N-1)."""
    cur, prev = _by_code(current), _by_code(previous)
    sums: dict[str, list[int]] = {}
    rows: list[Row] = []
    for kind, ref, label, note, refs in ASSETS:
        if kind == "section":
            rows.append(Row("section", ref, label, note))
            continue
        if kind == "post":
            c, p = cur.get(ref, {"gross": 0, "dep": 0}), prev.get(ref, {"gross": 0, "dep": 0})
            vals = [c["gross"], c["dep"], c["gross"] - c["dep"], p["gross"] - p["dep"]]
            sums[ref] = vals
        else:
            vals = [sum(sums[r][i] for r in refs) for i in range(4)]
            sums[ref] = vals
        rows.append(Row(kind, ref, label, note, vals if with_previous else vals[:3]))
    return rows


def balance_sheet_liabilities(current: list[StatementPostRow], previous: list[StatementPostRow], with_previous: bool) -> list[Row]:
    """Passif : net N, (net N-1)."""
    cur, prev = _by_code(current), _by_code(previous)
    sums: dict[str, list[int]] = {}
    rows: list[Row] = []
    for kind, ref, label, note, refs in LIABILITIES:
        if kind == "post":
            vals = [cur.get(ref, {"amount": 0})["amount"], prev.get(ref, {"amount": 0})["amount"]]
        else:
            vals = [sum(sums[r][i] for r in refs) for i in range(2)]
        sums[ref] = vals
        rows.append(Row(kind, ref, label, note, vals if with_previous else vals[:1]))
    return rows


def income_statement(current: list[StatementPostRow], previous: list[StatementPostRow], with_previous: bool) -> list[Row]:
    """Compte de résultat : N, (N-1). Les montants de la base sont signés (produits +, charges -) : les charges sont présentées en positif."""
    cur, prev = _by_code(current), _by_code(previous)

    def amt(src: dict, ref: str, sign: int) -> int:
        return sign * src.get(ref, {"amount": 0})["amount"]

    def pair(ref: str, sign: int) -> list[int]:
        return [amt(cur, ref, sign), amt(prev, ref, sign)]

    rows: list[Row] = []

    def add(kind: str, ref: str, label: str, note: str, vals: list[int]) -> None:
        rows.append(Row(kind, ref, label, note, vals if with_previous else vals[:1]))

    products = [(ref, label, note, pair(ref, 1)) for ref, label, note in INCOME_PRODUCTS]
    for ref, label, note, vals in products:
        add("post", ref, label, note, vals)
    xa = [sum(v[i] for *_, v in products) for i in range(2)]
    add("total", "XA", "REVENUS DES ACTIVITÉS ORDINAIRES (somme RA à RH)", "", xa)
    charges = [(ref, label, note, pair(ref, -1)) for ref, label, note in INCOME_CHARGES]
    for ref, label, note, vals in charges:
        add("post", ref, label, note, vals)
    xb = [sum(v[i] for *_, v in charges) for i in range(2)]
    add("total", "XB", "CHARGES DES ACTIVITÉS ORDINAIRES (somme TA à TL)", "", xb)
    xc = [xa[i] - xb[i] for i in range(2)]
    add("total", "XC", "RÉSULTAT DES ACTIVITÉS ORDINAIRES (XA - XB)", "", xc)
    tm = pair(HAO_PRODUCTS[0], 1)
    tn = pair(HAO_CHARGES[0], -1)
    add("post", HAO_PRODUCTS[0], HAO_PRODUCTS[1], HAO_PRODUCTS[2], tm)
    add("post", HAO_CHARGES[0], HAO_CHARGES[1], HAO_CHARGES[2], tn)
    xd = [tm[i] - tn[i] for i in range(2)]
    add("total", "XD", "RÉSULTAT H.A.O. (TM - TN)", "", xd)
    add("total", "XE", "RÉSULTAT NET DE L'EXERCICE (+ excédent, - déficit) (XC + XD)", "", [xc[i] + xd[i] for i in range(2)])
    return rows


# Notes annexes que l'application ne produit pas automatiquement : à rédiger ou à compléter par le cabinet.
NOTES_NOT_PRODUCED = [
    ("1", "Dettes garanties et engagements"), ("2", "Informations obligatoires"), ("3", "Événements postérieurs à la clôture"),
    ("4", "Changements, estimations et erreurs"), ("5", "Immobilisations (mouvements, amortissements, cessions, réévaluations)"),
    ("6", "Immobilisations financières"), ("7", "Actif et dettes circulants HAO"), ("14", "Écarts de conversion"), ("15", "Dotation (membres et nationalité)"),
    ("18B", "Actifs et passifs éventuels"), ("29B", "Effectifs, masse salariale et personnel"), ("30", "Dotations, provisions et dépréciations"),
    ("33", "Principaux indicateurs financiers"), ("34", "Informations sociales et environnementales"), ("35", "Tableau d'exécution budgétaire"),
]
