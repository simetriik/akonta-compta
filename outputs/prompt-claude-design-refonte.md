# Refonte de l'interface d'Akonta — système de design puis maquettes, écran par écran

## 1. Le produit
Akonta est un logiciel comptable conforme au SYSCOHADA révisé (OHADA), utilisé par un cabinet d'expertise comptable au Bénin. Application Flutter : bureau, tablette et mobile, avec un mode hors ligne. Les utilisateurs sont des comptables, des associés et des collaborateurs qui saisissent au clavier plusieurs heures par jour. Les montants sont des entiers en FCFA. L'interface est en français, avec les dates au format jj/mm/aaaa et les milliers séparés par une espace fine insécable.

Le dossier courant (entité + exercice, par exemple « SARL Démo Distribution · 2026 ») doit rester visible en permanence, avec un sélecteur rapide.

## 2. Identité visuelle (validée, non négociable)
- Esprit : sérieux et rassurant comme une banque, mais moderne et léger (références : Qonto, Stripe).
- Bleu nuit `#1E2A5A` : couleur dominante (marque, textes forts, navigation).
- Orange chaud `#F28C28` : accents uniquement (bouton principal, mise en avant, focus éventuel), jamais en grande surface.
- Gris neutres pour l'interface. Pas de vert de marque : le vert est réservé au statut « validée » et aux succès.
- Logo : éléphant dont la trompe forme le A. Version bicolore (A orange, oreilles bleu nuit) uniquement pour l'accueil et la connexion. Version toute bleue pour les petites tailles et les documents. Ne jamais mélanger les deux sur un même écran. Fichiers joints : `akonta-logo-horizontal-v3.svg`, `akonta-symbole-bleu-orange.svg`, `akonta-symbole-bleu.svg`.
- Abandonner entièrement l'ancienne direction terracotta et sable (`#B5472A`, `#F7F3EC`) : aucune trace dans les maquettes.
- Polices : garder IBM Plex Sans (interface) et IBM Plex Mono (montants, codes), déjà embarquées dans l'application. Poppins reste facultatif, pour le mot « akonta » et le titre d'écran. Ne pas introduire d'autre famille. Si tu veux changer de police, dis-le explicitement avec la raison.

## 3. Ce qui existe déjà (à respecter)
L'application possède déjà un système de design centralisé dans un seul dossier : jetons de couleur, de typographie, d'espacement et de rayons, thèmes clair et sombre, 25 composants, et un test qui interdit les couleurs en dur et les textes de moins de 14 px hors de ce dossier. La refonte doit donc se traduire en nouvelles valeurs de jetons et en retouches de composants, sans toucher aux écrans. Tout ce que tu proposes doit pouvoir s'exprimer ainsi : couleurs, typographie, espacements, rayons, ombres, hauteurs de contrôles, largeurs de colonnes et de dialogues, tailles d'icônes, seuils de mise en page. Les captures jointes montrent l'état actuel, avec des données de recette.

## 4. Problèmes à résoudre
1. **Hiérarchie plate.** Tout le texte est à 14 px. Propose une échelle typographique avec des rôles distincts : titre d'écran, titre de section, corps, libellé, tableau dense, montant (15–16 px, chiffres tabulaires), chiffre clé (tableau de bord), légende. Donne taille, graisse, interligne et famille de chaque rôle.
2. **Hauteurs de champs incohérentes.** Une seule hauteur de champ par densité (confort / compact), sans exception. Boutons, champs, boutons-icônes, cases et interrupteurs s'alignent sur ces hauteurs.
3. **Trois rendus de tableau.** Définis un seul modèle : en-tête figé, groupes d'en-têtes (Ouverture / Mouvements / Clôture), lignes de section, lignes de total, ligne de total général toujours visible, montants alignés à droite en chiffres tabulaires. Règle unique pour le zéro (afficher ou masquer).
4. **Grille de saisie trop proche d'un formulaire.** Redessine-la comme un tableur : cellules sans bordure, bordure seulement au focus, ligne active mise en évidence, colonne Compte assez large pour l'intitulé complet (aujourd'hui tronqué), colonne Tiers discrète quand elle est vide, repère visuel Débit / Crédit.
5. **Tablette non gérée.** Trois mises en page : mobile (< 600 px), tablette (600–899 px, rail d'icônes de 72 px), bureau (≥ 900 px, rail de 232 px). Précise aussi le comportement au-delà de 1 400 px (aujourd'hui le contenu est plafonné et ne profite pas de l'espace).
6. **Soldes.** Indicateur D/C explicite (« 1 250 000 D » / « 340 000 C »), pas seulement le signe moins. Les débits et crédits doivent se distinguer à la lecture, sans dépendre de la seule couleur.
7. **Retours utilisateur.** Trois mécanismes, avec une règle claire : toast (action terminée), bandeau (état persistant), dialogue (confirmation). Chaque mécanisme a des variantes succès / erreur / info / avertissement.
8. **Sélecteur de dossier.** Liste déroulante sans recherche aujourd'hui. Propose un sélecteur avec recherche, ouvrable au clavier (Ctrl K), utilisable avec 40 dossiers.

## 5. Contraintes
- Contraste WCAG AA minimum (4,5:1 pour le texte, 3:1 pour les bordures de contrôles et icônes porteuses de sens), en thème clair et en thème sombre. Vérifie aussi le texte désactivé, l'anneau de focus et le texte sur toast.
- Un statut n'est jamais porté par la couleur seule : icône + mot. Quatre statuts d'écriture : brouillard, validée, revue, à corriger. Choisis des couleurs qui ne se confondent pas avec la marque bleu nuit et orange, et justifie-les.
- Espacements sur une base de 4. Aucune valeur hors échelle.
- Cibles tactiles de 48 px sur mobile et tablette. Le mode compact (32 px) n'existe qu'à la souris.
- Pas de hauteurs de ligne fixes qui tronqueraient le texte : prévois un texte agrandi à ×1,3.
- Densité forte sur bureau, une tâche par écran sur mobile. Ne jamais proposer de supprimer une écriture validée : seule la contre-passation existe. Les actions irréversibles (arrêté définitif, déverrouillage) demandent une confirmation explicite avec motif.
- Réseau lent : pas d'images lourdes, pas d'effets coûteux, icônes en contour cohérentes.

## 6. Ce que j'attends de toi, dans cet ordre

### Étape A — Le système de design
1. Palette complète en clair et en sombre : marque, neutres, surfaces, bordures, texte (fort, normal, atténué, désactivé), focus, quatre statuts (fond et texte), succès / erreur / avertissement / info. Chaque paire texte/fond avec son ratio de contraste.
2. Échelle typographique avec rôles (voir §4.1).
3. Espacements, rayons, ombres (élévations), hauteurs de contrôles (confort / compact / tactile), largeurs de dialogues S / M / L, tailles d'icônes (16 / 20 / 24), seuils de mise en page, largeurs de colonnes types d'un tableau (date, pièce, compte, libellé, montant).
4. Tout cela sous forme d'une table de jetons nommés avec leurs valeurs, que je puisse transposer telle quelle dans le code.

### Étape B — Les composants
Boutons (primaire, secondaire, discret, danger, bouton-icône), champs (texte, montant, date, compte avec autocomplétion, tiers, liste, case, interrupteur, segmenté), tableau, grille de saisie, badges de statut, cartes indicateurs (chiffre clé + libellé), bandeaux, toasts, dialogues, onglets, rail et barre haute, sélecteur de dossier avec recherche, états vide / chargement / erreur. Pour chacun : états (repos, survol, focus, actif, désactivé, erreur) en clair et en sombre.

### Étape C — Les maquettes, écran par écran
Je valide chaque maquette avant de passer à la suivante. Ordre :
1. **Éditeur d'écriture (saisie)**, l'écran le plus important. 6 à 8 lignes remplies, comptes aux intitulés longs, 2 lignes avec tiers, curseur dans une cellule montant, liste d'autocomplétion de compte ouverte, barre d'équilibre fixe en bas (« Équilibrée » ou « Écart … »), raccourcis visibles (Ctrl B contrepartie, Ctrl S enregistrer, F1 aide). Montre aussi le même écran équilibré, puis une écriture validée en lecture seule avec contre-passation proposée.
2. **Grand livre** : 3 comptes développés dont un à solde créditeur, solde progressif avec D/C, « Comparer N-1 » cochée, filtres remplis, total de compte.
3. **Balance générale** : classes 1 à 7, groupes d'en-têtes Ouverture / Mouvements / Clôture, colonne N-1, total général toujours visible.
4. **Tableau de bord « Mes dossiers »** : 6 dossiers (dont certains avec « À corriger » et pièces en attente), compteurs, sélecteur de dossier ouvert dans la barre haute.
5. **Liste des écritures** : 15 écritures avec les quatre statuts, un filtre actif.
6. **Clôture de l'exercice** : contrôles avec un échec bloquant et un avertissement, génération des états financiers et de la liasse DGI, bouton d'arrêté définitif avec confirmation et motif.
7. **Connexion** (logo bicolore), avec l'étape du code TOTP.
8. **Mobile (390×844)** : écran Pièces avec « Photographier une pièce » et 3 pièces en attente, en clair puis en sombre, cibles de 48 px, rappel du dossier courant.

Pour la tablette (600–899 px), montre seulement le gabarit : rail d'icônes, un écran représentatif, sans refaire les 8 écrans.

## 7. Données d'exemple
Dossier : « SARL Démo Distribution · Exercice 2026 », monnaie FCFA. Écriture de vente, journal VE, pièce FA-0042 : 4111CHU Clients (débit 1 180 000), 7011 Ventes de marchandises (crédit 1 000 000), 4431 TVA facturée (crédit 180 000). Version déséquilibrée pour l'état d'erreur : écart de 180 000. Comptes à intitulé long pour tester la colonne Compte : « 6222 Locations de bâtiments », « 4181 Clients, factures à établir ». Utilise des valeurs plausibles et réalistes, jamais « Lorem ipsum ».

## 8. Pièces jointes
- Logos : `akonta-logo-horizontal-v3.svg`, `akonta-symbole-bleu-orange.svg`, `akonta-symbole-bleu.svg`
- Audit : `audit-design.md`
- Captures actuelles (desktop 1440×900, thème clair, données de recette) : éditeur d'écriture, grand livre, balance, tableau de bord, liste des écritures, clôture, Pièces mobile (clair et sombre)

Commence par l'étape A et attends ma validation avant l'étape B.
