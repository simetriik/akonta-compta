-- Tableau des flux de trésorerie SYCEBNL (D-027) : classement par compte de contrepartie, totaux, réconciliation avec le grand livre et le bilan.
begin;
select plan(13);

-- Classement des contreparties
select is(public.cash_flow_post('7010000', 100), 'FA', 'cotisations : FA');
select is(public.cash_flow_post('4110000', 100), 'FA', 'adhérents (cotisations appelées) : FA');
select is(public.cash_flow_post('7130000', 100), 'FB', 'subvention d''exploitation : FB');
select is(public.cash_flow_post('7041000', 100), 'FC', 'dons : FC');
select is(public.cash_flow_post('6222000', -100), 'FF', 'loyer : FF');
select is(public.cash_flow_post('6611000', -100), 'FG', 'rémunérations : FG');
select is(public.cash_flow_post('2442000', -100) || public.cash_flow_post('2442000', 100), 'FIFK', 'matériel : acquisition FI, cession FK');
select is(public.cash_flow_post('1820000', 100) || public.cash_flow_post('1820000', -100), 'FPFQ', 'emprunt : encaissement FP, remboursement FQ');

-- Exercice d'une association
select tests.create_cabinet('Cabinet A') as id \gset a_
insert into public.entities (cabinet_id, name, accounting_system) values (:'a_id', 'Association Espoir', 'sycebnl') returning id as sy_id \gset
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'sy_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'sy_id' \gset fy_
select public.create_journals_from_template(:'sy_id', null);
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'sy_id', 'BQ', 'Banque', 'bank', id from public.accounts where entity_id = :'sy_id' and code = '5211000';
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'sy_id', 'SOB', 'SOBEBRA', 'supplier');

select tests.make_entry(:'sy_id', 'AN', '2026-01-01', 'Dotation initiale', '[{"account":"5211000","debit":1000000},{"account":"1011000","credit":1000000}]') as id \gset e01_
select tests.make_entry(:'sy_id', 'BQ', '2026-02-10', 'Cotisations', '[{"account":"5211000","debit":400000},{"account":"7010000","credit":400000}]') as id \gset e02_
select tests.make_entry(:'sy_id', 'BQ', '2026-03-10', 'Don', '[{"account":"5211000","debit":100000},{"account":"7041000","credit":100000}]') as id \gset e03_
select tests.make_entry(:'sy_id', 'BQ', '2026-04-10', 'Subvention', '[{"account":"5211000","debit":300000},{"account":"7130000","credit":300000}]') as id \gset e04_
select tests.make_entry(:'sy_id', 'BQ', '2026-05-10', 'Loyer', '[{"account":"6222000","debit":120000},{"account":"5211000","credit":120000}]') as id \gset e05_
select tests.make_entry(:'sy_id', 'AC', '2026-05-20', 'Achat à crédit', '[{"account":"6011000","debit":150000},{"account":"4011000","tp":"SOB","credit":150000}]') as id \gset e06_
select tests.make_entry(:'sy_id', 'BQ', '2026-06-10', 'Règlement fournisseur', '[{"account":"4011000","tp":"SOB","debit":100000},{"account":"5211000","credit":100000}]') as id \gset e07_
select tests.make_entry(:'sy_id', 'BQ', '2026-06-30', 'Salaires', '[{"account":"6611000","debit":80000},{"account":"5211000","credit":80000}]') as id \gset e08_
select tests.make_entry(:'sy_id', 'BQ', '2026-07-10', 'Achat de matériel', '[{"account":"2442000","debit":250000},{"account":"5211000","credit":250000}]') as id \gset e09_
select tests.make_entry(:'sy_id', 'BQ', '2026-08-10', 'Dotation reçue', '[{"account":"5211000","debit":200000},{"account":"1011000","credit":200000}]') as id \gset e10_
select tests.make_entry(:'sy_id', 'BQ', '2026-09-10', 'Emprunt', '[{"account":"5211000","debit":500000},{"account":"1820000","credit":500000}]') as id \gset e11_
select tests.make_entry(:'sy_id', 'BQ', '2026-10-10', 'Remboursement d''emprunt', '[{"account":"1820000","debit":50000},{"account":"5211000","credit":50000}]') as id \gset e12_
select tests.make_entry(:'sy_id', 'OD', '2026-11-10', 'Versement à la caisse', '[{"account":"5710000","debit":30000},{"account":"5211000","credit":30000}]') as id \gset e13_
select public.validate_entries(array[:'e01_id', :'e02_id', :'e03_id', :'e04_id', :'e05_id', :'e06_id', :'e07_id', :'e08_id', :'e09_id', :'e10_id', :'e11_id', :'e12_id', :'e13_id']::uuid[]);

select is((select string_agg(post_code || '=' || amount, ', ' order by sort_order) from public.cash_flow_posts(:'sy_id', :'fy_id') where amount <> 0),
          'ZA=1000000, FA=400000, FB=300000, FC=100000, FF=-220000, FG=-80000, ZB=500000, FI=-250000, ZC=-250000, FM=200000, ZD=200000, FP=500000, FQ=-50000, ZE=450000, ZDE=650000, ZF=900000, ZG=1900000',
          'tableau des flux de l''association : lignes, totaux et trésorerie finale');
select is((select count(*) from public.cash_flow_posts(:'sy_id', :'fy_id')), 25::bigint, '25 lignes : 17 postes et 8 totaux');

select public.generate_financial_statements(:'sy_id', :'fy_id') as id \gset st_
select is((select count(*) from public.financial_statements s, jsonb_array_elements(s.checks) c where s.id = :'st_id' and (c->>'passed')::boolean is not true), 0::bigint,
          'tous les contrôles passent, dont la réconciliation avec le grand livre et le bilan');
select is((select (e->>'amount')::bigint from public.financial_statements s, jsonb_array_elements(s.data->'cash_flow') e where s.id = :'st_id' and e->>'post_code' = 'ZG'), 1900000::bigint,
          'tableau des flux enregistré avec les états');
select is((select count(*) from public.financial_statements s, jsonb_array_elements(s.checks) c where s.id = :'st_id' and c->>'code' like 'cash_flow%'), 2::bigint, 'deux contrôles de trésorerie ajoutés');

select * from finish();
rollback;
