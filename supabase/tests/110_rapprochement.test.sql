-- Module 7 — Rapprochement bancaire : import de relevé, propositions ± 5 jours, pointage n-n, état, écriture depuis le relevé, état figé (§5, §10.7).
begin;
select plan(18);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('assist@a.test', :'a_id') as id \gset assist_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select public.create_journals_from_template(:'e1_id', null);
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'e1_id', 'BQ', 'Ecobank', 'bank', id from public.accounts where entity_id = :'e1_id' and code = '5210000';
select id as id from public.journals where entity_id = :'e1_id' and code = 'BQ' \gset bq_
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'e1_id', 'CHU', 'CHU', 'customer');

-- Comptabilité : AN banque 1 000 000 ; encaissement 500 000 le 10/01 ; chèque fournisseur 200 000 le 25/01 (non débité) ; deux virements 150 000 + 50 000 le 20/01 (une seule ligne de relevé de 200 000)
select tests.make_entry(:'e1_id', 'AN', '2026-01-01', 'AN', '[{"account":"5210000","debit":1000000},{"account":"1011000","credit":1000000}]', :'assist_id') as id \gset an_
select tests.make_entry(:'e1_id', 'BQ', '2026-01-10', 'Encaissement CHU', '[{"account":"5210000","debit":500000},{"account":"4111000","tp":"CHU","credit":500000}]', :'assist_id') as id \gset enc_
select tests.make_entry(:'e1_id', 'BQ', '2026-01-25', 'Chèque 112', '[{"account":"6221000","debit":200000},{"account":"5210000","credit":200000}]', :'assist_id') as id \gset chq_
select tests.make_entry(:'e1_id', 'BQ', '2026-01-20', 'Virement A', '[{"account":"6221000","debit":150000},{"account":"5210000","credit":150000}]', :'assist_id') as id \gset va_
select tests.make_entry(:'e1_id', 'BQ', '2026-01-20', 'Virement B', '[{"account":"6221000","debit":50000},{"account":"5210000","credit":50000}]', :'assist_id') as id \gset vb_
select public.validate_entries(array[:'an_id', :'enc_id', :'chq_id', :'va_id', :'vb_id']::uuid[]);

-- Relevé : solde début 1 000 000 ; +500 000 le 12/01 ; -200 000 le 21/01 (virements groupés) ; -16 500 frais le 31/01 (non comptabilisés) ; solde fin 1 283 500
select tests.authenticate_as(:'assist_id');
select public.import_bank_statement(:'bq_id', '2026-01-01', '2026-01-31', '[
  {"date":"2026-01-12","label":"VIR CHU PARAKOU","credit":500000},
  {"date":"2026-01-21","label":"VIR GROUPE LOYERS","amount":-200000},
  {"date":"2026-01-31","label":"FRAIS TENUE DE COMPTE","debit":16500}]', 1000000, 1283500, null, 'releve-janvier.csv') as id \gset st_
select is((select count(*) from public.bank_statement_lines where statement_id = :'st_id'), 3::bigint, '3 lignes de relevé importées (montant signé converti)');
select is((select debit from public.bank_statement_lines where statement_id = :'st_id' and line_no = 2), 200000::bigint, 'montant négatif = sortie (débit banque)');

-- 1. Propositions : encaissement 500 000 (écart 2 jours) ; le virement groupé de 200 000 est proposé face au chèque 112 (même montant, 4 jours) — à l'utilisateur de refuser ; rien pour les frais
select is((select count(*) from public.reconciliation_proposals(:'bq_id')), 2::bigint, 'deux propositions (montant identique, date ± 5 jours)');
select is((select entry_line_id from public.reconciliation_proposals(:'bq_id') where statement_line_id = (select id from public.bank_statement_lines where statement_id = :'st_id' and line_no = 1)),
          (select id from public.entry_lines where entry_id = :'enc_id' and debit > 0), 'proposition : encaissement CHU');
select is((select count(*) from public.reconciliation_proposals(:'bq_id') where statement_line_id = (select id from public.bank_statement_lines where statement_id = :'st_id' and line_no = 3)), 0::bigint, 'aucune proposition pour les frais non comptabilisés');

-- 2. Pointage 1-1 puis 1-n
select public.match_bank_lines(:'bq_id', array[(select id from public.bank_statement_lines where statement_id = :'st_id' and line_no = 1)], array[(select id from public.entry_lines where entry_id = :'enc_id' and debit > 0)]) as id \gset m1_
select throws_ok(format('select public.match_bank_lines(%L, array[%s], array[%L]::uuid[])', :'bq_id', (select id from public.bank_statement_lines where statement_id = :'st_id' and line_no = 2), (select id from public.entry_lines where entry_id = :'va_id' and credit > 0)),
                 '23514', null, 'pointage déséquilibré refusé (200 000 ≠ 150 000)');
select lives_ok(format('select public.match_bank_lines(%L, array[%s], array[%L, %L]::uuid[])', :'bq_id', (select id from public.bank_statement_lines where statement_id = :'st_id' and line_no = 2),
                       (select id from public.entry_lines where entry_id = :'va_id' and credit > 0), (select id from public.entry_lines where entry_id = :'vb_id' and credit > 0)),
                'pointage une ligne de relevé ↔ deux lignes comptables');
select throws_ok(format('select public.match_bank_lines(%L, array[%s], array[%L]::uuid[])', :'bq_id', (select id from public.bank_statement_lines where statement_id = :'st_id' and line_no = 1), (select id from public.entry_lines where entry_id = :'chq_id' and credit > 0)),
                 '23514', null, 'une ligne de relevé déjà pointée ne se repointe pas');

-- 3. État au 31/01 : comptable 1 100 000 ; banque 1 283 500 ; chèque non débité 200 000 ; frais non comptabilisés 16 500 → écart 0 ? (1 283 500 - 200 000 + 16 500 = 1 100 000)
select is((select book_balance from public.reconciliation_state(:'bq_id', '2026-01-31')), 1100000::bigint, 'solde comptable 1 100 000');
select is((select bank_balance from public.reconciliation_state(:'bq_id', '2026-01-31')), 1283500::bigint, 'solde banque = solde de clôture du relevé');
select is((select outstanding_payments from public.reconciliation_state(:'bq_id', '2026-01-31')), 200000::bigint, 'décaissement non débité : chèque 200 000');
select is((select unmatched_bank_debits from public.reconciliation_state(:'bq_id', '2026-01-31')), 16500::bigint, 'frais bancaires non comptabilisés 16 500');
select is((select difference from public.reconciliation_state(:'bq_id', '2026-01-31')), 0::bigint, 'écart nul : banque + encaissements non crédités - décaissements non débités + débits banque non comptabilisés = comptabilité');

-- 4. Écriture depuis la ligne de frais, validée et pointée
select public.entry_from_statement_line((select id from public.bank_statement_lines where statement_id = :'st_id' and line_no = 3), (select id from public.accounts where entity_id = :'e1_id' and code = '6311000'), null, 'Frais de tenue de compte janvier', true) as id \gset fee_
select is((select status::text from public.entries where id = :'fee_id'), 'validated', 'écriture de frais créée et validée depuis le relevé');
select is((select count(*) from public.unmatched_statement_lines(:'bq_id')), 0::bigint, 'toutes les lignes de relevé sont pointées');
select is((select difference from public.reconciliation_state(:'bq_id', '2026-01-31')), 0::bigint, 'écart toujours nul après comptabilisation des frais');

-- 5. État figé
select public.finalize_reconciliation(:'bq_id', '2026-01-31', :'st_id') as id \gset rec_
select is((select status::text from public.reconciliations where id = :'rec_id'), 'final', 'état de rapprochement de janvier figé');
select tests.clear_auth();
select throws_ok(format('update public.reconciliations set book_balance = 1 where id = %L', :'rec_id'), '42501', null, 'état figé : intangible');

select * from finish();
rollback;
