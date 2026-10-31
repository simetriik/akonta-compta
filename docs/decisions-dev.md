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

## D-018 — 2026-10-30 — Le créateur d'un dossier le voit dès l'insertion (INSERT ... RETURNING)
- **Contexte** : en recette, l'associé ne pouvait pas créer de dossier (« violation RLS »). `entities_repository.create` utilise `insert(...).select()` ; la politique `entities_select` appelle `can_access_entity(id)`, qui relit `entities` (contrôle du cabinet) et ne voit pas la ligne insérée par la commande en cours. Régression introduite par le contrôle de cabinet ajouté à `can_access_entity` (migration dossiers) ; aucun test ne couvrait l'insertion avec RETURNING.
- **Choix** : migration `20261030100002_entities_select_creator.sql` : `entities_select` accepte aussi `created_by = auth.uid()`. Test : `supabase/tests/170_entities_insert_returning.test.sql`.
- **Conséquence acceptée** : un créateur qui perdrait ensuite son affectation continue de voir le dossier qu'il a créé.
- **Alternative écartée** : id généré côté Flutter (dépendance `uuid` à ajouter), fonction volatile (coût sur toutes les lectures).

## D-019 — 2026-10-30 — Affectations : politique d'écriture scindée pour que la lecture reste filtrée
- **Contexte** : après D-017, l'écran Cabinet > Affectations plantait (« type error ») pour l'associé. `assignments_write` était `FOR ALL` : elle comprend la lecture et donnait à l'associé (`assignments.manage`) la ligne de l'administrateur technique, contournant `assignments_select` ; le profil lié étant masqué, `(r['profiles'] as Map)` recevait `null`. Le test 160 passait à tort : il connectait l'associé en aal1 (le rôle exige le TOTP), donc sans aucun droit.
- **Choix** : migration `20261030100003_assignments_write_split.sql` : `assignments_write` remplacée par `assignments_insert`, `assignments_update`, `assignments_delete` ; update/delete interdits sur l'affectation d'un administrateur technique sauf pour un administrateur technique. Le dépôt de données ignore une ligne dont le profil est illisible. Test 160 refait en aal2.
- **Leçon** : une politique `FOR ALL` s'ajoute (OU) aux politiques de lecture ; tout test RLS d'un rôle `requires_mfa` doit s'authentifier en aal2. Autres politiques `FOR ALL` du schéma (liste dans la session) : sans lien avec un masquage de lecture pour l'instant.

## D-020 — 2026-10-30 — Sélecteurs à recherche au-delà de 12 options
- **Contexte** : en recette, les listes déroulantes longues (dossiers, comptes, tiers, collaborateurs, bientôt une vingtaine de modèles d'écriture) obligeaient à faire défiler. La conception ne prévoit l'autocomplétion que pour la grille de saisie ; les 34 autres `AkDropdown` n'avaient pas été revus.
- **Choix** : `AkDropdown` bascule seul vers `AkSearchSelect` quand il a plus de `akSearchThreshold` (12) options ; paramètre `searchable` pour forcer (`true`) ou interdire (`false`). Aucun écran modifié. Filtre sans casse ni accents, tous les mots saisis requis, libellés commençant par la saisie en tête ; ↑ ↓ Entrée Échap ; en quittant le champ, une saisie qui ne désigne qu'une option la retient, sinon l'option précédente est rétablie. Les options à valeur nulle (« Tous les tiers ») restent choisissables.
- **Test** : `app/test/search_select_test.dart`. Aucune migration.
- **Reste** : affichage enrichi des options (code en chasse fixe, intitulé en dessous) pour comptes et tiers, à faire si la recette le demande ; vérification visuelle sur mobile.

## D-021 — 2026-10-30 — Bibliothèque de 25 modèles d'écritures supplémentaires
- **Contexte** : la recette a montré que 5 modèles ne suffisent pas à accélérer la saisie.
- **Choix** : migration `20261030100004_entry_template_library.sql`. Fonction `seed_entry_template_library(cabinet)`, rejouable, appelée à la création d'un cabinet et pour les cabinets existants : 25 modèles (achats courants avec TVA, loyer avec/sans TVA, immobilisation, ventes de services et exonérées, avoirs client/fournisseur, règlements banque et caisse, versement d'espèces, paiements TVA / CNSS / IRPP). Comptes pris dans le plan de référence du dépôt, à la longueur du plan de l'entité. Correction de Q-013 : `SALAIRES` vise `422` (et non 4221) ; `FRAIS_BQ_TAF` et `REGL_CLIENT_RET` visent `521` (aligné sur le compte du journal de banque, 5210000) au lieu de 5211.
- **Hypothèse à confirmer** : les comptes et la TVA de chaque modèle (voir `outputs/modeles-ecritures-a-valider.md`). Choix prudents : loyer proposé avec et sans TVA ; prime d'assurance sans TVA ; avoirs inscrits sur les comptes de vente et d'achat (le plan de référence n'a pas de compte 709) ; versement d'espèces direct caisse → banque sans compte de virement interne.
- **Test** : `supabase/tests/180_entry_template_library.test.sql` (comptes au plan, tiers sur collectifs, taux existants, une ligne solde par modèle, Q-013, rejouable) ; `030_referentiels` passe de 5 à 30 modèles.
- **Limite connue** : le modèle `SALAIRES` garde sa ligne d'IRPP « saisie » qui reprend le montant de base ; non modifié ici.

## D-022 — 2026-10-31 — Associations (SYCEBNL) : choix du référentiel à la création de l'entité, chantier planifié hors V1
- **Contexte** : demande d'ajouter la comptabilité des associations (SYCEBNL, OHADA). La conception (`inputs/conception.md`, lignes 10, 18 et 129) la classe hors V1 ; la vision long terme la cite. Le schéma a déjà `entities.accounting_system`, limité à `'normal'` par contrainte, et un déclencheur en réservait la modification à l'associé (`dossiers.sql`, lignes 39 et 82), sans l'interdire.
- **Choix** : le système comptable se choisit **à la création de l'entité** (donc du dossier), dans un champ « Référentiel comptable » du formulaire de création, et reste **non modifiable** ensuite : un changement de référentiel passe par une nouvelle entité. La forme juridique peut pré-sélectionner le référentiel. Le choix détermine le plan de comptes, les modèles d'écriture, les états financiers et la clôture proposés par défaut.
- **Périmètre du futur lot** (aucun code pour l'instant), en tranches : (a) valeur `'sycebnl'` et choix à la création ; (b) plan de comptes et modèles d'écriture SYCEBNL ; (c) états financiers ; (d) clôture et affectation du résultat propres aux associations. Les règles de validation d'écriture (équilibre, période, numérotation continue) ne changent pas. Plan et correspondances en tables paramétrables versionnées.
- **Réalisé (tranches 1 et 2)** : migrations `20261031100001_sycebnl_referentiel.sql` (valeur `'sycebnl'`, référentiel **immuable** ; `reference_accounts` clé par `(system, code)`, codes jusqu'à 5 chiffres ; `accounts.reference_system` ; `copy_reference_plan` suit le référentiel de l'entité, compte imputable = sans subdivision pour le SYCEBNL ; `entry_templates.accounting_system`), `20261031100002_seed_sycebnl_accounts.sql` (1 130 comptes, généré par `scripts/generate_sycebnl_accounts.py` depuis `outputs/sycebnl/plan-sycebnl.csv`), `20261031100003_sycebnl_template_library.sql` (19 modèles `AS_*`, sans TVA). Interface : champ « Référentiel comptable » à la création (pré-sélection par la forme juridique, figé ensuite), modèles filtrés par référentiel, avertissement sur l'écran de clôture d'un dossier SYCEBNL. Tests : `190_sycebnl_referentiel.test.sql`, `entity_form_test.dart`.
- **Source du plan** : https://plan-comptable-ohada.com/sycebnl/comptes.html, site tiers (1 130 comptes, total conforme à l'annonce du site), non le Journal officiel OHADA. À rapprocher du texte officiel avant la production. Sens normal, comptes collectifs et lettrables : hypothèses (règles par préfixe du générateur), à faire valider par ABC.
- **Limites connues** : classe 9 (contributions volontaires en nature, comptabilité analytique) non copiée dans l'entité, comme pour le SYSCOHADA ; cinq comptes de regroupement (28, 29, 49, 59, 68) se confondent avec leur sous-compte en `0` une fois complétés à la longueur du plan : le plus détaillé est conservé (règle déjà en vigueur) ; états financiers, fiscalité et clôture SYCEBNL non livrés (tranches 3 et 4) : l'assistant de clôture affiche un avertissement mais ne bloque pas ; modèle de paie simplifié sans retenues.
- **Priorité** : prochaine étape décidée par l'utilisateur le 31 oct. 2026, avant le palier 0 des suggestions de saisie (non commencé).

## D-023 — 2026-10-31 — Un compte copié du plan de référence garde son sens et son rattachement
- **Contexte** : en préparant le SYCEBNL, constat que `accounts_validate` appliquait à chaque insertion l'héritage du sens, de la nature et du parent depuis le plus long préfixe existant, y compris pour la copie du plan de référence. Les comptes dont le sens diffère de leur « parent » étaient faussés : en recette, `2800000` Amortissements est stocké au débit (référence : crédit), `1390000` perte au crédit (référence : débit), `1090000` au crédit (référence : débit). Pour le SYCEBNL, les comptes à 2 chiffres auraient en plus été rattachés au premier compte de leur classe.
- **Choix** : `copy_reference_plan` positionne le réglage transactionnel `akonta.reference_copy` ; pendant la copie, `accounts_validate` ne touche ni au sens, ni à la nature, ni au parent (fixés ensuite par rattachement d'après le plan de référence). Les subdivisions créées à la main héritent toujours de leur parent. Test : `190_sycebnl_referentiel.test.sql`.
- **Reste** : les entités déjà créées gardent les sens erronés (voir Q-018) ; correction à décider.

## D-024 — 2026-10-31 — États financiers et clôture SYCEBNL (bilan, compte de résultat, à-nouveaux, affectation)
- **Contexte** : tranches 3a et 4 du lot SYCEBNL (D-022). Source : Journal officiel OHADA 2023, acte uniforme SYCEBNL, partie 4 (PDF ohada.com, pages 346 à 348 et 395-396), lues sur le scan : l'OCR du site tiers comportait des codes faux. Le chapitre 2 (associations) comprend 3 états principaux (bilan, compte de résultat, tableau des flux) et 35 notes ; il n'y a **pas** de « compte d'emploi des ressources » (le tableau emplois-ressources relève du chapitre 3, projets de développement ; le chapitre 4 est le système minimal de trésorerie).
- **Choix** : migrations `20261031100005_seed_sycebnl_statement_mappings.sql` (136 règles, version `SYCEBNL-2024`, généré par `scripts/generate_sycebnl_mappings.py`), `20261031100006_statements_by_system.sql` (`statement_version`, `statement_result_post` ; `generate_financial_statements` choisit la version selon le référentiel de l'entité ; le résultat net implicite est le poste CH au lieu de CJ), `20261031100007_sycebnl_closing.sql` (compte « résultat en instance » 128 au lieu de 130 pour les à-nouveaux ; affectation du résultat SYCEBNL vers 112, 118 et 121 sans dividendes ; calcul de l'impôt sur les sociétés refusé). Interface : intitulé et boutons des états selon le référentiel (pas d'export PDF ni de liasse DGI pour un dossier SYCEBNL), étape fiscale « non applicable », affectation sans dividendes.
- **Interprétations du texte officiel** (à valider par ABC, Q-020) : XA = RA à **RH** (le libellé dit RA à RG, ce qui exclurait les reprises 79 et fausserait le résultat) ; comptes « p » (part) 2919 → AF, 2939 → AK, 2949 → AL ; chiffre illisible de la colonne amortissements de AG lu 2951 ; 702 en RG ; écarts avec le tableau officiel pour que tout compte imputable soit repris : 35 en BB, 46 en BE (solde débiteur) ou DI (solde créditeur), 7054 et 7055 en RE, 2817 en dépréciation de AF ; 409 et 419 lus à solde net ; 478 et 479 uniquement en BY et DY ; CG reprend 12 et les 13 en instance, CH est calculé (comme CH/CJ du SYSCOHADA, migration 0019).
- **Test** : `200_sycebnl_statements.test.sql` (couverture des 1 130 comptes : tout compte imputable repris une fois sur son sens normal, jamais deux fois sur le sens inverse ; version selon le référentiel ; bilan et compte de résultat d'une association, contrôles passés) et `210_sycebnl_closing.test.sql` (résultat, à-nouveaux sur 128, affectation, refus des dividendes et de l'IS).
- **Limites** : un solde dans le sens anormal (ex. 4991 au débit, 5710 au crédit) reste hors des postes ; le contrôle « actif = passif » le signale. Tableau des flux, 35 notes annexes et exports PDF / Excel non livrés : le texte ne donne pas de correspondance pour les flux. Les travaux d'inventaire (amortissements 28x, dotations 681x, provisions, écarts de conversion, cessions) utilisent encore des comptes SYSCOHADA : non adaptés. L'écran Clôture n'a pas de test de widget.

