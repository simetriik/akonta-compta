# Questions pour Dansi / ABC (hypothèses appliquées, travail poursuivi)

## Q-001 — Format des exports de balance Perfecto
- **Question** : quel est le format exact des exports « balance générale », « balance auxiliaire » et « factures non soldées » de Perfecto ?
- **Hypothèse appliquée** : même format que le journal (texte tabulé, Windows-1252, CRLF) avec colonnes Compte / Intitulé / Débit / Crédit (ou soldes débiteur / créditeur). Table de correspondance éditable avant import ; le parseur est isolé pour être adapté en une fonction.

## Q-002 — Taux fiscaux en vigueur
- **Question** : taux d'AIB (1 % / 3 % / 5 % selon le statut ?), minimum d'impôt IS, TAF, IRPP barème à confirmer.
- **Hypothèse appliquée** : TVA 18 %, AIB 1 % (immatriculé) et 5 % (non immatriculé), TVA retenue 18 % du HT sur marchés publics, TAF 10 %, IS 30 % avec minimum 0,5 % du CA (plancher 250 000 FCFA). Tous dans la table des taux avec dates de validité : modifiables sans code.

## Q-003 — Numérotation Perfecto
- **Question** : les numéros de pièce Perfecto sont à 6 chiffres dans l'export fourni (`000001`), les comptes à 6 chiffres aussi ; la conception parle de 7 chiffres. Quelle longueur de compte pour les dossiers d'ABC ?
- **Hypothèse appliquée** : longueur par défaut 7 au niveau cabinet, modifiable par entité (§3.3) ; l'import complète à droite (D-004).

## Q-004 — Formats des relevés bancaires des clients
- **Question** : Ecobank, BOA, UBA, Orabank… fournissent-ils des exports CSV, Excel natif ou PDF seulement ?
- **Hypothèse appliquée** : CSV / texte tabulé, gabarit de colonnes mémorisé par banque. Les relevés `.xlsx` sont à exporter en CSV depuis le tableur ; les PDF restent hors V1 (§10.7).

## Q-005 — Tableau des flux de trésorerie (TFT) et notes annexes dans la liasse DGI
- **Question** : ABC souhaite-t-il que le TFT et les notes 1 à 35 soient calculés automatiquement dès la première clôture, ou complétés dans le modèle Excel ?
- **Hypothèse appliquée** : la liasse DGI est remplie automatiquement pour la fiche R1/R2 (identification), le bilan (actif, passif, N et N-1) et le compte de résultat ; le TFT et les notes restent à compléter dans le classeur (macros conservées). Les cellules correspondantes sont cartographiées (version `SN-2025`) pour une automatisation ultérieure.

## Q-006 — Refonte UI : composants à compléter ?
- **Question** : faut-il ajouter à la bibliothèque un `AkTabs`, un `AkRadio` et une grille paresseuse (grand livre) pour supprimer les derniers widgets Material thémés ?
- **Hypothèse appliquée** : non en V1 ; ils sont thémés aux jetons et listés dans `docs/design/systeme-de-design.md` (écarts connus).

## Q-007 — Import Perfecto : deux « Date illisible » sur l'en-tête et le total
- **Constat** : `import_parse_perfecto_journal` signale « Date illisible » pour la ligne d'en-tête faite de seules tabulations (le `trim` ne retire pas les tabulations) et pour la ligne `Total<TAB>Journal` (le motif attend « Total Journal »). Vérifié sur le vrai `JOURNAL BANQUE.TXT` : mêmes deux alertes, aucune ligne de données rejetée.
- **Hypothèse appliquée** : bénin, laissé en l'état pendant la préparation de la recette (pas de changement de logique) ; le test `150_recette_import` fige ce comportement. À corriger après la recette (ignorer les lignes vides de tabulations et accepter `Total<TAB>Journal`).

## Q-008 — Invitation : création du mot de passe
- **Constat** : l'Edge Function `invite-user` envoie un lien Supabase, mais l'application n'a aucun écran pour définir le mot de passe depuis ce lien (`updatePassword` n'est jamais appelé) ni pour réinitialiser un mot de passe oublié.
- **Hypothèse appliquée** : recette avec `recette/definir-mot-de-passe.sh`. À traiter avant toute mise en service.

## Q-009 — Saisie en devise absente de la grille
- **Constat** : la base accepte les écritures en devise (euro à parité fixe, autre devise avec cours) mais la grille de saisie n'expose ni devise, ni montant en devise, ni cours.
- **Hypothèse appliquée** : `recette/injecter-ecritures-devise.sh` crée les deux brouillards du jeu de données.

## Q-010 — Verrouillage du compte après 5 échecs de connexion
- **Constat** : prévu par la fiche de recette, absent du code et de la base ; la configuration locale ne fait que limiter le débit des connexions.
- **Hypothèse appliquée** : écart consigné dans `recette/LISEZMOI.md`, non corrigé. À trancher avec ABC (paramètre du cabinet ou comportement Supabase).

## Q-011 — « Reclassement » d'une écriture validée
- **Constat** : la permission est libellée « contre-passer / reclasser », mais seule la contre-passation (avec motif) existe dans l'interface.
- **Hypothèse appliquée** : la correction se fait par contre-passation puis nouvelle saisie.

## Q-012 — Associés de l'exercice
- **Constat** : la table `fiscal_year_partners` et le dépôt de données existent, aucun écran ne permet de saisir les associés et leurs parts.
- **Hypothèse appliquée** : non bloquant pour la recette ; la fiche R3 ne couvre que les dirigeants.

## Q-013 — Modèles d'écritures : comptes absents du plan
- **Constat** : le modèle SALAIRES vise 4221 (inexistant : le collectif est 422) ; les modèles de règlement et de frais bancaires visent 5211 « Banque X ».
- **Hypothèse appliquée** : l'utilisateur choisit le compte à la main ; correction des modèles par défaut (`seed_default_referentials`) après la recette.
- **Résolu le 30 oct. 2026** : `SALAIRES` → 422, banque → 521 (D-021).

## Q-014 — Manifestes mobiles
- **Constat** : le manifeste Android principal ne déclare pas INTERNET (seuls les manifestes debug et profile l'ont) ; `Info.plist` iOS n'a ni `NSCameraUsageDescription` ni description d'accès aux photos ; aucun dossier `windows/` ni `macos/` dans `app/`.
- **Hypothèse appliquée** : recette mobile sur build de débogage Android, avec HTTP en clair autorisé dans le seul manifeste de débogage ; le reste à régler avant un build de production.

## Q-015 — Cabinet-coquille de l'instance de recette
- **Constat** : aucun écran ne crée un cabinet et `profiles.cabinet_id` est obligatoire ; « aucun cabinet » est donc impossible pour l'administrateur technique.
- **Hypothèse appliquée** : `recette/bootstrap-admin.sql` crée un cabinet minimal « Cabinet de recette Simetriik » (nom seul) et l'administrateur. Pour ABC, le cabinet sera créé par une procédure d'amorçage à définir.

## Q-016 — Aucun rôle donné aux utilisateurs invités (associé inclus)
- **Constat** : la fonction `invite-user` crée le compte et le profil mais aucune ligne dans `assignments`. Un utilisateur invité n'a donc aucun droit. L'écran Cabinet > Affectations est réservé à l'associé, qui n'a lui-même aucun rôle : impasse. L'administrateur technique ne voit pas les données comptables et n'a pas d'écran pour affecter. Constaté le 30 oct. 2026 sur l'instance de recette (seul `admin.recette` avait une affectation).
- **Hypothèse appliquée** : pour la recette, l'hôte insère à la main l'affectation `partner` (portée cabinet) de l'associé ; l'associé affecte ensuite les autres depuis l'application.
- **À décider** : l'invitation doit-elle porter le rôle (choisi par l'administrateur ou l'associé) et créer l'affectation ? À trancher avant la recette avec ABC.

## Q-017 — Associations (SYCEBNL) : besoin réel du cabinet
- **Constat** : la conception range SYCEBNL hors V1. L'utilisateur souhaite l'ajouter à Akonta (31 oct. 2026) ; voir D-022.
- **À demander à ABC** : gère-t-il des associations, ONG, fondations ou syndicats, combien, et pour quand ? Tient-il leurs comptes dans Perfecto (impact sur l'import) ? Quels états produit-il pour eux (bilan, compte de résultat, tableau des flux, notes annexes) ?
- **À obtenir** : texte officiel du SYCEBNL (plan de comptes, états financiers, modèles de liasse).
- **Hypothèse appliquée** : aucune ; le schéma n'accepte que `'normal'`. Rien n'est livré avant la réponse.

## Q-018 — Sens normal erroné dans les plans d'entités SYSCOHADA déjà créés
- **Constat** : jusqu'à la migration `20261031100001`, la copie du plan de référence faisait hériter le sens du compte de classe. Dans la base de recette, `2800000` (amortissements) est au débit, `1390000` (perte) au crédit, `1090000` au crédit au lieu de leur sens de référence (voir D-023). Les comptes subdivisés à la main sous ces comptes ont hérité du même sens. Les entités créées après la migration sont correctes.
- **Impact à mesurer** : le sens normal sert aux alertes de solde et à l'affichage ; pas à l'équilibre des écritures. Le déclencheur interdit de modifier le sens d'un compte existant.
- **À décider** : migration de correction des entités existantes (mise à jour du sens d'après `reference_accounts`, déclencheur contourné par le même réglage transactionnel) ; modification de données, donc à faire valider avant application, sur la recette puis chez ABC.
- **Résolu le 31 oct. 2026** : migration `20261031100004_fix_reference_account_sides.sql` (fonction `fix_reference_account_sides()`, rejouable) ; test dans `190_sycebnl_referentiel.test.sql`.

## Q-019 — Plan SYCEBNL : source et sens normal à valider
- **Constat** : le plan de 1 130 comptes vient d'un site tiers ; le sens normal, les collectifs et les comptes lettrables sont déduits de règles par préfixe (`scripts/generate_sycebnl_accounts.py`). Les 19 modèles `AS_*` sont sans TVA.
- **À faire** : rapprocher du Journal officiel OHADA (acte uniforme du 22 déc. 2022) ; faire valider par ABC les comptes des modèles et les sens ambigus (87, 88, 169, 475, comptes à recevoir).

## Q-020 — États SYCEBNL : interprétations à valider et reste à faire
- **À faire valider par ABC** : le total XA (RA à RH au lieu de RA à RG) ; le rattachement des comptes « p » (2919, 2939, 2949) ; le compte 2951 pour les dépréciations de AG (chiffre illisible sur le scan) ; les écarts du D-024 (35, 46, 702, 7054, 7055, 2817) ; la présentation du résultat en instance dans CG.
- **À faire valider** : la règle de classement du tableau des flux (D-027), choisie faute de correspondance officielle.
- **À définir** : les 35 notes annexes (priorité : notes 5, 15, 16, 17A, 17B, 23) ; export PDF et Excel des états SYCEBNL (le service de documents suit le modèle SYSCOHADA) .
- **Hypothèse appliquée** : bilan et compte de résultat générés et affichés à l'écran ; flux, notes et exports « à venir ».

