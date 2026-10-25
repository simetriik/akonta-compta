# Akonta — Guide d'usage du logo

Version 1.0 — 25 octobre 2026. Remplace la version compacte du matin (wordmark désormais vectorisé, version petite taille ajoutée).

## 1. Le logo
- **Idée** : la tête d'éléphant réduite à son oreille et sa trompe — « un éléphant n'oublie jamais », pour une comptabilité où aucune écriture ne se perd.
- **Versions** : horizontal (symbole + nom) · empilé · symbole seul · symbole petite taille.
- **Fichiers maîtres** (SVG, encre `#1A1A18`) :
  - `akonta-symbol.svg` — symbole de référence (avec l'œil).
  - `akonta-symbol-small.svg` — version petite taille : sans œil, trompe épaissie et raccourcie. Sert au favicon, aux icônes d'application et à tout usage ≤ 32 px.
  - `akonta-lockup-horizontal.svg` — logo horizontal (cadre 750 × 256).
  - `akonta-lockup-stacked.svg` — logo empilé (cadre 360 × 420).
- **Déclinaisons générées** à partir de chaque maître : `*-black` (encrage de référence), `*-white` (fond sombre ou couleur), `*-mono-b5472a` (terracotta), `*-square` (avatar, canevas carré), `*-app-icon` (tuile arrondie terracotta). PNG transparents aux tailles indiquées dans le nom.
- **Icônes web** : `favicon.ico` (16/32/48), `favicon.svg`, `favicon-16/32/48.png`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png`, `maskable-512.png`, `site.webmanifest`, `head-snippet.html` (balises `<head>` prêtes à coller). Toutes sont dessinées à partir de la version petite taille.

## 2. Zone de respect
Laisser un espace libre d'au moins **1 × la hauteur de l'œil du symbole** (≈ 1/10 de la hauteur du symbole) autour du logo, sur tous les côtés. Zone relative à la taille du logo, jamais une distance fixe.

## 3. Taille minimale
| Version | Écran | Impression | Remarque |
|---|---|---|---|
| Horizontal | 120 px de large | 30 mm | en dessous, passer au symbole seul |
| Empilé | 72 px de large | 20 mm | — |
| Symbole (référence) | 32 px | 8 mm | l'œil disparaît en dessous |
| Symbole petite taille | 16 px | 4 mm | seule version autorisée sous 32 px |

## 4. Couleurs
| Nom | HEX | RGB | CMJN (approx.) |
|---|---|---|---|
| Encre (texte, symbole par défaut) | `#1A1A18` | 26, 26, 24 | 0/0/8/90 |
| Terracotta (couleur de marque) | `#B5472A` | 181, 71, 42 | 0/61/77/29 |
| Sable (fond neutre, symbole sur fond couleur) | `#F7F3EC` | 247, 243, 236 | 0/2/4/3 |

Équivalents Pantone à valider avec l'imprimeur sur nuancier physique avant un usage print engageant.

**Associations approuvées** : encre sur blanc ou sable · blanc sur terracotta · blanc sur fond sombre · terracotta sur blanc ou sable. **Éviter** encre sur terracotta (contraste insuffisant) et toute association hors de cette liste sans test.

## 5. Typographie
- **Wordmark** : « akonta » en bas de casse, dessiné à partir de **Poppins SemiBold** (Indian Type Foundry, licence SIL Open Font License 1.1, qui autorise l'usage en logo). Les lettres sont **vectorisées en tracés** dans les fichiers maîtres : aucune police n'est nécessaire pour les afficher ou les imprimer.
- Ne jamais recomposer le wordmark en tapant le nom dans un traitement de texte : utiliser le fichier fourni. Même graisse (SemiBold) dans les deux lockups.
- **Texte courant et interface** : Poppins (titres) et la police système de la plateforme pour les tableaux de saisie ; à préciser dans le design system de l'application.

## 6. À ne pas faire
Ne pas étirer ni déformer le symbole ou le wordmark · ne pas recolorer hors de la palette · ne pas faire pivoter le symbole · ne pas ajouter d'ombre, de contour, de dégradé ou d'effet · ne pas réarranger les éléments d'un lockup · ne pas isoler l'oreille ou la trompe · ne pas utiliser le symbole de référence (avec l'œil) sous 32 px · ne pas utiliser la version petite taille au-dessus de 48 px (elle paraît lourde).

## 7. Points ouverts
- Aucune recherche d'antériorité de marque n'a été faite — recommandée avant dépôt ou lancement public (bases INPI/OAPI, recherche d'image inversée).
- Les versions blanches sont une simple inversion de couleur ; pour une très grande taille sur fond sombre (enseigne), un amincissement optique manuel peut être souhaitable.
- Fichiers éditables : les SVG sont les maîtres. Pas de PDF/AI/EPS fournis ; à exporter depuis Inkscape ou Illustrator si l'imprimeur l'exige.
