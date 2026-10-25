# Décisions prises en autonomie

Format : identifiant, date, contexte, choix, raison. Une décision ne rouvre jamais un point tranché dans `inputs/conception.md`.

## D-001 — 2026-10-25 — Référencer `inputs/` au lieu de copier dans `docs/`
- **Contexte** : le prompt de lancement demandait de copier `conception.md` et le modèle DGI sous `docs/`. Dansi a demandé de garder les fichiers dans `inputs/`.
- **Choix** : aucun fichier copié ; toute la documentation pointe vers `inputs/conception.md` et `inputs/Modèle DGI-Etats-Financiers-SN.xlsm`. `inputs/` reste hors git.
- **Raison** : instruction explicite ; convention intrants/extrants du projet.
- **Conséquence** : un clone du dépôt sans `inputs/` n'a pas la conception. Les règles implémentées sont néanmoins toutes traçables dans les tests et dans `docs/plan.md`.

## D-002 — 2026-10-25 — pgTAP via `supabase test db`
- **Contexte** : `pg_prove` n'est pas installé sur la machine.
- **Choix** : tests pgTAP dans `supabase/tests/*.sql`, exécutés par `supabase test db` (image Postgres Supabase, pgTAP inclus). Script `scripts/test.sh`.
- **Raison** : zéro dépendance supplémentaire, même moteur que la base locale.

## D-003 — 2026-10-25 — Dérivation des attributs du plan de référence
- **Contexte** : `inputs/plan-comptable-syscohada-revise.csv` ne fournit que code et libellé.
- **Choix** : nature dérivée de la classe (1-5 bilan, 6-8 gestion, 9 analytique) ; sens normal dérivé de la classe avec exceptions explicites (comptes soustractifs 28x, 29x, 39x, 49x, 59x, 109, 119/129, 4xx selon préfixe) ; indicateur collectif pour 401, 402, 408, 409, 411, 412, 418, 419, 421, 422, 42x…, 462/465 ; le tout porté dans le seed et modifiable par migration.
- **Raison** : règles SYSCOHADA stables ; traçables par test.

## D-004 — 2026-10-25 — Longueur des comptes importés de Perfecto
- **Contexte** : l'export réel montre des comptes à 6 chiffres (`401100`) ; §10.10 parle de 7 chiffres.
- **Choix** : l'import prend le numéro tel quel, le scinde si suffixe alphanumérique (collectif + tiers), puis complète à droite par des zéros jusqu'à la longueur fixe de l'entité (§3.3). Un numéro plus long que la longueur de l'entité est rejeté avec message dans le rapport d'import.
- **Raison** : conforme à §3.3 et robuste aux deux formats observés.

## D-005 — 2026-10-25 — Organisation du dépôt
- `supabase/` (config, migrations, seed, tests pgTAP, functions Edge) · `app/` (Flutter, une base de code desktop + mobile) · `service-documents/` (Python, PDF + Excel DGI) · `scripts/` · `docs/`.
- Branche de travail `lot1` ; fusion dans `main` au point d'étape.

## D-006 — 2026-10-25 — Permissions dérivées pour le verrouillage de période et la création de dossier
- **Contexte** : la matrice §8 n'a pas de ligne « verrouiller une période ». §10.2 : verrouillage par l'associé, ou par le chef de mission si l'option de l'entité est active ; déverrouillage réservé à l'associé avec motif.
- **Choix** : verrouillage = `cabinet.settings` (associé) ou `closing.provisional` sur le dossier (chef de mission) si `monthly_lock_enabled` ; déverrouillage = `cabinet.settings` + motif obligatoire. Création d'un dossier = `entities.manage` détenue sur au moins un périmètre ; le chef de mission créateur est affecté automatiquement au nouveau dossier (sinon il ne le verrait pas). Permission supplémentaire `roles.manage` (associé) pour « paquets ajustables par l'associé ».
- **Raison** : respecte la matrice sans inventer de rôle ; traçable par test.

## D-007 — 2026-10-25 — Copie du plan de référence et imputabilité
- **Contexte** : §3.3 « plan de référence copié à la création de l'entité, puis subdivisé » ; la classe 9 (analytique / hors bilan) est hors périmètre V1.
- **Choix** : copie des classes 1 à 8 (1 295 comptes) complétées à la longueur fixe de l'entité ; les comptes de 1 et 2 chiffres sont des têtes de chapitre non imputables (`allow_posting = false`), les autres sont imputables. La classe 9 reste dans le plan de référence, non copiée. Sept paires de codes donnent le même numéro complété (4/40, 5/50, 6/60, 7/70, 13/130, 49/490, 59/590) : le compte le plus détaillé l'emporte (ex. 1300000 = « Résultat en instance d'affectation »), les comptes enfants se rattachent à ce numéro. Les journaux de trésorerie (banque, caisse) ne sont pas créés automatiquement : ils exigent un compte de classe 5, choisi dans l'assistant d'ouverture ; seul le journal AN est créé d'office.
- **Raison** : respecte §3.4 (AN imposé) et évite des journaux de banque sans compte.

## D-008 — 2026-10-25 — Import Perfecto : comptes inconnus jamais créés automatiquement
- **Contexte** : l'export réel contient des subdivisions propres à Perfecto (`4452002`, `4478004`) absentes du plan SYSCOHADA copié dans l'entité.
- **Choix** : l'analyse les signale (`unknown_accounts`) ; la table de correspondance éditable permet de les rediriger vers un compte existant ou l'utilisateur crée d'abord la subdivision dans le plan. Les tiers manquants, eux, sont créés à l'application (case « créer » cochée par défaut), rattachés au collectif, typés d'après la classe du collectif (41 client, 40 fournisseur, 42 salarié). Un compte de banque suffixé (`5210ECO`) est proposé scindé ; l'utilisateur retire le suffixe dans la correspondance puisque 5210 n'est pas collectif.
- **Raison** : option la plus prudente (§prompt) : pas de compte créé à l'insu du chef de mission.
