-- Rejeu de la recette du 12/11/2026 : AN-35 (la contre-passation de l'écriture de résultat ne doit pas fausser le résultat
-- comptable ni les soldes des états) et AN-36 (recalculer l'IS remplace le brouillard précédent).
begin;
select plan(4);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'e1_id' \gset fy_
select public.create_journals_from_template(:'e1_id', null);
select tests.make_entry(:'e1_id', 'OD', '2026-03-01', 'Capital', '[{"account":"5210000","debit":5000000},{"account":"1011000","credit":5000000}]', :'partner_id') as id \gset cap_
select tests.make_entry(:'e1_id', 'OD', '2026-04-01', 'Vente', '[{"account":"5210000","debit":2000000},{"account":"7011000","credit":2000000}]', :'partner_id') as id \gset sale_
select tests.make_entry(:'e1_id', 'OD', '2026-05-01', 'Achat', '[{"account":"6011000","debit":800000},{"account":"5210000","credit":800000}]', :'partner_id') as id \gset buy_
select tests.authenticate_as(:'partner_id', 'aal2');
select public.validate_entries(array[:'cap_id', :'sale_id', :'buy_id']::uuid[]);

-- AN-36 : deux calculs d'IS de suite (le second remplace le brouillard du premier)
select public.compute_income_tax(:'e1_id', :'fy_id', public.propose_tax_adjustments(:'e1_id', :'fy_id', '2026'), '2026', 250000);
select lives_ok(format('select public.compute_income_tax(%L, %L, public.propose_tax_adjustments(%L, %L, %L), %L, 250000)', :'e1_id', :'fy_id', :'e1_id', :'fy_id', '2026', '2026'), 'AN-36 : un second calcul d''IS remplace le brouillard sans erreur');
select is((select count(*) from public.entries where entity_id = :'e1_id' and generated_source = 'income_tax:' || :'fy_id'), 1::bigint, 'AN-36 : un seul brouillard d''IS');

-- AN-35 : résultat, validation, contre-passation du résultat
select is(public.accounting_result(:'e1_id', :'fy_id'), 1200000::bigint, 'Résultat comptable avant écriture de résultat');
select public.validate_entries(array(select id from public.entries where entity_id = :'e1_id' and status = 'draft'));
select public.generate_result_entry(:'e1_id', :'fy_id') as id \gset res_
select public.validate_entry(:'res_id');
select public.reverse_entry(:'res_id', 'Recalcul', '2026-12-31', true);
select is(public.accounting_result(:'e1_id', :'fy_id'), 1200000::bigint, 'AN-35 : la contre-passation du résultat ne double pas le résultat comptable');

select * from finish();
rollback;
