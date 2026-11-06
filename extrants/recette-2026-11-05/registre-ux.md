# Registre des défauts d'expérience utilisateur – recette du 05/11/2026

**Méthode réellement employée.** Balayage statique du code des écrans (`app/lib/src/presentation`) avec des scanners ciblés sur les familles du cadrage, recoupé avec les trois retours de la recette (points 6, 7, 8). **Je n'ai pas fait le parcours manuel des 19 écrans sur une pile en marche** (créer un dossier, saisir dix écritures, exporter, clôturer) : ce parcours reste à faire pour les familles 5 (clavier), 7 (cohérence visuelle) et 8 (états vide/chargement/erreur), que seules les gardes automatiques existantes (`design_guard_test`, goldens) couvrent.

Familles : 1 rupture de parcours · 2 éléments inertes · 3 absence de retour/double clic · 4 données mal affichées · 5 clavier · 6 messages/confirmations · 7 cohérence · 8 états.

| Id | Écran | Description | Fam. | Gravité | Correction | Statut |
|---|---|---|---|---|---|---|
| UX-01 | Tableau de bord | La carte d'un dossier ne faisait que le sélectionner : rien ne s'ouvrait (bug du point 7). | 2 | bloquant | Clic ou Entrée = dossier courant + ouverture de sa fiche. Test `dashboard_open_dossier_test`. | corrigé |
| UX-02 | Liste des dossiers | Ouvrir une fiche ne rendait pas le dossier courant (incohérent avec UX-01). | 2 | gênant | Même comportement que le tableau de bord. | corrigé |
| UX-03 | Assistant de création de dossier | Double clic possible, deux dossiers « Maître ASSANI » créés (point 8). | 3 | bloquant | Garde anti-double soumission, libellé « Création en cours… », idempotence serveur (`request_id`), refus des homonymes sans IFU. Tests `entity_duplicates_test` + pgTAP 410. | corrigé |
| UX-04 | Grille de saisie | Il fallait quitter la saisie pour créer un tiers ou un compte manquant (point 6). | 1 | bloquant | Ligne « Créer ce tiers / ce compte » + panneau léger, retour sur la même ligne. Tests `quick_create_test`. | corrigé |
| UX-05 | Tous les écrans (≈25 boutons) | Boutons d'action asynchrone sans état « en cours » : comptes, journaux, taux, modèles, exercices, inventaire, équipe, clôture… un second clic relançait l'action. | 3 | gênant | Correction à la source dans `AkButton` : désactivé avec sablier tant que l'action asynchrone n'est pas finie, réactivé même en cas d'échec. Test `button_pending_test`. | corrigé |
| UX-06 | Consultation : balance | Les lignes de la balance n'étaient pas cliquables : pour voir le détail d'un compte, il fallait ressaisir le filtre du grand livre. | 1 | gênant | Clic sur un compte = grand livre filtré sur ce compte. Test `balance_drilldown_test`. | corrigé |
| UX-07 | Saisie, Pièces, Inventaire (régularisations), Dossier (dirigeants), Cabinet (affectations) | Suppression sans confirmation (dont le **brouillard d'écriture** et une pièce), et, pour trois d'entre elles, aucune erreur affichée en cas d'échec. | 6 | bloquant (brouillard) / gênant | `showAkConfirm` avant chaque suppression, erreurs via `showError`. Garde-fou `confirm_guard_test` (échoue si une suppression d'écran n'est pas précédée d'une confirmation). | corrigé |
| UX-08 | Grand livre (écran, PDF, Excel) | Colonne Tiers : le code (« 4011 ») au lieu du nom. | 4 | gênant | Traité avec le point 2. | voir point 2 |
| UX-09 | Test `password_test` | Le test du tableau de bord vide ne connaissait pas le message « Compte sans rôle » (D-049) : suite rouge sur `main`. | – | gênant (qualité) | Test mis à jour (avec un rôle) et cas « sans rôle » ajouté. | corrigé |
| UX-10 | Dépôt | `.env` à la racine : sa première ligne n'est pas commentée, la CLI Supabase refuse de démarrer (« failed to parse environment file »). Contourné en lançant la CLI depuis une copie de `supabase/`. | – | gênant (outillage) | Non modifié (un `.env` ne se touche pas sans ton accord) : préfixer la ligne 1 par `#`. | à décider |
| UX-12 | Consultation (onglets Contrôles et Piste d'audit) | Les filtres de comptes et de classe, au-dessus des onglets, ne servent pas à ces deux onglets. | 7 | cosmétique | Non corrigé : masquer les filtres selon l'onglet. | reporté (coût faible, à grouper avec UX-11) |
| UX-11 | Tous | Parcours manuel des 19 écrans, clavier intégral de la saisie, états vide/chargement/erreur par liste. | 5, 7, 8 | – | Non réalisé dans cette session. | reporté |

## Résumé
- Défauts relevés : 12. Bloquants : 4 (UX-01, 03, 04, 07-brouillard), tous corrigés. Gênants : 6 corrigés, 1 traité au point 2, 1 outillage à décider. Cosmétique : 1 relevé (UX-12), reporté.
- Reporté : UX-11 (parcours manuel) – il demande une session de recette sur une pile en marche avec captures.
