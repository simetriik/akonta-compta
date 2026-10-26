# Système de design Akonta

Source unique : `app/lib/design/` (import : `package:akonta/design/design.dart`). Tout écran n'utilise que ces composants ; `app/test/design_guard_test.dart` échoue sinon.

## Jetons (`tokens.dart`, `theme.dart`)
- **Couleurs** : terracotta `#B5472A` (marque), neutres chauds (sable `#F7F3EC`, encre `#1A1A18`), couleurs d'état succès / alerte / erreur / info avec teinte de fond. Thèmes clair et sombre (`AkTokens.light` / `.dark`, accès `context.ak`). Hors `lib/design/`, aucune couleur codée en dur.
- **Contraste** : `test/design_tokens_test.dart` vérifie ≥ 4,5:1 (WCAG AA) sur 17 paires texte/fond, dans les deux thèmes. Le statut n'est jamais porté par la seule couleur (icône + mot).
- **Espacements** : base 4 (`AkSpace` : 4, 8, 12, 16, 20, 24, 32, 48). Contrôles : 40 px (48 px sur écran < 600 px), 32 px en grille dense.
- **Rayons** : 2 (badges), 4 (champs, boutons), 6 (cartes, dialogues). **Ombre** : une seule, pour les surfaces flottantes.
- **Typographie** (`AkText`, 14 px minimum) : IBM Plex Sans (interface), IBM Plex Mono à chiffres tabulaires (montants, codes), Poppins SemiBold pour le seul titre d'écran. Montants alignés à droite.
- **Logo** : `AkLogo`, PNG du kit `outputs/logo-akonta` (versions noire / blanche selon le thème, symbole petite taille sous 32 px), dans `app/assets/logo/`.

## Composants (`components/`)
| Besoin | Composant |
|---|---|
| Texte | `AkTextField` (libellé au-dessus, aide, erreur, `dense` pour une cellule de grille) |
| Montant FCFA entier | `AkAmountField` (milliers séparés, droite, Plex Mono) ; affichage `AkAmountText` |
| Compte / tiers | `AkAccountField`, `AkThirdPartyField` (autocomplétion, Entrée choisit, Tab choisit la 1re proposition, saisie d'un code complet) ; base `AkAutocompleteField` |
| Date | `AkDateField` (jj/mm/aaaa + calendrier) |
| Liste, cases, choix | `AkDropdown` + `AkOption`, `AkCheckbox`, `AkSwitch`, `AkSegmented` |
| Boutons | `AkButton` (primary, secondary, danger, dangerOutline, ghost ; `icon`, `loading`, `dense`), `AkIconButton` |
| Statuts | `AkStatusBadge` (brouillard, validée, revue, à corriger), `AkBadge` |
| Tableau dense | `AkTable` / `AkColumn` (en-tête teinté, montants à droite, pied de totaux, défilement horizontal) |
| Structure | `AkCard`, `AkPage`, `AkPageHead`, `AkSectionTitle`, `AkDialog`, `showAkConfirm` |
| Retours | `AkBanner`, `AkErrorMessage`, `AkEmptyState`, `AkLoading`, `AkKbd` |

Catalogue visuel : route `/catalogue` (mode debug ou `--dart-define=AK_DEV=true`).

## Saisie au clavier (écran Saisie)
Tab / Maj+Tab : cellule suivante / précédente (le bouton de suppression de ligne est hors parcours). Entrée : champ suivant ; dans une liste de comptes, choisit la proposition surlignée ; sur le dernier montant, crée une ligne avec la contrepartie déjà proposée. ↑ ↓ : propositions. Ctrl B : contrepartie automatique. Ctrl S : enregistrer le brouillard. F1 : aide. Une barre fixe en bas affiche en permanence totaux, équilibre (ou écart) et actions.

## Mise en page
Desktop : barre supérieure avec dossier courant, navigation latérale, contenu borné à 1 400 px. Mobile (< 600 px) : navigation basse réduite (Pièces, Tableau de bord, Consultation, Menu), bouton « Photographier une pièce » en tête de l'écran Pièces, contrôles tactiles de 48 px.

## Garde-fous et tests
- `design_guard_test` : aucun `TextField`, `FilledButton`, `OutlinedButton`, `TextButton`, `IconButton`, `ElevatedButton`, `DropdownButton*`, `AlertDialog`, `DataTable`, `Checkbox`, `Switch`, `SegmentedButton`, `Autocomplete`, `Card`, `showDatePicker` hors `lib/design/` ; aucun `fontSize` < 14 ; aucune couleur en dur.
- Goldens : `test/golden/` (connexion, tableau de bord, saisie, grand livre, balance, lettrage, clôture, mobile) ; régénération : `flutter test --update-goldens test/golden`.
- Captures : `docs/design/avant/` (recette réelle, avant refonte) et `docs/design/apres/` (goldens, données fictives).

## Écarts connus
`TabBar`, `ListTile`, `RadioListTile`, `FilterChip`, `PopupMenuButton` restent des widgets Material (thémés, non couverts par le garde-fou). Les grilles du grand livre, de la balance générale et du centralisateur gardent la grille paresseuse locale `_DataGrid` (défilement long, lignes de section) que `AkTable` ne couvre pas encore.
