# Akonta — Recette interne (équipe Simetriik)

Objectif : dérouler Akonta de bout en bout, sur une base vierge, avant la recette globale avec le cabinet ABC. Chaque membre de l'équipe joue un rôle réel.

## 1. Préparation de l'environnement

- Instance de **test** dédiée (jamais la base destinée à ABC), base remise à zéro.
- Seuls éléments présents au départ : le plan de référence SYSCOHADA et un compte administrateur technique.
- Données fournies par Claude Code dans `recette/` :
  - `export-perfecto-simule.txt` : faux export Perfecto au format réel (tabulations, cp1252, en-tête JOURNAL, sous-totaux), PME fictive de Cotonou, à-nouveaux au 01/01/2027 ;
  - `releve-ecobank-janvier.csv` : relevé bancaire fictif pour le rapprochement ;
  - quelques pièces justificatives fictives (factures, reçus) en PDF/JPEG ;
  - `jeu-de-donnees.md` : description de l'entreprise fictive et des opérations à saisir.

## 2. Répartition des rôles

| Rôle | Membre de l'équipe |
|---|---|
| Administrateur technique | … |
| Associé | Hodonou |
| Chef de mission | … |
| Assistant | … |
| Stagiaire | … |

## 3. Scénario de bout en bout

Chaque étape : qui agit, ce qu'il fait, le résultat attendu. Cocher OK ou noter l'anomalie.

### Étape 1 — Socle (administrateur)
1. Se connecter, activer la double authentification (TOTP).
2. Inviter les autres membres par e-mail ; chacun crée son mot de passe (12 caractères minimum).
3. Vérifier : 5 échecs de connexion verrouillent le compte ; 30 min d'inactivité déconnectent.
4. Vérifier que l'administrateur **ne voit aucune donnée comptable**.

### Étape 2 — Cabinet et dossier (associé)
1. Paramétrer le cabinet (modèle de journaux, rôles par défaut).
2. Ouvrir le dossier de la PME fictive via l'assistant en 5 étapes : fiche entité (blocs R1/R2/R3), exercice 2027, plan de comptes à 7 chiffres, journaux, option de verrouillage mensuel.
3. Affecter le chef de mission, l'assistant et le stagiaire au dossier.

### Étape 3 — Référentiels (chef de mission)
1. Créer quelques subdivisions de comptes et des tiers (clients, fournisseurs).
2. Vérifier les modèles d'écritures (achat/vente TVA 18 %, règlement avec AIB et TVA retenue, frais bancaires, salaires).
3. Tenter de supprimer un compte mouvementé : doit être refusé.

### Étape 4 — Import Perfecto (chef de mission)
1. Importer `export-perfecto-simule.txt` en **mode essai** ; vérifier la scission des comptes collés (ex. 4110CHU → collectif 411 + tiers CHU).
2. Ajuster la table de correspondance si besoin, puis importer pour de bon.
3. Vérifier que les à-nouveaux arrivent en brouillard, équilibrés, puis les valider.

### Étape 5 — Saisie et pièces (assistant, stagiaire)
1. Stagiaire : saisir une écriture → elle reste en brouillard, il ne peut pas la valider.
2. Assistant : saisir un mois d'opérations du jeu de données, au clavier, avec autocomplétion et contrepartie.
3. Vérifier les garde-fous : écriture déséquilibrée et montant négatif refusés.
4. Valider : le numéro de pièce est attribué à la validation, sans trou.
5. Joindre des pièces ; depuis le mobile, photographier une pièce → elle arrive dans la boîte de réception du dossier.
6. Faire une écriture en devise (euro à 655,957).

### Étape 6 — Revue (chef de mission)
1. Marquer des écritures « revues », en signaler une « à corriger » avec commentaire.
2. Corriger par contre-passation (motif obligatoire), puis par reclassement.

### Étape 7 — Consultation (tous)
1. Grand livre, balance générale, balance auxiliaire, balance âgée : cohérentes entre elles.
2. Vérifier que les brouillards n'apparaissent pas.
3. Exporter en PDF et Excel ; vérifier la trace dans la piste d'audit.

### Étape 8 — Lettrage et rapprochement (assistant)
1. Lettrer manuellement, accepter des propositions automatiques, faire un lettrage partiel, délettrer.
2. Cas règlement + retenues = facture.
3. Importer `releve-ecobank-janvier.csv`, pointer, créer une écriture depuis une ligne non rapprochée, générer l'état de rapprochement PDF.

### Étape 9 — Verrouillage (associé / chef de mission)
1. Verrouiller janvier ; tenter une saisie dessus : refusée.
2. Déverrouiller avec motif ; vérifier la trace.

### Étape 10 — Travaux d'inventaire (chef de mission, assistant)
1. Immobilisations : acquisition, dotation prorata temporis, cession.
2. Stocks : saisir le stock final, générer la variation.
3. Provisions : partir de la balance âgée, fixer un taux, générer la dotation.
4. Régularisations : une charge à payer et une CCA, vérifier l'extourne prévue au 1er janvier.
5. Écart de conversion sur une dette en devise.

### Étape 11 — Clôture (chef de mission puis associé)
1. Lancer les contrôles : provoquer une anomalie bloquante (brouillard restant, 471 non soldé), la corriger ; lever une alerte avec commentaire.
2. Tableau de passage fiscal, calcul de l'IS (minimum d'impôt, acomptes), écriture d'IS.
3. Générer les états financiers ; ouvrir le modèle Excel DGI rempli (macros intactes) et le PDF ; contrôler bilan équilibré.
4. Clôture provisoire, réouverture avec motif, nouvelle clôture provisoire.
5. Associé : arrêté définitif ; vérifier que plus rien n'est modifiable.

### Étape 12 — Exercice suivant (associé, chef de mission)
1. Ouvrir 2028 : à-nouveaux générés, factures non lettrées reprises, extournes passées.
2. Saisir l'affectation du résultat.

### Étape 13 — Piste d'audit (associé)
1. Consulter et filtrer la piste d'audit ; vérifier l'intégrité de la chaîne.

### Étape 14 — Facturation e-MECeF (associé, assistant) — D-043
Prérequis : jeton de test et NIM du point de vente fournis par la DGI (sinon, s'arrêter au point 2).
1. Associé : déclarer l'e-MCF du dossier (NIM, mode test) et saisir le jeton ; refus attendu si le jeton ne correspond pas au NIM.
2. Assistant : créer une facture de vente (FV) en brouillon, avec groupes de taxe A et B, puis un cas AIB 1 % et 5 % ; vérifier les totaux affichés.
3. Émettre : statut « confirmée », code MECeF et QR code présents ; ouvrir le PDF et **scanner le QR au téléphone**.
4. Facture d'avoir (FA) sur une facture confirmée ; annulation d'une émission en attente (« pending »).
5. Couper le réseau pendant l'émission : la facture reste reprenable (« reprendre ») sans doublon.
6. Vérifier l'écriture de vente générée **en brouillard**, marquée « générée » ; contrôler le compte AIB et la ventilation HT/TVA/total.
7. Passer les 20 cas d'auto-déclaration DGI (liste dans `intrants/emcf-dgi/06-auto-declaration-sfe.md`) et noter les écarts.

### Étape 15 — Accès clients (associé, comptable, client) — D-044
1. Associé : fiche du dossier, onglet **Clients** → état « fermé » par défaut ; ouvrir l'accès ; inviter un `client_saisie` puis un `client_gerant` (le gérant doit enrôler le TOTP).
2. Client saisie, première connexion : l'accueil client s'affiche ; seules les routes saisie, pièces et factures sont accessibles (taper une autre adresse → retour à l'accueil).
3. Client : saisir un brouillard, déposer une pièce, créer une facture. Vérifier qu'il **ne voit ni les écritures validées, ni les soldes, ni les autres dossiers**, ni les brouillards du cabinet.
4. Client : tenter de valider une écriture → impossible. Modifier/supprimer une pièce du cabinet → impossible.
5. Comptable : voir le brouillard du client, le **renvoyer avec un motif** ; le client voit « À corriger : … » et reçoit la notification, corrige, le comptable valide.
6. Associé : **suspendre** l'accès → le client lit mais ne crée plus rien (boutons masqués) ; **fermer** → le client ne voit plus rien.
7. Piste d'audit : les changements d'état (`client_access`) et les renvois (`return_draft`) y figurent.
8. Points à trancher pendant la recette : TOTP pour un saisisseur qui émet ; création de tiers par le client ; visibilité des brouillards du cabinet.

### Étape 16 — Saisie par scan de pièce (assistant, chef de mission) — D-050
Prérequis : migration `20261111100001` appliquée, fonction `extract-document` déployée, service de documents lancé avec Tesseract.
1. Déposer dans la boîte de réception les pièces de `recette/pieces/` (01, 04, 07, 12 en PDF ; 06 en JPEG), puis **Proposer une écriture** : brouillard ouvert, marqué « générée », pièce liée.
2. Contrôler : date, référence, HT, TVA récupérable, fournisseur au crédit avec son tiers (par IFU ou nom) ; avertissements affichés (tiers non retrouvé, compte 4711).
3. Pièce en devise (10, 11) : montant en FCFA par la contre-valeur, sans TVA. Pièce 05 (avis de retenue) : noter que l'achat proposé n'est pas le bon traitement.
4. Relancer l'action sur la même pièce : le brouillard retouché est rouvert, rien n'est écrasé.
5. Corriger le compte de charge, valider : la validation passe par les règles habituelles.
6. Rôle client saisie : sa propre pièce oui, une pièce du cabinet non ; rôle auditeur : action refusée ; hors connexion : message clair.
7. **Pièces réelles** : essayer 5 à 10 vraies pièces d'ABC (photos, scans), noter les champs mal lus pour ajuster les règles.

## 4. Fiche d'anomalie

| N° | Étape | Rôle | Description | Gravité (bloquante / majeure / mineure / ergonomie) | Capture | Statut |
|---|---|---|---|---|---|---|

## 5. Bilan

- Nombre d'anomalies par gravité.
- Décision : prêt pour la recette ABC, ou nouvelle passe de corrections.
- Points d'ergonomie à remonter à la refonte de l'interface.
