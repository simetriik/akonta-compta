# Script de narration — vidéo de recette Akonta

## Akonta

- Bienvenue dans Akonta, le logiciel comptable SYSCOHADA révisé du cabinet ABC Expertise Comptable. Cette vidéo déroule le parcours de recette des trois lots sur le jeu de démonstration.
- Nous suivons le scénario global du compte rendu de livraison du lot trois : de la connexion jusqu'à l'arrêté définitif d'un exercice et l'ouverture du suivant.

## 1 · Connexion et tableau de bord

- Chaque collaborateur se connecte avec son adresse e-mail et un mot de passe d'au moins douze caractères. Nous commençons avec le chef de mission, Kofi Mensah.
- Le tableau de bord liste les dossiers affectés et, pour chacun, les brouillards en attente, les écritures non revues, celles à corriger et les pièces à traiter.

## 2 · Dossiers et exercices

- Un dossier est une entité et un exercice. La liste rappelle la forme juridique, l'IFU et la longueur fixe des comptes, figée dès que le plan existe.
- La fiche reprend les champs d'identification de la liasse DGI : dénomination, siège, IFU, RCCM, régime fiscal, activité et paramètres comptables.
- L'onglet Exercices et périodes montre le verrouillage mensuel. Sur SARL Démo Distribution, janvier, février et mars sont verrouillés ; le déverrouillage est réservé à l'associé, avec motif consigné.

## 3 · Saisie, validation et revue

- Le module Saisie affiche le brouillard et les écritures validées, filtrables par journal, par mois et par statut. Chaque statut a sa couleur : brouillard, validée, revue, à corriger.
- L'éditeur est pensé pour le clavier : journal, date, pièce, libellé, puis une grille de lignes. Tabulation passe à la cellule suivante, Contrôle B appelle la contrepartie, Contrôle S enregistre le brouillard.
- Un modèle, ici Achat avec TVA, pré-remplit les lignes à partir d'un montant hors taxes. La pastille indique en permanence si l'écriture est équilibrée ; une écriture déséquilibrée reste en brouillard, jamais validée.
- La validation est une fonction de la base : elle contrôle l'équilibre, la période et les comptes, puis attribue le numéro séquentiel sans trou, ici AC-21. Une écriture validée ne se modifie plus : on la contre-passe.
- Le chef de mission revoit chaque écriture validée : conforme, ou à corriger avec un commentaire obligatoire.
- Le statut de revue et le commentaire apparaissent dans la liste, et le tableau de bord compte les écritures à reprendre.

## 4 · Consultation

- Le grand livre, les balances et le centralisateur sont calculés à la demande par la base : aucun solde n'est stocké. Chaque compte affiche ses mouvements, son total et son solde.
- La balance générale présente ouverture, mouvements et clôture par classe, se compare à l'exercice précédent et s'exporte. Les mêmes calculs alimentent les états financiers.

## 5 · Pièces justificatives

- Les pièces, PDF ou photos, arrivent du bureau ou du mobile dans une boîte de réception, puis sont rattachées aux écritures. Chaque fichier reçoit une empreinte SHA-256 ; une pièce rattachée à une écriture validée ne se supprime pas.

## 6 · Lettrage

- Sur un compte de tiers, Akonta propose les lettrages évidents, ici neuf règlements SOBEB de même montant. Voir présélectionne les lignes, Confirmer lettre.
- La proposition confirmée disparaît et les lignes sont lettrées. Les lettrages partiels restent ouverts jusqu'au solde ; le délettrage est possible tant que la période n'est pas verrouillée.

## 7 · Rapprochement bancaire

- Pour chaque journal de banque, l'état de rapprochement confronte le solde comptable et le solde du relevé, et liste les lignes non pointées de chaque côté. Les relevés s'importent en CSV avec un gabarit mémorisé par banque.
- Une ligne de relevé sans écriture, ici des agios, se comptabilise directement depuis le rapprochement. Sa période de février est verrouillée : on date l'écriture dans une période ouverte.
- L'écriture est validée dans le journal de banque et pointée aussitôt : écart zéro. À écart nul, l'état du mois se fige et s'exporte en PDF.

## 8 · Travaux d'inventaire

- Une immobilisation se déclare avec son compte, ses dates, sa valeur brute et sa durée : ici un véhicule de douze millions sur cinq ans, mis en service le premier avril.
- Le tableau d'amortissement est calculé au prorata, sur une base de trois cent soixante jours.
- Générer les dotations crée l'écriture d'amortissement en brouillard, marquée générée. Elle se valide ensuite dans la saisie, comme toute écriture.
- Les autres onglets couvrent les stocks avec leur variation, les provisions sur créances, les régularisations de charges et de produits, et les écarts de conversion au cours de clôture.

## 9 · Clôture

- La clôture commence par les contrôles. Les bloquants, comme un brouillard en attente ou un grand livre déséquilibré, empêchent de continuer ; les alertes se lèvent avec un commentaire.
- Chaque levée d'alerte est tracée dans la piste d'audit avec son auteur et son motif.
- L'onglet Fiscalité passe du résultat comptable au résultat fiscal par réintégrations et déductions, calcule l'impôt sur les sociétés avec le minimum de perception, et génère l'écriture d'impôt.
- Les états financiers SYSCOHADA sont générés depuis la balance par une table de correspondance versionnée, avec deux contrôles de cohérence, puis exportés en PDF et dans la liasse DGI Excel, macros conservées.

## 10 · Arrêté définitif et exercice suivant

- Sur SA Alpha Services, l'exercice 2026 est entièrement clôturé : les états financiers sont marqués arrêtés et les deux contrôles de cohérence sont verts.
- L'arrêté définitif est réservé à l'associé. L'exercice devient intangible : plus aucune réouverture, états financiers, grand livre et balance archivés avec leurs empreintes SHA-256.
- L'exercice 2027 est ouvert avec ses à-nouveaux générés par tiers, le résultat en instance d'affectation, puis l'affectation : réserve légale et report à nouveau.

## Sécurité, cloisonnement et piste d'audit

- Le rôle d'associé impose la vérification en deux étapes : à la première connexion, une application d'authentification est enrôlée par QR code ou clé manuelle.
- Toute action sensible alimente une piste d'audit en ajout seul, chaînée par empreintes SHA-256. Vérifier la chaîne confirme qu'aucune ligne n'a été altérée.
- Les droits reposent sur les affectations collaborateur, dossier, rôle, appliquées par la base elle-même : un cabinet ne voit jamais les données d'un autre.
- Les scénarios pas à pas, les décisions prises pendant le développement et les questions encore ouvertes sont dans le dossier docs du dépôt. Bonne recette.
