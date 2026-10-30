# Audit du design et de l'interface d'Akonta

Date : 29 octobre 2026. Audit en lecture seule de `app/` (Flutter), état du dépôt au commit `fc8dc47`. Aucun fichier de code modifié.

## Constat préalable

Le dépôt contient **déjà un système de design centralisé** (`app/lib/design/`, branche `refonte-ui` fusionnée) : jetons, thème clair et sombre, 25 composants `Ak*`, un catalogue, des goldens, et un test garde-fou (`app/test/design_guard_test.dart`) qui interdit les widgets Material bruts, les couleurs en dur et les textes < 14 px hors de `lib/design/`. La documentation est dans `docs/design/systeme-de-design.md`.

Conséquence : les problèmes ne sont pas « tout est en dur et incohérent ». Ils portent surtout sur **la direction visuelle et l'ergonomie** (voir §5 à 8 et le résumé final), plus quelques écarts de mise en œuvre listés ci-dessous. La refonte avec Claude Design doit donc **remplacer des valeurs de jetons et retoucher des composants**, pas réécrire 17 écrans. Je n'ai pas lancé l'application ; les constats visuels s'appuient sur le code et sur les captures `docs/design/apres/` (goldens, données fictives).

---

## 1. Inventaire des écrans

Routes : `app/lib/src/presentation/router.dart`. Gabarit commun : `shell/app_shell.dart`. Les rôles sont ceux de la conception (comptable de cabinet, associé, collaborateur ; le dirigeant de petite entreprise n'a pas d'écran propre en V1 : « saisie par les clients » est hors V1).

| Écran | Fichier (`app/lib/src/presentation/…`) | Route | Rôle pour l'utilisateur | Actions principales |
|---|---|---|---|---|
| Connexion | `auth/login_screen.dart` | `/connexion` | Entrer dans le cabinet | Se connecter, mot de passe oublié |
| MFA (défi, enrôlement) | `auth/mfa_screens.dart` | `/mfa/*` | Second facteur TOTP | Saisir le code, scanner le QR |
| Tableau de bord « Mes dossiers » | `dashboard/dashboard_screen.dart` | `/` | Vue d'ensemble des dossiers affectés | Voir compteurs (brouillards, à corriger, pièces), ouvrir un dossier |
| Dossiers (liste) | `entities/entities_screen.dart` | `/dossiers` | Parcourir les entités | Ouvrir, créer |
| Assistant d'ouverture | `entities/entity_wizard_screen.dart`, `entity_form.dart` | `/dossiers/nouveau` | Créer entité + exercice | Renseigner, importer Perfecto, saisir à-nouveaux |
| Fiche dossier | `entities/entity_detail_screen.dart` (534 l.) | `/dossiers/:id` | Fiche, dirigeants, exercices, périodes, historique | Créer exercice, verrouiller/déverrouiller période |
| Saisie (liste) | `entries/entries_screen.dart` | `/saisie` | Liste des écritures de l'exercice | Filtrer par statut, nouvelle écriture |
| Éditeur d'écriture | `entries/entry_editor_screen.dart` (747 l.) | `/saisie/nouvelle`, `/saisie/:id` | **Cœur** : saisie au clavier | Remplir lignes, contrepartie, modèle, enregistrer, valider |
| Consultation | `consultation/consultation_screen.dart` (957 l.) | `/consultation` | Grand livre, balances (générale, auxiliaire, âgée), centralisateur | Filtrer, comparer N-1, exporter |
| Pièces | `documents/documents_screen.dart` | `/pieces` | Boîte de réception des justificatifs | Déposer, photographier (mobile), rattacher, ouvrir |
| Lettrage | `lettering/lettering_screen.dart` | `/lettrage` | Apparier lignes de tiers | Choisir un compte, lettrer, délettrer, propositions |
| Rapprochement | `reconciliation/reconciliation_screen.dart` (801 l.) | `/rapprochement` | Relevé bancaire vs comptabilité | Importer, accepter les propositions, état PDF |
| Inventaire | `inventory/inventory_screen.dart` (1 133 l.) | `/inventaire` | Immobilisations, stocks, provisions, régularisations, écarts de conversion | Saisir, générer les écritures (brouillard) |
| Clôture | `closing/closing_screen.dart` (1 080 l.) | `/cloture` | Contrôles, états financiers, liasse DGI, arrêt | Ouvrir les travaux, générer PDF/liasse, arrêter l'exercice |
| Référentiels | `references/references_screen.dart` (1 345 l.) | `/referentiels` | Plan de comptes, tiers, journaux, taux, modèles | Ajouter/modifier lignes |
| Import Perfecto | `imports/import_screen.dart` | `/import` | Reprise d'historique | Choisir fichier, mode essai, importer |
| Cabinet | `admin/cabinet_screen.dart` | `/cabinet` | Paramètres, rôles, affectations, piste d'audit | Éditer, transférer des affectations |
| Collaborateurs | `admin/users_screen.dart` | `/utilisateurs` | Gestion des comptes | Inviter, importer un CSV eABC |
| Catalogue de design | `design/catalog/catalog_screen.dart` | `/catalogue` (debug) | Interne | Aucune |

Les **états financiers** (bilan, compte de résultat) ne sont pas un écran : ils sont produits en PDF/Excel depuis la Clôture (`closing_screen.dart`, service Python). Toute refonte « états financiers » concerne donc les documents PDF (hors Flutter) et l'écran de contrôle de clôture.

Mort-code : `PlaceholderScreen` (`shell/app_shell.dart:329`) n'est plus référencé.

## 2. Parcours principaux

| Tâche | Enchaînement |
|---|---|
| Saisir une écriture | Sélecteur de dossier (barre haute) → rail « Saisie » `/saisie` → « Nouvelle écriture » → `/saisie/nouvelle` : en-tête (journal, date, pièce, libellé) → grille → barre d'équilibre → « Enregistrer » (brouillard) ou « Valider » |
| Consulter le grand livre | Rail « Consultation » → onglet « Grand livre » → filtres (dates, comptes, classe) → « Actualiser » → ouvrir une écriture |
| Balance | Même écran, onglet « Balance générale » (ou auxiliaire, âgée) ; case « Comparer N-1 » |
| États financiers | Rail « Clôture » → contrôles → génération PDF / liasse DGI → arrêt |
| Changer d'entité (cabinet) | Liste déroulante « dossier courant » en barre haute (`app_shell.dart:305`) **ou** carte du tableau de bord ; sur mobile, même liste dans l'`AppBar` |
| Capturer une pièce (mobile) | Barre basse « Pièces » → « Photographier » → rattacher |

Point faible : le sélecteur de dossier est une liste déroulante simple, sans recherche. Un cabinet à 40 dossiers (`entityDashboardProvider`, tout chargé) la rend pénible.

## 3. Thème actuel

Sources : `app/lib/design/tokens.dart` (jetons), `theme.dart` (ThemeData). `MaterialApp.router` : thème clair/sombre, `ThemeMode.system` (`app.dart:28`).

| Famille | Valeur | Origine |
|---|---|---|
| Marque | terracotta `#B5472A` (survol `#963A22`) | `AkTokens` (ThemeExtension), centralisé |
| Neutres | fond sable `#F7F3EC`, surface `#FFFFFF`, creux `#EFE8DC`, encre `#1A1A18`, atténué `#6B645A` | `AkTokens.light` |
| Statuts | brouillard `#8A5A00`, validée `#2E6B3F`, revue `#2B5B84`, à corriger `#A4133C` (+ teintes) | `AkTokens` |
| Thème sombre | jeu complet distinct | `AkTokens.dark` |
| Polices | IBM Plex Sans (interface), IBM Plex Mono (montants, codes), Poppins SemiBold (titre d'écran + wordmark) | `AkFonts`, `pubspec.yaml`, assets locaux |
| Tailles | 24 titre / 18 / 16 / **14 pour tout le reste** (corps, libellé, légende, tableau, montant) | `AkText` |
| Espacements | base 4 : 4, 8, 12, 16, 20, 24, 32, 48 ; contrôle 40 (48 tactile, 32 dense) | `AkSpace` |
| Rayons | 2 (badges), 4 (champs, boutons), 6 (cartes, dialogues) | `AkRadius` |
| Ombres | une seule (`AkShadow.overlay`), menus et dialogues ; cartes sans ombre | `AkShadow`, thème |
| Rail / barre haute / page | 232 px / 56 px / 1 400 px max | `AkSpace` |

Ce qui est écrit **en dur dans les widgets** (hors thème) :

| Valeur | Où |
|---|---|
| `Colors.white` (fond du QR) | `auth/mfa_screens.dart:127` (toléré par le garde-fou) |
| `fontSize: 24` + `height` + `w600` sur un montant | `dashboard/dashboard_screen.dart:95` (style « chiffre clé » inexistant dans `AkText`) |
| Remplissages 6, 10, 2, 4 px, `SizedBox(width: 6/10)` | `shell/app_shell.dart:157,159,182,196,199,279`, `entries/entry_editor_screen.dart:245,343`, `closing_screen.dart:225`, `entries_screen.dart:452`, `documents_screen.dart:226` : hors échelle de 4 (`design_tokens_test.dart` ne vérifie que les constantes) |
| Largeurs de colonnes et de champs (≈ 157 occurrences de `width/height: NN`) | tous les écrans ; ex. grille de saisie `entry_editor_screen.dart` : index 32, compte 260, tiers 130, montant 150, suppression 40, largeur min 960 |
| Largeurs de dialogues : 380, 420, 460, 520, 560, 760 | `users_screen.dart:197`, `cabinet_screen.dart:285,355`, `reconciliation_screen.dart:520,607,748`, `documents_screen.dart:320,373`, `references_screen.dart:76`, `entry_editor_screen.dart` |
| Seuils responsives : 600, 620, 640, 720, 840, 900, 1000 | cf. §7 |
| Tailles d'icône : 14, 16, 18, 20, 28 | partout |
| Couleur d'erreur d'un SnackBar posée au cas par cas | `consultation_screen.dart:231` |

## 4. Composants

Réutilisables (`app/lib/design/components/`) :

| Besoin | Composant | Fichier |
|---|---|---|
| Boutons | `AkButton` (5 variantes), `AkIconButton` | `buttons.dart` |
| Champs | `AkTextField`, `AkAmountField`, `AkDateField`, `AkDropdown`, `AkAccountField`, `AkThirdPartyField`, `AkAutocompleteField`, `AkCheckbox`, `AkSwitch`, `AkSegmented` | `fields.dart` (858 l.) |
| Tableau | `AkTable` / `AkColumn` | `table.dart` |
| Structure | `AkCard`, `AkPage`, `AkPageHead`, `AkSectionTitle`, `AkDialog`, `showAkConfirm` | `layout.dart`, `dialog.dart` |
| Retours | `AkBanner`, `AkErrorMessage`, `AkEmptyState`, `AkLoading`, `AkBadge`, `AkStatusBadge`, `AkKbd`, `AkAmountText`, `AkAvatar` | `feedback.dart` |
| Logo | `AkLogo` | `logo.dart` |
| Chargement asynchrone | `AsyncView` | `presentation/widgets/async_view.dart` |

Éléments **refaits localement** (doublons à fusionner dans `lib/design/`) :

| Élément | Où | Remarque |
|---|---|---|
| Grille de données paresseuse `_DataGrid`, `_Col`, `_GRow`, `_txt`, `_codeTxt`, `_amt` | `consultation_screen.dart:266-422` | Duplique `AkTable` (en-têtes de groupe, lignes de section/total, `ListView.builder`). Trois onglets l'utilisent, deux autres (`_AgedTab`, `_AuxiliaryTab`) passent par `AkTable` : **deux rendus de tableau différents dans le même écran**. Connu : `docs/design/systeme-de-design.md`, « Écarts connus ». |
| Grille de saisie (`_GridHeader`, `_LineRow`, pied de totaux) | `entry_editor_screen.dart` | Troisième implémentation de « tableau avec en-tête et pied », pied recodé à la main (filet 2 px identique à `AkTable`) |
| `_SearchField`, `_toolbarDropdown`, `_ListRow`, `_InactiveBadge` | `references_screen.dart:116-175` | Barre d'outils et ligne de liste propres à un écran ; utiles ailleurs (Lettrage, Pièces) |
| `_FieldRow` | `entities/entity_form.dart:229` | Mise en grille de formulaire à deux colonnes |
| `_RailItem`, `_Rail`, `_TopBar`, `_UserMenu`, `_CurrentEntitySelector` | `shell/app_shell.dart` | Cohérents, mais non exposés : pas de rail réutilisable pour une tablette |
| Cartes de totaux (point + libellé + chiffre) | `dashboard_screen.dart:63-110` | Pas de composant « indicateur » |
| Pastille de solde (équilibrée / écart) | `entry_editor_screen.dart:423` | Bandeau d'équilibre dédié |
| Bascule sens débit/crédit, filtres d'état | `AkSegmented` | Utilisé 3 fois seulement ; `FilterChip`, `RadioListTile` cités dans la doc mais non repérés dans le code actuel |

Widgets Material encore utilisés directement (thémés mais hors garde-fou) : `TabBar` (`consultation_screen.dart:97`, `cabinet_screen.dart:33`, `inventory_screen.dart:97`), `ListTile` (`cabinet_screen.dart:235,480`, `users_screen.dart:238`), `PopupMenuButton` (`app_shell.dart:271`, `consultation_screen.dart:181`), `NavigationBar` et `Drawer` (mobile, `app_shell.dart`), `SnackBar` (37 appels), `Badge`, `RefreshIndicator`, `Scaffold`. Le style du `TabBar` vient bien du thème ; les autres ne passent pas par un composant maison.

## 5. Incohérences

| Constat | Fichiers |
|---|---|
| **Deux rendus de tableau** dans Consultation (`_DataGrid` pour grand livre/balance/centralisateur, `AkTable` pour les autres) : hauteurs, filets et marges de première colonne (16 px vs 12 px) différents | `consultation_screen.dart:282`, `table.dart` |
| **Retours utilisateur hétérogènes** : `SnackBar` (37 appels, mélange de messages d'erreur et de confirmation, une couleur d'erreur posée à la main) à côté de `AkBanner` et `AkErrorMessage` | `consultation_screen.dart:228-231`, `cabinet_screen.dart:111,120,386` |
| Texte d'un montant **à 0 affiché ou masqué selon l'écran** : la grille de saisie montre « 250 000 » dans une seule des deux colonnes, le pied de totaux et « Total compte » affichent `0` (`showZero`) | `formatting.dart:11`, capture `04-grand-livre.png` |
| **Spécial-cas de style** hors échelle : chiffre clé 24 px du tableau de bord, poids `w600` ajouté ici et là, rail à 10 px de marge | `dashboard_screen.dart:95`, `app_shell.dart:159,205` |
| Boutons : libellés d'un même geste différents (« Déposer » primaire/secondaire selon plateforme, « Fermer » primaire dans des dialogues d'information, « Valider » dans trois contextes distincts) | `documents_screen.dart:56`, `cabinet_screen.dart`, `inventory_screen.dart`, `references_screen.dart` |
| Tailles d'icône sans règle : 14, 16, 18, 20, 28 | partout |
| **Largeurs de dialogues** toutes différentes (380 à 760) et deux formules pour s'adapter au mobile (`size.width - 80`) | cf. §3 |
| **Rôles de la hiérarchie typographique** : légende, corps, libellé, tableau, code et montant font tous 14 px ; seul le poids ou la famille les distingue. La hiérarchie visuelle passe par le gras et la couleur atténuée | `tokens.dart` `AkText` |
| Contrôles actifs : `AkIconButton` tient 40 px (32 en dense), la case à cocher et le commutateur dépendent du thème Material | `buttons.dart:118`, `fields.dart` |

Ce qui est **bon** : aucune couleur codée en dur hors un blanc de QR, aucun widget brut de champ/bouton/dialogue/tableau, aucun `fontSize` < 14 (sauf le test qui le vérifie, qui est vert).

## 6. Tableaux et saisie

### Montants
- Entiers FCFA, séparateur de milliers **insécable fine** : `NumberFormat('#,##0', 'fr_FR')` (`core/formatting.dart:5`). Pas de symbole « FCFA » dans les cellules ; l'unité est portée par les en-têtes (« Débit (FCFA) ») et par `suffixText: 'FCFA'` dans les champs hors grille (`fields.dart`, désactivé en `dense`).
- Alignement à droite, **IBM Plex Mono à chiffres tabulaires** (`AkText.amount`, `AkAmountText`) : colonnes propres.
- Zéro affiché vide dans les colonnes débit/crédit (`Fmt.fcfa`), sauf pieds de totaux (`showZero: true`). **Négatifs** : seul le solde peut l'être ; aucun style dédié (pas de couleur ni de parenthèses) : le signe `-` seul distingue un solde créditeur.
- Pas d'indicateur Débit/Crédit (D/C) sur le solde : l'utilisateur doit lire le signe.

### Colonnes débit et crédit
- Deux colonnes de 150 px séparées de 8 px, dans la grille de saisie (`_kAmountW = 150`) et en largeurs fixes dans les tableaux. Une saisie dans l'une vide l'autre (`l.credit = 0`).
- Aucun repère visuel de sens (pas de fond ou d'en-tête distinct débit/crédit), la ligne de totaux et la barre d'équilibre les répètent.

### Navigation clavier dans la saisie (`entry_editor_screen.dart`)
Bonne base : `CallbackShortcuts` (Ctrl B contrepartie, Ctrl S enregistrer, F1 aide), `FocusTraversalGroup` en ordre de lecture, Tab/Maj+Tab entre cellules (suppression de ligne exclue), Entrée = champ suivant ou nouvelle ligne avec contrepartie proposée sur le dernier montant, ↑ ↓ et Entrée dans l'autocomplétion de compte, sélection du contenu au focus (`selectOnFocus` en `dense`). Barre fixe en bas : débit, crédit, « Équilibrée » / « Écart X ».

Limites visuelles repérées sur la capture `03-saisie.png` :
- Chaque cellule de la grille est un **champ à bordure complète de 32 px** : la grille ressemble à un formulaire de boîtes empilées, pas à un tableur. Beaucoup de bruit pour 8 colonnes × N lignes.
- Colonne **Compte** de 260 px : l'intitulé est tronqué (« Locations de bâtime… ») dès la première ligne.
- Colonne **Tiers** vide et pourtant large (130 px) sur les comptes sans tiers.
- Pas de ligne active mise en évidence, ni de pilotage visuel du focus au-delà de la bordure terracotta de 2 px.
- Le texte d'aide des raccourcis est dans une rangée de légendes (`AkKbd`) qui disparaît sur mobile.

### Grand livre / balance
Rendu correct (en-têtes teintés, lignes de 32 px, lignes de section par compte, « Total compte » en filet fort). Manques : en-tête non figé en défilement vertical dans la grille paresseuse locale, groupes d'en-têtes (« Ouverture », « Mouvements », « Clôture ») sans tableaux étroits, pas de ligne de total général visible en permanence.

## 7. Adaptation aux écrans

Seuils (non centralisés : `AkSpace` n'a pas de constante de breakpoint) :

| Seuil | Effet | Fichier |
|---|---|---|
| < 600 px (`akIsCompact`) | contrôles 48 px, marges 16 px, tableaux à lignes 48 px, boutons étendus | `layout.dart:5` |
| < 900 px | rail remplacé par `Drawer` + `NavigationBar` basse (3 raccourcis + Menu) | `app_shell.dart:52,114` |
| 720 / 1000 / 640 px | colonnes des cartes du tableau de bord | `dashboard_screen.dart:63,117` |
| 840 / 620 / 960 px | largeurs de dialogues et de grilles | `documents_screen.dart`, `entry_editor_screen.dart` |

Comportements :
- **Grand écran** : contenu borné à 1 400 px, centré (`AkPage`). Sur un écran large (≥ 1 600 px), les tableaux ne profitent pas de l'espace, ce qui coûte en saisie intensive : à discuter.
- **Tablette (600–899 px)** : **trou**. Le gabarit est mobile (Drawer, barre basse à 4 entrées) mais les contrôles sont de taille « bureau » (40 px, marges 24 px). Une tablette en paysage (≥ 900 px) obtient le rail, en portrait elle perd la navigation latérale. Aucun mode intermédiaire (rail réduit à icônes).
- **Téléphone** : bien traité pour les Pièces et le tableau de bord ; la grille de saisie impose un défilement horizontal (`_kGridMinWidth = 960`), tous les tableaux aussi (`AkTable.minWidth = 640`) : lisibles mais lourds. Barre basse limitée à Pièces, Tableau de bord, Consultation, Menu : Saisie et Lettrage sont derrière le tiroir.
- Écrans très denses non vérifiés en étroit par un golden : Référentiels, Inventaire, Clôture, Cabinet (seuls 8 goldens existent : connexion, tableau de bord, saisie, grand livre, balance, lettrage, clôture, mobile saisie / tableau de bord).
- `textScaler` n'est pas pris en compte nulle part (`grep textScal` : 0) ; les hauteurs de ligne fixes (32 px) tronqueraient un texte agrandi.

## 8. Accessibilité

| Sujet | État |
|---|---|
| Contraste | Vérifié par test (`design_tokens_test.dart`) : 17 paires texte/fond ≥ 4,5:1 en clair et en sombre. Les bordures de champs (`borderControl #8E8576` sur `#FFFFFF` ≈ 3,6:1) respectent le seuil de 3:1 pour les composants. Non testés : texte désactivé (`#9C9385` sur blanc ≈ 3,1:1, estimation à confirmer), indicateurs de focus, texte blanc sur SnackBar rouge, chevrons et icônes atténuées. |
| Statut jamais par la couleur seule | Respecté (icône + mot dans `AkBadge`). Exception : les points colorés des cartes du tableau de bord (`_Dot`) sont accompagnés d'un libellé, donc corrects. |
| Taille de texte | Minimum 14 px imposé par test. Mais **tout est à 14 px** : la lisibilité d'un tableau dense à 14 px sur grand écran est limite pour une lecture longue ; les montants Plex Mono 14 px gagneraient à être plus grands (15-16). |
| Cibles tactiles | 48 px sous 600 px : bon. Sur bureau : boutons-icônes 40 px, mode dense 32 px (suppression de ligne, boutons de grille) : acceptable à la souris, trop petit en tactile sur tablette ≥ 600 px. |
| Infobulles et sémantique | `AkIconButton` impose `tooltip` ; seulement 12 fichiers contiennent `Semantics`/`tooltip`. Le rail, lui, a un `Semantics(selected, button)`. Les cellules de grille et les montants n'ont pas d'étiquette Débit/Crédit pour un lecteur d'écran. |
| Clavier | Bonne couverture sur la saisie ; focus visible 2 px terracotta ; pas de parcours clavier documenté pour les tableaux, le rail ni le sélecteur de dossier. |
| Mouvement et thème | Pas d'animation gênante ; thème sombre suit le système (pas de réglage manuel). |

## 9. Dépendances d'interface

`app/pubspec.yaml` :

| Paquet | Usage UI | Limite éventuelle |
|---|---|---|
| `flutter` + Material 3 (`useMaterial3`) | tout | Beaucoup de comportements Material (focus, hover, `NavigationBar`, `TabBar`, `SnackBar`) à surcharger pour s'éloigner du style par défaut |
| `go_router ^18` | navigation | pas d'effet sur le design ; transitions par défaut |
| `flutter_riverpod ^3` | état | aucun |
| `intl` | formats fr_FR | aucun |
| `qr_flutter` | QR de l'enrôlement TOTP | fond blanc forcé |
| `file_picker`, `image_picker`, `url_launcher` | pièces, import | sélecteurs natifs, non stylables |
| `shared_preferences` | préférences | aucun |
| Polices embarquées | IBM Plex Sans/Mono, Poppins | assets locaux (bon pour réseau lent) ; seulement 3 graisses de Plex Sans, 2 de Mono, 1 de Poppins : un nouveau design avec d'autres poids exige d'ajouter les fichiers |
| Aucun paquet de grille de données, de graphiques, de toasts ou d'icônes | — | Icônes : `Icons.*` Material (≈ 50 distinctes), style contour ; pas de jeu d'icônes dédié à la comptabilité |

Aucune bibliothèque tierce de design : **bonne nouvelle pour la refonte**, tout se règle dans `lib/design/`.

## 10. Recommandations techniques pour la refonte

Le centre de gravité existe déjà ; la refonte doit s'y appuyer.

1. **Garder `lib/design/` comme seule porte** : un nouveau design = nouvelles valeurs dans `AkTokens`, `AkText`, `AkRadius`, `AkSpace` et nouveaux rendus dans les composants, **sans toucher aux écrans**. Le garde-fou `design_guard_test.dart` et les goldens protègent déjà ce principe.
2. **Compléter les jetons manquants** avant de changer le style :
   - échelle typographique avec rôles distincts (corps, tableau dense, montant, chiffre clé, légende) au lieu de 14 px partout ;
   - jetons de **breakpoints** (`compact < 600`, `medium 600-899`, `expanded ≥ 900`, éventuellement `wide ≥ 1 400`) dans `AkSpace` et un `AkBreakpoint` ;
   - jetons d'**icônes** (16/20/24), de **largeurs de dialogue** (S/M/L) et de **densité** (confort / compact), d'**élévation** ;
   - jetons de **colonnes de tableau** (date 96, compte 100, montant 112/150…) pour éviter les 157 largeurs en dur.
3. **Un seul tableau** : faire évoluer `AkTable` pour couvrir ce que fait `_DataGrid` (liste paresseuse, groupes d'en-têtes, lignes de section et de total, en-tête figé, première colonne figée), puis supprimer `_DataGrid`, `_Col`, `_GRow`. C'est la plus grosse dette de composants.
4. **Un composant de grille de saisie** : extraire `_GridHeader` / `_LineRow` / pied de totaux dans `lib/design/components/entry_grid.dart` avec un mode « cellule sans bordure, bordure au focus » (type tableur). C'est le principal levier de l'impression « logiciel comptable ».
5. **Retours utilisateur** : créer `AkToast` (remplace les 37 `SnackBar`) avec variantes succès/erreur/info ; règle documentée entre toast (action terminée), bandeau (état persistant) et dialogue (confirmation).
6. **Composants à ajouter** : `AkStat` (indicateur du tableau de bord), `AkTabs` (enveloppe du `TabBar`), `AkMenu` (enveloppe du `PopupMenuButton`), `AkListRow` (remplace `ListTile` et `_ListRow`), `AkToolbar` (barre d'outils avec recherche), `AkEntitySwitcher` (sélecteur avec recherche, clavier Ctrl K).
7. **Tablette** : ajouter un état intermédiaire du shell (rail d'icônes à 72 px entre 600 et 899 px), au lieu du tiroir.
8. **Texte agrandi** : tester `textScaler` ×1,3 ; remplacer les hauteurs de ligne fixes par des hauteurs minimales.
9. **Tests** : étendre les goldens aux écrans non couverts (Référentiels, Inventaire, Clôture étroite, Pièces, Rapprochement, Cabinet) avant la refonte pour disposer d'un filet, et régénérer (`flutter test --update-goldens test/golden`) à chaque étape. Étendre `design_tokens_test.dart` aux paires manquantes (désactivé, focus, toast).
10. **Hors code Flutter** : le design des documents (PDF des états financiers, état de rapprochement, liasse DGI) vit dans `service-documents/` ; il demande son propre cadrage si l'image du cabinet doit suivre.

### Ordre de traitement, du moins risqué au plus risqué

| Étape | Contenu | Risque | Filet |
|---|---|---|---|
| 0 | Ajouter les goldens manquants ; documenter les breakpoints | nul | — |
| 1 | Nouvelles valeurs de jetons (couleurs, typographie, rayons, espacements) + thème | faible (aucun écran touché) | goldens, `design_tokens_test` |
| 2 | Composants simples : boutons, champs, badges, cartes, bannières, dialogues, `AkToast` | faible | catalogue, goldens |
| 3 | Shell : barre haute, rail, mode tablette, sélecteur de dossier | moyen | goldens, tests de login/permissions |
| 4 | Écrans de lecture : tableau de bord, dossiers, fiche dossier, connexion/MFA, Pièces | faible | goldens |
| 5 | `AkTable` étendu + migration de la Consultation (grand livre, balances) | moyen | goldens, test des exports |
| 6 | Écrans à formulaires : Référentiels, Cabinet, Collaborateurs, Import, Inventaire | moyen | tests de dialogues |
| 7 | Lettrage, Rapprochement, Clôture | moyen | `recette_jeu_test`, goldens |
| 8 | **Grille de saisie** (en dernier : écran le plus critique, tests clavier à rejouer) | élevé | `entry_editor_test`, `entry_draft_test`, recette |

## 11. Captures d'écran à faire pour Claude Design

À prendre sur le jeu de données fictif de la recette interne (`scripts/` : recette) en **desktop 1440×900**, thème clair, sauf mention. Les goldens existants dans `docs/design/apres/` sont d'un jeu à 2-5 lignes : trop pauvres, d'où les états ci-dessous.

| # | Écran | État à montrer | Pourquoi |
|---|---|---|---|
| 1 | Éditeur d'écriture | 6 à 8 lignes remplies, comptes longs, 2 lignes avec tiers, écart non nul, le curseur dans une cellule montant, liste d'autocomplétion de compte ouverte | Cœur du produit : densité, focus, erreurs |
| 2 | Éditeur d'écriture | même écriture équilibrée, barre « Équilibrée » visible, mode lecture seule d'une écriture validée | États contrastés |
| 3 | Consultation > Grand livre | 3 comptes développés, dont un avec solde créditeur, case « Comparer N-1 » cochée, filtres remplis | Tableau dense à totaux |
| 4 | Consultation > Balance générale | classes 1 à 7 avec groupes d'en-têtes (Ouverture, Mouvements, Clôture), ligne de total général | Plus large tableau |
| 5 | Tableau de bord « Mes dossiers » | 6 dossiers dont certains avec « À corriger » et pièces en attente, sélecteur de dossier ouvert dans la barre haute | Navigation et changement d'entité |
| 6 | Saisie (liste) | 15 écritures avec les 4 statuts (brouillard, validée, revue, à corriger), un filtre actif | Statuts colorés |
| 7 | Clôture de l'exercice | contrôles avec un échec, un avertissement, génération des états financiers et de la liasse proposée | Écran à enjeu, bandeaux, boutons dangereux |
| 8 | Mobile 390×844 (clair) : Pièces avec bouton « Photographier » et 3 pièces, **puis** même écran en thème sombre | Mobile et sombre | Vérifier l'adaptation |

Bonus facultatifs : Lettrage avec propositions et Rapprochement (deux colonnes), dialogue d'invitation de collaborateur.

---

## Résumé : les cinq problèmes de design les plus importants

1. **La refonte porte sur la direction visuelle, pas sur l'architecture** : un système de design centralisé existe et est gardé par des tests. Il faut modifier les jetons et les composants dans `app/lib/design/`, non réécrire les écrans ; tout travail qui contourne `lib/design/` serait une régression.
2. **Hiérarchie visuelle plate** : tout le texte est à 14 px (corps, libellés, légendes, tableaux, montants), la hiérarchie repose sur le gras et la couleur atténuée ; une échelle typographique et des rôles distincts manquent (`tokens.dart`, `AkText`).
3. **Le tableau n'est pas unifié** : la Consultation mélange `_DataGrid` local et `AkTable` ; la grille de saisie est un troisième tableau ; 157 largeurs de colonnes et de dialogues en dur (`consultation_screen.dart:282`, `entry_editor_screen.dart`, tous écrans).
4. **La grille de saisie fonctionne bien au clavier mais ressemble à un formulaire**, pas à un tableur : cellules à bordure pleine, compte tronqué, colonne Tiers vide, pas de ligne active, zéros traités différemment d'un tableau à l'autre (`entry_editor_screen.dart`, `formatting.dart:11`).
5. **Adaptation inégale** : trou entre 600 et 899 px (navigation mobile avec contrôles de bureau), contenu plafonné à 1 400 px sur grand écran, `textScaler` ignoré, retours utilisateur dispersés entre 37 `SnackBar` et bandeaux (`app_shell.dart:52`, `layout.dart:5`, `consultation_screen.dart:228`).
