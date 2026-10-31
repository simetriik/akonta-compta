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
- **Dépôt `hsounton/akonta`** (vide, créé par erreur) : à supprimer par l'utilisateur après `! gh auth refresh -h github.com -s delete_repo`.
- **Déploiement Dokploy par API** : non commencé. Il faut l'URL, un jeton fourni par variable d'environnement hors du dépôt (`DOKPLOY_URL`, `DOKPLOY_TOKEN`) et le choix du périmètre ; recommandation : commencer par un accès en lecture seule, puis la Supabase de recette complète.
- **Erreurs d'inventaire connues** : l'écran Inventaire propose le compte de variation 603 pour les stocks 31 à 33 et 73 sinon ; pour le SYCEBNL le stock 34 (dons en nature) relève plutôt de 6035 (D-025).
- **Anomalies de solde** : un solde dans le sens anormal (ex. 4991 au débit) reste hors des postes des états ; le contrôle « actif = passif » le signale (D-024).
- **Plan SYCEBNL** : classe 9 (contributions volontaires en nature) non copiée dans l'entité ; cinq comptes de regroupement (28, 29, 49, 59, 68) confondus avec leur sous-compte une fois complétés (D-022).
- **Invitation et rôles** : l'invitation ne crée pas d'affectation (Q-016).

## 5. IA locale (à analyser avant tout code)
- **Palier 0 livré** (D-026) : suggestions par ressemblance de texte, sans modèle.
- **Palier 1** (vecteurs : `pgvector`, embeddings légers type EmbeddingGemma ou multilingual-e5-small) : à décider après usage réel du palier 0 ; recoupement sémantique (« loyer » ↔ « bail »).
- **Palier 2** (OCR des pièces : Tesseract, PaddleOCR ou RapidOCR + règles), **palier 3** (LLM de 3 à 4 milliards de paramètres quantifié, environ 2 à 2,5 Go de mémoire, quelques jetons par seconde sur CPU de bureau) : non commencés.
- **Note de cadrage IA** : à rédiger dans `outputs/` après l'analyse conjointe. Questions ouvertes : où tourne le serveur, quelle machine minimale, quel cas d'usage d'abord, tolérance à la lenteur, contrainte de licence (Apache 2.0 ou MIT préférés, Akonta étant revendable), V1 ou V2. Aucun modèle en ligne ni abonnement.
- Si on veut mesurer l'usage des suggestions : ajouter une table de compteurs sans contenu comptable (écartée pour l'instant, D-026).

## 6. Autres évolutions déjà identifiées
- Hors V1 d'après la conception : missions du cabinet et lien eABC, relevés PDF, stock permanent, saisie par les clients, système minimal de trésorerie, multi-cabinets commercial.
- Chapitres 3 (projets de développement, tableau emplois-ressources) et 4 (système minimal de trésorerie) du SYCEBNL : non traités.
