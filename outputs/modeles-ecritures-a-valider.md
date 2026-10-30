# Modèles d'écritures à valider par ABC

Généré le 30 oct. 2026 à partir de la base de recette (décision D-021). Les numéros de compte sont ceux du plan de référence SYSCOHADA du dépôt, complétés à la longueur du plan de l'entité (ex. `521` devient `5210000`).

**À faire** : pour chaque modèle, un comptable d'ABC confirme les comptes, le sens (débit / crédit) et la TVA, ou indique la correction. Colonne *Avis* à remplir.

Lecture : *Saisie* = montant saisi par le collaborateur ; *% de ligne n* = pourcentage (taux indiqué) d'une autre ligne ; *Solde* = montant qui équilibre l'écriture ; *Tiers* = le code tiers est demandé.


## Journal Achats


### `ACHAT_IMMO` — Achat de matériel de bureau (immobilisation)

Immobilisation HT, TVA sur immobilisations, fournisseur d'investissement

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 2441 | Matériel de bureau | Débit | Saisie |  | |
| 2 | 4451 | T.V.A. récupérable sur immobilisations | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4812 | Immobilisations corporelles | Crédit | Solde | oui | |

### `ACHAT_SERVICES` — Achat de prestations de services avec TVA

Prestation de services, TVA récupérable, fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6057 | Achats d'études et prestations de service | Débit | Saisie |  | |
| 2 | 4454 | T.V.A. récupérable sur services extérieurs et autres charges | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `ACHAT_TVA` — Achat avec TVA

Charge HT, TVA récupérable, fournisseur TTC

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6011 | dans la Région | Débit | Saisie |  | |
| 2 | 4452 | T.V.A. récupérable sur achats | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `ASSURANCE` — Prime d'assurance

Assurance non soumise à la TVA : prime et fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6251 | Assurances multirisques | Débit | Saisie |  | |
| 2 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `AVOIR_ACHAT` — Avoir fournisseur avec TVA

Annulation partielle d'un achat : achat et TVA en diminution, fournisseur en débit

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6011 | dans la Région | Crédit | Saisie |  | |
| 2 | 4452 | T.V.A. récupérable sur achats | Crédit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Débit | Solde | oui | |

### `DEPLACEMENTS` — Voyages et déplacements avec TVA

Voyages et déplacements, TVA récupérable, fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6181 | Voyages et déplacements | Débit | Saisie |  | |
| 2 | 4454 | T.V.A. récupérable sur services extérieurs et autres charges | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `EAU` — Facture d'eau avec TVA

Eau, TVA récupérable, fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6051 | Fournitures non stockables-Eau | Débit | Saisie |  | |
| 2 | 4454 | T.V.A. récupérable sur services extérieurs et autres charges | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `ELECTRICITE` — Facture d'électricité avec TVA

Électricité, TVA récupérable, fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6052 | Fournitures non stockables- Electricité | Débit | Saisie |  | |
| 2 | 4454 | T.V.A. récupérable sur services extérieurs et autres charges | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `ENTRETIEN` — Entretien et réparations avec TVA

Entretien et réparations, TVA récupérable, fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6242 | Entretien et réparations des biens mobiliers | Débit | Saisie |  | |
| 2 | 4454 | T.V.A. récupérable sur services extérieurs et autres charges | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `FOURNITURES` — Fournitures de bureau avec TVA

Fournitures de bureau, TVA récupérable, fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6055 | Fournitures de bureau non stockables | Débit | Saisie |  | |
| 2 | 4452 | T.V.A. récupérable sur achats | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `HONORAIRES` — Honoraires avec TVA

Honoraires, TVA récupérable, fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6324 | Honoraires des professions règlementées | Débit | Saisie |  | |
| 2 | 4454 | T.V.A. récupérable sur services extérieurs et autres charges | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `LOYER` — Loyer sans TVA

Bailleur non assujetti à la TVA : loyer et fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6222 | Locations de bâtiments | Débit | Saisie |  | |
| 2 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `LOYER_TVA` — Loyer avec TVA

Bailleur assujetti à la TVA

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6222 | Locations de bâtiments | Débit | Saisie |  | |
| 2 | 4454 | T.V.A. récupérable sur services extérieurs et autres charges | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `PUBLICITE` — Publicité et annonces avec TVA

Publicité, TVA récupérable, fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6271 | Annonces, insertions | Débit | Saisie |  | |
| 2 | 4454 | T.V.A. récupérable sur services extérieurs et autres charges | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Crédit | Solde | oui | |

### `TELECOM` — Téléphone et internet avec TVA

Téléphone et internet, TVA récupérable, fournisseur

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6281 | Frais de téléphone | Débit | Saisie |  | |
| 2 | 4454 | T.V.A. récupérable sur services extérieurs et autres charges | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4011 | Fournisseurs | Crédit | Solde | oui | |

## Journal Ventes


### `AVOIR_VENTE` — Avoir client avec TVA

Annulation partielle d'une vente : vente et TVA en diminution, client en crédit

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 7011 | dans la Région (1) | Débit | Saisie |  | |
| 2 | 4431 | T.V.A. facturée sur ventes | Débit | % de ligne 1 (TVA) |  | |
| 3 | 4111 | Clients | Crédit | Solde | oui | |

### `VENTE_EXONEREE` — Vente exonérée de TVA

Vente sans TVA : client et vente

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 7011 | dans la Région (1) | Crédit | Saisie |  | |
| 2 | 4111 | Clients | Débit | Solde | oui | |

### `VENTE_SERVICES` — Vente de services avec TVA

Client TTC, prestation HT, TVA sur prestations

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 7061 | dans la Région (1) | Crédit | Saisie |  | |
| 2 | 4432 | T.V.A. facturée sur prestations de services | Crédit | % de ligne 1 (TVA) |  | |
| 3 | 4111 | Clients | Débit | Solde | oui | |

### `VENTE_TVA` — Vente avec TVA

Client TTC, vente HT, TVA facturée

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 7011 | dans la Région (1) | Crédit | Saisie |  | |
| 2 | 4431 | T.V.A. facturée sur ventes | Crédit | % de ligne 1 (TVA) |  | |
| 3 | 4111 | Clients | Débit | Solde | oui | |

## Journal Banque


### `FRAIS_BQ_TAF` — Frais bancaires avec TAF

Frais HT, TAF, banque

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6311 | Frais sur titres (, vente, garde) | Débit | Saisie |  | |
| 2 | 6312 | Frais sur effets | Débit | % de ligne 1 (TAF) |  | |
| 3 | 521 | BANQUES LOCALES | Crédit | Solde |  | |

### `PAIEMENT_CNSS` — Paiement des cotisations CNSS

Reversement des cotisations sociales par banque

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 4311 | Prestations familiales | Débit | Saisie |  | |
| 2 | 521 | BANQUES LOCALES | Crédit | Solde |  | |

### `PAIEMENT_IRPP` — Paiement de l'impôt sur salaires

Reversement de l'impôt retenu sur salaires par banque

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 4472 | Impôts sur salaires | Débit | Saisie |  | |
| 2 | 521 | BANQUES LOCALES | Crédit | Solde |  | |

### `PAIEMENT_TVA` — Paiement de la TVA due

Reversement de la TVA due à l'État par banque

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 4441 | Etat, T.V.A. due | Débit | Saisie |  | |
| 2 | 521 | BANQUES LOCALES | Crédit | Solde |  | |

### `REGL_CLIENT` — Règlement client par banque

Banque encaissée, client soldé

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 521 | BANQUES LOCALES | Débit | Saisie |  | |
| 2 | 4111 | Clients | Crédit | Solde | oui | |

### `REGL_CLIENT_RET` — Règlement client avec AIB et TVA retenue

Banque net, AIB et TVA retenues, client soldé

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 4111 | Clients | Crédit | Saisie | oui | |
| 2 | 4478 | Autres impôts et contributions | Débit | % de ligne 1 (AIB1) |  | |
| 3 | 4452 | T.V.A. récupérable sur achats | Débit | % de ligne 1 (TVA_RET) |  | |
| 4 | 521 | BANQUES LOCALES | Débit | Solde |  | |

### `REGL_FOURNISSEUR` — Règlement fournisseur par banque

Fournisseur soldé, banque décaissée

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 4011 | Fournisseurs | Débit | Saisie | oui | |
| 2 | 521 | BANQUES LOCALES | Crédit | Solde |  | |

## Journal Caisse


### `ENCAISSEMENT_CAISSE` — Encaissement client en espèces

Caisse encaissée, client soldé

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 571 | CAISSE SIEGE SOCIAL | Débit | Saisie |  | |
| 2 | 4111 | Clients | Crédit | Solde | oui | |

### `PAIEMENT_CAISSE` — Paiement fournisseur en espèces

Fournisseur soldé, caisse décaissée

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 4011 | Fournisseurs | Débit | Saisie | oui | |
| 2 | 571 | CAISSE SIEGE SOCIAL | Crédit | Solde |  | |

### `VERSEMENT_ESPECES` — Versement d'espèces en banque

Banque créditée, caisse déchargée

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 521 | BANQUES LOCALES | Débit | Saisie |  | |
| 2 | 571 | CAISSE SIEGE SOCIAL | Crédit | Solde |  | |

## Journal Paie


### `SALAIRES` — Salaires avec IRPP et CNSS

Salaires bruts, retenues salariales, charges patronales, net à payer

| N° | Compte | Intitulé | Sens | Montant | Tiers | Avis |
|---|---|---|---|---|---|---|
| 1 | 6611 | Appointements, salaires et commissions | Débit | Saisie |  | |
| 2 | 4472 | Impôts sur salaires | Crédit | Saisie |  | |
| 3 | 4311 | Prestations familiales | Crédit | % de ligne 1 (CNSS_SAL) |  | |
| 4 | 6641 | Charges sociales sur rémunération du personnel national | Débit | % de ligne 1 (CNSS_PAT) |  | |
| 5 | 4311 | Prestations familiales | Crédit | % de ligne 1 (CNSS_PAT) |  | |
| 6 | 422 | PERSONNEL, REMUNERATIONS DUES | Crédit | Solde | oui | |
