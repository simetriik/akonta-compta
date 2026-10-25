# Livraison du lot 3 — Akonta (livraison finale)

Date : 25 octobre 2026. Branche `lot3` fusionnée dans `main`. Périmètre : module 8 Travaux d'inventaire, module 9 Clôture (conception §6, §7, §10.8, §10.9), liasse DGI, jeu de démonstration clôturé.

## 1. Ce qui est livré

| Fonction | Base de données | Application | Documents |
|---|---|---|---|
| Amortissements | plan linéaire / dégressif (coefficient), prorata temporis base 360 (D-011), reprise de l'existant (cumul antérieur), `generate_depreciation` (tableau de l'exercice + écriture 68x / 28x en brouillard « générée », régénérable tant que non validée), `dispose_asset` (dotation complémentaire, sortie 81 / 28 / 2x, produit 82 / 485 ou trésorerie, rebut) | registre, fiche, tableau d'amortissement, génération, cession / rebut | — |
| Stocks | inventaire intermittent : stock initial repris des à-nouveaux, stock final saisi par compte, variations 603x / 73x | onglet Stocks | — |
| Provisions | créances douteuses proposées depuis la balance âgée (taux par tranche ou par tiers), provisions pour risques, dotation / reprise par différence avec N-1 | onglet Provisions | — |
| Régularisations | CAP, PAR, CCA, PCA au prorata au jour, écriture au 31/12, extourne au 1er janvier N+1 (`generate_reversals`) | onglet Régularisations | — |
| Écarts de conversion | lignes en devises non lettrées, cours de clôture par devise (euro fixe), 478 / 479 + provision 194 / 6591, extourne N+1 | onglet Écarts de conversion | — |
| Contrôles de clôture | bloquants (brouillards, équilibre, comptes désactivés mouvementés, 471) non levables ; alertes (non revues, à corriger, rapprochements non figés, dotations, périodes) levables par le chef de mission avec commentaire tracé | étape 1 de l'assistant | — |
| Fiscalité | règles de passage livrées (version 2026, paramétrables par cabinet), résultat comptable, réintégrations / déductions proposées, IS = max(taux × résultat fiscal, minimum sur CA, plancher 250 000), acomptes 4492, écriture 891 / 441 en brouillard | étape 3 | — |
| États financiers | moteur comptes → postes versionné `SYSCOHADA-2017` (bilan actif / passif, compte de résultat), N-1, résultat net implicite, contrôles de cohérence, écriture de détermination du résultat 131 / 139 | étape 4 | PDF (service Python), **liasse DGI** : modèle Excel rempli avec macros conservées (fiche R1/R2, bilan, compte de résultat ; cartographie `SN-2025` de 233 cellules générée depuis le modèle, D-012) |
| Clôture | provisoire (périodes verrouillées), réouverture avec motif, **arrêté définitif** par l'associé (TOTP, confirmation « ARRETER AAAA », archive avec empreintes SHA-256 du grand livre, de la balance et des états ; exercice intangible) | étapes 5 et 6 | — |
| N+1 | à-nouveaux par compte et par tiers, résultat en 1300, recalculables tant que N n'est pas arrêté ; affectation du résultat (réserve légale, réserves, dividendes, report) | étape 7 | — |

Jeu de démonstration (`scripts/demo.sh`) : SA Alpha Services a un exercice 2026 **entièrement clôturé** (dotation, IS, états, arrêté, archive) et un exercice 2027 ouvert avec à-nouveaux validés ; SARL Démo Distribution reste en tenue courante (brouillards, revues, lettrages, rapprochement) pour la recette.

## 2. Installation, lancement, tests

Identiques aux lots 1 et 2. Variable supplémentaire du service de documents : `AKONTA_DGI_TEMPLATE` (chemin du modèle `.xlsm`). `scripts/test.sh` : pgTAP 329 assertions, Flutter 32, pytest 11, Deno 8.

## 3. Décisions prises seul

D-011 (prorata base 360, dégressif avec bascule), D-012 (cartographie DGI générée depuis la feuille « champs fixes » du modèle), ordre de clôture (IS avant détermination du résultat), TFT et notes laissés à la saisie dans le classeur (Q-005). Liste complète : `docs/decisions-dev.md`.

## 4. Questions restantes

Q-001 à Q-005 (`docs/questions.md`). Points à valider avec ABC avant la première clôture réelle (début 2028) : taux d'IS, minimum d'impôt et plancher ; plafonds des réintégrations ; durées d'amortissement usuelles ; taux de provision par tranche ; version du modèle DGI en vigueur.

Limites connues : TFT et notes annexes non calculés ; dégressif sans bascule paramétrable par bien ; pas de proratisation des provisions réglementées ; états financiers des sociétés consolidées hors périmètre.

## 5. Scénario de recette global (ABC)

Pré-requis : `scripts/demo.sh`, application lancée, service de documents démarré avec `AKONTA_DGI_TEMPLATE`.

### Parcours complet sur SARL Démo Distribution (exercice 2026)
1. **Ouverture** — `chef@akonta.demo` : Dossiers → fiche SARL Démo (longueur 7 figée, verrouillage mensuel actif), Exercices (janvier-mars verrouillés).
2. **Saisie** — `assistant@akonta.demo` : nouvelle écriture avec modèle « Achat avec TVA », Valider ; brouillard déséquilibré → erreurs ; Ctrl+B ; validation par lot des brouillards de caisse refusée (pas ses écritures).
3. **Validation et revue** — `chef@akonta.demo` : valider le lot ; revue « à corriger » avec commentaire ; contre-passation avec motif.
4. **Pièces** — déposer un PDF, photographier sur mobile, rattacher, visionneuse, suppression refusée.
5. **Lettrage** — compte 4111000 / CHU : propositions, lettrage, lettrage partiel, délettrage.
6. **Rapprochement** — journal BQ : état de janvier (écart 0, figé), import d'un relevé de février CSV, propositions, pointage n-n, écriture depuis le relevé, état PDF.
7. **Inventaire** — immobilisation « Véhicule » 12 000 000 sur 5 ans (1er avril) : tableau, dotation générée ; stock final 5 000 000 → variation ; provisions clients 25 % / 50 % ; régularisation CCA loyer ; cours de clôture et écarts (aucune ligne en devise : « rien à générer »). Valider les brouillards générés dans Saisie.
8. **Clôture** — Contrôles : brouillards bloquants tant qu'il en reste ; lever les alertes avec commentaire. Fiscalité : réintégration des amendes, IS avec minimum, écriture validée. États financiers : générer, contrôles verts, PDF, liasse DGI (ouvrir le `.xlsm` : fiche R1, bilan et compte de résultat remplis, macros présentes). Écriture de résultat validée. Clôture provisoire → plus aucune validation possible ; réouverture avec motif ; nouvelle clôture provisoire.
9. **Arrêté définitif** — `associe@akonta.demo` (TOTP) : case à cocher, texte « ARRETER 2026 », arrêté ; exercice clôturé, archive visible dans la piste d'audit (`close_final`, empreinte).
10. **Exercice 2027** — créer l'exercice 2027 (Dossiers), générer les à-nouveaux (par tiers, résultat en 1300), valider ; affecter le résultat (réserve légale 10 %, dividendes, report) ; extournes des régularisations au 1er janvier.

### Vérification sur SA Alpha Services
- Exercice 2026 clôturé : tentative de saisie refusée ; piste d'audit : `close_final` avec empreinte ; états financiers marqués arrêtés ; exercice 2027 ouvert avec à-nouveaux validés.

### Cloisonnement et sécurité (associé)
- Piste d'audit : « Vérifier la chaîne » → intègre ; filtrer sur les arrêtés et les levées d'alertes.
- `scripts/test.sh sql` : `090_rls_coverage` prouve qu'aucune table de dossier n'est visible depuis un autre cabinet.

Résultat attendu : le parcours ouverture → saisie → validation → revue → lettrage → rapprochement → inventaire → états financiers → arrêté définitif → ouverture N+1 se déroule sans erreur technique ; chaque refus correspond à une règle de `inputs/conception.md`.
