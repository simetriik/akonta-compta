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

## D-009 — 2026-10-25 — Propositions de lettrage et de pointage en SQL
- **Contexte** : le plan prévoyait une Edge Function pour les propositions de lettrage (§11.1 cite les Edge Functions pour « propositions de lettrage »).
- **Choix** : fonctions SQL `lettering_proposals` (règle 1 : même tiers et même montant ; règle 2 : facture = règlement net + retenue constatée par une écriture débitant 447x / 445x) et `reconciliation_proposals` (même montant, date ± 5 jours), testées par pgTAP. L'application les appelle directement.
- **Raison** : aucune donnée externe ni traitement lourd ; la logique reste dans la base, testable et sous RLS.

## D-010 — 2026-10-25 — À-nouveaux exclus du pointage bancaire
- **Contexte** : la ligne de banque du journal des à-nouveaux n'a pas de contrepartie dans un relevé ; elle correspond au solde d'ouverture du premier relevé.
- **Choix** : les lignes du journal AN ne figurent pas parmi les lignes comptables à pointer ; les suspens antérieurs au premier relevé se saisissent comme écritures de l'exercice (ou s'importent) et se pointent normalement.
- **Raison** : évite un écart permanent égal au solde d'ouverture.

## D-011 — 2026-10-25 — Prorata temporis sur base 360 jours
- **Contexte** : §6 et §10.8 exigent le prorata temporis des amortissements et le prorata « au jour » des régularisations, sans préciser la base.
- **Choix** : base 360 jours (mois de 30 jours), fonction `days360` ; première annuité = base × taux × jours/360 ; dernier exercice = solde. Dégressif : taux linéaire × coefficient (1,5 par défaut) sur la valeur nette, bascule en linéaire sur la durée restante dès qu'il devient supérieur. Les extournes (régularisations, écarts de conversion) sont générées au 1er janvier N+1 en brouillard dès que l'écriture de N est validée et que N+1 existe.
- **Raison** : convention la plus répandue dans les cabinets de la zone et conforme au guide SYSCOHADA (prorata en jours ou en mois admis) ; modifiable en un point.

## D-012 — 2026-10-25 — Cartographie DGI générée depuis le modèle lui-même
- **Contexte** : §10.9 et §13 demandent une cartographie des cellules du modèle Excel DGI, versionnée.
- **Choix** : le modèle contient une feuille « champs fixes » (3 008 champs : code tableau, code ligne, libellé, cellule) utilisée par ses propres macros d'export XML. `scripts/generate_dgi_mappings.py` la lit, suit les formules de renvoi (ACTIF/PASSIF → BILAN) jusqu'aux cellules de saisie, ignore les totaux calculés et produit la migration `…0014_dgi_mappings.sql` (table `dgi_cell_mappings`, version `SN-2025`). La fonction SQL `dgi_cells` associe les postes des états générés et les champs d'identification ; le service Python écrit les cellules avec `keep_vba` sans jamais écraser une formule.
- **Raison** : fidèle au modèle officiel, rejouable quand la DGI publie une nouvelle version (nouveau numéro de version, régénération).

## D-013 — 2026-10-26 — Écriture créée depuis une ligne de relevé : date au choix
- **Contexte** : une ligne de relevé peut concerner une période déjà verrouillée (agios découverts au rapprochement suivant). La fonction `entry_from_statement_line` datait l'écriture à la date d'opération et la base la refusait, sans issue pour l'utilisateur.
- **Choix** : paramètre `p_entry_date` (défaut : date d'opération). L'application propose la date d'opération et laisse la reporter dans une période ouverte ; la ligne de relevé reste pointée avec l'écriture quelle que soit sa date. Aucune réouverture de période.
- **Raison** : respecte l'immutabilité des périodes verrouillées (§11.2) tout en permettant de solder le rapprochement.

## D-014 — 2026-10-26 — Poste CJ toujours implicite, comptes 13x des à-nouveaux en report à nouveau
- **Contexte** : la cartographie associait les comptes 13 au poste CJ « Résultat net de l'exercice » et le résultat implicite (classes 6/7/8) n'était ajouté que si CJ valait zéro. Dès qu'un exercice reprenait en à-nouveaux le résultat de l'an passé en instance d'affectation (1300000), CJ affichait ce résultat passé et le résultat courant disparaissait : bilan déséquilibré en cours d'exercice et sur N+1 tant que l'affectation n'était pas faite (vu sur SARL Démo pendant la préparation de la vidéo de recette).
- **Choix** : migration 0019. CJ est toujours le résultat implicite de l'exercice (hors écriture de détermination du résultat, D-013 bis) ; les comptes 12 et 13 vont au poste CH « Report à nouveau et résultat en instance », conformément au bilan SYSCOHADA (« Report à nouveau (+ ou −) »).
- **Raison** : un seul calcul du résultat, cohérent avec `accounting_result` ; l'équilibre actif = passif tient à tout moment de l'exercice.

## D-015 — 2026-10-27 — Refonte UI : un seul système de design dans `lib/design/`
- **Choix** : les jetons et composants vivent dans `app/lib/design/` (le thème de `core/theme.dart` y est déplacé) ; la table de saisie dense reste une grille spécifique à l'écran Saisie ; les widgets Material thémés non listés au garde-fou (TabBar, ListTile, RadioListTile, FilterChip, PopupMenuButton) sont tolérés ; captures « après » = goldens sur données fictives, « avant » = captures de la recette (données réelles de démo).
- **Raison** : périmètre maîtrisé sans toucher à la logique métier ni à la base ; comparaison avant/après indicative, non pixel à pixel.

## D-016 — 2026-10-30 — Changement d'identité visuelle : bleu nuit et orange (système Claude Design)
- **Contexte** : audit du design (`docs/audit-design.md`), puis refonte du système de design avec Claude Design (https://claude.ai/artifact/ScBBYrdyJ5o3CPkYTrYsNx). Décision de Dansi : l'identité terracotta/sable (logo validé le 25 oct.) est remplacée.
- **Choix** : bleu nuit `#1E2A5A` (rail, titres), orange `#F28C28` réservé à l'action (un bouton principal par écran, texte bleu nuit dessus), neutres bleutés ; logos SVG du système (`app/assets/logo/`, paquet `flutter_svg`, validé par Dansi) ; jetons renommés (`accent`, `textStrong`, `rowSelected`…, voir `docs/design/systeme-de-design.md`) ; échelle typographique par rôles (corps 15 px, montants 15 px) ; rayons 4/8/12 ; contrôles 40 px (48 px sous 900 px) ; rail réduit sur tablette ; `AkToast` à la place des `SnackBar` ; `AkGrid` unique pour les tableaux longs ; grille de saisie sans bordures ; solde écrit « 1 250 000 D » (jamais de signe moins) ; dialogues en trois largeurs.
- **Raison** : lisibilité en saisie intensive, hiérarchie visuelle, cohérence des tableaux, adaptation tablette. Aucun changement de logique métier ni de base.
- **Reste** : documents PDF et liasse du service Python (identité à reprendre), réglage manuel clair/sombre dans le menu utilisateur, `TabBar` et `PopupMenuButton` encore Material thémés, choix de langue du kit logo `outputs/logo-akonta/` (ancien, conservé tel quel).


## D-017 — 2026-10-30 — L'administrateur technique est invisible des membres du cabinet
- **Contexte** : constaté en recette (voir Q-016) : `profiles_select` et `assignments_select` montraient l'administrateur technique à tous les membres, et la piste d'audit affichait son nom. La conception le définit « sans accès aux données comptables » sans traiter sa visibilité ; décision de Dansi le 30 oct. 2026.
- **Choix** : migration `20261030100001_tech_admin_invisible.sql`. Fonction `is_tech_admin(uuid)` ; politiques `profiles_select` et `assignments_select` qui masquent les administrateurs techniques aux autres (ils se voient entre eux et se voient eux-mêmes) ; fonction `actor_labels(uuid[])` qui rend le libellé « Administration technique » dans la piste d'audit pour les non-administrateurs. Les actions restent tracées (la piste d'audit n'est pas altérée). L'écran d'audit lit les libellés par cette fonction.
- **Test** : `supabase/tests/160_tech_admin_invisible.test.sql`.
- **Raison** : séparation des pouvoirs ; la règle vit dans la base, pas dans Flutter.
- **Reste** : les relations imbriquées vers `profiles` (créateur, auteur d'une écriture) renvoient `null` pour un administrateur ; à vérifier dans les écrans au fil de la recette.
