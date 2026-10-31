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
