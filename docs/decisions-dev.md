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
