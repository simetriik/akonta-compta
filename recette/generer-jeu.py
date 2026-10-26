#!/usr/bin/env python3
"""Génère le jeu de données de la recette interne d'Akonta (PME fictive de Cotonou, exercice 2027).

Source unique : ce fichier. Il écrit, dans recette/ :
  - jeu-de-donnees.md            fiche de l'entité, tiers, à-nouveaux, ~40 opérations, relevé, inventaire, balance attendue ;
  - export-perfecto-simule.txt   faux « JOURNAL » Perfecto (cp1252, tabulations, CRLF) : à-nouveaux au 01/01/2027 ;
  - releve-ecobank-janvier.csv   relevé bancaire de janvier (avec lignes volontairement non rapprochables) ;
  - pieces/                      pièces justificatives fictives (PDF et JPEG) ;
  - supabase/tests/150_recette_import.test.sql   test pgTAP : l'export est lu sans erreur en mode essai.
Contrôles internes : chaque écriture et les à-nouveaux sont équilibrés, la banque ne passe jamais en négatif.

Usage (Python avec reportlab et Pillow, ex. celui du service de documents) :
  service-documents/.venv/bin/python recette/generer-jeu.py
"""
from __future__ import annotations

import hashlib
import sys
from collections import OrderedDict, defaultdict
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "recette"

# --------------------------------------------------------------------------------------------------------------------
# Plan de comptes utilisé (codes à 7 chiffres du plan de l'entité) et tiers
# --------------------------------------------------------------------------------------------------------------------
ACC = {
    "1010000": "Capital social",
    "1181000": "Réserves facultatives",
    "1210000": "Report à nouveau créditeur",
    "1301000": "Résultat en instance d'affectation : bénéfice",
    "1620000": "Emprunts auprès des établissements de crédit",
    "2441000": "Matériel de bureau",
    "2444000": "Mobilier de bureau",
    "2451000": "Matériel automobile",
    "2844000": "Amortissements du matériel et mobilier",
    "2845000": "Amortissements du matériel de transport",
    "3111000": "Marchandises A1",
    "4011000": "Fournisseurs",
    "4111000": "Clients",
    "4220000": "Personnel, rémunérations dues",
    "4311000": "Sécurité sociale (CNSS)",
    "4431000": "TVA facturée sur ventes",
    "4441000": "État, TVA due",
    "4451000": "TVA récupérable sur immobilisations",
    "4452000": "TVA récupérable sur achats",
    "4472000": "Impôts sur salaires (IRPP)",
    "4478000": "Autres impôts et contributions (AIB)",
    "5210000": "Banques locales",
    "6011000": "Achats de marchandises dans la Région",
    "6012000": "Achats de marchandises hors Région",
    "6052000": "Fournitures non stockables : électricité",
    "6056000": "Achats de petit matériel et outillage",
    "6222000": "Locations de bâtiments",
    "6251000": "Assurances multirisques",
    "6281000": "Frais de téléphone",
    "6311000": "Frais bancaires",
    "6312000": "TAF sur frais bancaires",
    "6611000": "Appointements, salaires et commissions",
    "6641000": "Charges sociales sur rémunération du personnel national",
    "7011000": "Ventes de marchandises dans la Région",
}

# code tiers -> (nom, type, collectif)
TIERS = OrderedDict([
    ("CBM", ("Quincaillerie Bénin Matériaux", "client", "4111000")),
    ("CAK", ("Akpakpa Bâtiment SA", "client", "4111000")),
    ("CZO", ("Entreprise ZOUNON & Fils", "client", "4111000")),
    ("CMA", ("Mairie d'Abomey-Calavi", "client", "4111000")),
    ("CDX", ("Entreprise DOSSOU BTP", "client", "4111000")),
    ("CBS", ("Établissements BOSSOU", "client", "4111000")),
    ("FCG", ("Cimenterie du Golfe", "fournisseur", "4011000")),
    ("FFA", ("Fer et Acier du Bénin", "fournisseur", "4011000")),
    ("FPL", ("Peintures du Littoral", "fournisseur", "4011000")),
    ("FEN", ("Fournisseur Énergie (électricité)", "fournisseur", "4011000")),
    ("FTL", ("Opérateur Télécom du Bénin", "fournisseur", "4011000")),
    ("FEU", ("Euro Import SAS (France)", "fournisseur", "4011000")),
    ("FUS", ("Global Tools Inc. (États-Unis)", "fournisseur", "4011000")),
    ("FAI", ("Auto Import Cotonou", "fournisseur", "4011000")),
    ("PE1", ("Employé 1 : Gildas AHOUANSOU", "personnel", "4220000")),
    ("PE2", ("Employé 2 : Chantal DEGBE", "personnel", "4220000")),
    ("PE3", ("Employé 3 : Rodrigue TOKPO", "personnel", "4220000")),
])

MONTHS = {1: "janvier", 2: "février", 3: "mars"}


def d(day: int, month: int) -> date:
    return date(2027, month, day)


def fr(n: int) -> str:
    return f"{n:,}".replace(",", " ")


def tva(ht: int) -> int:
    return round(ht * 18 / 100)


# --------------------------------------------------------------------------------------------------------------------
# Modèle
# --------------------------------------------------------------------------------------------------------------------
@dataclass
class Line:
    account: str
    debit: int = 0
    credit: int = 0
    tiers: str | None = None
    label: str | None = None


@dataclass
class Op:
    no: int
    day: date
    journal: str
    label: str
    piece: str | None
    lines: list[Line]
    note: str = ""
    currency: tuple[str, float, float] | None = None  # (devise, montant en devise, cours)
    inventory: bool = False  # saisie à faire via le module Inventaire plutôt que par la grille
    doc: dict | None = None  # description de la pièce justificative associée


def L(account: str, debit: int = 0, credit: int = 0, tiers: str | None = None, label: str | None = None) -> Line:
    return Line(account, debit, credit, tiers, label)


# --------------------------------------------------------------------------------------------------------------------
# À-nouveaux au 01/01/2027
# --------------------------------------------------------------------------------------------------------------------
AN_CLIENTS = [("CBM", 1_770_000, "FA-2026-131"), ("CAK", 2_360_000, "FA-2026-140"), ("CMA", 5_900_000, "FA-2026-152"),
              ("CDX", 3_540_000, "FA-2025-077"), ("CBS", 1_416_000, "FA-2025-102")]
AN_FOURN = [("FCG", 3_068_000, "FA-FCG-0198"), ("FPL", 1_180_000, "FA-FPL-0511")]

AN: list[Line] = [
    L("2441000", 2_400_000), L("2444000", 1_800_000), L("2451000", 8_500_000),
    L("2844000", credit=2_040_000), L("2845000", credit=3_400_000),
    L("3111000", 4_800_000),
    *[L("4111000", debit=m, tiers=t, label=f"Facture {ref} non réglée") for t, m, ref in AN_CLIENTS],
    *[L("4011000", credit=m, tiers=t, label=f"Facture {ref} non réglée") for t, m, ref in AN_FOURN],
    L("4311000", credit=218_500, label="CNSS de décembre 2026 à payer"),
    L("4441000", credit=410_000, label="TVA due de décembre 2026"),
    L("4472000", credit=52_000, label="IRPP retenu sur salaires de décembre 2026"),
    L("1010000", credit=20_000_000), L("1181000", credit=4_000_000), L("1210000", credit=3_250_000),
    L("1301000", credit=6_750_000), L("1620000", credit=6_000_000),
]
_deb = sum(l.debit for l in AN)
_cre = sum(l.credit for l in AN)
AN.append(L("5210000", debit=_cre - _deb, label="Solde bancaire au 31/12/2026"))  # banque = solde d'équilibre
AN_BANK = _cre - _deb
assert sum(l.debit for l in AN) == sum(l.credit for l in AN), "à-nouveaux déséquilibrés"
assert AN_BANK > 10_000_000

# --------------------------------------------------------------------------------------------------------------------
# Opérations de janvier à mars 2027
# --------------------------------------------------------------------------------------------------------------------
OPS: list[Op] = []


def add(day, journal, label, piece, lines, **kw):
    OPS.append(Op(len(OPS) + 1, day, journal, label, piece, lines, **kw))


def achat(day, tiers, label, piece, ht, account="6011000", **kw):
    t = tva(ht)
    add(day, "AC", label, piece, [L(account, ht), L("4452000", t), L("4011000", credit=ht + t, tiers=tiers)], **kw)


def vente(day, tiers, label, piece, ht, **kw):
    t = tva(ht)
    add(day, "VT", label, piece, [L("4111000", ht + t, tiers=tiers), L("7011000", credit=ht), L("4431000", credit=t)], **kw)


def reglt_client(day, tiers, label, piece, amount, **kw):
    add(day, "BQ", label, piece, [L("5210000", amount), L("4111000", credit=amount, tiers=tiers)], **kw)


def reglt_fourn(day, tiers, label, piece, amount, **kw):
    add(day, "BQ", label, piece, [L("4011000", amount, tiers=tiers), L("5210000", credit=amount)], **kw)


def frais_bq(day, ht=25_000, doc=True):
    taf = round(ht * 10 / 100)
    add(day, "BQ", f"Frais bancaires {MONTHS[day.month]} 2027", f"AD-{day:%m}27", [L("6311000", ht), L("6312000", taf), L("5210000", credit=ht + taf)],
        note="Modèle FRAIS_BQ_TAF (frais + TAF 10 %).",
        doc={"kind": "avis", "title": "Avis de débit : frais de tenue de compte", "issuer": "Ecobank Bénin", "format": "jpg", "amount": ht + taf} if doc else None)


PAY = [  # (tiers, brut, irpp, cnss salariale)
    ("PE1", 450_000, 24_000, 16_200), ("PE2", 380_000, 17_000, 13_680), ("PE3", 320_000, 11_000, 11_520)]


def paie(day, doc=True):
    brut = sum(p[1] for p in PAY)
    irpp = sum(p[2] for p in PAY)
    cnss_s = sum(p[3] for p in PAY)
    assert cnss_s == round(brut * 3.6 / 100)
    cnss_p = round(brut * 15.4 / 100)
    nets = [(t, b - i - c) for t, b, i, c in PAY]
    add(day, "PA", f"Salaires {MONTHS[day.month]} 2027", f"PAIE-{day:%m}27",
        [L("6611000", brut), L("6641000", cnss_p), L("4472000", credit=irpp), L("4311000", credit=cnss_s + cnss_p),
         *[L("4220000", credit=n, tiers=t, label=f"Net à payer {t}") for t, n in nets]],
        note=f"Brut {fr(brut)} ; CNSS salariale 3,6 % = {fr(cnss_s)} ; patronale 15,4 % = {fr(cnss_p)} ; IRPP {fr(irpp)}.",
        doc={"kind": "paie", "title": f"Récapitulatif de paie {MONTHS[day.month]} 2027", "issuer": "Comptoir Aïdé Négoce SARL", "format": "jpg", "amount": sum(n for _, n in nets)} if doc else None)
    return sum(n for _, n in nets), cnss_s + cnss_p, irpp


# --- Janvier
achat(d(3, 1), "FCG", "Achat de ciment, Cimenterie du Golfe", "FA-FCG-0215", 4_200_000,
      doc={"kind": "facture", "title": "FACTURE FA-FCG-0215", "issuer": "Cimenterie du Golfe", "format": "pdf", "ht": 4_200_000})
vente(d(5, 1), "CBM", "Vente de matériaux, Quincaillerie Bénin Matériaux", "F-2027-001", 3_500_000,
      doc={"kind": "facture", "title": "FACTURE F-2027-001", "issuer": "Comptoir Aïdé Négoce SARL", "client": "Quincaillerie Bénin Matériaux", "format": "pdf", "ht": 3_500_000})
add(d(5, 1), "BQ", "Loyer de janvier 2027, SCI du bailleur de Ganhi", "QUIT-0127",
    [L("6222000", 600_000), L("5210000", credit=600_000)], note="Loyer sans TVA, payé par virement.",
    doc={"kind": "recu", "title": "REÇU DE LOYER JANVIER 2027", "issuer": "SCI du bailleur de Ganhi", "format": "jpg", "amount": 600_000})
add(d(6, 1), "BQ", "Paiement de la TVA due de décembre 2026", "TVA-1226",
    [L("4441000", 410_000), L("5210000", credit=410_000)], note="Solde la dette reprise dans les à-nouveaux.")
achat(d(7, 1), "FFA", "Achat de fer à béton, Fer et Acier du Bénin", "FA-FFA-1042", 2_800_000,
      doc={"kind": "facture", "title": "FACTURE FA-FFA-1042", "issuer": "Fer et Acier du Bénin", "format": "pdf", "ht": 2_800_000})
add(d(8, 1), "BQ", "Prime d'assurance multirisque 15 mois (01/01/2027 au 31/03/2028)", "ASS-2027-044",
    [L("6251000", 1_500_000), L("5210000", credit=1_500_000)],
    note="Sert aux régularisations : charge constatée d'avance en fin d'exercice (voir « Données d'inventaire »).")
vente(d(10, 1), "CZO", "Vente de matériaux, Entreprise ZOUNON", "F-2027-002", 1_250_000)
reglt_client(d(12, 1), "CBM", "Règlement CBM, facture FA-2026-131", "VIR-0112", 1_770_000, note="Règle une facture reprise des à-nouveaux (lettrage).")
add(d(14, 1), "BQ", "Règlement Mairie d'Abomey-Calavi, facture FA-2026-152 (AIB et TVA retenue)", "VIR-0114",
    [L("5210000", 4_950_000), L("4478000", 50_000), L("4452000", 900_000), L("4111000", credit=5_900_000, tiers="CMA")],
    note="Facture 5 900 000 TTC = banque 4 950 000 + AIB retenu 1 % du HT (50 000) + TVA retenue à la source (900 000). Cas « règlement + retenues = facture ».",
    doc={"kind": "avis", "title": "Bordereau de retenue à la source (AIB et TVA)", "issuer": "Mairie d'Abomey-Calavi", "format": "pdf", "amount": 950_000})
achat(d(15, 1), "FEN", "Facture d'électricité de décembre 2026", "FA-EN-0127", 180_000, account="6052000",
      doc={"kind": "facture", "title": "FACTURE D'ÉLECTRICITÉ N° 0127", "issuer": "Fournisseur Énergie", "format": "jpg", "ht": 180_000})
add(d(15, 1), "BQ", "Paiement CNSS et IRPP de décembre 2026", "VIR-0115",
    [L("4311000", 218_500), L("4472000", 52_000), L("5210000", credit=270_500)], note="Solde les dettes sociales reprises dans les à-nouveaux.")
achat(d(16, 1), "FTL", "Facture téléphone et internet de décembre 2026", "FA-TEL-0127", 95_000, account="6281000",
      doc={"kind": "facture", "title": "FACTURE TÉLÉPHONE N° 0127", "issuer": "Opérateur Télécom du Bénin", "format": "pdf", "ht": 95_000})
add(d(18, 1), "BQ", "Règlement partiel CAK, facture FA-2026-140", "VIR-0118",
    [L("5210000", 1_000_000), L("4111000", credit=1_000_000, tiers="CAK")], note="Règlement partiel : lettrage partiel (solde 1 360 000 restant).")
reglt_fourn(d(20, 1), "FCG", "Paiement FCG, facture FA-FCG-0198", "VIR-0120", 3_068_000, note="Règle une facture reprise des à-nouveaux.")
achat(d(22, 1), "FPL", "Achat de peintures, Peintures du Littoral", "FA-FPL-0612", 640_000)
reglt_client(d(25, 1), "CZO", "Règlement CZO, facture F-2027-002", "VIR-0125", 1_475_000)
reglt_fourn(d(28, 1), "FFA", "Paiement FFA, facture FA-FFA-1042", "VIR-0128", 3_304_000)
add(d(28, 1), "BQ", "Règlement de la facture d'électricité FA-EN-0127 par chèque n° 0004512", "CHQ-4512",
    [L("4011000", 212_400, tiers="FEN"), L("5210000", credit=212_400)], note="Chèque émis fin janvier et non encore débité : écriture sans ligne de relevé (écart de rapprochement).")
nets, soc, irpp = paie(d(31, 1))
add(d(31, 1), "BQ", "Paiement des salaires de janvier 2027", "VIR-0131",
    [*[L("4220000", b - i - c, tiers=t) for t, b, i, c in PAY], L("5210000", credit=nets)])
frais_bq(d(31, 1))

# --- Février
vente(d(2, 2), "CBM", "Vente de matériaux, Quincaillerie Bénin Matériaux", "F-2027-003", 2_900_000)
achat(d(4, 2), "FCG", "Achat de ciment, Cimenterie du Golfe", "FA-FCG-0243", 3_600_000)
add(d(5, 2), "BQ", "Loyer de février 2027, SCI du bailleur de Ganhi", "QUIT-0227", [L("6222000", 600_000), L("5210000", credit=600_000)])
vente(d(9, 2), "CAK", "Vente de matériaux, Akpakpa Bâtiment SA", "F-2027-004", 4_100_000)
reglt_client(d(10, 2), "CBM", "Règlement CBM, facture F-2027-001", "VIR-0210", 4_130_000)
add(d(12, 2), "AC", "Achat de marchandises importées, 3 000 EUR (Euro Import SAS)", "FACT-EU-3381",
    [L("6012000", 1_967_871), L("4011000", credit=1_967_871, tiers="FEU")],
    currency=("EUR", 3_000.00, 655.957), note="Écriture en devise : 3 000 EUR × 655,957 = 1 967 871 FCFA (parité fixe). Dette laissée ouverte.",
    doc={"kind": "facture", "title": "INVOICE 2027-3381", "issuer": "Euro Import SAS", "format": "pdf", "eur": 3_000.00})
reglt_fourn(d(17, 2), "FPL", "Paiement FPL, facture FA-FPL-0511", "VIR-0217", 1_180_000)
add(d(18, 2), "AC", "Achat d'outillage, 2 000 USD (Global Tools Inc.)", "INV-GT-5520",
    [L("6056000", 1_225_000), L("4011000", credit=1_225_000, tiers="FUS")],
    currency=("USD", 2_000.00, 612.5), note="Écriture en dollar : 2 000 USD × 612,500 = 1 225 000 FCFA. Dette laissée ouverte (écart de conversion en fin d'exercice).",
    doc={"kind": "facture", "title": "COMMERCIAL INVOICE GT-5520", "issuer": "Global Tools Inc.", "format": "pdf", "usd": 2_000.00})
add(d(20, 2), "AC", "Acquisition d'un véhicule utilitaire, Auto Import Cotonou", "FA-AIC-0088",
    [L("2451000", 12_000_000), L("4451000", 2_160_000), L("4011000", credit=14_160_000, tiers="FAI")],
    note="Immobilisation : à enregistrer ensuite dans Inventaire > Immobilisations (mise en service 20/02/2027, linéaire 5 ans).",
    doc={"kind": "facture", "title": "FACTURE FA-AIC-0088 : véhicule utilitaire", "issuer": "Auto Import Cotonou", "format": "pdf", "ht": 12_000_000})
reglt_fourn(d(25, 2), "FAI", "Paiement du véhicule, Auto Import Cotonou", "VIR-0225", 14_160_000)
nets2, _, _ = paie(d(28, 2), doc=False)
add(d(28, 2), "BQ", "Paiement des salaires de février 2027", "VIR-0228",
    [*[L("4220000", b - i - c, tiers=t) for t, b, i, c in PAY], L("5210000", credit=nets2)])
frais_bq(d(28, 2), doc=False)

# --- Mars
vente(d(3, 3), "CMA", "Vente de matériaux, Mairie d'Abomey-Calavi (marché public)", "F-2027-005", 6_000_000,
      note="Client public : à son règlement, AIB et TVA retenue (même cas que l'opération du 14/01).")
achat(d(5, 3), "FFA", "Achat de fer à béton, Fer et Acier du Bénin", "FA-FFA-1107", 3_200_000)
add(d(5, 3), "BQ", "Loyer de mars 2027, SCI du bailleur de Ganhi", "QUIT-0327", [L("6222000", 600_000), L("5210000", credit=600_000)])
vente(d(10, 3), "CBM", "Vente de matériaux, Quincaillerie Bénin Matériaux", "F-2027-006", 1_800_000)
reglt_client(d(12, 3), "CAK", "Règlement CAK, facture F-2027-004", "VIR-0312", 4_838_000)
add(d(15, 3), "BQ", "Paiement CNSS et IRPP de janvier et février 2027", "VIR-0315",
    [L("4311000", 2 * soc), L("4472000", 2 * irpp), L("5210000", credit=2 * (soc + irpp))])
reglt_fourn(d(20, 3), "FCG", "Paiement FCG, facture FA-FCG-0215", "VIR-0320", 4_956_000)
add(d(25, 3), "BQ", "Cession du mobilier de bureau (vente au comptant)", "CES-0327",
    [L("5210000", 800_000), L("7011000", credit=800_000, label="Produit de cession")],
    inventory=True,
    note="À faire par Inventaire > Immobilisations > Sortir (prix 800 000, compte de contrepartie 5210000) : "
         "le module génère la dotation complémentaire, la sortie de l'immobilisation, la VNC et la plus-value. L'écriture ci-contre n'est qu'indicative : ne pas la saisir à la main.")
nets3, _, _ = paie(d(31, 3), doc=False)
add(d(31, 3), "BQ", "Paiement des salaires de mars 2027", "VIR-0331",
    [*[L("4220000", b - i - c, tiers=t) for t, b, i, c in PAY], L("5210000", credit=nets3)])
frais_bq(d(31, 3), doc=False)

# --------------------------------------------------------------------------------------------------------------------
# Contrôles
# --------------------------------------------------------------------------------------------------------------------
for op in OPS:
    dd = sum(l.debit for l in op.lines)
    cc = sum(l.credit for l in op.lines)
    assert dd == cc, f"opération {op.no} déséquilibrée : {dd} / {cc}"
    for l in op.lines:
        assert l.account in ACC, f"compte inconnu {l.account}"
        assert (l.debit == 0) != (l.credit == 0), f"op {op.no}: débit xor crédit"
        if l.tiers:
            assert l.tiers in TIERS and TIERS[l.tiers][2] == l.account, f"op {op.no}: tiers {l.tiers} / compte {l.account}"
    if op.currency:
        cur, amt, rate = op.currency
        assert round(amt * rate) == dd, f"op {op.no}: conversion {cur}"
for l in AN:
    assert l.account in ACC
    if l.tiers:
        assert TIERS[l.tiers][2] == l.account

NO = {op.piece: op.no for op in OPS}  # numéro d'opération par référence de pièce
N_ASSURANCE, N_VEHICULE, N_CESSION = NO["ASS-2027-044"], NO["FA-AIC-0088"], NO["CES-0327"]

# La cession est traitée par le module Inventaire : son écriture indicative reste hors balance attendue ; on la remplace ici
# par ses effets (dotation complémentaire, sortie, plus-value) calculés comme le module.
CESSION = next(o for o in OPS if o.inventory)
DOT_CES = round(1_800_000 * 10 / 100 * 85 / 360)  # days360 du 01/01 au 25/03 inclus = 85
VNC_CES = 1_800_000 - (1_080_000 + DOT_CES)
PLUS_VALUE = 800_000 - VNC_CES

bank = AN_BANK
for op in sorted(OPS, key=lambda o: (o.day, o.no)):
    for l in op.lines:
        if l.account == "5210000":
            bank += l.debit - l.credit
    assert bank > 0, f"banque négative après l'opération {op.no} ({op.day})"
BANK_END = bank


def balances(include_an=True):
    b: dict[str, int] = defaultdict(int)
    if include_an:
        for l in AN:
            b[l.account] += l.debit - l.credit
    for op in OPS:
        if op.inventory:
            continue
        for l in op.lines:
            b[l.account] += l.debit - l.credit
    return b


# --------------------------------------------------------------------------------------------------------------------
# Export Perfecto simulé
# --------------------------------------------------------------------------------------------------------------------
def perfecto_account(l: Line) -> tuple[str, str]:
    """Compte tel qu'écrit par Perfecto : tiers collé au collectif (ex. 4111CBM), sinon 7 chiffres."""
    if l.tiers:
        name = TIERS[l.tiers][0]
        return f"{l.account[:4]}{l.tiers}", name
    if l.account == "5210000":
        return "5210ECO", "Ecobank Bénin"
    return l.account, ACC[l.account]


def build_perfecto() -> bytes:
    rows = ["JOURNAL <AN> À-nouveaux", "Pièces du 01/01/2027  au 01/01/2027\t\t", "\t\t\t\t\t\t",
            "Date\tN° pièce\tCompte\tIntitulé\tDébit\tCrédit\tLibellé"]
    td = tc = 0
    for l in AN:
        acc, name = perfecto_account(l)
        lib = l.label or "À-nouveaux au 01/01/2027"
        rows.append(f"01/01/2027\t000001\t{acc}\t{name}\t{l.debit}\t{l.credit}\t{lib}")
        td += l.debit
        tc += l.credit
    rows.append(f"Sous-total\t000001\t\t\t{td}\t{tc}\t")
    rows.append(f"Total\tJournal\t\t\t{td}\t{tc}\t")
    return ("\r\n".join(rows) + "\r\n").encode("cp1252")


# --------------------------------------------------------------------------------------------------------------------
# Relevé bancaire de janvier
# --------------------------------------------------------------------------------------------------------------------
@dataclass
class StLine:
    op_date: date
    value_date: date
    label: str
    debit: int
    credit: int
    ref: str
    matches: str  # note de rapprochement (documentation)


def build_statement() -> list[StLine]:
    lines: list[StLine] = []
    jan = [o for o in OPS if o.journal == "BQ" and o.day.month == 1 and o.piece != "CHQ-4512"]
    for o in jan:
        amt = sum(l.debit - l.credit for l in o.lines if l.account == "5210000")
        lab = {"QUIT-0127": "VIR PERMANENT LOYER JANV 2027 SCI GANHI", "TVA-1226": "PAIEMENT IMPOT TVA 12/2026 DGI",
               "ASS-2027-044": "PRELEVEMENT PRIME ASSURANCE 2027", "VIR-0112": "VIR RECU QUINCAILLERIE BENIN MATERIAUX",
               "VIR-0114": "VIR RECU MAIRIE ABOMEY-CALAVI SOLDE FACTURE", "VIR-0115": "PAIEMENT CNSS + IRPP 12/2026",
               "VIR-0118": "VIR RECU AKPAKPA BATIMENT ACOMPTE", "VIR-0120": "VIR EMIS CIMENTERIE DU GOLFE",
               "VIR-0125": "VIR RECU ZOUNON ET FILS", "VIR-0128": "VIR EMIS FER ET ACIER DU BENIN",
               "VIR-0131": "VIR SALAIRES JANVIER 2027", "AD-0127": "FRAIS TENUE DE COMPTE JANV 2027 + TAF"}.get(o.piece, o.label[:40].upper())
        shift = {"VIR-0125": 2, "VIR-0128": 1}.get(o.piece, 0)  # date de valeur décalée : le pointage ne doit pas dépendre de la date seule
        lines.append(StLine(o.day, date(2027, 1, min(31, o.day.day + shift)), lab, -amt if amt < 0 else 0, amt if amt > 0 else 0, o.piece or "", f"écriture n° {o.no}"))
    # lignes volontairement non rapprochables
    lines.append(StLine(d(22, 1), d(22, 1), "VIR RECU REF 99812 DONNEUR NON IDENTIFIE", 0, 120_000, "99812", "aucune écriture : à identifier (acompte client ?)"))
    lines.append(StLine(d(26, 1), d(26, 1), "VERSEMENT ESPECES GUICHET", 0, 250_000, "VE-0126", "aucune écriture : à justifier"))
    lines.append(StLine(d(31, 1), d(31, 1), "COMMISSION MOUVEMENT DE COMPTE JANV", 15_000, 0, "CMC-0127", "frais non comptabilisés : créer l'écriture depuis la ligne"))
    lines.sort(key=lambda s: (s.op_date, s.ref))
    return lines


def build_statement_csv(lines: list[StLine]) -> str:
    out = ["Date opération;Date valeur;Libellé;Débit;Crédit;Référence;Solde"]
    bal = AN_BANK
    for s in lines:
        bal += s.credit - s.debit
        deb = f"{fr(s.debit)},00" if s.debit else ""
        cre = f"{fr(s.credit)},00" if s.credit else ""
        out.append(f"{s.op_date:%d/%m/%Y};{s.value_date:%d/%m/%Y};{s.label};{deb};{cre};{s.ref};{fr(bal)},00")
    return "\r\n".join(out) + "\r\n"


# --------------------------------------------------------------------------------------------------------------------
# Pièces justificatives
# --------------------------------------------------------------------------------------------------------------------
def make_pieces(ops: list[Op]) -> list[tuple[str, Op]]:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfgen import canvas

    pdir = OUT / "pieces"
    pdir.mkdir(exist_ok=True)
    for old in pdir.glob("*"):
        old.unlink()
    font_path = ROOT / "app" / "assets" / "fonts" / "IBMPlexSans-Regular.ttf"
    done: list[tuple[str, Op]] = []

    def body_lines(op: Op) -> list[str]:
        doc = op.doc or {}
        rows = [f"Date : {op.day:%d/%m/%Y}", f"Référence : {op.piece}", ""]
        if "client" in doc:
            rows += [f"Client : {doc['client']}", ""]
        if "ht" in doc:
            ht = doc["ht"]
            rows += [f"Montant HT : {fr(ht)} FCFA", f"TVA 18 % : {fr(tva(ht))} FCFA", f"TOTAL TTC : {fr(ht + tva(ht))} FCFA"]
        elif "eur" in doc:
            rows += [f"Total : {doc['eur']:,.2f} EUR".replace(",", " "), "Taux de conversion : 655,957 FCFA pour 1 EUR", f"Contre-valeur : {fr(round(doc['eur'] * 655.957))} FCFA"]
        elif "usd" in doc:
            rows += [f"Total : {doc['usd']:,.2f} USD".replace(",", " "), "Taux retenu : 612,500 FCFA pour 1 USD", f"Contre-valeur : {fr(round(doc['usd'] * 612.5))} FCFA"]
        elif "amount" in doc:
            rows += [f"Montant : {fr(doc['amount'])} FCFA"]
        rows += ["", op.label, "", "DOCUMENT FICTIF : jeu de données de recette Akonta"]
        return rows

    idx = 0
    for op in ops:
        if not op.doc:
            continue
        idx += 1
        doc = op.doc
        slug = f"{idx:02d}-{doc['kind']}-{(op.piece or 'x').lower()}"
        path = pdir / f"{slug}.{doc['format']}"
        rows = body_lines(op)
        if doc["format"] == "pdf":
            c = canvas.Canvas(str(path), pagesize=A4)
            w, h = A4
            c.setFont("Helvetica-Bold", 16)
            c.drawString(50, h - 70, doc["issuer"])
            c.setFont("Helvetica-Bold", 13)
            c.drawString(50, h - 110, doc["title"])
            c.setFont("Helvetica", 11)
            y = h - 150
            for r in rows:
                c.drawString(50, y, r)
                y -= 18
            c.rect(40, h - 180 - 18 * len(rows), w - 80, 18 * len(rows) + 120, stroke=1, fill=0)
            c.showPage()
            c.save()
        else:  # JPEG : « photo » d'un reçu, légèrement inclinée, sur fond de table
            img = Image.new("RGB", (900, 1200), (212, 205, 193))
            ticket = Image.new("RGB", (700, 1000), (250, 249, 245))
            dr = ImageDraw.Draw(ticket)
            fb = ImageFont.truetype(str(font_path), 34)
            fn = ImageFont.truetype(str(font_path), 26)
            dr.text((40, 40), doc["issuer"], fill=(30, 30, 30), font=fb)
            dr.text((40, 100), doc["title"], fill=(30, 30, 30), font=fn)
            y = 170
            for r in rows:
                dr.text((40, y), r, fill=(40, 40, 40), font=fn)
                y += 42
            ticket = ticket.rotate(-2.5, expand=True, fillcolor=(212, 205, 193))
            img.paste(ticket, (80, 70))
            img = img.filter(ImageFilter.GaussianBlur(0.6))
            img.save(path, "JPEG", quality=82)
        done.append((path.name, op))
    return done


# --------------------------------------------------------------------------------------------------------------------
# Données d'inventaire
# --------------------------------------------------------------------------------------------------------------------
STOCK_FINAL = 6_120_000
PROVISIONS = [("CDX", 3_540_000, 50), ("CBS", 1_416_000, 75)]
CHARGE_A_PAYER = (260_000, "Électricité de décembre 2027, facture non reçue", "6052000")
CCA = (1_500_000, 15, 3)  # prime, durée en mois, mois restant à courir après le 31/12/2027 (janvier à mars 2028)
CCA_AMOUNT = CCA[0] * CCA[2] // CCA[1]
USD_CLOSING = 574.3
ECART_USD = round(2_000 * 612.5) - round(2_000 * USD_CLOSING)
DOT_VEHICULE = round(12_000_000 * 20 / 100 * 311 / 360)  # days360 du 20/02 au 31/12 inclus = 311


# --------------------------------------------------------------------------------------------------------------------
# Rédaction du jeu de données (Markdown)
# --------------------------------------------------------------------------------------------------------------------
def md_table(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(out)


def build_md(statement: list[StLine], pieces: list[tuple[str, Op]]) -> str:
    o: list[str] = []
    o.append("# Jeu de données de la recette interne : Comptoir Aïdé Négoce SARL\n")
    o.append("Données **entièrement fictives**, générées par `recette/generer-jeu.py` (rejouable). Tout est à créer dans l'application par l'équipe : rien n'est pré-chargé.\n")
    o.append("## 1. Fiche de l'entité (assistant d'ouverture de dossier)\n")
    o.append("### R1 : Identification\n")
    o.append(md_table(["Champ", "Valeur"], [
        ("Dénomination", "Comptoir Aïdé Négoce SARL"), ("Sigle", "CAN"), ("Forme juridique", "SARL"),
        ("Adresse du siège", "Zone industrielle de Vèdoko, Cotonou, Bénin"), ("Pays", "Bénin"),
        ("IFU (13 chiffres)", "3202700001234"), ("RCCM", "RB/COT/21 B 4567"), ("Régime fiscal", "Réel normal"),
        ("Date de création", "12/04/2021"), ("Nombre d'établissements", "1"), ("Contrôle / Origine", "Privé / National"),
    ]))
    o.append("\n### R2 : Activité\n")
    o.append(md_table(["Champ", "Valeur"], [
        ("Activité principale", "Commerce de gros et de détail de matériaux de construction"),
        ("Activités secondaires", "Location d'outillage de chantier, transport de marchandises"), ("Code de nomenclature", "4752"),
    ]))
    o.append("\n### R3 : Dirigeants (onglet Dirigeants de la fiche du dossier)\n")
    o.append(md_table(["Nom", "Qualité", "Nationalité", "Conseil"], [
        ("Aïcha ZINSOU", "Gérante", "Béninoise", "non"), ("Ferdinand HOUNSA", "Cogérant", "Béninoise", "non"),
    ]))
    o.append("\n### Exercice, capital, associés, effectif\n")
    o.append(md_table(["Champ", "Valeur"], [
        ("Exercice", "01/01/2027 au 31/12/2027 (12 mois)"), ("Capital", "20 000 000 FCFA"), ("Effectif", "8 personnes"),
        ("Associés", "Aïcha ZINSOU 55 % ; Ferdinand HOUNSA 30 % ; Reine DAGBA 15 %"),
        ("Plan de comptes", "7 chiffres"), ("Verrouillage mensuel", "activé"),
        ("Journaux à créer", "AC Achats, VT Ventes, BQ Banque (compte 5210000, « Ecobank Bénin »), OD Opérations diverses, PA Paie, AN À-nouveaux"),
    ]))
    o.append("\n## 2. Tiers à créer (étape 3)\n")
    o.append("Les tiers CBM à CBS, FCG et FPL sont aussi créés par l'import Perfecto (étape 4) ; les autres (FFA, FEN, FTL, FEU, FUS, FAI, PE1 à PE3) se créent à la main ou à la volée.\n")
    o.append(md_table(["Code", "Nom", "Type", "Collectif"], [(k, v[0], v[1], f"{v[2]} {ACC[v[2]]}") for k, v in TIERS.items()]))
    o.append("\n## 3. À-nouveaux au 01/01/2027 (fichier `export-perfecto-simule.txt`)\n")
    o.append("Une seule pièce `000001`, équilibrée, journal source `<AN>`. À importer dans le journal **AN**. Les comptes de tiers sont collés comme dans Perfecto (`4111CBM` → collectif 4111000 + tiers CBM). Le compte `5210ECO` (banque) se rapproche de 5210000 : retirer le tiers « ECO » dans la table de correspondance (la banque n'est pas un tiers).\n")
    rows = []
    for l in AN:
        acc, name = perfecto_account(l)
        rows.append((acc, name, fr(l.debit) if l.debit else "", fr(l.credit) if l.credit else ""))
    rows.append(("**Total**", "", f"**{fr(sum(x.debit for x in AN))}**", f"**{fr(sum(x.credit for x in AN))}**"))
    o.append(md_table(["Compte (export)", "Intitulé", "Débit", "Crédit"], rows))
    o.append(f"\nSolde bancaire d'ouverture : **{fr(AN_BANK)} FCFA** (compte 5210000).\n")
    o.append("Factures clients non réglées reprises (à lettrer ensuite) : " + ", ".join(f"{t} {ref} {fr(m)}" for t, m, ref in AN_CLIENTS) + ".  \n")
    o.append("Factures fournisseurs non réglées reprises : " + ", ".join(f"{t} {ref} {fr(m)}" for t, m, ref in AN_FOURN) + ".\n")

    o.append("## 4. Opérations de janvier à mars 2027 (à saisir à la main : étapes 5 à 9)\n")
    o.append("Montants en FCFA entiers. TVA 18 %. La colonne « Pièce » est la référence à saisir dans « Référence pièce » ; « Doc » renvoie au fichier de `pieces/` à joindre. "
             "Répartition conseillée : le **stagiaire** saisit l'opération 1 (elle reste en brouillard), l'**assistant** saisit janvier (étape 5), le chef de mission valide.\n")
    piece_of = {op.no: name for name, op in pieces}
    syn = []
    for op in OPS:
        dd = sum(l.debit for l in op.lines)
        flag = " (module Inventaire)" if op.inventory else ""
        syn.append((op.no, f"{op.day:%d/%m/%Y}", op.journal, op.label + flag, op.piece or "", fr(dd), piece_of.get(op.no, "")))
    o.append(md_table(["N°", "Date", "Jnl", "Libellé", "Pièce", "Montant", "Doc"], syn))
    o.append("\n### Détail des écritures\n")
    for op in OPS:
        o.append(f"**{op.no}. {op.day:%d/%m/%Y} : {op.journal} : {op.label}** (pièce `{op.piece}`)")
        if op.currency:
            cur, amt, rate = op.currency
            o.append(f"  \nDevise : {amt:,.2f} {cur} au cours de {rate:.3f}".replace(",", " "))
        if op.note:
            o.append(f"  \n_{op.note}_")
        o.append("")
        o.append(md_table(["Compte", "Tiers", "Débit", "Crédit"], [
            (f"{l.account} {ACC[l.account]}", l.tiers or "", fr(l.debit) if l.debit else "", fr(l.credit) if l.credit else "") for l in op.lines]))
        o.append("")

    o.append("### Cas à tester volontairement (garde-fous, étape 5.3)\n")
    o.append("- Écriture déséquilibrée : reprendre l'opération 1 et saisir 4 956 000 au crédit du fournisseur mais 4 900 000 en débit au total : refus à la validation.\n"
             "- Montant négatif : saisir « -100 000 » dans un débit : refusé (un montant est toujours positif ; débit **ou** crédit).\n"
             "- Date hors exercice : écriture datée du 15/12/2026 dans l'exercice 2027 : refusée.\n"
             "- Suppression d'un compte mouvementé : refusée (étape 3.3).\n"
             "- Saisie dans un mois verrouillé (étape 9) : refusée.\n")

    o.append("## 5. Relevé bancaire de janvier (fichier `releve-ecobank-janvier.csv`)\n")
    o.append("Format : UTF-8, séparateur `;`, en-tête sur la première ligne, dates `jj/mm/aaaa`, montants à la française (espaces, virgule). "
             "Gabarit à créer à la première importation (banque Ecobank) : **date = colonne 1, date de valeur = 2, libellé = 3, débit = 4, crédit = 5, référence = 6**, séparateur « ; », virgule décimale. "
             "Le « Débit » du relevé est une **sortie** d'argent.\n")
    o.append(md_table(["Date", "Valeur", "Libellé", "Débit", "Crédit", "Réf.", "Attendu"], [
        (f"{s.op_date:%d/%m}", f"{s.value_date:%d/%m}", s.label, fr(s.debit) if s.debit else "", fr(s.credit) if s.credit else "", s.ref, s.matches) for s in statement]))
    jan_bank = sum(sum(l.debit - l.credit for l in op.lines if l.account == "5210000") for op in OPS if op.journal == "BQ" and op.day.month == 1)
    st_bal = AN_BANK + sum(s.credit - s.debit for s in statement)
    assert st_bal - (AN_BANK + jan_bank) == 120_000 + 250_000 - 15_000 + 212_400
    o.append(f"\nSolde comptable de la banque au 31/01/2027 : **{fr(AN_BANK + jan_bank)}** (le chèque n° 0004512 de 212 400 y est déjà déduit) ; solde du relevé : **{fr(st_bal)}**. "
             f"Écart attendu **{fr(st_bal - (AN_BANK + jan_bank))}** = 120 000 + 250 000 de crédits à identifier − 15 000 de commission non comptabilisée + 212 400 de chèque en circulation. "
             "Après avoir créé l'écriture de la commission (15 000 TTC, à ventiler frais + TAF si l'on veut), l'état de rapprochement doit expliquer le reste par les deux virements/versements à identifier et le chèque en circulation.\n")

    o.append("## 6. Pièces justificatives (dossier `pieces/`)\n")
    o.append(md_table(["Fichier", "Opération", "Contenu"], [(f"`{n}`", f"{op.no} ({op.day:%d/%m})", op.doc["title"]) for n, op in pieces]))
    o.append("\nÀ joindre depuis l'ordinateur (Pièces > Déposer) ; pour tester la capture mobile, photographier un des documents affichés à l'écran ou imprimés.\n")

    o.append("## 7. Données de fin d'exercice (étape 10, exercice 2027)\n")
    o.append("Les travaux d'inventaire se font à la date du **31/12/2027** : la recette ne comporte que le premier trimestre, on suppose qu'il n'y a pas d'autres mouvements significatifs.\n")
    o.append("### Immobilisations\n")
    o.append(md_table(["Bien", "Valeur brute", "Mise en service", "Méthode", "Amort. cumulé au 31/12/2026", "À faire"], [
        ("Matériel de bureau (2441000)", "2 400 000", "01/01/2025", "linéaire 5 ans", "960 000", "reprise de l'existant"),
        ("Mobilier de bureau (2444000)", "1 800 000", "01/01/2021", "linéaire 10 ans", "1 080 000", "reprise, puis cession le 25/03/2027 pour 800 000"),
        ("Matériel automobile (2451000)", "8 500 000", "01/01/2025", "linéaire 5 ans", "3 400 000", "reprise de l'existant"),
        (f"Véhicule utilitaire (op. {N_VEHICULE}, 2451000)", "12 000 000", "20/02/2027", "linéaire 5 ans", "0", "acquisition 2027 : dotation prorata temporis"),
    ]))
    o.append(f"\nAttendus (base 360 jours, D-011 ; les écarts d'un franc dus aux arrondis sont à signaler comme anomalie mineure) : dotation 2027 du véhicule = 12 000 000 × 20 % × 311/360 = **{fr(DOT_VEHICULE)}** ; "
             f"cession du mobilier le 25/03/2027 : dotation complémentaire 1 800 000 × 10 % × 85/360 = **{fr(DOT_CES)}**, valeur nette comptable **{fr(VNC_CES)}**, plus-value **{fr(PLUS_VALUE)}**.\n")
    o.append("### Stocks\n")
    o.append(f"Stock initial (à-nouveaux, 3111000) : 4 800 000. **Stock final au 31/12/2027 : {fr(STOCK_FINAL)}** (inventaire physique) ; variation de stock attendue : **+{fr(STOCK_FINAL - 4_800_000)}** (produit, compte 6031).\n")
    o.append("### Provisions pour créances douteuses (depuis la balance âgée)\n")
    o.append(md_table(["Client", "Solde (TTC)", "Taux de provision", "Dotation attendue"], [
        (f"{t} {TIERS[t][0]}", fr(m), f"{p} %", fr(round(m * p / 100))) for t, m, p in PROVISIONS]))
    o.append(f"\nTotal attendu : **{fr(sum(round(m * p / 100) for _, m, p in PROVISIONS))}**. Les deux factures datent de 2025 : elles apparaissent dans la tranche la plus ancienne de la balance âgée.\n")
    o.append("### Régularisations\n")
    o.append(md_table(["Type", "Libellé", "Montant", "Détail"], [
        ("Charge à payer", CHARGE_A_PAYER[1], fr(CHARGE_A_PAYER[0]), f"au 31/12/2027, charge {CHARGE_A_PAYER[2]}, extourne attendue au 01/01/2028"),
        ("Charge constatée d'avance", f"Prime d'assurance 15 mois (op. {N_ASSURANCE})", fr(CCA_AMOUNT),
         f"{fr(CCA[0])} × {CCA[2]}/{CCA[1]} (janvier à mars 2028 restant à courir), extourne attendue au 01/01/2028"),
    ]))
    o.append("\n### Écart de conversion\n")
    o.append(f"Dette en dollars envers Global Tools Inc. : 2 000 USD comptabilisés à 612,500 (1 225 000 FCFA) ; **cours de clôture au 31/12/2027 : 574,300** → dette réévaluée {fr(round(2000 * USD_CLOSING))} ; "
             f"écart de conversion attendu **{fr(ECART_USD)} FCFA** (gain latent sur dette : compte 4792, pas de provision). La dette en euros (3 000 EUR) ne génère aucun écart : parité fixe 655,957.\n")

    o.append("## 8. Contrôles attendus après saisie complète du premier trimestre\n")
    o.append(f"Toutes les écritures validées (opérations 1 à {len(OPS)} hors l'opération {N_CESSION}, la cession, traitée par le module Inventaire) et les à-nouveaux validés. "
             "La balance générale au 31/03/2027 doit donner :\n")
    bal = balances()
    tot_d = sum(v for v in bal.values() if v > 0)
    tot_c = -sum(v for v in bal.values() if v < 0)
    o.append(md_table(["Compte", "Intitulé", "Solde débiteur", "Solde créditeur"], [
        (a, ACC[a], fr(v) if v > 0 else "", fr(-v) if v < 0 else "") for a, v in sorted(bal.items()) if v != 0] + [("**Total**", "", f"**{fr(tot_d)}**", f"**{fr(tot_c)}**")]))
    assert tot_d == tot_c
    prod = -sum(v for a, v in bal.items() if a.startswith("7"))
    chg = sum(v for a, v in bal.items() if a.startswith("6"))
    o.append(f"\nRésultat provisoire du trimestre (produits − charges, hors régularisations) : **{fr(prod - chg)} FCFA** (produits {fr(prod)}, charges {fr(chg)}). "
             f"Solde de la banque au 31/03/2027 hors cession : {fr(bal['5210000'])}. TVA : facturée {fr(-bal['4431000'])}, récupérable sur achats {fr(bal['4452000'])} (dont 900 000 de TVA retenue), sur immobilisations {fr(bal['4451000'])}.\n")
    o.append("Les brouillards (opération saisie par le stagiaire, non validée) ne figurent pas dans ces totaux.\n")
    return "\n".join(o) + "\n"


def build_pgtap(perfecto_bytes: bytes) -> str:
    text = perfecto_bytes.decode("cp1252")
    sha = hashlib.sha256(perfecto_bytes).hexdigest()
    accounts = sorted({l.account for op in OPS for l in op.lines} | {l.account for l in AN})
    acc_list = ",".join(f"'{a}'" for a in accounts)
    assert "$perf$" not in text
    return f"""-- GÉNÉRÉ par recette/generer-jeu.py : ne pas modifier à la main.
-- source-sha256: {sha}
-- Recette interne : l'export Perfecto simulé (recette/export-perfecto-simule.txt, décodé de Windows-1252) est lu sans erreur
-- par le module d'import en mode essai ; les à-nouveaux sont équilibrés ; tous les comptes du jeu de données existent dans le plan de l'entité.
begin;
select plan(11);

select tests.create_cabinet('Cabinet recette') as id \\gset a_
select tests.create_user('manager@recette.test', :'a_id') as id \\gset manager_
select tests.create_entity(:'a_id', 'Comptoir Aïdé Négoce SARL') as id \\gset e1_
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2027-01-01', '2027-12-31');
select id as id from public.journals where entity_id = :'e1_id' and code = 'AN' \\gset an_

select is((select count(*) from public.accounts where entity_id = :'e1_id' and code in ({acc_list})), {len(accounts)}::bigint,
          'les {len(accounts)} comptes du jeu de données existent dans le plan à 7 chiffres de l''entité');

select tests.authenticate_as(:'manager_id');
insert into public.import_batches (cabinet_id, entity_id, kind, source_file_name, target_journal_id)
values (:'a_id', :'e1_id', 'journal', 'export-perfecto-simule.txt', :'an_id');
select id as id from public.import_batches where entity_id = :'e1_id' \\gset batch_

select public.import_parse_perfecto_journal(:'batch_id', $perf${text}$perf$) as report \\gset parse_
select is((select source_journal from public.import_batches where id = :'batch_id'), 'AN', 'code du journal source lu dans l''en-tête');
select is((select period_from::text || '→' || period_to::text from public.import_batches where id = :'batch_id'), '2027-01-01→2027-01-01', 'période lue');
select is((:'parse_report'::jsonb ->> 'lines')::int, {len(AN)}, '{len(AN)} lignes de données lues');
select is((:'parse_report'::jsonb ->> 'pieces')::int, 1, 'une pièce (à-nouveaux)');
select is((:'parse_report'::jsonb ->> 'subtotal_errors')::int, 0, 'sous-total cohérent');
-- Comme sur le vrai JOURNAL BANQUE.TXT (vérifié), l'analyse signale deux « Date illisible » bénins : la ligne d'en-tête faite de seules
-- tabulations et la ligne « Total Journal » finale (Q-007). Ce sont les seules : aucune ligne de données n'est rejetée.
select is((select jsonb_agg(e ->> 'error' order by (e ->> 'line')::int)::text from jsonb_array_elements(:'parse_report'::jsonb -> 'parse_errors') e),
          '["Date illisible : ", "Date illisible : Total"]', 'seules les deux lignes d''en-tête et de total sont signalées (comme sur l''export réel)');

select public.import_propose_mappings(:'batch_id') as report \\gset map_
select is((select account_code || '|' || third_party_code from public.import_account_mappings where entity_id = :'e1_id' and raw_account = '4111CBM'), '4111000|CBM', '4111CBM → collectif 4111000 + tiers CBM');
-- La banque (5210ECO) n'est pas un tiers : la correspondance éditable retire le suffixe, comme le fera l'équipe (jeu-de-donnees.md).
update public.import_account_mappings set third_party_code = null, third_party_name = null, create_third_party = false where entity_id = :'e1_id' and raw_account = '5210ECO';
select public.import_apply(:'batch_id', true) as report \\gset dry_
select is((:'dry_report'::jsonb ->> 'error_count')::int, 0, 'essai sans erreur');
select is((:'dry_report'::jsonb ->> 'entries')::int, 1, 'essai : une écriture de à-nouveaux serait créée');
select is((select count(*) from public.entries where entity_id = :'e1_id'), 0::bigint, 'essai : aucune écriture créée');

select * from finish();
rollback;
"""



def build_pgtap_ops() -> str:
    """Test pgTAP : les 44 écritures et les à-nouveaux passent les règles de la base (équilibre, tiers, devises, validation, numérotation)."""
    import json

    def jl(l: Line) -> dict:
        x = {"a": l.account, "d": l.debit, "c": l.credit}
        if l.tiers:
            x["t"] = l.tiers
        return x

    ops = []
    for op in OPS:
        if op.inventory:
            continue
        item = {"n": op.no, "dt": op.day.isoformat(), "j": op.journal, "label": op.label, "ref": op.piece, "lines": [jl(l) for l in op.lines]}
        if op.currency:
            item["cur"] = {"code": op.currency[0], "amount": op.currency[1], "rate": op.currency[2]}
        ops.append(item)
    an = [jl(l) for l in AN]
    tiers = [{"code": k, "name": v[0], "kind": {"client": "customer", "fournisseur": "supplier", "personnel": "employee"}[v[1]], "acc": v[2]} for k, v in TIERS.items()]
    bal = balances()
    expected = ",".join(f"('{a}', {v})" for a, v in sorted(bal.items()) if v != 0)
    q = lambda obj: json.dumps(obj, ensure_ascii=False).replace("'", "''")
    sha = hashlib.sha256(json.dumps([ops, an], sort_keys=True).encode()).hexdigest()
    return f"""-- GÉNÉRÉ par recette/generer-jeu.py : ne pas modifier à la main.
-- content-sha256: {sha}
-- Recette interne : les {len(ops)} opérations de janvier à mars 2027 et les à-nouveaux de recette/jeu-de-donnees.md sont acceptés par les règles
-- de la base (équilibre, tiers sur collectifs, euro à parité fixe, devise, périodes) et validés avec une numérotation sans trou ;
-- la balance obtenue est celle annoncée dans le jeu de données (§ 8).
begin;
select plan(7);

select tests.create_cabinet('Cabinet recette') as id \\gset a_
select tests.create_user('manager@recette2.test', :'a_id') as id \\gset manager_
select tests.create_entity(:'a_id', 'Comptoir Aïdé Négoce SARL') as id \\gset e1_
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2027-01-01', '2027-12-31');
select public.create_journals_from_template(:'e1_id', array['AC', 'VT', 'OD', 'PA']);
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'e1_id', 'BQ', 'Ecobank Bénin', 'bank', id from public.accounts where entity_id = :'e1_id' and code = '5210000';

do $recette$
declare
  v_cab uuid; v_ent uuid; v_user uuid; v_len int; o jsonb; l jsonb; t jsonb; v_entry uuid; v_n int;
  v_ops jsonb := '{q(ops)}'::jsonb;
  v_an jsonb := '{q(an)}'::jsonb;
  v_tiers jsonb := '{q(tiers)}'::jsonb;
begin
  select id into v_ent from public.entities where name = 'Comptoir Aïdé Négoce SARL' order by created_at desc limit 1;
  select cabinet_id into v_cab from public.entities where id = v_ent;
  select id into v_user from public.profiles where email = 'manager@recette2.test';
  for t in select * from jsonb_array_elements(v_tiers) loop
    insert into public.third_parties (cabinet_id, entity_id, code, name, type)
    values (v_cab, v_ent, t->>'code', t->>'name', (t->>'kind')::public.third_party_type);
    insert into public.third_party_accounts (third_party_id, account_id)
    select tp.id, a.id from public.third_parties tp, public.accounts a where tp.entity_id = v_ent and tp.code = t->>'code' and a.entity_id = v_ent and a.code = t->>'acc';
  end loop;
  perform set_config('request.jwt.claims', json_build_object('sub', v_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  -- À-nouveaux
  insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, reference, label, created_by)
  values (v_cab, v_ent, (select id from public.fiscal_years where entity_id = v_ent), (select id from public.periods where entity_id = v_ent and '2027-01-01' between start_date and end_date),
          (select id from public.journals where entity_id = v_ent and code = 'AN'), '2027-01-01', '000001', 'À-nouveaux au 01/01/2027', v_user) returning id into v_entry;
  v_n := 0;
  for l in select * from jsonb_array_elements(v_an) loop
    v_n := v_n + 1;
    insert into public.entry_lines (cabinet_id, entity_id, entry_id, line_no, account_id, third_party_id, debit, credit)
    select v_cab, v_ent, v_entry, v_n, a.id, tp.id, (l->>'d')::bigint, (l->>'c')::bigint
      from public.accounts a left join public.third_parties tp on tp.entity_id = v_ent and tp.code = l->>'t'
     where a.entity_id = v_ent and a.code = l->>'a';
  end loop;
  perform public.validate_entry(v_entry);
  -- Opérations
  for o in select * from jsonb_array_elements(v_ops) loop
    insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, reference, label, currency_code, created_by)
    values (v_cab, v_ent, (select id from public.fiscal_years where entity_id = v_ent),
            (select id from public.periods where entity_id = v_ent and (o->>'dt')::date between start_date and end_date),
            (select id from public.journals where entity_id = v_ent and code = o->>'j'), (o->>'dt')::date, o->>'ref', o->>'label',
            coalesce(o->'cur'->>'code', 'XOF'), v_user) returning id into v_entry;
    v_n := 0;
    for l in select * from jsonb_array_elements(o->'lines') loop
      v_n := v_n + 1;
      insert into public.entry_lines (cabinet_id, entity_id, entry_id, line_no, account_id, third_party_id, debit, credit, currency_code, amount_currency, exchange_rate)
      select v_cab, v_ent, v_entry, v_n, a.id, tp.id, (l->>'d')::bigint, (l->>'c')::bigint,
             coalesce(o->'cur'->>'code', 'XOF'), (o->'cur'->>'amount')::numeric, (o->'cur'->>'rate')::numeric
        from public.accounts a left join public.third_parties tp on tp.entity_id = v_ent and tp.code = l->>'t'
       where a.entity_id = v_ent and a.code = l->>'a';
    end loop;
    perform public.validate_entry(v_entry);
  end loop;
  perform set_config('request.jwt.claims', '', true);
end $recette$;

select is((select count(*) from public.entries where entity_id = :'e1_id' and status = 'validated'), {len(ops) + 1}::bigint, '{len(ops)} opérations et les à-nouveaux validés');
select is((select count(*) from public.entries where entity_id = :'e1_id' and status = 'draft'), 0::bigint, 'aucun brouillard restant');
select is((select count(*) from public.entry_lines where entity_id = :'e1_id' and currency_code = 'EUR'), 2::bigint, 'écriture en euro acceptée (2 lignes)');
select is((select count(*) from public.entry_lines where entity_id = :'e1_id' and currency_code = 'USD'), 2::bigint, 'écriture en dollar acceptée (2 lignes)');
-- Numérotation continue par journal
select is((select count(*) from (select journal_id, max(number) - count(*) as gap from public.entries where entity_id = :'e1_id' and status = 'validated' group by journal_id) x where gap <> 0), 0::bigint, 'numérotation sans trou dans chaque journal');
-- Balance attendue (jeu-de-donnees.md § 8)
create temp table expected_balance (code text, balance bigint);
insert into expected_balance values {expected};
select is((select count(*) from (
  select a.code, sum(el.debit - el.credit) as bal from public.entry_lines el join public.accounts a on a.id = el.account_id
   where el.entity_id = :'e1_id' group by a.code having sum(el.debit - el.credit) <> 0
  except select code, balance from expected_balance) x), 0::bigint, 'aucun solde réel ne diffère de la balance annoncée');
select is((select count(*) from (select code, balance from expected_balance except
  select a.code, sum(el.debit - el.credit) from public.entry_lines el join public.accounts a on a.id = el.account_id where el.entity_id = :'e1_id' group by a.code) x), 0::bigint, 'aucun solde annoncé ne manque');

select * from finish();
rollback;
"""


def main() -> None:
    OUT.mkdir(exist_ok=True)
    perfecto = build_perfecto()
    (OUT / "export-perfecto-simule.txt").write_bytes(perfecto)
    statement = build_statement()
    (OUT / "releve-ecobank-janvier.csv").write_text(build_statement_csv(statement), encoding="utf-8", newline="")
    pieces = make_pieces(OPS)
    (OUT / "jeu-de-donnees.md").write_text(build_md(statement, pieces), encoding="utf-8")
    (ROOT / "supabase" / "tests" / "150_recette_import.test.sql").write_text(build_pgtap(perfecto), encoding="utf-8")
    (ROOT / "supabase" / "tests" / "151_recette_operations.test.sql").write_text(build_pgtap_ops(), encoding="utf-8")
    print(f"AN : {len(AN)} lignes, banque d'ouverture {fr(AN_BANK)}")
    print(f"{len(OPS)} opérations, {len(pieces)} pièces, {len(statement)} lignes de relevé, banque fin mars {fr(BANK_END)}")


if __name__ == "__main__":
    sys.exit(main())
