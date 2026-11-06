# Rapport – traitement des retours de la recette du 05/11/2026

Branche : `recette-2026-11-05` (depuis `main`, **ni poussée ni fusionnée**). 8 commits. Aucun push, aucune donnée réelle touchée.
Vérifications finales : `flutter analyze` sans alerte, **376 tests Flutter** (dont `design_guard_test`, `architecture_test` et les goldens), **pgTAP 48 fichiers, 758 assertions** (migrations rejouées sur une base locale vierge), **pytest 33**, **Deno 41**.

## 1. État par point

| Point | État | Ce qui est fait | Fichiers principaux | Tests ajoutés |
|---|---|---|---|---|
| **7** Dossier qui ne s'ouvre pas | **fait** | Clic ou Entrée sur une carte = dossier courant + ouverture de sa fiche ; même chose depuis la liste des dossiers. | `presentation/dashboard/dashboard_screen.dart`, `entities/entities_screen.dart` | `dashboard_open_dossier_test` (clic, Entrée) |
| **8** Doublons de dossiers | **fait** (reprise : outil prêt, non exécuté) | Bouton désactivé dès le 1er clic, « Création en cours… » ; idempotence serveur (`entities.request_id`) ; refus d'un homonyme quand un des deux dossiers n'a pas d'IFU (réglage cabinet) ; outil « Supprimer ce doublon » réservé à l'associé, refusé dès que le dossier contient une donnée. | `migrations/20261106100001_entity_duplicates.sql`, `entities/duplicate_entity_button.dart`, `entity_form.dart`, `entity_wizard_screen.dart`, `core/request_id.dart` | `entity_duplicates_test` (3), pgTAP `410` (10) |
| **6** Créer un tiers sans quitter la saisie | **fait** | Ligne « Créer ce tiers » / « Créer le compte » dans l'autocomplétion ; panneau léger (nom, type, collectif, IFU) ; retour sur la même ligne, saisie intacte ; double clic neutralisé. Composant `AkAutocompleteField.onCreate` ajouté au système de design. | `design/components/fields.dart`, `entries/quick_create_dialogs.dart`, `entries/entry_grid.dart` | `quick_create_test` (8, dont le parcours complet dans l'éditeur) |
| **9** Audit UX général | **partiel** | Voir registre : 12 défauts relevés, 10 traités. Correction systémique des boutons asynchrones, confirmations avant suppression (garde-fou automatique), balance → grand livre. **Parcours manuel des 19 écrans non fait** (voir §2). | `design/components/buttons.dart`, `consultation/balance_tab.dart`, 5 écrans de suppression | `button_pending_test`, `confirm_guard_test`, `balance_drilldown_test` |
| **2** Colonne « Contrepartie » | **fait** | Calcul en base (contrepartie principale, « + n », liste complète) ; colonne à l'écran (infobulle = liste complète), en PDF et en Excel ; option d'export « principale seule / toutes » ; colonne Tiers = nom du tiers. | `migrations/20261106200001_ledger_counterpart.sql`, `service-documents/app/{models,formatting,excel,pdf}.py`, `supabase/functions/_shared/documents.ts`, `consultation/ledger_tab.dart` | pgTAP `420` (9), pytest (+7), Deno (+1), `ledger_counterpart_test` (4) |
| **1** Modèles d'écriture | **fait, avec une limite** | Existait déjà : bibliothèque de 30 modèles, deux niveaux, montants en pourcentage ou solde, comptes génériques. Ajouté : « Enregistrer comme modèle » depuis l'éditeur ; tiers choisi à l'appel pour les comptes collectifs génériques ; droits `templates.manage_common` / `templates.manage_entity` paramétrables par rôle. | `migrations/20261106300001_template_permissions.sql`, `entries/save_as_template.dart`, `entry_template_picker.dart`, `application/entries/entry_editor_logic.dart` | pgTAP `430` (9), `entry_templates_recette_test` (6), `save_as_template_test` (3) |
| **4** Audit (partie compta) | **fait** (hors module ISA) | Rôle « Auditeur » en lecture seule ; piste d'audit par dossier (qui a saisi, modifié, validé, supprimé, quand) ; contrôles automatiques (soldes anormaux, écritures hors période) ; deux nouveaux onglets dans Consultation. | `migrations/20261106400001_auditor_trail_controls.sql`, `consultation/audit_tabs.dart` | pgTAP `440` (13), `audit_controls_test` (8) |
| **3** Pièces scannées | **préparé, non codé** | Architecture dans `plan.md` (endpoint, schéma JSON, contrôles, file d'attente hors ligne). Aucun appel d'API, aucune clé. | – | – |
| **5** Liasse e-Bilan | **préparé, non codé** | Liste de ce qu'il faut fournir dans `plan.md`. | – | – |

Limite du point 1 : dans un modèle, toutes les lignes « saisie » reprennent **le même montant de base** (comportement existant). Un modèle enregistré depuis une écriture a donc des lignes au même montant ; les pourcentages (TVA 18 %) se règlent ensuite dans Référentiels → Modèles. Détecter automatiquement un pourcentage depuis une écriture n'a pas été fait (question Q-R02).

## 2. Registre UX résumé
12 défauts : **4 bloquants, tous corrigés** ; 6 gênants corrigés, 1 renvoyé au point 2 (corrigé) ; 1 d'outillage à décider (`.env`) ; 1 cosmétique reporté (UX-12 : filtres inutiles sur les deux nouveaux onglets).
**Reporté (UX-11)** : le parcours manuel des 19 écrans sur une pile en marche (créer un dossier, saisir dix écritures, exporter, clôturer), qui est la seule façon de vérifier le clavier intégral (famille 5), la cohérence visuelle (7) et les états vide/chargement/erreur (8). Je n'ai pas piloté l'interface réelle dans cette session ; mon audit est statique plus les gardes automatiques. Le détail est dans `registre-ux.md`.

## 3. Doublon « Maître ASSANI » (à traiter par vous)
Je n'ai touché à aucune donnée réelle. Pour nettoyer : se connecter en associé, ouvrir la fiche du dossier en double qui est **vide** (Dossiers → le dossier → bouton rouge « Supprimer ce doublon »). La base refusera si le dossier contient déjà une écriture, une pièce, un tiers, un import ou une facture ; il faudra alors garder les deux ou fusionner à la main. Vérifier d'abord lequel des deux porte des données.

## 4. Décisions provisoires appliquées (à faire valider par le cabinet)
- **D-R01** Ouvrir un dossier depuis le tableau de bord = afficher sa fiche (comme la liste des dossiers) et en faire le dossier courant.
- **D-R02** Un dossier est refusé s'il a le même nom (sans casse ni accents) qu'un autre quand l'un des deux n'a pas d'IFU ; deux homonymes avec IFU distincts sont acceptés. Réglage cabinet `block_homonym_entities`. (Q-R01)
- **D-R03** Modèles d'écriture communs : associé et chefs de mission ; modèles de dossier : tout collaborateur du dossier (stagiaire inclus). L'associé peut retirer ces droits par rôle.
- **D-R04** Contrepartie : compte opposé au montant le plus élevé ; à égalité le plus petit numéro de compte ; plusieurs lignes sur un même compte opposé comptent pour un seul. Variante `lowest_account` disponible dans `cabinets.ledger_counterpart_rule`. Tiers affiché par son nom, code en infobulle.
- **D-R05** Rôle Auditeur : lecture du grand livre, des balances, des exports et de la piste d'audit, **double vérification (MFA) obligatoire**, affecté dossier par dossier. Les chefs de mission lisent la piste d'audit de leurs dossiers.
- **D-R06** Contrôles : solde anormal = fournisseurs 40x débiteurs (hors 409), clients 41x créditeurs (hors 419), caisse 57x créditrice, charges créditrices, produits débiteurs ; écriture hors période = date hors de sa période, hors de son exercice, ou postérieure de plus d'un mois à la date du jour.
- **D-R07** Tout bouton d'action asynchrone se désactive seul (sablier fixe) jusqu'à la fin de l'action.

## 5. Questions en attente (`questions.md`)
- **Q-R01** (tranchée) Règle sur le nom conservée, IFU non obligatoire ; homonymes sans IFU distingués par un suffixe.
- **Q-R02** (tranchée) Pas de détection automatique du pourcentage ; il se règle dans Référentiels → Modèles.
- **Q-R03** (résolue) Ligne 1 du `.env` commentée, la CLI Supabase démarre.

## 6. À savoir avant de déployer
- **4 migrations** à appliquer dans l'ordre : `20261106100001`, `…200001`, `…300001`, `…400001`. Toutes sont additives (colonnes, fonctions, politiques) ; seule `general_ledger` est supprimée puis recréée (nouvelles colonnes de retour) : **l'application Flutter de la recette doit être mise à jour en même temps**, sinon les écrans de consultation ne liront plus la réponse. Un retour arrière est consigné en commentaire en pied de chaque migration. Testées sur une base locale vierge, **pas sur une copie des données de la recette**.
- Les exports PDF/Excel avec contrepartie sont testés par pytest et Deno, **pas de bout en bout** sur la pile (Edge Function + service). À essayer une fois.
- Redéployer l'Edge Function `export-document` et le service de documents.
- Pour tester, j’ai démarré la pile Supabase locale depuis une copie de `supabase/` dans mon dossier temporaire (le `.env` racine bloque la CLI, Q-R03), puis je l’ai arrêtée.
- Mes décisions sont consignées ici et non dans `docs/decisions-dev.md` (la mission imposait `extrants/`) : à reporter si vous voulez les garder dans le dépôt.

## 7. Mode opératoire de recette (moins de 5 minutes par point)
Prérequis : application mise à jour, connecté en **associé**, un dossier avec quelques écritures validées.
1. **Point 7** (1 min) : tableau de bord → cliquer une carte (puis Tab + Entrée sur une autre) → la fiche du dossier s'ouvre et « Dossier courant » apparaît.
2. **Point 8** (3 min) : Nouveau dossier → remplir le nom → cliquer 2 fois vite sur « Créer » : un seul dossier, bouton « Création en cours… ». Essayer de créer un dossier au même nom sans IFU : refus avec message. Ouvrir ce dossier vide → « Supprimer ce doublon » → confirmer.
3. **Point 6** (3 min) : Saisie → nouvelle écriture → compte 411 → dans Tiers taper un nom inconnu → « Créer ce tiers » → valider le panneau : le tiers revient sur la ligne, le montant déjà saisi est intact. Même chose en tapant un numéro de compte absent du plan.
4. **Point 9** (3 min) : Consultation → Balance générale → cliquer un compte → grand livre filtré sur ce compte. Saisie → ouvrir un brouillard → Supprimer → une confirmation s'affiche. Cliquer 2 fois vite sur n'importe quel « Enregistrer » : une seule action.
5. **Point 2** (3 min) : Consultation → Grand livre : colonnes Tiers (nom) et Contrepartie (« 6011000 + 1 ») ; survol = liste complète. Exporter → PDF et Excel ; cocher « Grand livre : toutes les contreparties » et réexporter.
6. **Point 1** (4 min) : Saisie → saisir 2 lignes avec comptes → « Enregistrer comme modèle » → nommer. Nouvelle écriture → « Modèle » → le choisir, saisir un montant, choisir un tiers : l'écriture est préremplie (brouillard). Se connecter en assistant : il ne peut enregistrer qu'un modèle de dossier.
7. **Point 4** (4 min) : Cabinet → Collaborateurs → affecter un compte avec le rôle « Auditeur » sur un dossier. Se connecter avec ce compte : il lit Consultation (grand livre, balances, exports), ne peut ni saisir ni créer. Onglets « Piste d'audit » (qui a validé, quand) et « Contrôles » (anomalies, clic = ouvre l'écriture).
