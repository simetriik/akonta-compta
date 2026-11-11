# Reste à faire et chantiers repoussés

Mis à jour le 31 oct. 2026. Ce fichier rassemble ce qui a été décidé, étudié ou préparé mais **volontairement reporté**, avec de quoi reprendre sans repartir de zéro. Les décisions sont dans `decisions-dev.md` (D-0xx), les questions ouvertes dans `questions.md` (Q-0xx).

## 1. Hors périmètre pour l'instant (décision du 31 oct. 2026)

### 1.1 Export Excel des états SYCEBNL
- **Décision** : le PDF unique (D-029) suffit pour l'instant ; l'Excel est repoussé.
- **Pour reprendre** :
  - route `/excel/financial-statements-sycebnl` dans `service-documents/app/main.py`, fonction `sycebnl_statements_xlsx` dans un nouveau `app/excel_sycebnl.py` qui réutilise `app/sycebnl.py` (mise en page et totaux déjà prêts : `balance_sheet_assets`, `balance_sheet_liabilities`, `income_statement`) ;
  - un classeur, une feuille par état (Actif, Passif, Résultat, Flux) et une feuille « Notes » ; **de vraies formules** (`SUM`) dans les lignes de total pour que le comptable puisse les vérifier (proposition présentée le 31 oct., non contestée) ;
  - Edge Function : `servicePath("financial_statements", "xlsx", "sycebnl")` renvoie aujourd'hui `null` (`supabase/functions/_shared/documents.ts`) ; la charge utile est déjà construite pour le PDF (`export-document/index.ts`) ;
  - application : second bouton à côté de `export-sycebnl-pdf` dans `closing_screen.dart` (le texte « Export Excel : à venir » est à retirer) ;
  - tests : pytest (classeur ouvrable, formules de total, colonnes N-1), Deno (route), `documents_test.ts`.
- **Attention** : la liasse DGI Excel (`/excel/dgi`) est propre au SYSCOHADA et ne convient pas aux associations.

### 1.2 Commentaire de chaque note annexe
- Le PDF laisse une ligne « Commentaire : … » à remplir à la main sous chaque note.
- **Pour reprendre** : table `statement_note_comments (fiscal_year_id, note_code, comment, updated_by, updated_at)` avec RLS par entité et permission `statements.generate` ou équivalente, tests pgTAP d'isolation ; saisie dans `statement_notes_section.dart` ; reprise dans le PDF à la place des points ; trace dans l'audit.

### 1.3 Notes annexes non produites (12 sur 35)
| Note | Obstacle | Piste |
|---|---|---|
| 1, 2, 3, 4 | informations générales à saisie libre | zone de texte par exercice (voir 1.2) |
| 5A à 5H | mouvements (début, augmentation, diminution, fin) | à calculer depuis `fixed_assets` et `depreciation_schedules` |
| 6, 7 | immobilisations financières, actif et dettes HAO | tableaux de mouvements à définir |
| 14 | écarts de conversion : devise, cours | à produire depuis les écritures en devise (`generate_fx_revaluation`) |
| 15 | liste des membres et nationalité | table des membres, absente du grand livre |
| 18B, 29B, 30 | engagements, effectifs, dotations et reprises | saisie libre ou calcul à définir |
| 33, 34, 35 | indicateurs, informations sociales, exécution budgétaire | saisie libre ou module budget |
- **Colonnes d'échéances** des notes 9, 10 et 19 (à un an au plus, plus d'un an, plus de deux ans) : nécessitent l'échéance des écritures, absente du modèle.
- Les lignes des notes 18A, 20, 21, 22, 24 à 28, 31 et 32 viennent du plan et non des pages officielles (Q-021).

## 2. À valider par ABC avant la production
- Fiches `outputs/modeles-ecritures-a-valider.md` (30 modèles SYSCOHADA) et `outputs/sycebnl-a-valider.md` (sens des comptes, 19 modèles, correspondances des états, règle du tableau des flux, clôture, 23 notes). Les régénérer depuis la base si les modèles ou les correspondances changent.
- Questions de fond : combien d'associations, Perfecto, états attendus, notes annexes prioritaires (section 7 de la fiche SYCEBNL).
- Rapprocher le plan SYCEBNL du Journal officiel OHADA (le plan vient d'un site tiers, Q-019).
- Interprétations à confirmer : XA = RA à RH, comptes « p », 2951, comptes 35, 46, 702, 7054, 7055, 2817 (D-024, Q-020), classement des contreparties du tableau des flux (D-027).

## 3. Tests et vérifications non faits
- Application : vérification visuelle du sélecteur à recherche sur mobile (D-020) ; test de widget de l'écran de clôture et du bouton d'export SYCEBNL ; dossier d'association testé de bout en bout en recette (saisie, états, flux, notes, PDF, clôture).
- Export PDF SYCEBNL : l'Edge Function n'a pas été essayée avec une session réelle (seul le service Python l'a été).
- Suggestions de saisie (D-026) : performances non mesurées sur un gros historique (plan d'exécution des index trigramme) ; effet réel à juger après la saisie des 45 opérations de la recette.
- `recette/definir-role-associe.sh` jamais exécuté (seulement `bash -n`) ; limite du modèle `SALAIRES` (la ligne d'IRPP reprend le montant de base).

## 4. Chantiers techniques ouverts
- **Gestion des erreurs (D-030)** : à chaque nouvelle contrainte d'unicité de la base, ajouter son message dans `_constraintMessages` (`app/lib/src/infrastructure/supabase/supabase_error_classifier.dart`) ; journal conservé en mémoire seulement (pas de persistance ni d'envoi à l'équipe) ; vérification visuelle sur mobile à faire.
- **Dépôt `hsounton/akonta`** (vide, créé par erreur) : à supprimer par l'utilisateur après `! gh auth refresh -h github.com -s delete_repo`.
- **Déploiement Dokploy par API** : non commencé. Il faut l'URL, un jeton fourni par variable d'environnement hors du dépôt (`DOKPLOY_URL`, `DOKPLOY_TOKEN`) et le choix du périmètre ; recommandation : commencer par un accès en lecture seule, puis la Supabase de recette complète.
- **Erreurs d'inventaire connues** : l'écran Inventaire propose le compte de variation 603 pour les stocks 31 à 33 et 73 sinon ; pour le SYCEBNL le stock 34 (dons en nature) relève plutôt de 6035 (D-025).
- **Anomalies de solde** : un solde dans le sens anormal (ex. 4991 au débit) reste hors des postes des états ; le contrôle « actif = passif » le signale (D-024).
- **Plan SYCEBNL** : classe 9 (contributions volontaires en nature) non copiée dans l'entité ; cinq comptes de regroupement (28, 29, 49, 59, 68) confondus avec leur sous-compte une fois complétés (D-022).
- **Invitation et rôles** : l'invitation ne crée pas d'affectation, par décision (D-034) ; Q-016 close le 9 nov. 2026 (rôle auditeur désormais affectable).

## 4 bis. Architecture clean et mode hors connexion (D-031)
- **Écrans** (D-032) : les six écrans de plus de 780 lignes sont découpés (un fichier par onglet, étape ou dialogue) et leur logique est dans `application/` (règles, contrôleur de rapprochement, providers de clôture), avec tests. Restent des écrans de 450 à 550 lignes (`entries_screen`, `entity_detail_screen`, `cabinet_screen`, `app_shell`) et des écrans qui gardent leur état dans le widget (éditeur d'écriture, étapes de clôture) ; un test d'architecture interdit au-delà de 600 lignes.
- **Autre moteur de données (Oracle…)** : écrire un adaptateur par port et, pour un moteur sans PostgREST, un serveur d'API qui reprend le contrat des ports ; les règles comptables, aujourd'hui en SQL PostgreSQL, devraient alors être réécrites (PL/SQL) ou sorties de la base. Choix à faire quand un client Oracle sera réel.
- **Hors connexion, limites connues** : la modification hors ligne d'un brouillon déjà enregistré sur le serveur est mise en file mais la liste montre l'ancienne version jusqu'à la synchronisation ; pas de stockage local chiffré sur le web ; la file d'envoi n'est pas vidée à la déconnexion (les éléments restent à envoyer par le prochain utilisateur de l'appareil, sous ses droits) ; pas de résolution de conflit entre deux appareils (le serveur fait foi) ; compilation Linux de bureau non vérifiée (en-têtes `libsecret-1-dev` absents de la machine de développement : `sudo apt install libsecret-1-dev`) ; essai hors ligne fait sur le web seulement (cache et file d'envoi en mémoire).
- **À essayer en recette** : couper le réseau, saisir un brouillon et déposer une pièce, rétablir le réseau et vérifier l'envoi ; vérifier que grand livre, balance, validation et clôture sont bien refusés avec leur message.

## 5. IA locale (à analyser avant tout code)
- **Palier 0 livré** (D-026) : suggestions par ressemblance de texte, sans modèle.
- **Palier 1** (vecteurs : `pgvector`, embeddings légers type EmbeddingGemma ou multilingual-e5-small) : à décider après usage réel du palier 0 ; recoupement sémantique (« loyer » ↔ « bail »).
- **Palier 2 livré en première version** (D-050) : OCR local Tesseract + règles, brouillard proposé depuis une pièce d'achat. À faire : règles sur de vraies pièces d'ABC, factures de vente et avis bancaires, PDF scannés, bouton dans l'éditeur et lancement au dépôt, RapidOCR si la précision manque. **Palier 3** (LLM de 3 à 4 milliards de paramètres quantifié, environ 2 à 2,5 Go de mémoire, quelques jetons par seconde sur CPU de bureau) : non commencés.
- **Note de cadrage IA** : à rédiger dans `outputs/` après l'analyse conjointe. Questions ouvertes : où tourne le serveur, quelle machine minimale, quel cas d'usage d'abord, tolérance à la lenteur, contrainte de licence (Apache 2.0 ou MIT préférés, Akonta étant revendable), V1 ou V2. Aucun modèle en ligne ni abonnement.
- Si on veut mesurer l'usage des suggestions : ajouter une table de compteurs sans contenu comptable (écartée pour l'instant, D-026).

## 6. Autres évolutions déjà identifiées
- Hors V1 d'après la conception : missions du cabinet et lien eABC, relevés PDF, stock permanent, saisie par les clients, système minimal de trésorerie, multi-cabinets commercial.
- Chapitres 3 (projets de développement, tableau emplois-ressources) et 4 (système minimal de trésorerie) du SYCEBNL : non traités.

## 7. Facturation e-MECeF et accès des clients (D-043, ouvert le 2 nov. 2026)
- **Essai avec la DGI** : obtenir l'accès à la plateforme e-MECeF TEST et un jeton ; exécuter les cas de l'auto-déclaration (`intrants/emcf-dgi/06-auto-declaration-sfe.md`) ; lire le QR code avec un téléphone ; lever les points AIB et paiement (voir D-043).
- **Tranche 2 — pont comptable : livrée** (D-043). Reste : écran pour créer une nouvelle version des comptes à une date d'effet, assouplir le compte de TVA pour une association non assujettie, lettrage de l'encaissement avec la facture, et vérifier l'AIB avec les cas de test de la DGI.
- **Tranche 3 — clients du cabinet** (D-044) : **livrée**, à passer en recette interne. Reste : essai avec TOTP et un vrai navigateur, création de tiers par le client, jetons e-MECeF de chaque client (le cabinet les saisit), assouplir `requires_mfa` pour un saisisseur qui émet (règle par droit plutôt que par rôle), brouillards du cabinet visibles du client (aujourd'hui masqués).
- **Agrément** : demander à la DGI le délai et le coût, si un SaaS multi-clients est approuvé une fois pour tous ou client par client, et comment un éditeur obtient la plateforme de test (courriel à emecefbenin@finances.bj, à envoyer par Dansi). Toute modification du module de facturation après approbation exige une nouvelle auto-déclaration : isoler et versionner ce module.
- **Plus tard** : types exportation (EV, EA), TPS, régime d'exception, taxe spécifique et taxe de séjour (aujourd'hui « non utilisés » : interdits après approbation tant qu'ils ne sont pas redéclarés) ; reprise hors connexion d'une facture en cours ; import de factures émises par un autre SFE.

