-- Module 8 — Travaux d'inventaire : amortissements (linéaire, prorata, dégressif, cession), stocks, provisions, régularisations et extournes, écarts de conversion (§6, §10.8).
begin;
select plan(27);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('assist@a.test', :'a_id') as id \gset assist_
select tests.create_user('trainee@a.test', :'a_id') as id \gset trainee_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'trainee_id', :'a_id', 'trainee', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'e1_id' \gset fy_
select public.create_journals_from_template(:'e1_id', null);
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'e1_id', 'BQ', 'Ecobank', 'bank', id from public.accounts where entity_id = :'e1_id' and code = '5210000';
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'e1_id', 'CHU', 'CHU', 'customer'), (:'a_id', :'e1_id', 'UE', 'Client Europe', 'customer');

-- 1. Base 360 et plan linéaire avec prorata : véhicule 12 000 000 sur 5 ans mis en service le 1er avril 2026
select is(public.days360('2026-04-01', '2026-12-31'), 270, 'du 1er avril au 31 décembre : 270 jours (base 360)');
select is(public.days360('2026-01-01', '2026-12-31'), 360, 'année pleine : 360 jours');
insert into public.fixed_assets (cabinet_id, entity_id, code, designation, asset_account_id, acquisition_date, service_date, gross_value, duration_months)
  select :'a_id', :'e1_id', 'VEH-01', 'Véhicule utilitaire', id, '2026-03-25', '2026-04-01', 12000000, 60 from public.accounts where entity_id = :'e1_id' and code = '2451000';
select id as id from public.fixed_assets where code = 'VEH-01' \gset veh_
select is((select charge from public.depreciation_plan(:'veh_id') where year_no = 1), 1800000::bigint, 'année 1 : 12 000 000 × 20 % × 270/360 = 1 800 000');
select is((select charge from public.depreciation_plan(:'veh_id') where year_no = 2), 2400000::bigint, 'année 2 : dotation pleine 2 400 000');
select is((select count(*) from public.depreciation_plan(:'veh_id')), 6::bigint, 'plan sur 6 exercices civils (prorata)');
select is((select sum(charge) from public.depreciation_plan(:'veh_id')), 12000000::numeric, 'total des dotations = valeur brute');
select is((select net_book_value from public.depreciation_plan(:'veh_id') order by year_no desc limit 1), 0::bigint, 'valeur nette finale nulle');

-- Dégressif : matériel 3 000 000 sur 3 ans, coefficient 1,5, mis en service le 1er janvier
insert into public.fixed_assets (cabinet_id, entity_id, code, designation, asset_account_id, acquisition_date, service_date, gross_value, duration_months, method, declining_coefficient)
  select :'a_id', :'e1_id', 'MAT-01', 'Matériel informatique', id, '2026-01-01', '2026-01-01', 3000000, 36, 'declining', 1.5 from public.accounts where entity_id = :'e1_id' and code = '2441000';
select id as id from public.fixed_assets where code = 'MAT-01' \gset mat_
select is((select charge from public.depreciation_plan(:'mat_id') where year_no = 1), 1500000::bigint, 'dégressif année 1 : 3 000 000 × 50 %');
select is((select charge from public.depreciation_plan(:'mat_id') where year_no = 2), 750000::bigint, 'dégressif année 2 : 1 500 000 × 50 % (= linéaire sur 2 ans restants)');
select is((select sum(charge) from public.depreciation_plan(:'mat_id')), 3000000::numeric, 'dégressif : totalement amorti');

-- Reprise de l'existant : cumul antérieur 1 800 000
insert into public.fixed_assets (cabinet_id, entity_id, code, designation, asset_account_id, acquisition_date, service_date, gross_value, duration_months, prior_depreciation)
  select :'a_id', :'e1_id', 'MOB-01', 'Mobilier', id, '2023-01-01', '2023-01-01', 6000000, 120, 1800000 from public.accounts where entity_id = :'e1_id' and code = '2444000';

-- 2. Génération des dotations 2026 : écriture unique en brouillard « générée »
select tests.authenticate_as(:'assist_id');
select public.generate_depreciation(:'e1_id', :'fy_id') as id \gset dep_
select is((select status::text || '/' || is_generated from public.entries where id = :'dep_id'), 'draft/true', 'dotations : brouillard marqué générée');
select is((select count(*) from public.depreciation_schedules where fiscal_year_id = :'fy_id'), 3::bigint, '3 lignes de plan pour l''exercice');
select is((select sum(debit) from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'dep_id' and a.code like '68%'), (1800000 + 1500000 + 600000)::numeric, 'dotations 68x = 1 800 000 + 1 500 000 + 600 000');
select is((select charge from public.depreciation_schedules where asset_id = (select id from public.fixed_assets where code = 'MOB-01') and fiscal_year_id = :'fy_id'), 600000::bigint, 'mobilier repris : dotation annuelle 600 000 (cumul antérieur 1 800 000)');
select lives_ok(format('select public.generate_depreciation(%L, %L)', :'e1_id', :'fy_id'), 'régénération : le brouillard précédent est remplacé');
select is((select count(*) from public.entries where entity_id = :'e1_id' and generated_source like 'depreciation:%'), 1::bigint, 'une seule écriture de dotations');

-- 3. Cession du véhicule le 30 juin 2027 : exercice 2027 requis
select tests.clear_auth();
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2027-01-01', '2027-12-31');
select tests.authenticate_as(:'assist_id');
select public.validate_entry((select id from public.entries where entity_id = :'e1_id' and generated_source = 'depreciation:' || :'fy_id'));
select public.dispose_asset(:'veh_id', '2027-06-30', 9000000, (select id from public.accounts where entity_id = :'e1_id' and code = '4851000'), null, false) as id \gset ces_
select is((select status::text from public.fixed_assets where id = :'veh_id'), 'disposed', 'immobilisation sortie');
select is((select sum(debit) from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'ces_id' and a.code like '68%'), 1200000::numeric, 'dotation complémentaire : 2 400 000 × 180/360');
select is((select debit from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'ces_id' and a.code = '8120000'), 9000000::bigint, 'VCN sortie : 12 000 000 - 1 800 000 - 1 200 000 = 9 000 000');
select is((select credit from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'ces_id' and a.code = '8220000'), 9000000::bigint, 'produit de cession 9 000 000');
select is((select sum(debit) - sum(credit) from public.entry_lines where entry_id = :'ces_id'), 0::numeric, 'écriture de cession équilibrée');

-- 4. Stocks : marchandises 4 200 000 à l'ouverture, 5 000 000 à la clôture
select tests.clear_auth();
select tests.make_entry(:'e1_id', 'AN', '2026-01-01', 'AN', '[{"account":"3110000","debit":4200000},{"account":"1011000","credit":4200000}]', :'assist_id') as id \gset an_
select public.validate_entry(:'an_id');
insert into public.inventory_stocks (cabinet_id, entity_id, fiscal_year_id, stock_account_id, variation_account_id, closing_value)
  select :'a_id', :'e1_id', :'fy_id', (select id from public.accounts where entity_id = :'e1_id' and code = '3110000'), (select id from public.accounts where entity_id = :'e1_id' and code = '6031000'), 5000000;
select tests.authenticate_as(:'assist_id');
select public.generate_stock_variations(:'e1_id', :'fy_id') as id \gset stk_
select is((select debit from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'stk_id' and a.code = '3110000'), 800000::bigint, 'variation de stock : +800 000 au débit de 311');
select is((select opening_value from public.inventory_stocks where fiscal_year_id = :'fy_id'), 4200000::bigint, 'stock initial repris du solde d''ouverture');

-- 5. Régularisations : loyer annuel 1 200 000 payé le 1er octobre 2026 pour 12 mois → CCA 900 000 ; extourne au 1er janvier 2027
insert into public.accruals (cabinet_id, entity_id, fiscal_year_id, kind, description, account_id, counterpart_account_id, total_amount, period_from, period_to, amount)
  select :'a_id', :'e1_id', :'fy_id', 'cca', 'Loyer annuel bureaux', (select id from public.accounts where entity_id = :'e1_id' and code = '6221000'), (select id from public.accounts where entity_id = :'e1_id' and code = '4760000'), 1200000, '2026-10-01', '2027-09-30', 0;
select is(public.accrual_amount('cca', 1200000, '2026-10-01', '2027-09-30', '2026-01-01', '2026-12-31'), 900000::bigint, 'CCA : 9 mois sur 12 hors exercice = 900 000');
select public.generate_accruals(:'e1_id', :'fy_id') as id \gset acc_
select is((select debit from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'acc_id' and a.code = '4760000'), 900000::bigint, 'écriture au 31/12 : 476 débit 900 000');
select public.validate_entry(:'acc_id');
select public.generate_reversals(:'e1_id', :'fy_id') as ids \gset rev_
select is((select entry_date || '/' || status from public.entries where generated_source = 'accruals_reversal:' || :'fy_id'), '2027-01-01/draft', 'extourne générée au 1er janvier N+1 en brouillard');

-- 6. Permission
select tests.authenticate_as(:'trainee_id');
select throws_ok(format('select public.generate_depreciation(%L, %L)', :'e1_id', :'fy_id'), '42501', null, 'stagiaire : ne prépare pas l''inventaire');
select tests.clear_auth();

select * from finish();
rollback;
