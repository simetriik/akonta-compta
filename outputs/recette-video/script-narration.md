# Script de narration — vidéo de recette Akonta

## Avant de commencer · accéder à Akonta en équipe

- Bienvenue dans la recette interne d'Akonta. Cette vidéo montre d'abord comment accéder à l'application sur le réseau local, puis déroule le parcours complet avec la nouvelle interface.
- Un poste héberge l'instance de recette. Il lance le script lancer-réseau, qui affiche une adresse du type http, l'adresse IP du poste, deux-points huit mille quatre-vingts. Chaque collègue l'ouvre dans son navigateur.
- Chacun joue un rôle réel. Si vous jouez deux rôles, ouvrez une fenêtre privée par rôle. Les mots de passe sont fixés par le poste hôte, car les e-mails d'invitation arrivent dans sa boîte de test.
- En http, le navigateur refuse la caméra : pour la capture de pièce, déposez une photo existante. Si la page ne s'ouvre pas, le pare-feu du poste hôte doit autoriser le port. Toutes les données sont fictives.

## 1 · Connexion et tableau de bord

- Chaque collaborateur se connecte avec son adresse e-mail et un mot de passe d'au moins douze caractères. Nous commençons avec le chef de mission.
- Le tableau de bord résume les brouillards, les écritures non revues, celles à corriger et les pièces en attente, puis liste les dossiers affectés. Le dossier courant se change en haut à gauche, ou avec Contrôle K.

## 2 · Dossiers et exercices

- Un dossier est une entité et un exercice. La liste rappelle la forme juridique, l'IFU et la longueur fixe des comptes, figée dès que le plan existe.
- La fiche reprend les champs d'identification de la liasse DGI : dénomination, siège, IFU, RCCM, régime fiscal, activité et paramètres comptables.
- L'onglet Exercices et périodes montre le verrouillage mensuel. Sur SARL Démo Distribution, janvier, février et mars sont verrouillés ; le déverrouillage est réservé à l'associé, avec motif consigné.

## 3 · Saisie, validation et revue

- Le module Saisie liste le brouillard et les écritures validées, filtrables par statut. Chaque statut a sa couleur et son mot : brouillard en gris, validée en vert, revue en violet, à corriger en rouge.
- L'éditeur est pensé pour le clavier : en-tête, puis une grille sans cadres, comme un tableur. Tabulation passe à la cellule suivante, Contrôle B appelle la contrepartie, Contrôle S enregistre le brouillard.
- Un modèle remplit les lignes à partir d'un montant. La barre du bas indique en permanence l'équilibre, ou l'écart avec le côté dominant ; tant qu'il y a un écart, le bouton Valider l'écriture reste inactif.
- La validation est une fonction de la base : elle contrôle l'équilibre, la période et les comptes, puis attribue le numéro sans trou. Une écriture validée ne se modifie plus : on la contre-passe.
- Le chef de mission revoit chaque écriture validée : conforme, ou à corriger avec un commentaire obligatoire.
- Le statut de revue et le commentaire apparaissent dans la liste, et le tableau de bord compte les écritures à reprendre.

## 4 · Consultation

- Le grand livre, les balances et le centralisateur sont calculés à la demande par la base. Chaque compte affiche ses mouvements, son total et son solde, écrit sans signe moins, suivi de D pour débiteur ou C pour créditeur.
- La balance générale présente ouverture, mouvements et clôture par classe, se compare à l'exercice précédent et s'exporte. Les mêmes calculs alimentent les états financiers.

## 5 · Pièces justificatives

- Les pièces, PDF ou photos, arrivent du bureau ou du mobile dans une boîte de réception, puis sont rattachées aux écritures. Chaque fichier reçoit une empreinte numérique ; une pièce rattachée à une écriture validée ne se supprime pas.

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

## 10 · Arrêté définitif

- L'arrêté définitif est réservé à l'associé et ne s'ouvre qu'après la clôture provisoire : il rend l'exercice intangible, sans réouverture possible. Ici des brouillards restent à valider : ce déroulé est à faire pendant la recette, aux étapes onze et douze.

## Sécurité, cloisonnement et piste d'audit

- Le rôle d'associé impose la vérification en deux étapes : à la première connexion, une application d'authentification est enrôlée par QR code ou clé manuelle.
- Toute action sensible alimente une piste d'audit en ajout seul, chaînée par empreintes SHA-256. Vérifier la chaîne confirme qu'aucune ligne n'a été altérée.
- Les droits reposent sur les affectations collaborateur, dossier, rôle, appliquées par la base elle-même : un cabinet ne voit jamais les données d'un autre.

## Tablette et mobile

- Sur tablette, le rail se réduit à des icônes avec infobulles, et les contrôles passent à quarante-huit pixels pour le toucher.
- Sur mobile, le tableau de bord tient en une colonne, avec les mêmes compteurs que sur ordinateur.
- Sur mobile, une barre d'onglets basse donne accès aux pièces, à l'accueil, à la saisie et à la consultation ; le reste est dans le menu.

## Noter une anomalie

- Pour chaque écart, notez l'étape, votre rôle, ce que vous attendiez et ce que vous avez vu, avec une capture. Classez-la : bloquante, majeure, mineure, ou ergonomie.
- Les treize étapes, le jeu de données et les écarts déjà connus sont dans le dossier docs et le dossier recette du dépôt. Bonne recette.
