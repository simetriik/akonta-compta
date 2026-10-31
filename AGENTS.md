# AGENTS.md

Akonta : logiciel comptable conforme au SYSCOHADA révisé pour le cabinet ABC Expertise Comptable (remplace Perfecto). Application distincte d'eABC, pensée pour être revendue à d'autres cabinets.

## État du dépôt

Les trois lots sont construits (tags `lot1`, `lot2`, `lot3` sur `main`) ; la recette avec ABC reste à organiser.
- `inputs/` (lecture seule, non versionné) : `conception.md` est la **référence unique** des décisions. Ne pas rouvrir une décision qui y figure ; sur un point non tranché, choisir l'option la plus prudente et la consigner dans `docs/decisions-dev.md`. On référence `inputs/`, on ne le copie pas dans `docs/` (D-001).
- `supabase/` : migrations SQL versionnées (règles comptables, RLS, fonctions), `seed.sql` (démonstration), `tests/` pgTAP, `functions/` Edge (Deno).
- `app/` : application Flutter desktop + mobile, **architecture clean** (couches core / domain / application / infrastructure / composition / presentation, Riverpod, go_router) ; règles vérifiées par `test/architecture_test.dart`, détail dans `docs/architecture.md` (D-031). Mode hors connexion : base locale chiffrée, file d'envoi, synchronisation.
- `service-documents/` : service Python FastAPI (PDF, Excel, liasse DGI avec `keep_vba`).
- `scripts/` : `setup.sh`, `start.sh`, `stop.sh`, `reset-db.sh`, `demo.sh`, `test.sh` (toute la suite), générateurs de seed.
- `docs/` : `plan.md`, `avancement.md`, `decisions-dev.md`, `questions.md`, `audit.md`, `environnement.md`, `livraison-lot{1,2,3}.md`, `prompt-claude-design.md`.
- `outputs/logo-akonta/` : kit logo validé.

Avant de déclarer une tâche terminée : `scripts/test.sh` (pgTAP, Flutter, pytest, Deno) doit être vert.

## Stack imposée (prévaut sur la stack par défaut globale)

- **Flutter** : une base de code pour desktop (Windows/macOS/Linux, saisie intensive au clavier) et mobile (Android/iOS, capture de pièces, consultation). Couches présentation / domaine / données.
- **Supabase** (adaptateur actuel, derrière les ports de `domain/repositories/`) : PostgreSQL (source de vérité), Auth (MFA TOTP), RLS, Storage privé (URL signées), Edge Functions en TypeScript (invitations, imports, propositions de lettrage).
- **Service Python séparé** (appelé par une Edge Function) : génération PDF et remplissage du modèle Excel DGI avec `openpyxl` (`keep_vba`).
- Environnement local sous **Podman** (pas de Docker) : pour la Supabase CLI, activer `systemctl --user enable --now podman.socket` et exporter `DOCKER_HOST` vers ce socket ; sinon PostgreSQL + pgTAP dans un conteneur Podman, documenté dans `docs/environnement.md`.
- Tests : pgTAP (règles comptables et toutes les politiques RLS), tests Flutter (unitaires + widgets), pytest (service de documents). Chaque règle de la conception doit être traçable vers au moins un test.

## Architecture : les règles comptables vivent dans PostgreSQL

Flutter n'est pas la garantie ; la base l'est. Éléments qui traversent plusieurs couches :
- **Validation d'écriture** : une RPC SQL unique contrôle équilibre, période, comptes, puis attribue le numéro séquentiel dans la même transaction (verrou sur la séquence du journal : continue par journal et par exercice, sans trou).
- **Immutabilité** : déclencheurs interdisant modification/suppression d'une écriture validée, d'une période verrouillée, d'un exercice arrêté. Correction uniquement par contre-passation.
- **Piste d'audit** : table en ajout seul alimentée par déclencheurs, chaînage SHA-256.
- Contre-passation, à-nouveaux, extournes : fonctions SQL transactionnelles. Écritures générées (inventaire, etc.) arrivent en brouillard, marquées « générée ».
- **Multi-tenant** : toutes les données portent l'identifiant du cabinet. RLS par cabinet puis par affectation `(utilisateur, dossier, rôle)` ; permissions unitaires vérifiées par fonctions SQL ; rôles = paquets par défaut ajustables par l'associé.
- **Soldes jamais stockés comme source de vérité** : grand livre, balances, centralisation en vues/fonctions SQL indexées (cache mensuel toléré).
- Règles fiscales et correspondances comptes → postes des états financiers : tables paramétrables **versionnées**, pas du code.
- Montants : FCFA en `bigint`, devises `numeric(18,2)`, cours `numeric(18,6)`, aucun flottant. Montants négatifs interdits dans une écriture (débit **ou** crédit).
- Modèle de données : **entité** (permanente) + **exercice** ; « dossier » = entité + exercice, terme conservé dans l'UI. Plan de comptes à longueur fixe par entité ; tiers = collectif numérique + auxiliaire alphanumérique.
- La clé de service Supabase n'est jamais embarquée dans Flutter ; aucun accès à la production ; migrations SQL versionnées dans le dépôt (projets dev local / recette / production séparés).

## Phasage

Lot 1 (fin nov. 2026) : modules 1 Socle, 2 Cabinet et dossiers, 3 Référentiels, 4 Saisie, 5 Pièces, 6 Consultation, 10 Import Perfecto. Lot 2 (mars 2027) : 7 Lettrage et rapprochement. Lot 3 (sept. 2027) : 8 Inventaire, 9 Clôture. **Schéma SQL complet des lots 1 à 3 avant toute interface.** Hors V1 : missions du cabinet/lien eABC, relevés PDF, stock permanent, saisie par les clients, système minimal. Avancés en V1 par décision : SYCEBNL (D-022 à D-029 dans `docs/decisions-dev.md`) et suggestions de saisie sans modèle (D-026). Ce qui est repoussé ou à reprendre (export Excel SYCEBNL, commentaires de notes, IA, déploiement) est dans `docs/reste-a-faire.md`.

## Conventions propres au projet

- Interface en français ; dossier courant toujours visible ; statuts colorés (brouillard, validée, revue, à corriger).
- Import Perfecto : numéros à 7 chiffres repris tels quels ; comptes de tiers collés (ex. `4110CHU`) scindés en collectif + code tiers ; montants négatifs de l'export convertis en sens inverse ; mode essai sans écriture.
