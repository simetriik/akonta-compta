# Plan – retours de la recette du 05/11/2026

Sources : `intrants/Cadrage - retours de la recette du 05_11_2026.md` (règles métier) et `intrants/prompt-claude-code-recette-2026-11-05.md` (mission).
Branche : `recette-2026-11-05` (depuis `main`). Note : le prompt cite `intrants/recette-2026-11-05/…`, les fichiers sont en réalité à la racine de `intrants/`.

Ordre d'exécution : 7 → 8 → 6 → 9 → 2 → 1 → 4 (partie compta). Points 3 et 5 : préparation seulement.

## Point 7 – Un clic sur un dossier du tableau de bord l'ouvre

**Existant.** `app/lib/src/presentation/dashboard/dashboard_screen.dart:115-187` (`DossierCard`) : `onTap` appelle seulement `currentEntityProvider.notifier.select(entity)`. Le dossier devient courant mais aucun écran ne s'ouvre : c'est le « ne s'ouvre pas ». La liste `/dossiers` (`entities_screen.dart`) navigue, elle, vers `/dossiers/:id`.

**À faire.** `onTap` = sélectionner puis `context.go('/dossiers/${entity.id}')`. Entrée/Espace passent par l'`InkWell` de `AkCard` (focusable). Même comportement sur `/dossiers` : ouvrir la fiche rend aussi le dossier actif.

**Risque / effort.** Faible, 0,5 h. Destination « fiche du dossier » choisie par cohérence avec la liste (décision provisoire D-R01).

**Tests.** Widget : pomper `DossierCard` sous un `GoRouter`, taper → `currentEntityProvider` = dossier et route `/dossiers/<id>` ; idem avec Entrée.

## Point 8 – Doublons de dossiers

**Existant.**
- Création : `entity_wizard_screen.dart` (étape 1, `entity_form.dart`) → `SupabaseEntitiesRepository.create` (`supabase_entities_repository.dart:22`), simple `insert`, sans clé de demande.
- Base : index `entities_tax_id_unique (cabinet_id, tax_id) where tax_id is not null` (`20261025200002_dossiers.sql:50`). Le doublon Maître ASSANI a donc passé car l'IFU était vide : la contrainte ne protège rien sans IFU.

**À modifier / créer.**
1. UI : bouton « Créer » désactivé dès le premier clic, libellé « Création en cours… » (état `_submitting`, remis à faux en cas d'erreur).
2. Idempotence : colonne `entities.request_id uuid` + index unique `(cabinet_id, request_id)`; l'assistant génère l'UUID à l'ouverture de l'étape, `create` l'envoie, un second envoi renvoie le dossier existant (`insert … on conflict do nothing` puis `select`), via une RPC `create_entity`.
3. Unicité de l'identifiant client : paramètre cabinet `client_identifier` (défaut `tax_id`). Pour un client sans IFU : contrainte complémentaire douce sur `lower(unaccent(trim(name)))` par cabinet, avec avertissement bloquant « un dossier de ce nom existe » levé par une case explicite (décision provisoire D-R02, question Q-R01).
4. Outil de reprise : RPC `merge_empty_duplicate_entity(keep, duplicate)` réservée à l'associé : refuse si le doublon porte une écriture, une pièce, un tiers ou un exercice non vide ; sinon supprime le doublon (audit tracé). Écran dans la fiche du dossier. **Je ne l'exécute sur aucune donnée réelle** ; le doublon Maître ASSANI est signalé dans le rapport.

**Risques.** Migration sur table existante : colonne nullable, index partiel, aucune perte. Réversible (`down` fourni). Effort 4 h.

**Tests.** pgTAP : double appel `create_entity` même `request_id` → 1 dossier ; fusion refusée si écriture ; fusion acceptée si vide ; refus pour non-associé. Widget : deuxième tap sans effet, libellé « Création en cours ».

## Point 6 – Créer un tiers (ou un compte) sans quitter la saisie

**Existant.** `AkThirdPartyField` (`app/lib/design/components/fields.dart:914`) utilisé par `entry_grid.dart:181`; `AkAutocompleteField` ne propose que la sélection. Création de tiers : écran Référentiels uniquement (`references/`, `references_repository`).

**À faire.**
- `AkThirdPartyField` : paramètre `onCreate` ; quand le texte tapé ne correspond à rien, dernière option « Créer ce tiers “…” ».
- Panneau léger `ThirdPartyQuickCreate` (`AkDialog` taille S) : nom, type (client / fournisseur / autre), compte collectif (pré-rempli selon le type), IFU facultatif. Réutilise le même dépôt et la même validation que le référentiel.
- Au retour : tiers sélectionné sur la même ligne, brouillon intact (le dialogue ne touche pas au `State` de la grille).
- Même mécanique pour un compte général manquant (`AkAccountField`) : « Créer ce compte » (numéro pré-rempli, libellé, classe déduite).
- Droits : création réservée à qui a la permission existante sur les référentiels ; sinon option masquée.

**Risques.** Perte de focus clavier au retour (à traiter : refocus de la cellule). Effort 6 h.

**Tests.** Widget : saisie d'un nom inconnu → option visible ; création → tiers sélectionné et autres lignes inchangées ; compte idem ; clavier seul (Tab, Entrée).

## Point 9 – Audit général de l'expérience utilisateur

**Existant.** `extrants/audit-ux-ui-2026-11-04.md` et captures `audit-ux-captures-2026-11-04/` (point de départ, à revérifier), `design_guard_test.dart`, goldens `test/golden/`.

**Méthode.** Parcours des 19 écrans sur la pile locale (`scripts/start.sh`, `scripts/demo.sh`) avec les scénarios du cadrage : créer un dossier, saisir dix écritures avec nouveaux tiers, grand livre (consultation + export), corriger une écriture, clôturer. Balayage statique en complément (grep des `InkWell`/`onTap` nuls, `GestureDetector`, boutons sans état « en cours », `Text` de code là où un nom existe).
**Registre** : `registre-ux.md` (écran, description, famille 1-8, gravité, correction, statut). Correction par gravité, un commit par défaut, un test chacun.

**Risque.** Périmètre ouvert : borner aux bloquants et gênants ; cosmétiques seulement si coût faible. Effort 12-16 h.

## Point 2 – Colonne « Contrepartie » au grand livre

**Existant.** RPC `general_ledger` (`20261025200007_consultation.sql:40`) ; écran `consultation/ledger_tab.dart` (`LedgerGrid`, colonne « Tiers » affiche `line.thirdPartyCode`) ; exports PDF `service-documents/app/pdf.py:89`, Excel `excel.py:61`, modèles `models.py` ; menu d'export `consultation_screen.dart:190`.

**À faire.**
- SQL : calcul de la contrepartie par ligne dans `general_ledger` (ou fonction `ledger_counterparts`) : lignes de même écriture, sens opposé ; principale = montant le plus élevé, départage par numéro de ligne ; `counterpart_count` et liste complète JSON.
- Règle paramétrable (`ledger_counterpart_rule` : `largest_opposite` par défaut).
- Écran : colonne « Contrepartie » (« 6011 + 1 », infobulle/clic = liste complète) ; PDF et Excel : colonne + option d'export « principale seule / liste complète ».
- Colonne Tiers : afficher le **nom** du tiers (jointure `third_parties`), le code en infobulle ; corriger aussi PDF et Excel.

**Risques.** Performance de la RPC (fenêtrage par écriture, index existants sur `entry_id`) ; ne pas changer les soldes. Effort 6 h.

**Tests.** pgTAP : exemple du cadrage (OD 1 : 4011 → « 6011 + 1 », 6011 → « 4011 », 4452 → « 4011 »), écriture à deux lignes, ex æquo. pytest : colonnes PDF/Excel dans les deux modes. Widget : affichage et infobulle.

## Point 1 – Modèles d'écriture

**Existant (déjà là).** Tables `entry_templates` / `entry_template_lines` (niveau cabinet ou `entity_id`), formules `input` / `percent_of` / `balance`, taux paramétrés, bibliothèque de 30 modèles (`20261030100004_entry_template_library.sql`), comptes génériques avec `uses_third_party`, `EntryTemplatePicker` (`entry_template_picker.dart`).

**Manque.**
- « Enregistrer comme modèle » depuis une écriture existante.
- Résolution des comptes génériques au moment de l'appel (choix du compte précis du dossier, ex. 4111CHU).
- Montant « libre » ou pourcentage d'une ligne de base : à vérifier dans le sélecteur actuel (un seul « montant de base »).
- Écran de gestion des modèles de dossier ; droits : modèles communs = associé + seniors, modèles de dossier = tout collaborateur du dossier, **paramétrables** (table de permissions existante `permissions`, nouvelles permissions `templates.manage_common`, `templates.manage_entity`).
- Raccourci clavier d'appel depuis l'éditeur.

**Risques.** RLS des modèles de dossier ; collision de `code`. Effort 8 h.

**Tests.** pgTAP : RLS (associé/senior/collaborateur/autre dossier). Unitaires : calcul pourcentage et solde, résolution du générique. Widget : appel depuis l'éditeur → brouillon pré-rempli ; enregistrer comme modèle.

## Point 4 (partie compta) – Audit

**Existant.** `audit_log` chaînée SHA-256 (`20261025200001_socle.sql:308`), lue côté Flutter seulement par l'administration (`supabase_admin_repository.dart`).

**À faire.**
- Écran « Piste d'audit » du dossier : qui a saisi / modifié / validé, quand, filtres, export.
- Rôle **auditeur** : lecture seule sur un dossier (consultation, exports, piste d'audit), aucune écriture ; RLS + permissions ; boutons d'écriture masqués.
- Contrôles automatiques : soldes anormaux (compte de classe 4/5 au sens inverse), écritures hors période/exercice, listés dans un écran avec lien vers l'écriture.
- Pas de module ISA.

**Risques.** Ne pas affaiblir la RLS ; l'auditeur ne doit voir que les dossiers affectés. Effort 8 h.

**Tests.** pgTAP : auditeur ne peut ni insérer ni modifier ; contrôles détectent les cas ; chaîne de hachage inchangée.

## Hors périmètre – préparation seulement

### Point 3 – Lecture des pièces scannées (aucun appel d'API, aucune clé)
- **Endpoint serveur** : Edge Function `document-extract` (JWT + permission dossier) ; reçoit `document_id`, lit la pièce dans Storage (URL signée), appelle le fournisseur configurable côté serveur, renvoie le JSON. La clé reste dans les secrets de l'Edge Function.
- **Schéma JSON d'extraction** : `supplier_name`, `supplier_tax_id`, `invoice_date`, `invoice_number`, `currency`, `amount_excl_tax`, `vat_amount`, `vat_rate`, `amount_incl_tax`, `confidence` par champ.
- **Contrôles Akonta (code, pas IA)** : HT + TVA = TTC, taux cohérent (18 %), format IFU, doublon (fournisseur + numéro + montant), date dans l'exercice.
- **Proposition** : tiers retrouvé par IFU puis nom ; imputation reprise de l'historique ou d'un modèle (point 1) ; écriture en brouillard, pièce affichée à côté.
- **File d'attente hors ligne** : table `document_extraction_jobs` (`pending`, `processing`, `done`, `failed`), file locale de la pièce déjà prévue par le mode hors connexion, traitement au retour du réseau, reprise sur échec.
- **Prérequis** : accord du cabinet pour l'envoi externe, test comparatif sur ~20 factures, choix du modèle.

### Point 5 – Liasse e-Bilan
À obtenir : le modèle officiel téléchargé depuis e-Bilan (ou fourni par l'expert-comptable d'ABC), la notice de remplissage, le tableau compte → poste de liasse à jour, les règles d'annexes (immobilisations, amortissements, créances/dettes), un jeu de balance de clôture de référence avec la liasse attendue, et la confirmation du format de dépôt. Le mécanisme `keep_vba` (`service-documents/app/dgi.py`) et `dgi_cells` existent déjà.

## Garde-fous appliqués
Un commit par point ou défaut ; `flutter analyze` + `scripts/test.sh` (dont `design_guard_test.dart` et goldens) avant chaque point ; aucune règle comptable touchée ; migrations réversibles testées sur copie ; décisions provisoires dans `rapport.md`, questions dans `questions.md`.
