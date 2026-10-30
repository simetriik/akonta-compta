# Système de design Akonta

Source unique : `app/lib/design/` (import : `package:akonta/design/design.dart`). Tout écran n'utilise que ces composants ; `app/test/design_guard_test.dart` échoue sinon. Identité « bleu nuit et orange » (décision D-016) ; maquette de référence : https://claude.ai/artifact/ScBBYrdyJ5o3CPkYTrYsNx.

## Jetons (`tokens.dart`, `theme.dart`)
- **Couleurs** : bleu nuit `#1E2A5A` structure (rail, titres : `railBg`, `textStrong`) ; orange `#F28C28` n'est que l'action (`accent`, un seul bouton principal par écran, texte `onAccent` bleu nuit dessus, jamais en texte sur fond clair) ; neutres bleutés (`bg`, `surface`, `surfaceSunken`, `tableHead`, `rowActive`, `rowSelected`). Statuts : brouillard gris, validée vert, revue violet, à corriger rouge ; retours succès, alerte, erreur, info. Thèmes clair et sombre (`AkTokens.light` / `.dark`, accès `context.ak`).
- **Contraste** : `test/design_tokens_test.dart` vérifie ≥ 4,5:1 (WCAG AA) sur une trentaine de paires texte/fond (rail, statuts, toast compris) et ≥ 3:1 pour les bordures de contrôle, l'anneau de focus et l'indicateur du rail, dans les deux thèmes. Le statut n'est jamais porté par la seule couleur (icône + mot).
- **Espacements** : base 4 (`AkSpace` : 4, 8, 12, 16, 20, 24, 32, 40, 48, 64). Contrôles : 40 px (48 px sous 900 px), 32 px en grille dense à la souris. Colonnes types `AkSpace.col*`, dialogues `AkDialogSize` (400, 560, 800), icônes 16, 20, 24.
- **Points de rupture** (`AkBreakpoint`) : mobile < 600, tablette 600–899, bureau ≥ 900, large ≥ 1 440. `akIsCompact` : < 600 ; `akIsTouch` : < 900 (contrôles et lignes tactiles).
- **Rayons** : 4 (badges), 8 (champs, boutons, cartes), 12 (dialogues, toasts). **Ombres** : cartes sans ombre ; `AkShadow.overlay` pour ce qui flotte, `dialog` pour les dialogues.
- **Typographie** (`AkText`, 14 px minimum), par rôles : `titleLg` 24 Poppins (un seul par écran), `title` 18, `heading` 16, `body` / `bodyStrong` 15, `label`, `table`, `tableHead`, `caption`, `code` 14, `amount` / `amountTotal` 15 et `keyFigure` 28 en IBM Plex Mono à chiffres tabulaires. Polices embarquées : Plex Sans 400/500/600, Plex Mono 400/500/600, Poppins 600.
- **Logo** : `AkLogo(tone: auto | blue | onDark)`, SVG du système (`flutter_svg`) dans `app/assets/logo/` : bicolore sur clair, version blanche sur sombre et dans le rail, bleu sous 32 px.

## Règles de chiffres
- Un mouvement à zéro reste vide ; un total, un solde ou un cumul affiche toujours sa valeur (« 0 » compris).
- Un solde n'a jamais de signe moins : `Fmt.balance` écrit « 1 250 000 D », « 340 000 C », « 0 ».
- Un écart est chiffré et qualifié : « Écart 180 000 · débit supérieur ». L'unité (FCFA) est dans l'en-tête de colonne.

## Composants (`components/`)
| Besoin | Composant |
|---|---|
| Texte | `AkTextField` (libellé au-dessus, aide, erreur, `dense` pour une cellule de grille) |
| Montant FCFA entier | `AkAmountField` ; affichage `AkAmountText` (`bold` = total) |
| Compte / tiers | `AkAccountField`, `AkThirdPartyField` (autocomplétion) ; base `AkAutocompleteField` |
| Date, liste, choix | `AkDateField`, `AkDropdown` + `AkOption`, `AkCheckbox`, `AkSwitch`, `AkSegmented`, `AkRadioGroup` |
| Boutons | `AkButton` (primary, secondary, danger, dangerOutline, ghost), `AkIconButton` |
| Statuts | `AkStatusBadge`, `AkBadge` |
| Tableau court | `AkTable` / `AkColumn` ; tableau long (grand livre, balances) `AkGrid` / `AkGridColumn` / `AkGridRow` |
| Grille de saisie | `AkEntryGridTheme` (cellules sans bordure, anneau de focus 2 px), `AkEntryGridCols` ; ligne active sur `rowActive` |
| Structure | `AkCard`, `AkPage`, `AkPageHead`, `AkSectionTitle`, `AkStat`, `AkListRow`, `AkDialog` (`AkDialogSize`), `showAkConfirm` |
| Retours | `showAkToast` (5 s, action facultative), `AkBanner`, `AkErrorMessage`, `AkEmptyState`, `AkLoading`, `AkKbd` |

Catalogue visuel : route `/catalogue` (mode debug ou `--dart-define=AK_DEV=true`).

## Saisie au clavier
Tab / Maj+Tab : cellule suivante / précédente (la suppression de ligne est hors parcours). Entrée : champ suivant ; dans une liste de comptes, choisit la proposition surlignée ; sur le dernier montant, crée une ligne avec la contrepartie proposée. ↑ ↓ : propositions. Ctrl B contrepartie, Ctrl S enregistrer le brouillard, F1 aide, Ctrl K changer de dossier. Barre fixe en bas : totaux, équilibre (ou écart qualifié) et actions ; « Valider l'écriture » reste inactif tant qu'il y a un écart.

## Mise en page
Bureau (≥ 900 px) : rail bleu nuit de 232 px (logo en tête, entrée active sur `railActiveBg` avec barre orange), barre haute avec le dossier courant. Tablette (600–899 px) : rail réduit à 72 px (icônes et infobulles), contrôles de 48 px. Mobile (< 600 px) : barre d'onglets basse sur le fond du rail (Pièces, Accueil, Saisie, Consulter, Menu), tiroir pour le reste.

## Garde-fous et tests
- `design_guard_test` : aucun widget Material brut de champ, bouton, dialogue, tableau, `SnackBar`, `ListTile`, `RadioListTile`, `Card`, `showDatePicker` hors `lib/design/` ; aucun `fontSize` < 14 ; aucune couleur en dur.
- Goldens : `test/golden/` ; régénération : `flutter test --update-goldens test/golden`. Captures : `docs/design/avant/` (ancienne interface), `docs/design/apres/` (terracotta, obsolète), `docs/design/identite-bleu-nuit/` (identité actuelle).

## Écarts connus
`TabBar`, `PopupMenuButton`, `NavigationBar` et `Drawer` restent des widgets Material thémés. Pas encore de réglage manuel clair/sombre (le thème suit le système). Largeurs de colonnes de certains écrans (lettrage, rapprochement) encore locales. Les PDF du service Python reprennent seulement la couleur d'accent (bleu nuit).
