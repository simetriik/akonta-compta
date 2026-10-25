# Plan de travail — lots 1 à 3

Référence : `inputs/conception.md` (§ cités). Une tâche = quelques heures au plus, avec un critère de fin vérifiable. Cocher ici, journaliser dans `docs/avancement.md`. Branches : `lot1`, `lot2`, `lot3`, fusionnées dans `main` à chaque point d'étape.

Arborescence cible : `supabase/` (config, migrations, seed, tests pgTAP, functions) · `app/` (Flutter desktop + mobile) · `service-documents/` (Python) · `scripts/` · `docs/`.

## Lot 1 — modules 1 à 6 et 10

### Fondations
- [x] **L1-00 Audit** — `docs/audit.md`, fichiers de pilotage. *Fin : fichiers présents et commités.*
- [x] **L1-01 Environnement local** — `supabase init`, `supabase start` sous Podman, `scripts/setup.sh`, `scripts/start.sh`, `scripts/stop.sh`, `scripts/test.sh`, `docs/environnement.md`. *Fin : `scripts/test.sh` exécute un test pgTAP trivial vert ; `flutter doctor` documenté.*
- [x] **L1-02 Schéma socle (module 1, §10.1)** — `cabinets`, `profiles`, `roles`, `permissions`, `role_permissions`, `assignments(user, entity, role)`, `audit_log` (ajout seul, chaînage SHA-256 par déclencheur), fonctions `current_cabinet_id()`, `has_permission(entity, perm)`, `require_aal2()` pour associé/admin, politiques RLS. *Fin : pgTAP — ajout seul et chaîne vérifiable, permissions par défaut de la matrice §8, RLS cabinet.*
- [x] **L1-03 Schéma cabinet et dossiers (module 2, §10.2)** — `entities` (4 blocs R1-R3), `entity_directors`, `entity_history`, `fiscal_years` (statuts, continuité), `periods` (12 générées, verrou), `fiscal_year_partners`. *Fin : pgTAP — unicité IFU/RCCM par cabinet, 12 périodes générées, pas de trou ni chevauchement, verrou/déverrou avec motif, RLS par affectation.*
- [x] **L1-04 Schéma référentiels (module 3, §10.3)** — `reference_accounts` + seed du CSV (D-003), `accounts` (longueur fixe, subdivision, désactivation, suppression interdite si mouvements), `third_parties`, `journals`, `entry_templates` + `entry_template_lines`, `tax_rates` (validité). *Fin : pgTAP — 1 339 comptes seedés, copie du plan à la création d'entité, règles de subdivision et de longueur, modèles fournis présents.*
- [x] **L1-05 Schéma saisie (module 4, §4, §10.4, §11.2)** — `entries`, `entry_lines`, `journal_sequences`, RPC `validate_entry` / `validate_entries` (équilibre, période ouverte, comptes actifs, débit xor crédit > 0, numéro séquentiel sous verrou), déclencheurs d'immutabilité, `reverse_entry` (motif), revue (`review_status`, commentaire), devises (`numeric(18,2)`, cours `numeric(18,6)`, arrondi). *Fin : pgTAP — chaque contrôle refuse le cas invalide, numérotation sans trou sous concurrence, écriture validée immuable, contre-passation liée.*
- [x] **L1-06 Schéma pièces (module 5, §10.5)** — `documents` (empreinte SHA-256, taille, type), `entry_documents` (n-n), boîte de réception par entité, bucket privé `documents` + politiques Storage. *Fin : pgTAP — pièce liée à une écriture validée non supprimable, RLS bucket par affectation.*
- [x] **L1-07 Schéma consultation (module 6, §10.6)** — vues/fonctions : grand livre général et auxiliaire, balance générale / auxiliaire / âgée (0-30, 31-60, 61-90, 91-180, >180), journal, centralisateur mensuel, comparaison N-1 ; index. *Fin : pgTAP — totaux débit = crédit, balance âgée sur un jeu connu, écritures validées uniquement.*
- [ ] **L1-08 Schéma import Perfecto (module 10, §10.10)** — `import_batches`, `import_lines`, `import_account_mappings`, fonction d'application (à-nouveaux en brouillard, mode essai). *Fin : pgTAP — scission `4110CHU` → collectif + tiers, montants négatifs inversés, mode essai sans écriture.*
- [ ] **L1-09 Schéma lots 2 et 3 (tables + contraintes + RLS)** — lettrage (`lettering_groups`, `lettering_lines`), rapprochement (`bank_statements`, `bank_statement_lines`, `bank_templates`, `reconciliations`), immobilisations, stocks, provisions, régularisations, écarts de conversion, clôture (`closing_checks`, `tax_rules`, `statement_mappings` versionnées, `closing_archives`). Fonctions métier aux lots 2 et 3. *Fin : pgTAP — RLS de chaque table ; schéma complet des lots 1 à 3 avant toute interface (§12.1).*
- [ ] **L1-10 Tests de cloisonnement** — suite pgTAP RLS systématique : deux cabinets, deux dossiers, cinq rôles ; aucune fuite en lecture ni en écriture. *Fin : suite verte et liste des tables couvertes = liste des tables du schéma.*

### Application
- [ ] **L1-11 Socle Flutter** — projet `app/` (desktop Linux + Android), couches présentation / domaine / données, client Supabase, thème (palette du kit logo, statuts colorés), connexion e-mail + mot de passe, MFA TOTP (enrôlement et vérification, exigée associé/admin), déconnexion après inactivité paramétrable, réinitialisation par e-mail. *Fin : tests widgets de l'écran de connexion et du minuteur d'inactivité ; `flutter analyze` propre.*
- [ ] **L1-12 Module 1 UI + Edge Function invitations** — utilisateurs (invitation, désactivation), import CSV eABC, rôles et permissions ajustables, affectations avec réaffectation en masse, consultation de la piste d'audit (associé). *Fin : tests widgets ; fonction `invite-user` testée (Deno test).*
- [ ] **L1-13 Module 2 UI** — paramètres cabinet, fiche entité 4 blocs, exercices et périodes, assistant d'ouverture 5 étapes, tableau de bord des dossiers, verrouillage de période, sélecteur de dossier courant toujours visible. *Fin : tests widgets de l'assistant et du tableau de bord.*
- [ ] **L1-14 Module 3 UI** — plan de comptes (subdivision, renommage, désactivation), tiers, journaux, modèles d'écritures, taux. *Fin : tests widgets ; création d'un compte de 7 chiffres complété.*
- [ ] **L1-15 Module 4 UI** — grille de saisie par journal et par mois (clavier : Tab/Entrée, autocomplétion, contrepartie automatique, code tiers, modèles), saisie par pièce, validation unitaire et par lot, file de revue, contre-passation, recherche. *Fin : tests widgets de la grille (équilibre affiché, blocage montant négatif) et du flux de revue.*
- [ ] **L1-16 Module 5 UI** — dépôt desktop, capture mobile (photo, recadrage, choix du dossier), boîte de réception, rattachement, création de brouillard pré-rempli, visionneuse à côté de l'écriture. *Fin : tests unitaires empreinte et compression ; widget boîte de réception.*
- [ ] **L1-17 Service de documents (Python)** — `service-documents/` (FastAPI, `uv`), endpoints PDF (grand livre, balance, journal) et Excel ; Edge Function `export-document` qui l'appelle et trace l'export dans la piste d'audit. *Fin : pytest vert ; export PDF réel d'une balance de démonstration.*
- [ ] **L1-18 Module 6 UI** — grand livre, balances, journal, centralisateur, période libre, comparaison N-1, liens vers écriture et pièce, exports. *Fin : tests widgets des filtres ; export tracé dans l'audit.*
- [ ] **L1-19 Module 10 UI + parseur** — Edge Function `import-perfecto` (texte tabulé Windows-1252, Excel), table de correspondance éditable, contrôles, mode essai, rapport, validation par le chef de mission. *Fin : `inputs/JOURNAL BANQUE.TXT` importé en essai sans erreur ; tests Deno du parseur.*
- [ ] **L1-20 Jeu de démonstration** — `supabase/seed.sql` : cabinet de démonstration, 2 entités, exercice 2026 complet (achats, ventes, banque, caisse, OD, paie), tiers, pièces, utilisateurs des 5 rôles. *Fin : rejouable par `scripts/demo.sh` ; balance équilibrée.*
- [ ] **L1-21 Prompt Claude Design** — `docs/prompt-claude-design.md` (écrans desktop et mobile par module, rôles, données, actions). *Fin : fichier relu, couvre modules 1 à 10.*
- [ ] **L1-22 Livraison lot 1** — fusion `lot1` → `main`, `docs/livraison-lot1.md` (fonctionnalités, installation, lancement, décisions, questions, scénario de recette pas à pas). *Fin : suite complète verte sur `main`.*

## Lot 2 — module 7

- [ ] **L2-01 Lettrage SQL** — fonctions `letter_lines`, `unletter` (tracé, interdit après clôture), lettrage partiel, tolérance paramétrable, comptes lettrables. *Fin : pgTAP.*
- [ ] **L2-02 Propositions de lettrage** — Edge Function (même tiers et montant ; facture = règlement + retenues). *Fin : tests Deno sur jeu de démo.*
- [ ] **L2-03 UI lettrage** — écran par compte de tiers, sélection, propositions à confirmer, délettrage. *Fin : tests widgets.*
- [ ] **L2-04 Import de relevés** — gabarits de colonnes mémorisés par banque, import CSV/Excel. *Fin : pgTAP + tests Deno.*
- [ ] **L2-05 Rapprochement** — pointage 1-1 et n-n, propositions (montant, date ± 5 j), état mensuel écart 0, création d'écriture depuis une ligne, état figé archivé en PDF. *Fin : pgTAP + widgets + PDF.*
- [ ] **L2-06 Démo enrichie** — relevés, factures, règlements avec retenues. *Fin : rapprochement de démo à écart 0.*
- [ ] **L2-07 Livraison lot 2** — `docs/livraison-lot2.md`, fusion. 

## Lot 3 — modules 8 et 9

- [ ] **L3-01 Immobilisations** — fiches, composants, linéaire (dégressif option), prorata temporis, tableau, dotations générées en brouillard « générée », cessions / rebuts, reprise de l'existant. *Fin : pgTAP sur un cas calculé à la main ; UI.*
- [ ] **L3-02 Stocks** — stock final par compte, variations générées. *Fin : pgTAP ; UI.*
- [ ] **L3-03 Provisions** — balance âgée → taux par tiers, dotation/reprise par différence, provisions pour risques, tableau. *Fin : pgTAP ; UI.*
- [ ] **L3-04 Régularisations** — CAP, PAR, CCA, PCA, prorata au jour, écriture 31/12 et extourne 01/01. *Fin : pgTAP ; UI.*
- [ ] **L3-05 Écarts de conversion** — lignes en devises non lettrées, cours de clôture, 478/479 + provision, extourne. *Fin : pgTAP ; UI.*
- [ ] **L3-06 Contrôles de clôture** — bloquants et alertes levables avec commentaire ; assistant. *Fin : pgTAP ; UI.*
- [ ] **L3-07 Fiscalité** — tableau de passage paramétrable, IS = max(taux × résultat fiscal, minimum), acomptes 4492, écriture d'IS. *Fin : pgTAP.*
- [ ] **L3-08 États financiers** — moteur comptes → postes (plages, sens, versionné), bilan, compte de résultat, TFT, notes, fiches R, contrôles de cohérence, PDF. *Fin : pgTAP (bilan équilibré sur la démo) ; pytest PDF.*
- [ ] **L3-09 Modèle Excel DGI** — cartographie des cellules (table versionnée), remplissage `openpyxl keep_vba`, test sur la démo. *Fin : pytest ; fichier produit ouvrable, macros présentes.*
- [ ] **L3-10 Arrêté et N+1** — clôture provisoire / réouverture, arrêté définitif (double confirmation, archivage avec empreintes, lecture seule), à-nouveaux (provisoires recalculés), affectation du résultat. *Fin : pgTAP ; UI.*
- [ ] **L3-11 Démo clôturée** — exercice 2026 de démo arrêté, 2027 ouvert. *Fin : parcours complet rejouable.*
- [ ] **L3-12 Livraison finale** — `docs/livraison-lot3.md`, scénario de recette global, fusion.
