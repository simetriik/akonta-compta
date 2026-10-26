# Jeu de données de la recette interne : Comptoir Aïdé Négoce SARL

Données **entièrement fictives**, générées par `recette/generer-jeu.py` (rejouable). Tout est à créer dans l'application par l'équipe : rien n'est pré-chargé.

## 1. Fiche de l'entité (assistant d'ouverture de dossier)

### R1 : Identification

| Champ | Valeur |
|---|---|
| Dénomination | Comptoir Aïdé Négoce SARL |
| Sigle | CAN |
| Forme juridique | SARL |
| Adresse du siège | Zone industrielle de Vèdoko, Cotonou, Bénin |
| Pays | Bénin |
| IFU (13 chiffres) | 3202700001234 |
| RCCM | RB/COT/21 B 4567 |
| Régime fiscal | Réel normal |
| Date de création | 12/04/2021 |
| Nombre d'établissements | 1 |
| Contrôle / Origine | Privé / National |

### R2 : Activité

| Champ | Valeur |
|---|---|
| Activité principale | Commerce de gros et de détail de matériaux de construction |
| Activités secondaires | Location d'outillage de chantier, transport de marchandises |
| Code de nomenclature | 4752 |

### R3 : Dirigeants (onglet Dirigeants de la fiche du dossier)

| Nom | Qualité | Nationalité | Conseil |
|---|---|---|---|
| Aïcha ZINSOU | Gérante | Béninoise | non |
| Ferdinand HOUNSA | Cogérant | Béninoise | non |

### Exercice, capital, associés, effectif

| Champ | Valeur |
|---|---|
| Exercice | 01/01/2027 au 31/12/2027 (12 mois) |
| Capital | 20 000 000 FCFA |
| Effectif | 8 personnes |
| Associés | Aïcha ZINSOU 55 % ; Ferdinand HOUNSA 30 % ; Reine DAGBA 15 % |
| Plan de comptes | 7 chiffres |
| Verrouillage mensuel | activé |
| Journaux à créer | AC Achats, VT Ventes, BQ Banque (compte 5210000, « Ecobank Bénin »), OD Opérations diverses, PA Paie, AN À-nouveaux |

## 2. Tiers à créer (étape 3)

Les tiers CBM à CBS, FCG et FPL sont aussi créés par l'import Perfecto (étape 4) ; les autres (FFA, FEN, FTL, FEU, FUS, FAI, PE1 à PE3) se créent à la main ou à la volée.

| Code | Nom | Type | Collectif |
|---|---|---|---|
| CBM | Quincaillerie Bénin Matériaux | client | 4111000 Clients |
| CAK | Akpakpa Bâtiment SA | client | 4111000 Clients |
| CZO | Entreprise ZOUNON & Fils | client | 4111000 Clients |
| CMA | Mairie d'Abomey-Calavi | client | 4111000 Clients |
| CDX | Entreprise DOSSOU BTP | client | 4111000 Clients |
| CBS | Établissements BOSSOU | client | 4111000 Clients |
| FCG | Cimenterie du Golfe | fournisseur | 4011000 Fournisseurs |
| FFA | Fer et Acier du Bénin | fournisseur | 4011000 Fournisseurs |
| FPL | Peintures du Littoral | fournisseur | 4011000 Fournisseurs |
| FEN | Fournisseur Énergie (électricité) | fournisseur | 4011000 Fournisseurs |
| FTL | Opérateur Télécom du Bénin | fournisseur | 4011000 Fournisseurs |
| FEU | Euro Import SAS (France) | fournisseur | 4011000 Fournisseurs |
| FUS | Global Tools Inc. (États-Unis) | fournisseur | 4011000 Fournisseurs |
| FAI | Auto Import Cotonou | fournisseur | 4011000 Fournisseurs |
| PE1 | Employé 1 : Gildas AHOUANSOU | personnel | 4220000 Personnel, rémunérations dues |
| PE2 | Employé 2 : Chantal DEGBE | personnel | 4220000 Personnel, rémunérations dues |
| PE3 | Employé 3 : Rodrigue TOKPO | personnel | 4220000 Personnel, rémunérations dues |

## 3. À-nouveaux au 01/01/2027 (fichier `export-perfecto-simule.txt`)

Une seule pièce `000001`, équilibrée, journal source `<AN>`. À importer dans le journal **AN**. Les comptes de tiers sont collés comme dans Perfecto (`4111CBM` → collectif 4111000 + tiers CBM). Le compte `5210ECO` (banque) se rapproche de 5210000 : retirer le tiers « ECO » dans la table de correspondance (la banque n'est pas un tiers).

| Compte (export) | Intitulé | Débit | Crédit |
|---|---|---|---|
| 2441000 | Matériel de bureau | 2 400 000 |  |
| 2444000 | Mobilier de bureau | 1 800 000 |  |
| 2451000 | Matériel automobile | 8 500 000 |  |
| 2844000 | Amortissements du matériel et mobilier |  | 2 040 000 |
| 2845000 | Amortissements du matériel de transport |  | 3 400 000 |
| 3111000 | Marchandises A1 | 4 800 000 |  |
| 4111CBM | Quincaillerie Bénin Matériaux | 1 770 000 |  |
| 4111CAK | Akpakpa Bâtiment SA | 2 360 000 |  |
| 4111CMA | Mairie d'Abomey-Calavi | 5 900 000 |  |
| 4111CDX | Entreprise DOSSOU BTP | 3 540 000 |  |
| 4111CBS | Établissements BOSSOU | 1 416 000 |  |
| 4011FCG | Cimenterie du Golfe |  | 3 068 000 |
| 4011FPL | Peintures du Littoral |  | 1 180 000 |
| 4311000 | Sécurité sociale (CNSS) |  | 218 500 |
| 4441000 | État, TVA due |  | 410 000 |
| 4472000 | Impôts sur salaires (IRPP) |  | 52 000 |
| 1010000 | Capital social |  | 20 000 000 |
| 1181000 | Réserves facultatives |  | 4 000 000 |
| 1210000 | Report à nouveau créditeur |  | 3 250 000 |
| 1301000 | Résultat en instance d'affectation : bénéfice |  | 6 750 000 |
| 1620000 | Emprunts auprès des établissements de crédit |  | 6 000 000 |
| 5210ECO | Ecobank Bénin | 17 882 500 |  |
| **Total** |  | **50 368 500** | **50 368 500** |

Solde bancaire d'ouverture : **17 882 500 FCFA** (compte 5210000).

Factures clients non réglées reprises (à lettrer ensuite) : CBM FA-2026-131 1 770 000, CAK FA-2026-140 2 360 000, CMA FA-2026-152 5 900 000, CDX FA-2025-077 3 540 000, CBS FA-2025-102 1 416 000.  

Factures fournisseurs non réglées reprises : FCG FA-FCG-0198 3 068 000, FPL FA-FPL-0511 1 180 000.

## 4. Opérations de janvier à mars 2027 (à saisir à la main : étapes 5 à 9)

Montants en FCFA entiers. TVA 18 %. La colonne « Pièce » est la référence à saisir dans « Référence pièce » ; « Doc » renvoie au fichier de `pieces/` à joindre. Répartition conseillée : le **stagiaire** saisit l'opération 1 (elle reste en brouillard), l'**assistant** saisit janvier (étape 5), le chef de mission valide.

| N° | Date | Jnl | Libellé | Pièce | Montant | Doc |
|---|---|---|---|---|---|---|
| 1 | 03/01/2027 | AC | Achat de ciment, Cimenterie du Golfe | FA-FCG-0215 | 4 956 000 | 01-facture-fa-fcg-0215.pdf |
| 2 | 05/01/2027 | VT | Vente de matériaux, Quincaillerie Bénin Matériaux | F-2027-001 | 4 130 000 | 02-facture-f-2027-001.pdf |
| 3 | 05/01/2027 | BQ | Loyer de janvier 2027, SCI du bailleur de Ganhi | QUIT-0127 | 600 000 | 03-recu-quit-0127.jpg |
| 4 | 06/01/2027 | BQ | Paiement de la TVA due de décembre 2026 | TVA-1226 | 410 000 |  |
| 5 | 07/01/2027 | AC | Achat de fer à béton, Fer et Acier du Bénin | FA-FFA-1042 | 3 304 000 | 04-facture-fa-ffa-1042.pdf |
| 6 | 08/01/2027 | BQ | Prime d'assurance multirisque 15 mois (01/01/2027 au 31/03/2028) | ASS-2027-044 | 1 500 000 |  |
| 7 | 10/01/2027 | VT | Vente de matériaux, Entreprise ZOUNON | F-2027-002 | 1 475 000 |  |
| 8 | 12/01/2027 | BQ | Règlement CBM, facture FA-2026-131 | VIR-0112 | 1 770 000 |  |
| 9 | 14/01/2027 | BQ | Règlement Mairie d'Abomey-Calavi, facture FA-2026-152 (AIB et TVA retenue) | VIR-0114 | 5 900 000 | 05-avis-vir-0114.pdf |
| 10 | 15/01/2027 | AC | Facture d'électricité de décembre 2026 | FA-EN-0127 | 212 400 | 06-facture-fa-en-0127.jpg |
| 11 | 15/01/2027 | BQ | Paiement CNSS et IRPP de décembre 2026 | VIR-0115 | 270 500 |  |
| 12 | 16/01/2027 | AC | Facture téléphone et internet de décembre 2026 | FA-TEL-0127 | 112 100 | 07-facture-fa-tel-0127.pdf |
| 13 | 18/01/2027 | BQ | Règlement partiel CAK, facture FA-2026-140 | VIR-0118 | 1 000 000 |  |
| 14 | 20/01/2027 | BQ | Paiement FCG, facture FA-FCG-0198 | VIR-0120 | 3 068 000 |  |
| 15 | 22/01/2027 | AC | Achat de peintures, Peintures du Littoral | FA-FPL-0612 | 755 200 |  |
| 16 | 25/01/2027 | BQ | Règlement CZO, facture F-2027-002 | VIR-0125 | 1 475 000 |  |
| 17 | 28/01/2027 | BQ | Paiement FFA, facture FA-FFA-1042 | VIR-0128 | 3 304 000 |  |
| 18 | 28/01/2027 | BQ | Règlement de la facture d'électricité FA-EN-0127 par chèque n° 0004512 | CHQ-4512 | 212 400 |  |
| 19 | 31/01/2027 | PA | Salaires janvier 2027 | PAIE-0127 | 1 327 100 | 08-paie-paie-0127.jpg |
| 20 | 31/01/2027 | BQ | Paiement des salaires de janvier 2027 | VIR-0131 | 1 056 600 |  |
| 21 | 31/01/2027 | BQ | Frais bancaires janvier 2027 | AD-0127 | 27 500 | 09-avis-ad-0127.jpg |
| 22 | 02/02/2027 | VT | Vente de matériaux, Quincaillerie Bénin Matériaux | F-2027-003 | 3 422 000 |  |
| 23 | 04/02/2027 | AC | Achat de ciment, Cimenterie du Golfe | FA-FCG-0243 | 4 248 000 |  |
| 24 | 05/02/2027 | BQ | Loyer de février 2027, SCI du bailleur de Ganhi | QUIT-0227 | 600 000 |  |
| 25 | 09/02/2027 | VT | Vente de matériaux, Akpakpa Bâtiment SA | F-2027-004 | 4 838 000 |  |
| 26 | 10/02/2027 | BQ | Règlement CBM, facture F-2027-001 | VIR-0210 | 4 130 000 |  |
| 27 | 12/02/2027 | AC | Achat de marchandises importées, 3 000 EUR (Euro Import SAS) | FACT-EU-3381 | 1 967 871 | 10-facture-fact-eu-3381.pdf |
| 28 | 17/02/2027 | BQ | Paiement FPL, facture FA-FPL-0511 | VIR-0217 | 1 180 000 |  |
| 29 | 18/02/2027 | AC | Achat d'outillage, 2 000 USD (Global Tools Inc.) | INV-GT-5520 | 1 225 000 | 11-facture-inv-gt-5520.pdf |
| 30 | 20/02/2027 | AC | Acquisition d'un véhicule utilitaire, Auto Import Cotonou | FA-AIC-0088 | 14 160 000 | 12-facture-fa-aic-0088.pdf |
| 31 | 25/02/2027 | BQ | Paiement du véhicule, Auto Import Cotonou | VIR-0225 | 14 160 000 |  |
| 32 | 28/02/2027 | PA | Salaires février 2027 | PAIE-0227 | 1 327 100 |  |
| 33 | 28/02/2027 | BQ | Paiement des salaires de février 2027 | VIR-0228 | 1 056 600 |  |
| 34 | 28/02/2027 | BQ | Frais bancaires février 2027 | AD-0227 | 27 500 |  |
| 35 | 03/03/2027 | VT | Vente de matériaux, Mairie d'Abomey-Calavi (marché public) | F-2027-005 | 7 080 000 |  |
| 36 | 05/03/2027 | AC | Achat de fer à béton, Fer et Acier du Bénin | FA-FFA-1107 | 3 776 000 |  |
| 37 | 05/03/2027 | BQ | Loyer de mars 2027, SCI du bailleur de Ganhi | QUIT-0327 | 600 000 |  |
| 38 | 10/03/2027 | VT | Vente de matériaux, Quincaillerie Bénin Matériaux | F-2027-006 | 2 124 000 |  |
| 39 | 12/03/2027 | BQ | Règlement CAK, facture F-2027-004 | VIR-0312 | 4 838 000 |  |
| 40 | 15/03/2027 | BQ | Paiement CNSS et IRPP de janvier et février 2027 | VIR-0315 | 541 000 |  |
| 41 | 20/03/2027 | BQ | Paiement FCG, facture FA-FCG-0215 | VIR-0320 | 4 956 000 |  |
| 42 | 25/03/2027 | BQ | Cession du mobilier de bureau (vente au comptant) (module Inventaire) | CES-0327 | 800 000 |  |
| 43 | 31/03/2027 | PA | Salaires mars 2027 | PAIE-0327 | 1 327 100 |  |
| 44 | 31/03/2027 | BQ | Paiement des salaires de mars 2027 | VIR-0331 | 1 056 600 |  |
| 45 | 31/03/2027 | BQ | Frais bancaires mars 2027 | AD-0327 | 27 500 |  |

### Détail des écritures

**1. 03/01/2027 : AC : Achat de ciment, Cimenterie du Golfe** (pièce `FA-FCG-0215`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6011000 Achats de marchandises dans la Région |  | 4 200 000 |  |
| 4452000 TVA récupérable sur achats |  | 756 000 |  |
| 4011000 Fournisseurs | FCG |  | 4 956 000 |

**2. 05/01/2027 : VT : Vente de matériaux, Quincaillerie Bénin Matériaux** (pièce `F-2027-001`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4111000 Clients | CBM | 4 130 000 |  |
| 7011000 Ventes de marchandises dans la Région |  |  | 3 500 000 |
| 4431000 TVA facturée sur ventes |  |  | 630 000 |

**3. 05/01/2027 : BQ : Loyer de janvier 2027, SCI du bailleur de Ganhi** (pièce `QUIT-0127`)
  
_Loyer sans TVA, payé par virement._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6222000 Locations de bâtiments |  | 600 000 |  |
| 5210000 Banques locales |  |  | 600 000 |

**4. 06/01/2027 : BQ : Paiement de la TVA due de décembre 2026** (pièce `TVA-1226`)
  
_Solde la dette reprise dans les à-nouveaux._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4441000 État, TVA due |  | 410 000 |  |
| 5210000 Banques locales |  |  | 410 000 |

**5. 07/01/2027 : AC : Achat de fer à béton, Fer et Acier du Bénin** (pièce `FA-FFA-1042`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6011000 Achats de marchandises dans la Région |  | 2 800 000 |  |
| 4452000 TVA récupérable sur achats |  | 504 000 |  |
| 4011000 Fournisseurs | FFA |  | 3 304 000 |

**6. 08/01/2027 : BQ : Prime d'assurance multirisque 15 mois (01/01/2027 au 31/03/2028)** (pièce `ASS-2027-044`)
  
_Sert aux régularisations : charge constatée d'avance en fin d'exercice (voir « Données d'inventaire »)._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6251000 Assurances multirisques |  | 1 500 000 |  |
| 5210000 Banques locales |  |  | 1 500 000 |

**7. 10/01/2027 : VT : Vente de matériaux, Entreprise ZOUNON** (pièce `F-2027-002`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4111000 Clients | CZO | 1 475 000 |  |
| 7011000 Ventes de marchandises dans la Région |  |  | 1 250 000 |
| 4431000 TVA facturée sur ventes |  |  | 225 000 |

**8. 12/01/2027 : BQ : Règlement CBM, facture FA-2026-131** (pièce `VIR-0112`)
  
_Règle une facture reprise des à-nouveaux (lettrage)._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 5210000 Banques locales |  | 1 770 000 |  |
| 4111000 Clients | CBM |  | 1 770 000 |

**9. 14/01/2027 : BQ : Règlement Mairie d'Abomey-Calavi, facture FA-2026-152 (AIB et TVA retenue)** (pièce `VIR-0114`)
  
_Facture 5 900 000 TTC = banque 4 950 000 + AIB retenu 1 % du HT (50 000) + TVA retenue à la source (900 000). Cas « règlement + retenues = facture »._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 5210000 Banques locales |  | 4 950 000 |  |
| 4478000 Autres impôts et contributions (AIB) |  | 50 000 |  |
| 4452000 TVA récupérable sur achats |  | 900 000 |  |
| 4111000 Clients | CMA |  | 5 900 000 |

**10. 15/01/2027 : AC : Facture d'électricité de décembre 2026** (pièce `FA-EN-0127`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6052000 Fournitures non stockables : électricité |  | 180 000 |  |
| 4452000 TVA récupérable sur achats |  | 32 400 |  |
| 4011000 Fournisseurs | FEN |  | 212 400 |

**11. 15/01/2027 : BQ : Paiement CNSS et IRPP de décembre 2026** (pièce `VIR-0115`)
  
_Solde les dettes sociales reprises dans les à-nouveaux._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4311000 Sécurité sociale (CNSS) |  | 218 500 |  |
| 4472000 Impôts sur salaires (IRPP) |  | 52 000 |  |
| 5210000 Banques locales |  |  | 270 500 |

**12. 16/01/2027 : AC : Facture téléphone et internet de décembre 2026** (pièce `FA-TEL-0127`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6281000 Frais de téléphone |  | 95 000 |  |
| 4452000 TVA récupérable sur achats |  | 17 100 |  |
| 4011000 Fournisseurs | FTL |  | 112 100 |

**13. 18/01/2027 : BQ : Règlement partiel CAK, facture FA-2026-140** (pièce `VIR-0118`)
  
_Règlement partiel : lettrage partiel (solde 1 360 000 restant)._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 5210000 Banques locales |  | 1 000 000 |  |
| 4111000 Clients | CAK |  | 1 000 000 |

**14. 20/01/2027 : BQ : Paiement FCG, facture FA-FCG-0198** (pièce `VIR-0120`)
  
_Règle une facture reprise des à-nouveaux._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4011000 Fournisseurs | FCG | 3 068 000 |  |
| 5210000 Banques locales |  |  | 3 068 000 |

**15. 22/01/2027 : AC : Achat de peintures, Peintures du Littoral** (pièce `FA-FPL-0612`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6011000 Achats de marchandises dans la Région |  | 640 000 |  |
| 4452000 TVA récupérable sur achats |  | 115 200 |  |
| 4011000 Fournisseurs | FPL |  | 755 200 |

**16. 25/01/2027 : BQ : Règlement CZO, facture F-2027-002** (pièce `VIR-0125`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 5210000 Banques locales |  | 1 475 000 |  |
| 4111000 Clients | CZO |  | 1 475 000 |

**17. 28/01/2027 : BQ : Paiement FFA, facture FA-FFA-1042** (pièce `VIR-0128`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4011000 Fournisseurs | FFA | 3 304 000 |  |
| 5210000 Banques locales |  |  | 3 304 000 |

**18. 28/01/2027 : BQ : Règlement de la facture d'électricité FA-EN-0127 par chèque n° 0004512** (pièce `CHQ-4512`)
  
_Chèque émis fin janvier et non encore débité : écriture sans ligne de relevé (écart de rapprochement)._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4011000 Fournisseurs | FEN | 212 400 |  |
| 5210000 Banques locales |  |  | 212 400 |

**19. 31/01/2027 : PA : Salaires janvier 2027** (pièce `PAIE-0127`)
  
_Brut 1 150 000 ; CNSS salariale 3,6 % = 41 400 ; patronale 15,4 % = 177 100 ; IRPP 52 000._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6611000 Appointements, salaires et commissions |  | 1 150 000 |  |
| 6641000 Charges sociales sur rémunération du personnel national |  | 177 100 |  |
| 4472000 Impôts sur salaires (IRPP) |  |  | 52 000 |
| 4311000 Sécurité sociale (CNSS) |  |  | 218 500 |
| 4220000 Personnel, rémunérations dues | PE1 |  | 409 800 |
| 4220000 Personnel, rémunérations dues | PE2 |  | 349 320 |
| 4220000 Personnel, rémunérations dues | PE3 |  | 297 480 |

**20. 31/01/2027 : BQ : Paiement des salaires de janvier 2027** (pièce `VIR-0131`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4220000 Personnel, rémunérations dues | PE1 | 409 800 |  |
| 4220000 Personnel, rémunérations dues | PE2 | 349 320 |  |
| 4220000 Personnel, rémunérations dues | PE3 | 297 480 |  |
| 5210000 Banques locales |  |  | 1 056 600 |

**21. 31/01/2027 : BQ : Frais bancaires janvier 2027** (pièce `AD-0127`)
  
_Modèle FRAIS_BQ_TAF (frais + TAF 10 %)._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6311000 Frais bancaires |  | 25 000 |  |
| 6312000 TAF sur frais bancaires |  | 2 500 |  |
| 5210000 Banques locales |  |  | 27 500 |

**22. 02/02/2027 : VT : Vente de matériaux, Quincaillerie Bénin Matériaux** (pièce `F-2027-003`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4111000 Clients | CBM | 3 422 000 |  |
| 7011000 Ventes de marchandises dans la Région |  |  | 2 900 000 |
| 4431000 TVA facturée sur ventes |  |  | 522 000 |

**23. 04/02/2027 : AC : Achat de ciment, Cimenterie du Golfe** (pièce `FA-FCG-0243`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6011000 Achats de marchandises dans la Région |  | 3 600 000 |  |
| 4452000 TVA récupérable sur achats |  | 648 000 |  |
| 4011000 Fournisseurs | FCG |  | 4 248 000 |

**24. 05/02/2027 : BQ : Loyer de février 2027, SCI du bailleur de Ganhi** (pièce `QUIT-0227`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6222000 Locations de bâtiments |  | 600 000 |  |
| 5210000 Banques locales |  |  | 600 000 |

**25. 09/02/2027 : VT : Vente de matériaux, Akpakpa Bâtiment SA** (pièce `F-2027-004`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4111000 Clients | CAK | 4 838 000 |  |
| 7011000 Ventes de marchandises dans la Région |  |  | 4 100 000 |
| 4431000 TVA facturée sur ventes |  |  | 738 000 |

**26. 10/02/2027 : BQ : Règlement CBM, facture F-2027-001** (pièce `VIR-0210`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 5210000 Banques locales |  | 4 130 000 |  |
| 4111000 Clients | CBM |  | 4 130 000 |

**27. 12/02/2027 : AC : Achat de marchandises importées, 3 000 EUR (Euro Import SAS)** (pièce `FACT-EU-3381`)
  
Devise : 3 000.00 EUR au cours de 655.957
  
_Écriture en devise : 3 000 EUR × 655,957 = 1 967 871 FCFA (parité fixe). Dette laissée ouverte._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6012000 Achats de marchandises hors Région |  | 1 967 871 |  |
| 4011000 Fournisseurs | FEU |  | 1 967 871 |

**28. 17/02/2027 : BQ : Paiement FPL, facture FA-FPL-0511** (pièce `VIR-0217`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4011000 Fournisseurs | FPL | 1 180 000 |  |
| 5210000 Banques locales |  |  | 1 180 000 |

**29. 18/02/2027 : AC : Achat d'outillage, 2 000 USD (Global Tools Inc.)** (pièce `INV-GT-5520`)
  
Devise : 2 000.00 USD au cours de 612.500
  
_Écriture en dollar : 2 000 USD × 612,500 = 1 225 000 FCFA. Dette laissée ouverte (écart de conversion en fin d'exercice)._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6056000 Achats de petit matériel et outillage |  | 1 225 000 |  |
| 4011000 Fournisseurs | FUS |  | 1 225 000 |

**30. 20/02/2027 : AC : Acquisition d'un véhicule utilitaire, Auto Import Cotonou** (pièce `FA-AIC-0088`)
  
_Immobilisation : à enregistrer ensuite dans Inventaire > Immobilisations (mise en service 20/02/2027, linéaire 5 ans)._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 2451000 Matériel automobile |  | 12 000 000 |  |
| 4451000 TVA récupérable sur immobilisations |  | 2 160 000 |  |
| 4011000 Fournisseurs | FAI |  | 14 160 000 |

**31. 25/02/2027 : BQ : Paiement du véhicule, Auto Import Cotonou** (pièce `VIR-0225`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4011000 Fournisseurs | FAI | 14 160 000 |  |
| 5210000 Banques locales |  |  | 14 160 000 |

**32. 28/02/2027 : PA : Salaires février 2027** (pièce `PAIE-0227`)
  
_Brut 1 150 000 ; CNSS salariale 3,6 % = 41 400 ; patronale 15,4 % = 177 100 ; IRPP 52 000._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6611000 Appointements, salaires et commissions |  | 1 150 000 |  |
| 6641000 Charges sociales sur rémunération du personnel national |  | 177 100 |  |
| 4472000 Impôts sur salaires (IRPP) |  |  | 52 000 |
| 4311000 Sécurité sociale (CNSS) |  |  | 218 500 |
| 4220000 Personnel, rémunérations dues | PE1 |  | 409 800 |
| 4220000 Personnel, rémunérations dues | PE2 |  | 349 320 |
| 4220000 Personnel, rémunérations dues | PE3 |  | 297 480 |

**33. 28/02/2027 : BQ : Paiement des salaires de février 2027** (pièce `VIR-0228`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4220000 Personnel, rémunérations dues | PE1 | 409 800 |  |
| 4220000 Personnel, rémunérations dues | PE2 | 349 320 |  |
| 4220000 Personnel, rémunérations dues | PE3 | 297 480 |  |
| 5210000 Banques locales |  |  | 1 056 600 |

**34. 28/02/2027 : BQ : Frais bancaires février 2027** (pièce `AD-0227`)
  
_Modèle FRAIS_BQ_TAF (frais + TAF 10 %)._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6311000 Frais bancaires |  | 25 000 |  |
| 6312000 TAF sur frais bancaires |  | 2 500 |  |
| 5210000 Banques locales |  |  | 27 500 |

**35. 03/03/2027 : VT : Vente de matériaux, Mairie d'Abomey-Calavi (marché public)** (pièce `F-2027-005`)
  
_Client public : à son règlement, AIB et TVA retenue (même cas que l'opération du 14/01)._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4111000 Clients | CMA | 7 080 000 |  |
| 7011000 Ventes de marchandises dans la Région |  |  | 6 000 000 |
| 4431000 TVA facturée sur ventes |  |  | 1 080 000 |

**36. 05/03/2027 : AC : Achat de fer à béton, Fer et Acier du Bénin** (pièce `FA-FFA-1107`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6011000 Achats de marchandises dans la Région |  | 3 200 000 |  |
| 4452000 TVA récupérable sur achats |  | 576 000 |  |
| 4011000 Fournisseurs | FFA |  | 3 776 000 |

**37. 05/03/2027 : BQ : Loyer de mars 2027, SCI du bailleur de Ganhi** (pièce `QUIT-0327`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6222000 Locations de bâtiments |  | 600 000 |  |
| 5210000 Banques locales |  |  | 600 000 |

**38. 10/03/2027 : VT : Vente de matériaux, Quincaillerie Bénin Matériaux** (pièce `F-2027-006`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4111000 Clients | CBM | 2 124 000 |  |
| 7011000 Ventes de marchandises dans la Région |  |  | 1 800 000 |
| 4431000 TVA facturée sur ventes |  |  | 324 000 |

**39. 12/03/2027 : BQ : Règlement CAK, facture F-2027-004** (pièce `VIR-0312`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 5210000 Banques locales |  | 4 838 000 |  |
| 4111000 Clients | CAK |  | 4 838 000 |

**40. 15/03/2027 : BQ : Paiement CNSS et IRPP de janvier et février 2027** (pièce `VIR-0315`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4311000 Sécurité sociale (CNSS) |  | 437 000 |  |
| 4472000 Impôts sur salaires (IRPP) |  | 104 000 |  |
| 5210000 Banques locales |  |  | 541 000 |

**41. 20/03/2027 : BQ : Paiement FCG, facture FA-FCG-0215** (pièce `VIR-0320`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4011000 Fournisseurs | FCG | 4 956 000 |  |
| 5210000 Banques locales |  |  | 4 956 000 |

**42. 25/03/2027 : BQ : Cession du mobilier de bureau (vente au comptant)** (pièce `CES-0327`)
  
_À faire par Inventaire > Immobilisations > Sortir (prix 800 000, compte de contrepartie 5210000) : le module génère la dotation complémentaire, la sortie de l'immobilisation, la VNC et la plus-value. L'écriture ci-contre n'est qu'indicative : ne pas la saisir à la main._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 5210000 Banques locales |  | 800 000 |  |
| 7011000 Ventes de marchandises dans la Région |  |  | 800 000 |

**43. 31/03/2027 : PA : Salaires mars 2027** (pièce `PAIE-0327`)
  
_Brut 1 150 000 ; CNSS salariale 3,6 % = 41 400 ; patronale 15,4 % = 177 100 ; IRPP 52 000._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6611000 Appointements, salaires et commissions |  | 1 150 000 |  |
| 6641000 Charges sociales sur rémunération du personnel national |  | 177 100 |  |
| 4472000 Impôts sur salaires (IRPP) |  |  | 52 000 |
| 4311000 Sécurité sociale (CNSS) |  |  | 218 500 |
| 4220000 Personnel, rémunérations dues | PE1 |  | 409 800 |
| 4220000 Personnel, rémunérations dues | PE2 |  | 349 320 |
| 4220000 Personnel, rémunérations dues | PE3 |  | 297 480 |

**44. 31/03/2027 : BQ : Paiement des salaires de mars 2027** (pièce `VIR-0331`)

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 4220000 Personnel, rémunérations dues | PE1 | 409 800 |  |
| 4220000 Personnel, rémunérations dues | PE2 | 349 320 |  |
| 4220000 Personnel, rémunérations dues | PE3 | 297 480 |  |
| 5210000 Banques locales |  |  | 1 056 600 |

**45. 31/03/2027 : BQ : Frais bancaires mars 2027** (pièce `AD-0327`)
  
_Modèle FRAIS_BQ_TAF (frais + TAF 10 %)._

| Compte | Tiers | Débit | Crédit |
|---|---|---|---|
| 6311000 Frais bancaires |  | 25 000 |  |
| 6312000 TAF sur frais bancaires |  | 2 500 |  |
| 5210000 Banques locales |  |  | 27 500 |

### Cas à tester volontairement (garde-fous, étape 5.3)

- Écriture déséquilibrée : reprendre l'opération 1 et saisir 4 956 000 au crédit du fournisseur mais 4 900 000 en débit au total : refus à la validation.
- Montant négatif : saisir « -100 000 » dans un débit : refusé (un montant est toujours positif ; débit **ou** crédit).
- Date hors exercice : écriture datée du 15/12/2026 dans l'exercice 2027 : refusée.
- Suppression d'un compte mouvementé : refusée (étape 3.3).
- Saisie dans un mois verrouillé (étape 9) : refusée.

## 5. Relevé bancaire de janvier (fichier `releve-ecobank-janvier.csv`)

Format : UTF-8, séparateur `;`, en-tête sur la première ligne, dates `jj/mm/aaaa`, montants à la française (espaces, virgule). Gabarit à créer à la première importation (banque Ecobank) : **date = colonne 1, date de valeur = 2, libellé = 3, débit = 4, crédit = 5, référence = 6**, séparateur « ; », virgule décimale. Le « Débit » du relevé est une **sortie** d'argent.

| Date | Valeur | Libellé | Débit | Crédit | Réf. | Attendu |
|---|---|---|---|---|---|---|
| 05/01 | 05/01 | VIR PERMANENT LOYER JANV 2027 SCI GANHI | 600 000 |  | QUIT-0127 | écriture n° 3 |
| 06/01 | 06/01 | PAIEMENT IMPOT TVA 12/2026 DGI | 410 000 |  | TVA-1226 | écriture n° 4 |
| 08/01 | 08/01 | PRELEVEMENT PRIME ASSURANCE 2027 | 1 500 000 |  | ASS-2027-044 | écriture n° 6 |
| 12/01 | 12/01 | VIR RECU QUINCAILLERIE BENIN MATERIAUX |  | 1 770 000 | VIR-0112 | écriture n° 8 |
| 14/01 | 14/01 | VIR RECU MAIRIE ABOMEY-CALAVI SOLDE FACTURE |  | 4 950 000 | VIR-0114 | écriture n° 9 |
| 15/01 | 15/01 | PAIEMENT CNSS + IRPP 12/2026 | 270 500 |  | VIR-0115 | écriture n° 11 |
| 18/01 | 18/01 | VIR RECU AKPAKPA BATIMENT ACOMPTE |  | 1 000 000 | VIR-0118 | écriture n° 13 |
| 20/01 | 20/01 | VIR EMIS CIMENTERIE DU GOLFE | 3 068 000 |  | VIR-0120 | écriture n° 14 |
| 22/01 | 22/01 | VIR RECU REF 99812 DONNEUR NON IDENTIFIE |  | 120 000 | 99812 | aucune écriture : à identifier (acompte client ?) |
| 25/01 | 27/01 | VIR RECU ZOUNON ET FILS |  | 1 475 000 | VIR-0125 | écriture n° 16 |
| 26/01 | 26/01 | VERSEMENT ESPECES GUICHET |  | 250 000 | VE-0126 | aucune écriture : à justifier |
| 28/01 | 29/01 | VIR EMIS FER ET ACIER DU BENIN | 3 304 000 |  | VIR-0128 | écriture n° 17 |
| 31/01 | 31/01 | FRAIS TENUE DE COMPTE JANV 2027 + TAF | 27 500 |  | AD-0127 | écriture n° 21 |
| 31/01 | 31/01 | COMMISSION MOUVEMENT DE COMPTE JANV | 15 000 |  | CMC-0127 | frais non comptabilisés : créer l'écriture depuis la ligne |
| 31/01 | 31/01 | VIR SALAIRES JANVIER 2027 | 1 056 600 |  | VIR-0131 | écriture n° 20 |

Solde comptable de la banque au 31/01/2027 : **16 628 500** (le chèque n° 0004512 de 212 400 y est déjà déduit) ; solde du relevé : **17 195 900**. Écart attendu **567 400** = 120 000 + 250 000 de crédits à identifier − 15 000 de commission non comptabilisée + 212 400 de chèque en circulation. Après avoir créé l'écriture de la commission (15 000 TTC, à ventiler frais + TAF si l'on veut), l'état de rapprochement doit expliquer le reste par les deux virements/versements à identifier et le chèque en circulation.

## 6. Pièces justificatives (dossier `pieces/`)

| Fichier | Opération | Contenu |
|---|---|---|
| `01-facture-fa-fcg-0215.pdf` | 1 (03/01) | FACTURE FA-FCG-0215 |
| `02-facture-f-2027-001.pdf` | 2 (05/01) | FACTURE F-2027-001 |
| `03-recu-quit-0127.jpg` | 3 (05/01) | REÇU DE LOYER JANVIER 2027 |
| `04-facture-fa-ffa-1042.pdf` | 5 (07/01) | FACTURE FA-FFA-1042 |
| `05-avis-vir-0114.pdf` | 9 (14/01) | Bordereau de retenue à la source (AIB et TVA) |
| `06-facture-fa-en-0127.jpg` | 10 (15/01) | FACTURE D'ÉLECTRICITÉ N° 0127 |
| `07-facture-fa-tel-0127.pdf` | 12 (16/01) | FACTURE TÉLÉPHONE N° 0127 |
| `08-paie-paie-0127.jpg` | 19 (31/01) | Récapitulatif de paie janvier 2027 |
| `09-avis-ad-0127.jpg` | 21 (31/01) | Avis de débit : frais de tenue de compte |
| `10-facture-fact-eu-3381.pdf` | 27 (12/02) | INVOICE 2027-3381 |
| `11-facture-inv-gt-5520.pdf` | 29 (18/02) | COMMERCIAL INVOICE GT-5520 |
| `12-facture-fa-aic-0088.pdf` | 30 (20/02) | FACTURE FA-AIC-0088 : véhicule utilitaire |

À joindre depuis l'ordinateur (Pièces > Déposer) ; pour tester la capture mobile, photographier un des documents affichés à l'écran ou imprimés.

## 7. Données de fin d'exercice (étape 10, exercice 2027)

Les travaux d'inventaire se font à la date du **31/12/2027** : la recette ne comporte que le premier trimestre, on suppose qu'il n'y a pas d'autres mouvements significatifs.

### Immobilisations

| Bien | Valeur brute | Mise en service | Méthode | Amort. cumulé au 31/12/2026 | À faire |
|---|---|---|---|---|---|
| Matériel de bureau (2441000) | 2 400 000 | 01/01/2025 | linéaire 5 ans | 960 000 | reprise de l'existant |
| Mobilier de bureau (2444000) | 1 800 000 | 01/01/2021 | linéaire 10 ans | 1 080 000 | reprise, puis cession le 25/03/2027 pour 800 000 |
| Matériel automobile (2451000) | 8 500 000 | 01/01/2025 | linéaire 5 ans | 3 400 000 | reprise de l'existant |
| Véhicule utilitaire (op. 30, 2451000) | 12 000 000 | 20/02/2027 | linéaire 5 ans | 0 | acquisition 2027 : dotation prorata temporis |

Attendus (base 360 jours, D-011 ; les écarts d'un franc dus aux arrondis sont à signaler comme anomalie mineure) : dotation 2027 du véhicule = 12 000 000 × 20 % × 311/360 = **2 073 333** ; cession du mobilier le 25/03/2027 : dotation complémentaire 1 800 000 × 10 % × 85/360 = **42 500**, valeur nette comptable **677 500**, plus-value **122 500**.

### Stocks

Stock initial (à-nouveaux, 3111000) : 4 800 000. **Stock final au 31/12/2027 : 6 120 000** (inventaire physique) ; variation de stock attendue : **+1 320 000** (produit, compte 6031).

### Provisions pour créances douteuses (depuis la balance âgée)

| Client | Solde (TTC) | Taux de provision | Dotation attendue |
|---|---|---|---|
| CDX Entreprise DOSSOU BTP | 3 540 000 | 50 % | 1 770 000 |
| CBS Établissements BOSSOU | 1 416 000 | 75 % | 1 062 000 |

Total attendu : **2 832 000**. Les deux factures datent de 2025 : elles apparaissent dans la tranche la plus ancienne de la balance âgée.

### Régularisations

| Type | Libellé | Montant | Détail |
|---|---|---|---|
| Charge à payer | Électricité de décembre 2027, facture non reçue | 260 000 | au 31/12/2027, charge 6052000, extourne attendue au 01/01/2028 |
| Charge constatée d'avance | Prime d'assurance 15 mois (op. 6) | 300 000 | 1 500 000 × 3/15 (janvier à mars 2028 restant à courir), extourne attendue au 01/01/2028 |

### Écart de conversion

Dette en dollars envers Global Tools Inc. : 2 000 USD comptabilisés à 612,500 (1 225 000 FCFA) ; **cours de clôture au 31/12/2027 : 574,300** → dette réévaluée 1 148 600 ; écart de conversion attendu **76 400 FCFA** (gain latent sur dette : compte 4792, pas de provision). La dette en euros (3 000 EUR) ne génère aucun écart : parité fixe 655,957.

## 8. Contrôles attendus après saisie complète du premier trimestre

Toutes les écritures validées (opérations 1 à 45 hors l'opération 42, la cession, traitée par le module Inventaire) et les à-nouveaux validés. La balance générale au 31/03/2027 doit donner :

| Compte | Intitulé | Solde débiteur | Solde créditeur |
|---|---|---|---|
| 1010000 | Capital social |  | 20 000 000 |
| 1181000 | Réserves facultatives |  | 4 000 000 |
| 1210000 | Report à nouveau créditeur |  | 3 250 000 |
| 1301000 | Résultat en instance d'affectation : bénéfice |  | 6 750 000 |
| 1620000 | Emprunts auprès des établissements de crédit |  | 6 000 000 |
| 2441000 | Matériel de bureau | 2 400 000 |  |
| 2444000 | Mobilier de bureau | 1 800 000 |  |
| 2451000 | Matériel automobile | 20 500 000 |  |
| 2844000 | Amortissements du matériel et mobilier |  | 2 040 000 |
| 2845000 | Amortissements du matériel de transport |  | 3 400 000 |
| 3111000 | Marchandises A1 | 4 800 000 |  |
| 4011000 | Fournisseurs |  | 12 084 171 |
| 4111000 | Clients | 18 942 000 |  |
| 4311000 | Sécurité sociale (CNSS) |  | 218 500 |
| 4431000 | TVA facturée sur ventes |  | 3 519 000 |
| 4451000 | TVA récupérable sur immobilisations | 2 160 000 |  |
| 4452000 | TVA récupérable sur achats | 3 548 700 |  |
| 4472000 | Impôts sur salaires (IRPP) |  | 52 000 |
| 4478000 | Autres impôts et contributions (AIB) | 50 000 |  |
| 5210000 | Banques locales | 1 391 300 |  |
| 6011000 | Achats de marchandises dans la Région | 14 440 000 |  |
| 6012000 | Achats de marchandises hors Région | 1 967 871 |  |
| 6052000 | Fournitures non stockables : électricité | 180 000 |  |
| 6056000 | Achats de petit matériel et outillage | 1 225 000 |  |
| 6222000 | Locations de bâtiments | 1 800 000 |  |
| 6251000 | Assurances multirisques | 1 500 000 |  |
| 6281000 | Frais de téléphone | 95 000 |  |
| 6311000 | Frais bancaires | 75 000 |  |
| 6312000 | TAF sur frais bancaires | 7 500 |  |
| 6611000 | Appointements, salaires et commissions | 3 450 000 |  |
| 6641000 | Charges sociales sur rémunération du personnel national | 531 300 |  |
| 7011000 | Ventes de marchandises dans la Région |  | 19 550 000 |
| **Total** |  | **80 863 671** | **80 863 671** |

Résultat provisoire du trimestre (produits − charges, hors régularisations) : **-5 721 671 FCFA** (produits 19 550 000, charges 25 271 671). Solde de la banque au 31/03/2027 hors cession : 1 391 300. TVA : facturée 3 519 000, récupérable sur achats 3 548 700 (dont 900 000 de TVA retenue), sur immobilisations 2 160 000.

Les brouillards (opération saisie par le stagiaire, non validée) ne figurent pas dans ces totaux.

