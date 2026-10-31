# SYCEBNL : points à valider par ABC

Généré le 31 oct. 2026 à partir de la base de recette (décisions D-022 à D-027). Le plan et les états viennent de l'acte uniforme OHADA relatif au SYCEBNL (Journal officiel OHADA 2023, partie 4, pages 346-348 et 395-396 pour les états). Le plan de comptes a été relevé sur un site tiers (plan-comptable-ohada.com, 1 130 comptes) et reste à rapprocher du Journal officiel.

**À faire** : un comptable d'ABC confirme chaque ligne ou indique la correction dans la colonne *Avis*. Les sections 1 à 3 touchent la saisie, la section 4 les états financiers, la section 5 le tableau des flux, la section 6 la clôture.

## 1. Sens normal des comptes ambigus

Le sens normal (débit ou crédit) sert aux alertes de solde et à l'affichage. Il est déduit par préfixe ; les comptes ci-dessous sont ceux dont le sens s'écarte de celui de leur classe ou prête à discussion.

| Compte | Intitulé | Sens retenu | Avis |
|---|---|---|---|
| 129 | Report à nouveau des déficits | Débit | |
| 139 | Déficit de l'exercice | Débit | |
| 169 | Fonds affectés à recevoir | Débit | |
| 409 | Fournisseurs débiteurs | Débit | |
| 4098 | Fournisseurs, rabais, remises, ristournes et autres avoirs à obtenir | Débit | |
| 419 | Adhérents, Clients-usagers créditeurs | Crédit | |
| 421 | Personnel, avances et acomptes | Débit | |
| 4287 | Produits à recevoir | Débit | |
| 4387 | Produits à recevoir | Débit | |
| 445 | État, T.V.A. Récupérable | Débit | |
| 4487 | Produits à recevoir | Débit | |
| 4491 | Etat, Subvention à recevoir | Débit | |
| 4692 | Bailleurs -Fonds d'administration à recevoir | Débit | |
| 4693 | Etat -Fonds d'administration à recevoir | Débit | |
| 4694 | Autres tiers ou organismes de financement assimilés-Fonds d'administration à recevoir | Débit | |
| 4712 | Créditeurs divers | Crédit | |
| 4713 | Créditeurs, dons en nature courants non consommés | Crédit | |
| 477 | Produits constatés d’avance | Crédit | |
| 479 | Écarts de conversion — passif | Crédit | |
| 481 | Fournisseurs d’investissements | Crédit | |
| 485 | Créances sur cessions d’immobilisations | Débit | |
| 486 | Dettes et créances des legs et dons d’immobilisations | Crédit | |
| 488 | Autres créances hors activités ordinaires (H.A.O.) | Débit | |
| 4881 | Créditeurs, dons en nature HAO non consommés | Crédit | |
| 6019 | Rabais, Remises et Ristournes obtenus (non ventilés) | Crédit | |
| 6029 | Rabais, Remises et Ristournes obtenus (non ventilés) | Crédit | |
| 6049 | Rabais, Remises et Ristournes obtenus (non ventilés) | Crédit | |
| 6059 | Rabais, Remises et Ristournes obtenus (non ventilés) | Crédit | |
| 6089 | Rabais, Remises et Ristournes obtenus (non ventilés) | Crédit | |
| 619 | Rabais, Remises et Ristournes Obtenus (non ventilés) | Crédit | |
| 649 | Dégrèvements et annulations des impôts et taxes | Crédit | |
| 669 | Dégrèvements et annulations des charges sociales | Crédit | |
| 81 | VALEURS COMPTABLES DES CESSIONS D’IMMOBILISATIONS | Débit | |
| 82 | PRODUITS DES CESSIONS D’IMMOBILISATIONS | Crédit | |
| 83 | CHARGES HORS ACTIVITES ORDINAIRES | Débit | |
| 84 | REVENUS HORS ACTIVITES ORDINAIRES | Crédit | |
| 85 | DOTATIONS HORS ACTIVITES ORDINAIRES | Débit | |
| 86 | REPRISES D'AMORTISSEMENTS, PROVISIONS ET DEPRECIATIONS HAO. | Crédit | |
| 87 | VARIATIONS DE STOCKS DE DONS EN NATURE HAO | Débit | |
| 88 | SUBVENTIONS D'ÉQUILIBRE | Crédit | |

## 2. Modèles d'écritures SYCEBNL (19)

Aucune TVA : les associations ne sont en général pas assujetties. Lecture : *Saisie* = montant saisi ; *Solde* = montant qui équilibre l'écriture ; *Tiers* = code tiers demandé.

### Journal Achats

**`AS_ACHAT`** — Achat de biens et services liés à l'activité

Achat sans TVA : charge et fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6011 | Achats de biens et services liés à l’activité dans l'Etat partie | Débit | Saisie |  | |
| 2 | 4011 | Fournisseurs | Crédit | Solde | oui | |

**`AS_ELECTRICITE`** — Facture d'électricité

Électricité sans TVA : charge et fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6052 | Fournitures non stockables - Électricité | Débit | Saisie |  | |
| 2 | 4011 | Fournisseurs | Crédit | Solde | oui | |

**`AS_LOYER`** — Loyer

Loyer sans TVA : charge et fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6222 | Locations de bâtiments | Débit | Saisie |  | |
| 2 | 4011 | Fournisseurs | Crédit | Solde | oui | |

**`AS_TELECOM`** — Téléphone et internet

Téléphone sans TVA : charge et fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6281 | Frais de téléphone | Débit | Saisie |  | |
| 2 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### Journal Ventes

**`AS_COTIS_APPEL`** — Appel de cotisations aux adhérents

Cotisation due : adhérent débiteur, cotisation en produit

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 701 | Cotisations des adhérents | Crédit | Saisie |  | |
| 2 | 411 | Adhérents | Débit | Solde | oui | |

### Journal Banque

**`AS_COTIS_BQ`** — Cotisation encaissée par banque

Encaissement direct d'une cotisation

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 5211 | Banques en monnaie nationale | Débit | Saisie |  | |
| 2 | 701 | Cotisations des adhérents | Crédit | Solde |  | |

**`AS_DON_BQ`** — Don en numéraire reçu par banque

Revenus liés à la générosité : dons

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 5211 | Banques en monnaie nationale | Débit | Saisie |  | |
| 2 | 7041 | Dons | Crédit | Solde |  | |

**`AS_FRAIS_BANCAIRES`** — Frais bancaires

Frais prélevés par la banque

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6318 | Autres frais bancaires | Débit | Saisie |  | |
| 2 | 5211 | Banques en monnaie nationale | Crédit | Solde |  | |

**`AS_PAIEMENT_SALAIRES`** — Paiement des rémunérations par banque

Personnel soldé, banque décaissée

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 422 | Personnel, rémunérations dues | Débit | Saisie | oui | |
| 2 | 5211 | Banques en monnaie nationale | Crédit | Solde |  | |

**`AS_REGL_ADHERENT`** — Règlement d'un adhérent par banque

Cotisation appelée puis réglée : banque et adhérent soldé

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 5211 | Banques en monnaie nationale | Débit | Saisie |  | |
| 2 | 411 | Adhérents | Crédit | Solde | oui | |

**`AS_REGL_FOURN`** — Règlement fournisseur par banque

Fournisseur soldé, banque décaissée

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 4011 | Fournisseurs | Débit | Saisie | oui | |
| 2 | 5211 | Banques en monnaie nationale | Crédit | Solde |  | |

**`AS_SUBV_ETAT`** — Subvention d'exploitation reçue de l'État

Subvention de l'État ou d'une collectivité publique encaissée

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 5211 | Banques en monnaie nationale | Débit | Saisie |  | |
| 2 | 711 | Subventions d'exploitation versées par l’État et les Collectivités publiques | Crédit | Solde |  | |

**`AS_SUBV_ORG`** — Subvention d'exploitation reçue d'un organisme

Subvention d'un organisme national ou international encaissée

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 5211 | Banques en monnaie nationale | Débit | Saisie |  | |
| 2 | 713 | Subventions d’exploitation versées par les organismes nationaux et internationaux | Crédit | Solde |  | |

### Journal Caisse

**`AS_COTIS_CAISSE`** — Cotisation encaissée en espèces

Encaissement direct d'une cotisation en espèces

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 571 | Caisse en monnaie nationale | Débit | Saisie |  | |
| 2 | 701 | Cotisations des adhérents | Crédit | Solde |  | |

**`AS_DON_CAISSE`** — Don en numéraire reçu en espèces

Revenus liés à la générosité : dons

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 571 | Caisse en monnaie nationale | Débit | Saisie |  | |
| 2 | 7041 | Dons | Crédit | Solde |  | |

**`AS_PAIEMENT_CAISSE`** — Paiement fournisseur en espèces

Fournisseur soldé, caisse décaissée

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 4011 | Fournisseurs | Débit | Saisie | oui | |
| 2 | 571 | Caisse en monnaie nationale | Crédit | Solde |  | |

**`AS_VERSEMENT_ESP`** — Versement d'espèces en banque

Banque créditée, caisse déchargée

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 5211 | Banques en monnaie nationale | Débit | Saisie |  | |
| 2 | 571 | Caisse en monnaie nationale | Crédit | Solde |  | |

### Journal Opérations diverses

**`AS_SUBV_A_RECEVOIR`** — Subvention d'exploitation notifiée, à recevoir

Constatation de la subvention avant encaissement

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 4732 | Subventions d'exploitation à recevoir | Débit | Saisie |  | |
| 2 | 713 | Subventions d’exploitation versées par les organismes nationaux et internationaux | Crédit | Solde |  | |

### Journal Paie

**`AS_SALAIRES`** — Rémunérations du personnel (simplifié)

Rémunération brute et net à payer ; retenues sociales et fiscales à ajouter selon le cas

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6611 | Appointements salaires et commissions | Débit | Saisie |  | |
| 2 | 422 | Personnel, rémunérations dues | Crédit | Solde | oui | |

## 3. Plan de comptes : points à contrôler

| Point | Constat | Avis |
|---|---|---|
| Source du plan | Site tiers, 1 130 comptes ; à comparer au Journal officiel OHADA (acte uniforme du 22 décembre 2022). | |
| Comptes de regroupement confondus | Complétés à 7 chiffres, 28, 29, 49, 59 et 68 se confondent avec 280, 290, 490, 590 et 680 : le plus détaillé est conservé. | |
| Classe 9 | Contributions volontaires en nature et comptabilité analytique : non reprises dans le plan de l'entité. Faut-il les gérer ? | |
| Compte 2817 | « Amortissements des indemnités de transfert aux joueurs » figure au plan : faut-il le masquer pour les associations non sportives ? | |

## 4. États financiers : correspondance comptes → postes

Version `SYCEBNL-2024`, d'après les tableaux de correspondance officiels (pages 395 et 396). Les plages sont données par préfixes de comptes.

### Bilan — Actif

| Poste | Libellé | Comptes bruts / montants | Amortissements, dépréciations | Avis |
|---|---|---|---|---|
| AB | Immobilisations incorporelles destinées à la vente (dons et legs) | 201 | 280, 2901 | |
| AC | Immobilisations corporelles et financières destinées à la vente (dons et legs) | 202-205 | 2902 | |
| AE | Brevets, licences, logiciels et droits similaires | 212-214, 2193 | 2812-2814, 2912-2914 | |
| AF | Autres immobilisations incorporelles | 218, 2198 | 2817-2818, 2918-2919 | |
| AG | Avances et acomptes versés sur immobilisations incorporelles | 251 | 2951 | |
| AI | Terrains | 22 | 282, 292 | |
| AJ | Bâtiments | 231-233, 2391-2393, 2396 | 2831-2833, 2931-2933 | |
| AK | Aménagements, agencements et installations | 234-235, 238, 2394-2395, 2398 | 2834-2835, 2838, 2934-2935, 2938-2939 | |
| AL | Matériel, mobilier et actifs biologiques | 240-244, 246-248, 2490-2494, 2496-2499 | 2840-2844, 2846-2849, 2940-2944, 2946-2949 | |
| AM | Matériel de transport | 245, 2495 | 2845, 2945 | |
| AN | Avances et acomptes versés sur immobilisations corporelles | 252 | 2952 | |
| AX | Titres de participation | 26 | 296 | |
| AY | Autres immobilisations financières | 27 | 297 | |
| BA | Actif circulant HAO | 485, 4865 | 498 | |
| BB | Stocks et encours | 31-38 | 39 | |
| BC | Fournisseurs débiteurs | 409 | 490 | |
| BD | Adhérents, clients-usagers | 410-418 | 491 | |
| BE | Autres créances | 42-46 (solde débiteur), 470-477 (solde débiteur) | 492-494, 497 | |
| BU | Titres de placement | 50 | 590 | |
| BV | Valeurs à encaisser | 51 | 591 | |
| BW | Banques, établissements financiers, caisses et assimilés | 52-53 (solde débiteur), 55 (solde débiteur), 57 (solde débiteur) | 592-593, 595 | |
| BY | Écart de conversion-Actif | 478 |  | |

### Bilan — Passif

| Poste | Libellé | Comptes bruts / montants | Amortissements, dépréciations | Avis |
|---|---|---|---|---|
| CA | Dotation non consomptible sans droit de reprise | 101 |  | |
| CB | Dotation non consomptible avec droit de reprise | 102 |  | |
| CC | Droit d'entrée | 103 |  | |
| CD | Dotation consomptible | 104 |  | |
| CE | Écarts de réévaluation | 106 |  | |
| CF | Réserves | 11 |  | |
| CG | Report à nouveau et résultat en instance | 12-13 |  | |
| CI | Subventions d'investissement | 14 |  | |
| CJ | Provisions réglementées | 15 |  | |
| CW | Fonds affectés et provenant de dons et legs d'immobilisations | 16 |  | |
| CX | Fonds reportés | 17 |  | |
| DA | Emprunts et dettes financières | 181-183, 185-186, 188 |  | |
| DB | Dettes de location-acquisition | 187 |  | |
| DC | Provisions pour risques et charges | 19 |  | |
| DF | Dettes circulantes HAO | 481, 484, 4861, 488, 4998 |  | |
| DG | Adhérents, clients-usagers créditeurs | 419 |  | |
| DH | Fournisseurs | 400-408 |  | |
| DI | Autres dettes | 42-46 (solde créditeur), 470-477 (solde créditeur), 4990-4997 (solde créditeur), 4999 (solde créditeur), 599 (solde créditeur) |  | |
| DW | Banques, établissements financiers et crédits de trésorerie | 52-53 (solde créditeur), 56 (solde créditeur) |  | |
| DY | Écart de conversion-Passif | 479 |  | |

### Compte de résultat

| Poste | Libellé | Comptes bruts / montants | Amortissements, dépréciations | Avis |
|---|---|---|---|---|
| RA | Cotisations | 701 |  | |
| RB | Dotations consomptibles transférées au compte de résultat | 703 |  | |
| RC | Revenus liés à la générosité | 704 |  | |
| RD | Ventes de marchandises | 7051 |  | |
| RE | Ventes de services et produits finis | 7052-7055 |  | |
| RF | Subventions d'exploitation | 71 |  | |
| RG | Autres produits et transferts de charges | 702, 706-708, 72-73, 75, 77-78 |  | |
| RH | Reprises de provisions, dépréciations, subventions et autres reprises | 79 |  | |
| TA | Achats de biens et services liés à l'activité | 601 |  | |
| TB | Variation de stocks des achats de biens et services liés à l'activité | 6031 |  | |
| TC | Achats de marchandises et matières premières | 602 |  | |
| TD | Autres achats | 604-606, 608 |  | |
| TE | Variation de stocks de marchandises, de matières premières et autres | 6032-6035 |  | |
| TF | Transports | 61 |  | |
| TG | Services extérieurs | 62-63 |  | |
| TH | Impôts et taxes | 64 |  | |
| TI | Autres charges | 65 |  | |
| TJ | Charges de personnel | 66 |  | |
| TK | Frais financiers et charges assimilées | 67 |  | |
| TL | Dotations aux amortissements, aux provisions, aux dépréciations et autres | 68-69 |  | |
| TM | Produits H.A.O. | 82, 84, 86, 88 |  | |
| TN | Charges H.A.O. | 81, 83, 85, 87 |  | |

### Interprétations du texte officiel à confirmer

| Point | Choix retenu | Avis |
|---|---|---|
| Total XA « revenus des activités ordinaires » | Somme **RA à RH** (reprises 79 incluses), alors que le libellé indique RA à RG. Sans cela le résultat ne rejoint pas le grand livre. | |
| Comptes marqués « p » (part) | 2919 rattaché à AF, 2939 à AK, 2949 à AL. | |
| Poste AG, colonne amortissements | Chiffre illisible sur le scan, lu 2951. | |
| Compte 702 (quote-part de fonds d'administration transférés) | Absent du tableau officiel, rangé en RG « autres produits ». | |
| Compte 35 (produits et services en cours) | Absent du tableau officiel, rangé en BB « stocks et encours ». | |
| Compte 46 (bailleurs, fonds d'administration) | Absent du tableau officiel du chapitre 2, rangé en BE (solde débiteur) ou DI (solde créditeur). | |
| Comptes 7054 et 7055 | Absents du tableau officiel, rangés en RE « ventes de services et produits finis ». | |
| Compte 2817 | Rangé en dépréciation du poste AF. | |
| Comptes 409 et 419 | Lus à solde net (BC et DG). | |
| Comptes 478 et 479 | Uniquement en BY et DY (écarts de conversion). | |
| Report à nouveau et résultat | Le poste CG reprend 12 et les comptes 13 en instance ; le résultat de l'exercice (CH) est calculé. | |
| Solde dans le sens anormal | Un solde hors de son sens normal (par exemple 4991 au débit) reste hors des postes ; le contrôle « actif = passif » le signale. | |

## 5. Tableau des flux de trésorerie

Le texte officiel (page 348) donne les lignes mais aucune correspondance comptes → flux. Règle retenue (méthode directe) : pour chaque écriture touchant la trésorerie (comptes 50 à 57), chaque ligne de contrepartie apporte au flux son montant signé ; les virements internes (58), les à-nouveaux et l'écriture de résultat sont exclus.

| Compte de contrepartie | Poste du tableau | Avis |
|---|---|---|
| 701 cotisations, 411 adhérents | FA Encaissement des cotisations | |
| 71, 88, 473 (sauf 4731), 4491 subventions | FB Encaissement des subventions d'exploitation et d'équilibre | |
| 704 revenus liés à la générosité, 475 | FC Encaissement des revenus liés à la générosité | |
| 706 revenus des manifestations | FD Encaissement des revenus des manifestations | |
| Autres produits (7, 84, 86) et autres comptes 41 | FE Encaissement des autres revenus | |
| 40 fournisseurs, 60 à 63, stocks 31 à 38 | FF Décaissement des sommes versées aux fournisseurs | |
| 42, 43, 66 personnel et organismes sociaux | FG Décaissement des sommes versées au personnel | |
| 64, 65, 67 impôts, autres charges, frais financiers | FH Autres décaissements | |
| 21 à 25, 82, 485 immobilisations incorporelles et corporelles, 481 | FI (sortie) / FK (entrée) | |
| 26, 27, 826 immobilisations financières | FJ (sortie) / FL (entrée) | |
| 10 à 13, 16, 17, 45, 46 dotations, fonds, apporteurs | FM (entrée) / FO (sortie) | |
| 14, 4731 subventions d'investissement | FN Subventions d'investissement reçues | |
| 18 emprunts et dettes financières | FP (entrée) / FQ (sortie) | |
| Tout autre compte | FE si entrée, FH si sortie | |

Points à trancher : le classement des comptes 45 et 46 en fonds propres ; les comptes 41 hors 411 en « autres revenus » ; la présentation d'une écriture mêlant trésorerie et contreparties de nature différente (ventilation ligne par ligne) ; la ligne « activités de financement (D+E) » sans référence dans le texte (codée ZDE).

## 6. Clôture et affectation du résultat

| Point | Choix retenu | Avis |
|---|---|---|
| Résultat en instance d'affectation | Repris aux à-nouveaux au compte **128** (le compte 130 du système normal n'existe pas au plan SYCEBNL). | |
| Affectation de l'excédent | 128 débité ; crédit de **112** (réserves statutaires ou contractuelles), **118** (autres réserves) et **121** (report à nouveau des excédents). | |
| Distribution | Refusée pour une entité à but non lucratif (pas de dividendes). | |
| Déficit | Pas de traitement spécifique : le report des déficits (129) se fait par écriture manuelle. À confirmer. | |
| Impôt sur les sociétés | Calcul refusé pour une association. Y a-t-il une imposition à prévoir (impôt minimum, TVA sur activités lucratives) ? | |
| Inventaire | Amortissements (28x), dotations 6812 et 6813, cessions 812 et 822, provisions sur créances 4911, 6594, 7594 : repris du système normal, ces comptes existent au plan SYCEBNL. | |

## 7. Questions générales à poser à ABC

1. Combien d'associations, ONG, fondations ou syndicats le cabinet gère-t-il, et pour quand ?
2. Leurs comptes sont-ils tenus dans Perfecto ? L'import Perfecto doit-il traiter un plan SYCEBNL ?
3. Quels états produit le cabinet pour elles (bilan, compte de résultat, tableau des flux, notes annexes, tableau d'exécution budgétaire) ?
4. Les 35 notes annexes sont-elles toutes nécessaires, et lesquelles en priorité ?

## 8. Notes annexes calculables (23 sur 35)

Les notes de type « libellé, année N, année N-1, variation » dont les lignes se calculent depuis le grand livre sont produites à l'écran avec l'état financier. Pour les notes **8 à 13, 16, 17A, 17B, 19, 23 et 29A**, les lignes sont celles de la page officielle (Journal officiel, pages 364 à 369, 372 à 374, 377, 381 et 387). Pour les notes **18A, 20, 21, 22, 24 à 28, 31 et 32**, les pages officielles n'ont pas été relues : les lignes sont les comptes à 3 chiffres du plan (avec leur libellé), regroupés comme le bilan et le compte de résultat.

**Non produites** : notes 1 à 4 (informations générales), 5 (mouvements d'immobilisations), 6 et 7, 14 (écarts de conversion, saisie libre), 15 (membres et nationalité), 18B, 29B (effectifs), 30, 33 à 35 ; colonnes d'échéances des notes 9, 10 et 19 ; commentaires de chaque note.

Signe : *débit* = solde débiteur positif ; *crédit* = solde créditeur positif. Colonne *Avis* à remplir.

### Note 8 : Stocks et encours (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Biens et services liés à l'activité | 31 | Solde débiteur | |
| Marchandises, matières premières | 32 | Solde débiteur | |
| Autres approvisionnements | 33 | Solde débiteur | |
| Dons en nature | 34 | Solde débiteur | |
| Produits finis | 35-36 | Solde débiteur | |
| Dons en nature HAO | 38 | Solde débiteur | |
| Autres stocks HAO | 37 | Solde débiteur | |
| **TOTAL STOCKS ET ENCOURS** | | Somme des lignes ci-dessus | |
| Dépréciations des stocks | 39 | Solde créditeur | |
| **TOTAL NET DE DÉPRÉCIATIONS** | | Somme des lignes ci-dessus | |

### Note 9 : Adhérents, clients-usagers (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Adhérents | 411 | Solde débiteur | |
| Clients-usagers | 412 | Solde débiteur | |
| Adhérents, clients-usagers, chèques, effets et autres valeurs impayés | 413 | Solde débiteur | |
| Adhérents, créances litigieuses ou douteuses | 416 | Solde débiteur | |
| Adhérents, clients-usagers, produits à recevoir | 418 | Solde débiteur | |
| **TOTAL BRUT ADHÉRENTS, CLIENTS-USAGERS** | | Somme des lignes ci-dessus | |
| Dépréciations des comptes adhérents et clients-usagers | 491 | Solde créditeur | |
| **TOTAL NET DE DÉPRÉCIATIONS** | | Somme des lignes ci-dessus | |
| Adhérents, avances reçues | 4191 | Solde créditeur | |
| Clients-usagers, avances et acomptes reçus | 4192 | Solde créditeur | |
| Autres clients créditeurs | 4194 | Solde créditeur | |
| Autres clients créditeurs | 4198 | Solde créditeur | |
| **TOTAL CLIENTS CRÉDITEURS** | | Somme des lignes ci-dessus | |

### Note 10 : Autres créances (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Personnel | 42 (solde débiteur) | Solde débiteur | |
| Organismes sociaux | 43 (solde débiteur) | Solde débiteur | |
| État et collectivités publiques | 44 (solde débiteur) | Solde débiteur | |
| Fondateurs, apporteurs et comptes courants | 45 (solde débiteur) | Solde débiteur | |
| Bailleurs, État et autres organismes, fonds d'administration | 46 (solde débiteur) | Solde débiteur | |
| Débiteurs divers | 471 (solde débiteur) | Solde débiteur | |
| Autres débiteurs divers | 472-477 (solde débiteur) | Solde débiteur | |
| **TOTAL BRUT** | | Somme des lignes ci-dessus | |
| Dépréciations des autres créances | 492-494 | Solde créditeur | |
| Dépréciations des autres créances | 497 | Solde créditeur | |
| **TOTAL NET DE DÉPRÉCIATIONS** | | Somme des lignes ci-dessus | |

### Note 11 : Titres de placement (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Titres de trésor et bons de caisse à court terme | 501 | Solde débiteur | |
| Actions | 502 | Solde débiteur | |
| Obligations | 503 | Solde débiteur | |
| Bons de souscription | 504 | Solde débiteur | |
| Titres négociables hors région | 505 | Solde débiteur | |
| Intérêts courus | 506 | Solde débiteur | |
| Autres valeurs assimilées | 508 | Solde débiteur | |
| **TOTAL BRUT** | | Somme des lignes ci-dessus | |
| Dépréciations des titres de placement | 590 | Solde créditeur | |
| **TOTAL NET DE DÉPRÉCIATIONS** | | Somme des lignes ci-dessus | |

### Note 12 : Valeurs à encaisser (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Chèques à encaisser | 513 | Solde débiteur | |
| Chèques à l'encaissement | 514 | Solde débiteur | |
| Cartes de crédit à encaisser | 515 | Solde débiteur | |
| Autres valeurs à encaisser | 518 | Solde débiteur | |
| **TOTAL BRUT** | | Somme des lignes ci-dessus | |
| Dépréciations des valeurs à encaisser | 591 | Solde créditeur | |
| **TOTAL NET DE DÉPRÉCIATIONS** | | Somme des lignes ci-dessus | |

### Note 13 : Disponibilités (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Banques locales | 521 (solde débiteur) | Solde débiteur | |
| Banques autres États région | 522 (solde débiteur) | Solde débiteur | |
| Banques, dépôt à terme | 525 (solde débiteur) | Solde débiteur | |
| Autres banques | 523-524 (solde débiteur) | Solde débiteur | |
| Banques, intérêts courus | 526 (solde débiteur) | Solde débiteur | |
| Banques postales | 531 (solde débiteur) | Solde débiteur | |
| Autres établissements financiers | 532-533 (solde débiteur) | Solde débiteur | |
| Autres établissements financiers | 538 (solde débiteur) | Solde débiteur | |
| Établissements financiers, intérêts courus | 536 (solde débiteur) | Solde débiteur | |
| Instruments de monnaie électronique | 55 (solde débiteur) | Solde débiteur | |
| Caisse | 57 (solde débiteur) | Solde débiteur | |
| **TOTAL BRUT** | | Somme des lignes ci-dessus | |
| Dépréciations | 592-593 | Solde créditeur | |
| Dépréciations | 595 | Solde créditeur | |
| **TOTAL NET DE DÉPRÉCIATIONS** | | Somme des lignes ci-dessus | |

### Note 16 : Réserves (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Réserves statutaires ou contractuelles | 112 | Solde créditeur | |
| Autres réserves | 118 | Solde créditeur | |
| **TOTAL RÉSERVES** | | Somme des lignes ci-dessus | |
| Report à nouveau | 12 | Solde créditeur | |

### Note 17A : Subventions et provisions réglementées (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| État | 1411 | Solde créditeur | |
| Région | 1412 | Solde créditeur | |
| Département | 1413 | Solde créditeur | |
| Communes et collectivités publiques décentralisées | 1414 | Solde créditeur | |
| Entités publiques ou mixtes | 1415 | Solde créditeur | |
| Entités et organismes privés | 1416 | Solde créditeur | |
| Organismes internationaux | 1417 | Solde créditeur | |
| Autres subventions d'investissements | 1418 | Solde créditeur | |
| Autres subventions d'investissements | 148 | Solde créditeur | |
| **TOTAL SUBVENTIONS** | | Somme des lignes ci-dessus | |
| PROVISIONS RÉGLEMENTÉES | 15 | Solde créditeur | |
| **TOTAL SUBVENTIONS ET PROVISIONS RÉGLEMENTÉES** | | Somme des lignes ci-dessus | |

### Note 17B : Fonds affectés et reportés (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Fonds affectés aux investissements | 162-164 | Solde créditeur | |
| Fonds non consommés en fin d'exercice destinés à un projet spécifique | 165 | Solde créditeur | |
| Fonds provenant des dons et legs d'immobilisations | 167 | Solde créditeur | |
| Autres fonds affectés | 161 | Solde créditeur | |
| Autres fonds affectés | 168-169 | Solde créditeur | |
| **TOTAL FONDS AFFECTÉS** | | Somme des lignes ci-dessus | |
| Donations et legs non encore reçus d'immobilisations destinés à la vente | 172 | Solde créditeur | |
| Donation temporaire d'usufruit | 171 | Solde créditeur | |
| Autres fonds reportés | 178 | Solde créditeur | |
| **TOTAL FONDS REPORTÉS** | | Somme des lignes ci-dessus | |
| **TOTAL FONDS AFFECTÉS ET REPORTÉS** | | Somme des lignes ci-dessus | |

### Note 18A : Dettes financières et ressources assimilées (comptes du plan)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Emprunts obligataires | 181 | Solde créditeur | |
| Emprunts et dettes auprès des établissements de crédit | 182 | Solde créditeur | |
| Avances reçues de l’État | 183 | Solde créditeur | |
| Dépôts et cautionnements reçus | 185 | Solde créditeur | |
| Intérêts courus | 186 | Solde créditeur | |
| Autres emprunts et dettes | 188 | Solde créditeur | |
| Dettes de location-acquisition | 187 | Solde créditeur | |
| Provisions pour risques et charges | 19 | Solde créditeur | |
| **TOTAL DETTES FINANCIÈRES ET RESSOURCES ASSIMILÉES** | | Somme des lignes ci-dessus | |

### Note 19 : Fournisseurs d'exploitation (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Fournisseurs, dettes en compte | 4011-4012 | Solde créditeur | |
| Fournisseurs, dettes en compte | 4014-4015 | Solde créditeur | |
| Fournisseurs, dettes en compte | 4018-4019 | Solde créditeur | |
| Fournisseurs, réserve de propriété | 4016 | Solde créditeur | |
| Fournisseurs, retenue de garantie | 4017 | Solde créditeur | |
| Fournisseurs sous-traitants | 4013 | Solde créditeur | |
| Fournisseurs effets à payer | 402 | Solde créditeur | |
| Fournisseurs factures non parvenues | 408 | Solde créditeur | |
| **TOTAL FOURNISSEURS** | | Somme des lignes ci-dessus | |
| Fournisseurs, avances et acomptes | 4091-4092 | Solde débiteur | |
| Fournisseurs sous-traitants, avances et acomptes | 4093 | Solde débiteur | |
| Autres fournisseurs débiteurs | 4094-4099 | Solde débiteur | |
| **TOTAL FOURNISSEURS DÉBITEURS** | | Somme des lignes ci-dessus | |

### Note 20 : Dettes fiscales et sociales (comptes du plan)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Personnel | 42 (solde créditeur) | Solde créditeur | |
| Organismes sociaux | 43 (solde créditeur) | Solde créditeur | |
| État et collectivités publiques | 44 (solde créditeur) | Solde créditeur | |
| **TOTAL DETTES FISCALES ET SOCIALES** | | Somme des lignes ci-dessus | |

### Note 21 : Autres dettes et provisions à court terme (comptes du plan)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Fondateurs, apporteurs et comptes courants | 45 (solde créditeur) | Solde créditeur | |
| Bailleurs, fonds d'administration | 46 (solde créditeur) | Solde créditeur | |
| Créditeurs divers | 470-477 (solde créditeur) | Solde créditeur | |
| Provisions pour risques à court terme | 4990-4997 (solde créditeur) | Solde créditeur | |
| Provisions pour risques à court terme | 4999 (solde créditeur) | Solde créditeur | |
| Provisions pour risques à court terme | 599 (solde créditeur) | Solde créditeur | |
| **TOTAL AUTRES DETTES ET PROVISIONS À COURT TERME** | | Somme des lignes ci-dessus | |

### Note 22 : Banques et crédits de trésorerie (comptes du plan)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Banques, soldes créditeurs | 52 (solde créditeur) | Solde créditeur | |
| Établissements financiers, soldes créditeurs | 53 (solde créditeur) | Solde créditeur | |
| Crédits de trésorerie | 561 | Solde créditeur | |
| Escompte de crédits ordinaires | 565 | Solde créditeur | |
| Banques, crédits de trésorerie, intérêts courus | 566 | Solde créditeur | |
| **TOTAL BANQUES ET CRÉDITS DE TRÉSORERIE** | | Somme des lignes ci-dessus | |

### Note 23 : Revenus et autres produits (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Cotisations des adhérents | 701 | Solde créditeur | |
| Quote-part de dotation consomptible transférée | 703 | Solde créditeur | |
| Revenus liés à la générosité | 704 | Solde créditeur | |
| Ventes de marchandises, services et produits finis | 705 | Solde créditeur | |
| Revenus des manifestations | 706 | Solde créditeur | |
| Autres revenus | 702 | Solde créditeur | |
| Autres revenus | 707-708 | Solde créditeur | |
| **TOTAL : REVENUS** | | Somme des lignes ci-dessus | |
| Subventions d'exploitation | 71 | Solde créditeur | |
| Autres produits et transferts de charges d'exploitation | 72-73 | Solde créditeur | |
| Autres produits et transferts de charges d'exploitation | 75 | Solde créditeur | |
| Autres produits et transferts de charges d'exploitation | 78 | Solde créditeur | |
| **TOTAL : SUBVENTIONS D'EXPLOITATION ET AUTRES PRODUITS** | | Somme des lignes ci-dessus | |
| **TOTAL** | | Somme des lignes ci-dessus | |

### Note 24 : Achats (comptes du plan)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Achats de biens et services liés à l’activité | 601 | Solde débiteur | |
| Achats de marchandises, de matières premières et fournitures liées | 602 | Solde débiteur | |
| Achats stockés de matières et fournitures consommables | 604 | Solde débiteur | |
| Autres achats | 605 | Solde débiteur | |
| Achats autres activités | 606 | Solde débiteur | |
| Achats d'emballages | 608 | Solde débiteur | |
| **TOTAL** | | Somme des lignes ci-dessus | |

### Note 25 : Transports (comptes du plan)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Transports sur ventes | 612 | Solde débiteur | |
| Transports pour le compte de tiers | 613 | Solde débiteur | |
| Transports du personnel | 614 | Solde débiteur | |
| Transports de plis | 616 | Solde débiteur | |
| Autres frais de transport | 618 | Solde débiteur | |
| Rabais, Remises et Ristournes Obtenus (non ventilés) | 619 | Solde débiteur | |
| **TOTAL** | | Somme des lignes ci-dessus | |

### Note 26 : Services extérieurs (comptes du plan)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Sous-traitance générale | 621 | Solde débiteur | |
| Locations, charges locatives | 622 | Solde débiteur | |
| Redevances de location-acquisition | 623 | Solde débiteur | |
| Entretien, réparation, remise en état et maintenance | 624 | Solde débiteur | |
| Primes d’assurance | 625 | Solde débiteur | |
| Études, recherches et documentation | 626 | Solde débiteur | |
| Publicité, publications, relations publiques | 627 | Solde débiteur | |
| Frais de télécommunications | 628 | Solde débiteur | |
| Frais bancaires | 631 | Solde débiteur | |
| Rémunérations d’intermédiaires et de conseils | 632 | Solde débiteur | |
| Frais de formation | 633 | Solde débiteur | |
| Redevances pour brevets, licences, logiciels, sites internet, concessions et droits et valeurs similaires | 634 | Solde débiteur | |
| Cotisations | 635 | Solde débiteur | |
| Frais de recherche de fonds | 636 | Solde débiteur | |
| Rémunérations de personnel extérieur à l’entité | 637 | Solde débiteur | |
| Autres charges externes | 638 | Solde débiteur | |
| **TOTAL** | | Somme des lignes ci-dessus | |

### Note 27 : Impôts et taxes (comptes du plan)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Impôts et taxes directs | 641 | Solde débiteur | |
| Impôts et taxes indirects | 645 | Solde débiteur | |
| Droits d’enregistrement | 646 | Solde débiteur | |
| Pénalités, amendes fiscales | 647 | Solde débiteur | |
| Autres impôts et taxes | 648 | Solde débiteur | |
| Dégrèvements et annulations des impôts et taxes | 649 | Solde débiteur | |
| **TOTAL** | | Somme des lignes ci-dessus | |

### Note 28 : Autres charges (comptes du plan)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Pertes sur créances adhérents, clients et autres débiteurs | 651 | Solde débiteur | |
| Subventions accordées par l’entité | 652 | Solde débiteur | |
| Dons en nature courants à distribuer | 654 | Solde débiteur | |
| Pénalités et amendes pénales | 657 | Solde débiteur | |
| Charges diverses | 658 | Solde débiteur | |
| **TOTAL** | | Somme des lignes ci-dessus | |

### Note 29A : Charges de personnel (page officielle)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Rémunérations directes versées au personnel national | 661 | Solde débiteur | |
| Rémunérations directes versées au personnel non national | 662 | Solde débiteur | |
| Indemnités forfaitaires versées au personnel | 663 | Solde débiteur | |
| Charges sociales | 664 | Solde débiteur | |
| Habillement et équipement du personnel | 665 | Solde débiteur | |
| Rémunération transférée de personnel extérieur | 667 | Solde débiteur | |
| Autres charges sociales | 668 | Solde débiteur | |
| Dégrèvements et annulations des charges sociales | 669 | Solde débiteur | |
| **TOTAL** | | Somme des lignes ci-dessus | |

### Note 31 : Charges et revenus financiers (comptes du plan)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Intérêts des emprunts | 671 | Solde débiteur | |
| Intérêts dans loyers de location-acquisition | 672 | Solde débiteur | |
| Escomptes accordés | 673 | Solde débiteur | |
| Autres intérêts | 674 | Solde débiteur | |
| Pertes de change financières | 676 | Solde débiteur | |
| Pertes sur titres de placement | 677 | Solde débiteur | |
| Pertes et charges sur risques financiers | 678 | Solde débiteur | |
| Charges pour dépréciations et provisions pour risques à court terme financières | 679 | Solde débiteur | |
| **TOTAL FRAIS FINANCIERS ET CHARGES ASSIMILÉES** | | Somme des lignes ci-dessus | |
| Intérêts de prêts et créances diverses | 771 | Solde créditeur | |
| Revenus de participations et autres titres immobilisés | 772 | Solde créditeur | |
| Escomptes obtenus | 773 | Solde créditeur | |
| Revenus de placement | 774 | Solde créditeur | |
| Gains de change financiers | 776 | Solde créditeur | |
| Gains sur cessions de titres de placement | 777 | Solde créditeur | |
| Gains sur risques financiers | 778 | Solde créditeur | |
| Reprises de charges pour dépréciations et provisions pour risques à court terme financières | 779 | Solde créditeur | |
| **TOTAL REVENUS FINANCIERS ET PRODUITS ASSIMILÉS** | | Somme des lignes ci-dessus | |

### Note 32 : Autres charges et produits HAO (comptes du plan)

| Ligne | Comptes | Montant | Avis |
|---|---|---|---|
| Revenus hors activites ordinaires | 84 | Solde créditeur | |
| Reprises d'amortissements, provisions et depreciations hao. | 86 | Solde créditeur | |
| Produits des cessions d’immobilisations | 82 | Solde créditeur | |
| Subventions d'équilibre | 88 | Solde créditeur | |
| **TOTAL PRODUITS HAO** | | Somme des lignes ci-dessus | |
| Valeurs comptables des cessions d’immobilisations | 81 | Solde débiteur | |
| Charges hors activites ordinaires | 83 | Solde débiteur | |
| Dotations hors activites ordinaires | 85 | Solde débiteur | |
| Variations de stocks de dons en nature hao | 87 | Solde débiteur | |
| **TOTAL CHARGES HAO** | | Somme des lignes ci-dessus | |

