-- Recette 11/11/2026 : AN-21 (régénération après contre-passation), AN-24 (provision sur compte non collectif),
-- AN-29 (la réouverture déverrouille les périodes de la clôture provisoire), AN-16 (lettrage sans les deux sens).
begin;
select plan(7);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.create_user('assist@a.test', :'a_id') as id \gset assist_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'e1_id' \gset fy_
select public.create_journals_from_template(:'e1_id', null);
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'e1_id', 'CHU', 'CHU', 'customer');

-- AN-21 : stock généré, validé, contre-passé, puis régénéré
select tests.make_entry(:'e1_id', 'AN', '2026-01-01', 'AN', '[{"account":"3110000","debit":4200000},{"account":"1011000","credit":4200000}]', :'assist_id') as id \gset an_
select public.validate_entry(:'an_id');
insert into public.inventory_stocks (cabinet_id, entity_id, fiscal_year_id, stock_account_id, variation_account_id, closing_value)
  select :'a_id', :'e1_id', :'fy_id', (select id from public.accounts where entity_id = :'e1_id' and code = '3110000'), (select id from public.accounts where entity_id = :'e1_id' and code = '6031000'), 5000000;
select tests.authenticate_as(:'partner_id', 'aal2');
select public.generate_stock_variations(:'e1_id', :'fy_id') as id \gset stk_
select public.validate_entry(:'stk_id');
select throws_ok(format('select public.generate_stock_variations(%L, %L)', :'e1_id', :'fy_id'), '23514', null, 'AN-21 : une écriture générée validée et non contre-passée bloque la régénération');
select public.reverse_entry(:'stk_id', 'Stock mal saisi', '2026-12-31', true);
select lives_ok(format('select public.generate_stock_variations(%L, %L)', :'e1_id', :'fy_id'), 'AN-21 : après contre-passation, la régénération est possible');
select is((select count(*) from public.entries where entity_id = :'e1_id' and generated_source = 'stocks:' || :'fy_id' and status = 'draft'), 1::bigint, 'AN-21 : un nouveau brouillard de variation de stock existe');

-- AN-24 : provision de créance sur 4911000 avec un tiers
select tests.clear_auth();
insert into public.provisions (cabinet_id, entity_id, fiscal_year_id, kind, third_party_id, provision_account_id, expense_account_id, reversal_account_id, base_amount, amount, previous_amount)
  select :'a_id', :'e1_id', :'fy_id', 'receivable', (select id from public.third_parties where code = 'CHU' and entity_id = :'e1_id'),
         public.account_id_by_code(:'e1_id', '4911'), public.account_id_by_code(:'e1_id', '6594'), public.account_id_by_code(:'e1_id', '7594'), 1000000, 500000, 0;
select tests.authenticate_as(:'partner_id', 'aal2');
select lives_ok(format('select public.generate_provision_entries(%L, %L)', :'e1_id', :'fy_id'), 'AN-24 : provision sur 4911000 générée sans tiers');

-- AN-16 : deux lignes au débit ne se lettrent pas
select tests.clear_auth();
select tests.make_entry(:'e1_id', 'VT', '2026-03-01', 'Facture 1', '[{"account":"4111000","tp":"CHU","debit":100000},{"account":"7011000","credit":100000}]', :'assist_id') as id \gset f1_
select tests.make_entry(:'e1_id', 'VT', '2026-03-02', 'Facture 2', '[{"account":"4111000","tp":"CHU","debit":100000},{"account":"7011000","credit":100000}]', :'assist_id') as id \gset f2_
select public.validate_entries(array[:'f1_id', :'f2_id']::uuid[]);
select l.id as id from public.entry_lines l where l.entry_id = :'f1_id' and l.debit > 0 \gset l1_
select l.id as id from public.entry_lines l where l.entry_id = :'f2_id' and l.debit > 0 \gset l2_
select tests.authenticate_as(:'assist_id');
select throws_ok(format('select public.letter_lines(array[%L, %L]::uuid[], true)', :'l1_id', :'l2_id'), '23514', null, 'AN-16 : lettrage refusé sans ligne au crédit');

-- AN-29 : la réouverture déverrouille les périodes verrouillées par la clôture provisoire, pas celles verrouillées à la main
select tests.authenticate_as(:'partner_id', 'aal2');
select public.validate_entries(array(select id from public.entries where entity_id = :'e1_id' and status = 'draft'));
update public.periods set is_locked = true where fiscal_year_id = :'fy_id' and period_no = 1;
select public.run_closing_checks(:'e1_id', :'fy_id');
update public.closing_checks set status = 'waived', waive_comment = 'test' where fiscal_year_id = :'fy_id' and severity = 'warning' and status = 'failed';
select public.close_provisional(:'e1_id', :'fy_id');
select is((select count(*) from public.periods where fiscal_year_id = :'fy_id' and is_locked), 12::bigint, 'AN-29 : 12 périodes verrouillées par la clôture provisoire');
select public.reopen_fiscal_year(:'e1_id', :'fy_id', 'Facture oubliée');
select is((select count(*) from public.periods where fiscal_year_id = :'fy_id' and is_locked), 1::bigint, 'AN-29 : seule la période verrouillée à la main le reste après la réouverture');

select * from finish();
rollback;
