# Livraison du lot 2 — Akonta

Date : 25 octobre 2026. Branche `lot2` fusionnée dans `main`. Périmètre : module 7 Lettrage et rapprochement bancaire (conception §5, §10.7), jeu de démonstration enrichi.

## 1. Ce qui est livré

| Fonction | Base de données | Application | Documents |
|---|---|---|---|
| Lettrage | `letter_lines` (même compte lettrable et tiers, écritures validées, codes A…Z, AA… par compte et tiers, soldé si écart ≤ tolérance de l'entité avec brouillard d'OD 658/758 pour l'écart, partiel sur confirmation), `unletter` (motif, interdit après clôture, tracé), `unlettered_lines`, `lettering_proposals` (règle 1 : même tiers et montant ; règle 2 : facture = règlement net + retenue constatée par OD 447x/445x), comptes lettrables paramétrables (`accounts.is_letterable`), tolérance par entité | écran Lettrage : compte lettrable, tiers, lignes non lettrées, sélection avec écart, lettrage / lettrage partiel, propositions à confirmer, lettrages en cours, délettrage avec motif | — |
| Rapprochement | `import_bank_statement`, gabarits de relevés par banque, lignes non pointées (relevé / comptabilité), `reconciliation_proposals` (montant, ± 5 jours), `match_bank_lines` n-n équilibré, `unmatch_bank_lines`, `reconciliation_state` (solde comptable, solde banque, suspens, écart), `entry_from_statement_line`, `finalize_reconciliation` (écart nul, état intangible) | écran Rapprochement : import CSV selon un gabarit mémorisé (débit/crédit ou montant signé, formats de date, décimale, signe), deux volets, propositions, pointage, barre d'état, création d'écriture depuis une ligne de relevé, état figé | PDF de l'état de rapprochement (`/pdf/reconciliation`, Edge Function `export-document` kind `reconciliation`) |

La balance âgée (lot 1) tient désormais compte du lettrage : seules les lignes non lettrées y figurent.

## 2. Installation et lancement

Identiques au lot 1 (`docs/livraison-lot1.md`). Le PDF de rapprochement exige le service de documents et l'Edge Function `export-document`.

## 3. Tests

`scripts/test.sh` : pgTAP 258 assertions (dont `100_lettrage` 21 et `110_rapprochement` 18), Flutter 32 (dont parseur de relevés), pytest 9, Deno 7.

## 4. Décisions prises seul

- D-009 : propositions de lettrage et de pointage en SQL (pas d'Edge Function) ; règle 2 redéfinie comme « règlement net + retenue par OD », le cas « règlement crédité du montant total avec retenues dans la même écriture » relevant de la règle 1.
- D-010 : les à-nouveaux sont exclus du pointage (représentés par le solde d'ouverture du relevé).
- Tolérance de lettrage : un écart non nul dans la tolérance génère un brouillard d'OD (658 charge / 758 produit) qui solde le tiers ; il reste à valider.
- Relevés Excel : non pris en charge dans l'application (CSV / texte uniquement) ; exporter le relevé en CSV depuis le tableur. À ajouter si ABC fournit des relevés `.xlsx` natifs (Q-004).

## 5. Questions restantes

Voir `docs/questions.md` : formats réels des relevés des banques des clients (Q-004, ajoutée), en plus des questions du lot 1.

## 6. Scénario de recette

Pré-requis : `scripts/demo.sh` (le dossier SARL Démo Distribution contient un relevé de janvier pointé et neuf lettrages CHU).

1. **Lettrage** — `assistant@akonta.demo`, dossier SARL Démo, Lettrage : compte 4111000, tiers ACL. Sélectionner une facture et son règlement : écart affiché, « Lettrer ». Tiers CHU : les propositions restantes (factures d'octobre) s'affichent ; « Confirmer ». Choisir une facture et un règlement de montants différents : « Lettrer partiellement » demande confirmation ; le lettrage apparaît en partiel. Délettrer avec motif.
2. **Tolérance** — `associe@akonta.demo` : Dossiers → fiche → (SQL ou paramètre) `lettering_tolerance` = 500 ; lettrer une facture de 100 000 contre un règlement de 99 900 : lettrage soldé et brouillard « Écart de règlement » créé dans OD, à valider.
3. **Rapprochement** — Rapprochement : journal BQ, état au 31/01/2026 : écart affiché (agios de février non comptabilisés hors période : écart nul au 31/01 attendu). Importer un relevé de février au format CSV `Date;Libellé;Débit;Crédit;Réf` (gabarit « Export CSV Ecobank » mémorisé). Accepter les propositions ; pointer manuellement une ligne groupée contre deux écritures ; créer l'écriture des agios depuis la ligne du relevé (compte 6311000) ; vérifier l'écart 0 ; « Figer l'état du mois » ; « État PDF ».
4. **Contrôles** — tenter de pointer deux lignes de montants différents (refusé), de délettrer un lettrage d'un exercice clôturé (refusé au lot 3), de modifier un état figé (impossible).
