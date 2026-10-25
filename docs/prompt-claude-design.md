# Prompt pour Claude Design — écrans d'Akonta

> À coller tel quel dans Claude Design, avec le kit logo (`outputs/logo-akonta/`) en pièce jointe. Les interfaces Flutter actuelles sont fonctionnelles et sobres ; ce prompt sert à produire la maquette cible, écran par écran, pour desktop et mobile. Source des règles : `inputs/conception.md` §8 à §10.

---

## Contexte

Tu conçois l'interface d'**Akonta**, logiciel de comptabilité conforme au SYSCOHADA révisé, utilisé par un cabinet d'expertise comptable béninois (ABC Expertise Comptable) pour tenir les comptes de ses entreprises clientes. Il remplace Perfecto, un logiciel de bureau vieillissant. Les utilisateurs sont des comptables : saisie intensive au clavier toute la journée sur desktop, consultation et capture de pièces sur mobile.

**Identité** : marque « akonta » en minuscules, symbole tête d'éléphant (« un éléphant n'oublie jamais » : aucune écriture ne se perd). Palette : encre `#1A1A18` (texte), terracotta `#B5472A` (couleur de marque, actions principales), sable `#F7F3EC` (fonds). Typographie Poppins pour les titres, police système lisible pour les tableaux de chiffres (chiffres tabulaires obligatoires). Interface **en français**, montants en FCFA entiers avec séparateur de milliers (espace fine), dates jj/mm/aaaa.

**Principes non négociables**
1. Le **dossier courant** (entité + exercice, ex. « SARL Démo Distribution · 2026 ») est visible en permanence dans la barre supérieure, avec un sélecteur rapide.
2. **Statuts colorés** partout où une écriture apparaît : brouillard (ambre), validée (vert), revue (bleu), à corriger (rouge). Même code couleur sur mobile.
3. Desktop = densité élevée, tableaux, raccourcis clavier affichés ; mobile = une tâche par écran, gros boutons, mode hors connexion toléré (file d'attente des photos).
4. Ne jamais proposer de supprimer une écriture validée : seule la contre-passation existe. Les actions irréversibles (arrêté définitif, déverrouillage) exigent une confirmation explicite avec motif.
5. Accessibilité : contraste AA, focus visible, navigation clavier complète sur desktop.

**Rôles** (déterminent ce qui est visible) : Stagiaire (brouillards et consultation), Assistant (saisie, validation de ses écritures, lettrage, rapprochement, pièces, inventaire), Chef de mission (tout ce qui précède + revue, référentiels, dossiers, clôture provisoire, états, import), Associé (tout + paramètres, affectations, arrêté définitif, piste d'audit ; TOTP obligatoire), Administrateur technique (utilisateurs et sécurité uniquement, aucune donnée comptable ; TOTP obligatoire).

## Gabarit général

- **Desktop (≥ 1200 px)** : rail de navigation gauche (icône + libellé) : Tableau de bord, Dossiers, Saisie, Consultation, Pièces, Lettrage, Rapprochement, Inventaire, Clôture, Référentiels, Import Perfecto, Cabinet, Utilisateurs. Barre supérieure : logo, sélecteur de dossier courant, recherche globale (montant, libellé, compte, tiers, n°), notifications (écritures « à corriger » pour l'auteur), menu utilisateur (rôle, déconnexion). Le contenu est un « document » sur fond sable avec cartes blanches.
- **Mobile** : barre inférieure à 4 entrées : Dossiers, Pièces (capture), Consultation, Plus. Le dossier courant est rappelé sous le titre de chaque écran.

## Écrans par module

### Module 1 — Socle
- **Connexion** : e-mail, mot de passe (12 caractères min., indicateur), « mot de passe oublié ». Écran de **vérification TOTP** (6 chiffres, grand champ) et écran d'**activation TOTP** (QR code + clé manuelle + code de confirmation), avec mention « obligatoire pour votre rôle » quand c'est le cas.
- **Déconnexion pour inactivité** : bandeau d'avertissement 1 minute avant, puis retour à la connexion.
- **Utilisateurs** (administrateur) : liste des collaborateurs (nom, e-mail, fonction, actif/désactivé), bouton « Inviter » (e-mail, nom, fonction), « Importer un CSV eABC » avec rapport (invités / échecs / lignes ignorées), interrupteur de désactivation (jamais de suppression).
- **Piste d'audit** (associé) : journal filtrable (action, dossier, période, auteur), chaque ligne montre l'empreinte tronquée, bouton « Vérifier la chaîne » avec résultat intègre / rompue.

### Module 2 — Cabinet et dossiers
- **Tableau de bord** : une carte par dossier affecté : nom + exercice, chef de mission, dernier mois saisi, compteurs brouillards / non revues / à corriger / pièces en attente, rapprochements en retard. Tri et filtre par chef de mission. Clic = devient le dossier courant.
- **Assistant d'ouverture** en 5 étapes avec fil d'Ariane : 1 fiche entité (blocs R1 identification, R2 activité, R3 dirigeants, paramètres comptables : longueur des comptes, verrouillage mensuel) ; 2 exercice (dates, capital, associés et parts, effectif) ; 3 plan de comptes (copié automatiquement, aperçu, possibilité de subdiviser) ; 4 journaux (modèle du cabinet coché par défaut, AN imposé, choix du compte pour banque et caisse) ; 5 soldes d'ouverture (import Perfecto / saisie / plus tard).
- **Fiche dossier** : onglets Fiche, Dirigeants, Exercices et périodes (grille de 12 mois, cadenas ouvert/fermé, déverrouillage avec motif réservé à l'associé), Historique des modifications.
- **Paramètres cabinet** (associé) : raison sociale, logo, coordonnées, longueur des comptes par défaut, durée d'inactivité, modèle de journaux, modèles d'écritures du cabinet, rôles × permissions (matrice de cases à cocher), affectations (par dossier et par collaborateur, réaffectation en masse).

### Module 3 — Référentiels (par dossier)
- **Plan de comptes** : arbre indenté par niveau, recherche par numéro ou intitulé, filtre par classe, badge collectif / lettrable / sens ; action « Subdiviser » (le numéro saisi est complété à la longueur fixe, aperçu du résultat), renommer, désactiver ; suppression grisée avec info-bulle si mouvements.
- **Tiers** : liste (code, nom, type, collectifs, IFU), fiche en tiroir latéral, rattachement à un ou plusieurs collectifs par puces.
- **Journaux** : liste avec type et compte de trésorerie ; AN verrouillé.
- **Modèles d'écritures** : cartes dépliables montrant les lignes (compte, sens, formule : saisie / % d'une ligne via un taux nommé / solde) ; éditeur de modèle en tableau.
- **Taux** : tableau code, libellé, taux, validité ; nouvelle valeur datée.

### Module 4 — Saisie (cœur desktop)
- **Liste des écritures** : barre de filtres (journal, mois avec flèches, segments Toutes / Brouillards / Validées / À revoir, recherche), lignes compactes (date, n° journal-numéro, libellé, montant, statut coloré, icônes « générée » et « contre-passée »), cases à cocher pour **validation par lot**, menu contextuel (revue, contre-passation).
- **Grille de saisie par journal et par mois** : en-tête (journal, date, référence pièce, libellé) puis tableau de lignes : compte (autocomplétion numéro/intitulé), tiers (actif seulement sur collectif), libellé, débit, crédit. Tab passe à la cellule suivante, Entrée en fin de ligne ajoute une ligne, Ctrl+B pose la contrepartie, Ctrl+S enregistre, Ctrl+Entrée valide. Pied : totaux débit / crédit et pastille « Équilibrée » / « Écart 180 000 ». Panneau latéral : pièce justificative affichée à côté (visionneuse), erreurs de validation listées en clair.
- **Saisie par pièce** (formulaire) : même contenu en vertical pour une écriture isolée ; bouton « Modèle » (choix + montant de base → lignes pré-remplies avec TVA / retenues).
- **Revue** (chef de mission) : file « à revoir », dialogue Revue / À corriger (commentaire obligatoire) / Non revue ; l'auteur reçoit une notification.
- **Contre-passation** : dialogue motif + date, confirmation ; l'écriture inverse apparaît liée (icône, lien vers l'originale).
- **Mobile** : consultation d'une écriture, validation simple d'un brouillard (bouton unique), pas de grille.

### Module 5 — Pièces justificatives
- **Mobile (écran principal)** : bouton caméra plein écran, recadrage, choix du dossier, envoi en arrière-plan avec file d'attente hors connexion et indicateur ; la pièce arrive dans la boîte de réception du dossier.
- **Desktop** : boîte de réception (vignettes, date, taille, canal), glisser-déposer, rattacher à une écriture (recherche), « créer un brouillard avec cette pièce », visionneuse à côté de l'écriture, empreinte SHA-256 visible dans les détails ; suppression grisée si liée à une écriture validée.

### Module 6 — Consultation
- Barre commune : période (du / au), plage de comptes, classe, « comparer N-1 », bouton Exporter (PDF / Excel).
- **Grand livre** : groupé par compte, solde progressif, clic sur une ligne ouvre l'écriture et sa pièce. **Balance générale** : ouverture / mouvements / clôture + colonne N-1. **Balance auxiliaire** par collectif et tiers. **Balance âgée** : segments clients / fournisseurs, tranches 0-30, 31-60, 61-90, 91-180, > 180 jours, totaux. **Journal** et **Centralisateur** (journal × mois).
- Mobile : balance et grand livre d'un compte en lecture, recherche.

### Module 7 — Lettrage et rapprochement (lot 2)
- **Lettrage** : écran par compte de tiers : deux colonnes débit / crédit, sélection multiple, total sélectionné et écart, propositions automatiques (même tiers et montant, facture = règlement + retenues) à confirmer d'un clic, lettrage partiel signalé, délettrage avec confirmation.
- **Rapprochement** : import du relevé (gabarit de colonnes mémorisé par banque, aperçu), vue en deux volets relevé / comptabilité avec pointage 1-1 ou plusieurs-à-plusieurs, propositions (montant et date ± 5 jours), état mensuel (solde banque, solde comptable, écart = 0 en vert), « créer l'écriture » depuis une ligne non pointée, bouton « Figer et archiver en PDF ».

### Module 8 — Travaux d'inventaire (lot 3)
- **Immobilisations** : registre, fiche (composants, méthode, durée, tableau prévisionnel), cession / rebut avec plus ou moins-value, bouton « Générer les dotations » (écritures en brouillard « générée »).
- **Stocks** : saisie du stock final par compte, variations générées. **Provisions** : balance âgée → taux par tiers → dotations / reprises par différence, tableau des provisions. **Régularisations** : assistant CAP / PAR / CCA / PCA avec prorata au jour, aperçu de l'écriture au 31/12 et de l'extourne au 01/01. **Écarts de conversion** : lignes en devises non lettrées, cours de clôture, écritures 478 / 479 et provision.

### Module 9 — Clôture (lot 3)
- **Assistant de clôture** en étapes : Contrôles (bloquants en rouge, alertes levables avec commentaire par le chef de mission) → Inventaire (rappel des travaux) → Fiscalité (tableau de passage éditable, IS avec minimum, acomptes, écriture d'IS) → États financiers (bilan, compte de résultat, TFT, notes, fiches R ; contrôles de cohérence ; export modèle Excel DGI + PDF) → Clôture provisoire (réouverture possible avec motif) → Arrêté définitif (associé, double confirmation, archivage avec empreintes, exercice en lecture seule).
- **Ouverture N+1** : à-nouveaux provisoires recalculés tant que N n'est pas arrêté, écriture d'affectation du résultat.

### Module 10 — Import Perfecto
- Écran en 4 temps : fichier (texte Perfecto ou balance), analyse (journal source, période, lignes, pièces, erreurs de sous-total), **table de correspondance éditable** (compte Perfecto → compte Akonta + tiers à créer, lignes inconnues surlignées), essai (rapport : écritures qui seraient créées, tiers, erreurs) puis import réel (grisé tant que l'essai a des erreurs). Historique des lots.

## Livrables attendus
1. Système de composants (couleurs, typographie, boutons, champs, tableaux denses, puces de statut, cartes de dossier, cadenas de période).
2. Maquettes desktop haute fidélité des écrans : connexion + TOTP, tableau de bord, assistant d'ouverture (5 étapes), grille de saisie, liste des écritures, consultation (balance et grand livre), pièces, import Perfecto, lettrage, rapprochement, assistant de clôture.
3. Maquettes mobile : connexion, capture de pièce, boîte de réception, consultation d'un compte, validation d'un brouillard.
4. Flux annotés : saisie → validation → revue → correction par contre-passation ; capture mobile → rattachement desktop.
