-- Module 7 — Lettrage : codes, lettrage soldé / partiel / tolérance, propositions, délettrage (§5, §10.7).
begin;
select plan(21);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('assist@a.test',  :'a_id') as id \gset assist_
select tests.create_user('trainee@a.test', :'a_id') as id \gset trainee_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'assist_id',  :'a_id', 'assistant', :'e1_id');
select tests.assign(:'trainee_id', :'a_id', 'trainee',   :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select public.create_journals_from_template(:'e1_id', null);
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'e1_id', 'BQ', 'Ecobank', 'bank', id from public.accounts where entity_id = :'e1_id' and code = '5210000';
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'e1_id', 'CHU', 'CHU', 'customer'), (:'a_id', :'e1_id', 'ACL', 'ACL', 'customer');
select id as id from public.accounts where entity_id = :'e1_id' and code = '4111000' \gset c411_

-- Facture 1 180 000 ; règlement avec retenues : 1 180 000 crédit client, 10 000 AIB + 180 000 TVA retenue au débit, banque 990 000
select tests.make_entry(:'e1_id', 'VT', '2026-01-10', 'Facture 001', '[{"account":"4111000","tp":"CHU","debit":1180000},{"account":"7011000","credit":1000000},{"account":"4431000","credit":180000}]', :'assist_id') as id \gset f1_
select tests.make_entry(:'e1_id', 'BQ', '2026-02-05', 'Règlement 001', '[{"account":"5210000","debit":990000},{"account":"4478000","debit":10000},{"account":"4452000","debit":180000},{"account":"4111000","tp":"CHU","credit":1180000}]', :'assist_id') as id \gset r1_
-- Facture 2 : 590 000 ; règlement net 580 000 (banque / client) et retenue AIB 10 000 constatée par OD (4478 / client) → règle 2
select tests.make_entry(:'e1_id', 'VT', '2026-01-15', 'Facture 002', '[{"account":"4111000","tp":"CHU","debit":590000},{"account":"7011000","credit":500000},{"account":"4431000","credit":90000}]', :'assist_id') as id \gset f2_
select tests.make_entry(:'e1_id', 'BQ', '2026-02-10', 'Règlement 002', '[{"account":"5210000","debit":580000},{"account":"4111000","tp":"CHU","credit":580000}]', :'assist_id') as id \gset r2_
select tests.make_entry(:'e1_id', 'OD', '2026-02-10', 'AIB retenu facture 002', '[{"account":"4478000","debit":10000},{"account":"4111000","tp":"CHU","credit":10000}]', :'assist_id') as id \gset w2_
-- Facture 3 ACL : 100 000, règlement 99 900 (écart 100)
select tests.make_entry(:'e1_id', 'VT', '2026-03-01', 'Facture 003', '[{"account":"4111000","tp":"ACL","debit":100000},{"account":"7011000","credit":100000}]', :'assist_id') as id \gset f3_
select tests.make_entry(:'e1_id', 'BQ', '2026-03-09', 'Règlement 003', '[{"account":"5210000","debit":99900},{"account":"4111000","tp":"ACL","credit":99900}]', :'assist_id') as id \gset r3_
select public.validate_entries(array[:'f1_id', :'r1_id', :'f2_id', :'r2_id', :'w2_id', :'f3_id', :'r3_id']::uuid[]);

select l.id as id from public.entry_lines l where l.entry_id = :'f1_id' and l.debit > 0 \gset lf1_
select l.id as id from public.entry_lines l where l.entry_id = :'r1_id' and l.credit > 0 \gset lr1_
select l.id as id from public.entry_lines l where l.entry_id = :'f2_id' and l.debit > 0 \gset lf2_
select l.id as id from public.entry_lines l where l.entry_id = :'r2_id' and l.credit > 0 \gset lr2_
select l.id as id from public.entry_lines l where l.entry_id = :'w2_id' and l.credit > 0 \gset lw2_
select l.id as id from public.entry_lines l where l.entry_id = :'f3_id' and l.debit > 0 \gset lf3_
select l.id as id from public.entry_lines l where l.entry_id = :'r3_id' and l.credit > 0 \gset lr3_

-- 1. Propositions
select is((select rule from public.lettering_proposals(:'e1_id', :'c411_id') where debit_line_id = :'lf1_id'), 'same_amount', 'proposition règle 1 : même tiers et même montant');
select is((select credit_line_ids from public.lettering_proposals(:'e1_id', :'c411_id') where debit_line_id = :'lf2_id'), array[:'lr2_id', :'lw2_id']::uuid[], 'proposition règle 2 : facture = règlement net + retenue');
select is((select count(*) from public.lettering_proposals(:'e1_id', :'c411_id') where debit_line_id = :'lf3_id'), 0::bigint, 'pas de proposition quand les montants diffèrent hors retenues');

-- 2. Lettrage soldé
select tests.authenticate_as(:'assist_id');
select public.letter_lines(array[:'lf1_id', :'lr1_id']::uuid[]) as id \gset let1_
select is((select code || '/' || is_partial from public.letterings where id = :'let1_id'), 'A/false', 'premier lettrage du tiers : code A, soldé');
select is((select letter_code from public.entry_lines where id = :'lr1_id'), 'A', 'les lignes portent le code');
select is((select count(*) from public.unlettered_lines(:'e1_id', :'c411_id')), 5::bigint, '5 lignes restent non lettrées');
select throws_ok(format('select public.letter_lines(array[%L, %L]::uuid[])', :'lf1_id', :'lr2_id'), '23514', null, 'une ligne déjà lettrée ne se relettre pas');
select throws_ok(format('select public.letter_lines(array[%L]::uuid[])', :'lf2_id'), '23514', null, 'au moins deux lignes');
select lives_ok(format('select public.letter_lines(array[%L, %L, %L]::uuid[])', :'lf2_id', :'lr2_id', :'lw2_id'), 'lettrage à trois lignes : facture = règlement + retenue');

-- 3. Partiel et tolérance
select throws_ok(format('select public.letter_lines(array[%L, %L]::uuid[])', :'lf3_id', :'lr3_id'), '23514', null, 'écart 100 hors tolérance (0) : refusé sans confirmation');
select public.letter_lines(array[:'lf3_id', :'lr3_id']::uuid[], true) as id \gset let3_
select ok((select is_partial from public.letterings where id = :'let3_id'), 'lettrage partiel accepté sur confirmation');
select is((select code from public.letterings where id = :'let3_id'), 'A', 'code A pour le tiers ACL (séquence par compte et tiers)');
select public.unletter(:'let3_id', 'Refaire avec tolérance');
select tests.clear_auth();
update public.entities set lettering_tolerance = 500 where id = :'e1_id';
select tests.authenticate_as(:'assist_id');
select public.letter_lines(array[:'lf3_id', :'lr3_id']::uuid[]) as id \gset let4_
select ok(not (select is_partial from public.letterings where id = :'let4_id'), 'avec tolérance 500, écart 100 : lettrage soldé');
select is((select code from public.letterings where id = :'let4_id'), 'B', 'code suivant B (le A délettré reste tracé)');
select is((select count(*) from public.entries where entity_id = :'e1_id' and generated_source = 'lettering_gap' and status = 'draft'), 1::bigint, 'écart de règlement : brouillard d''OD généré');
select is((select sum(debit) from public.entry_lines l join public.entries e on e.id = l.entry_id join public.accounts a on a.id = l.account_id where e.generated_source = 'lettering_gap' and a.code = '6580000'), 100::numeric, 'écart de 100 passé en charge 658');

-- 4. Délettrage et permissions
select tests.authenticate_as(:'assist_id');
select throws_ok(format('select public.unletter(%L, '''')', :'let1_id'), '23514', null, 'délettrage : motif obligatoire');
select lives_ok(format('select public.unletter(%L, ''Erreur de rapprochement'')', :'let1_id'), 'délettrage tracé');
select is((select letter_code from public.entry_lines where id = :'lf1_id'), null, 'lignes libérées après délettrage');
select throws_ok(format('select public.unletter(%L, ''encore'')', :'let1_id'), '23514', null, 'pas de double délettrage');
select tests.authenticate_as(:'trainee_id');
select throws_ok(format('select public.letter_lines(array[%L, %L]::uuid[])', :'lf1_id', :'lr1_id'), '42501', null, 'stagiaire : ne lettre pas');
select tests.clear_auth();

select * from finish();
rollback;
