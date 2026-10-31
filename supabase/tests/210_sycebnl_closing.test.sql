-- Clôture SYCEBNL (D-024) : détermination du résultat, à-nouveaux sur le compte 128, affectation sans distribution,
-- pas de calcul d'impôt sur les sociétés pour une association.
begin;
select plan(8);

select tests.create_cabinet('Cabinet A') as id \gset a_
insert into public.entities (cabinet_id, name, accounting_system) values (:'a_id', 'Association Espoir', 'sycebnl') returning id as sy_id \gset
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'sy_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'sy_id' \gset fy_
select public.create_journals_from_template(:'sy_id', null);
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'sy_id', 'BQ', 'Banque', 'bank', id from public.accounts where entity_id = :'sy_id' and code = '5211000';

-- Excédent 2026 : dotation 1 M, cotisations 400 k, don 100 k, subvention 300 k, loyer 120 k, achat 150 k (payé) → 530 k
select tests.make_entry(:'sy_id', 'AN', '2026-01-01', 'Dotation', '[{"account":"5211000","debit":1000000},{"account":"1011000","credit":1000000}]') as id \gset e1_
select tests.make_entry(:'sy_id', 'BQ', '2026-02-10', 'Cotisations', '[{"account":"5211000","debit":400000},{"account":"7010000","credit":400000}]') as id \gset e2_
select tests.make_entry(:'sy_id', 'BQ', '2026-03-10', 'Don', '[{"account":"5211000","debit":100000},{"account":"7041000","credit":100000}]') as id \gset e3_
select tests.make_entry(:'sy_id', 'BQ', '2026-04-10', 'Subvention', '[{"account":"5211000","debit":300000},{"account":"7130000","credit":300000}]') as id \gset e4_
select tests.make_entry(:'sy_id', 'BQ', '2026-06-10', 'Loyer', '[{"account":"6222000","debit":120000},{"account":"5211000","credit":120000}]') as id \gset e5_
select tests.make_entry(:'sy_id', 'BQ', '2026-07-10', 'Achat', '[{"account":"6011000","debit":150000},{"account":"5211000","credit":150000}]') as id \gset e6_
select public.validate_entries(array[:'e1_id', :'e2_id', :'e3_id', :'e4_id', :'e5_id', :'e6_id']::uuid[]);

select public.generate_result_entry(:'sy_id', :'fy_id') as id \gset res_
select is((select credit from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'res_id' and a.code = '1310000'), 530000::bigint,
          'excédent 530 000 au crédit du compte 131');
select public.validate_entry(:'res_id');
select is((select sum(amount)::bigint from public.statement_posts_full(:'sy_id', :'fy_id', 'balance_sheet_liabilities', 'SYCEBNL-2024') where post_code = 'CH'), 530000::bigint,
          'résultat net (poste CH) inchangé après l''écriture de détermination du résultat');

-- À-nouveaux et affectation
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'sy_id', '2027-01-01', '2027-12-31');
select public.generate_opening_balances(:'sy_id', :'fy_id') as id \gset an_
select is((select credit from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'an_id' and a.code = '1280000'), 530000::bigint,
          'résultat 2026 repris au compte 128 (en instance d''affectation)');
select is((select sum(debit) - sum(credit) from public.entry_lines where entry_id = :'an_id'), 0::numeric, 'à-nouveaux équilibrés');
select public.validate_entry(:'an_id');

select id as id from public.fiscal_years where entity_id = :'sy_id' and label = '2027' \gset fy27_
select throws_ok(format('select public.allocate_result(%L, %L, ''2027-06-30'', 0, 0, 100000, 430000)', :'sy_id', :'fy27_id'), '23514', null,
                 'distribution refusée pour une entité à but non lucratif');
select public.allocate_result(:'sy_id', :'fy27_id', '2027-06-30', 100000, 80000, 0, 350000) as id \gset aff_
select is((select string_agg(a.code || '=' || coalesce(l.debit, 0) || '/' || coalesce(l.credit, 0), ', ' order by a.code)
             from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'aff_id' and (l.debit > 0 or l.credit > 0)),
          '1120000=0/100000, 1180000=0/80000, 1210000=0/350000, 1280000=530000/0', 'affectation : 128 soldé vers 112, 118 et 121');
select ok(public.validate_entry(:'aff_id') is not null, 'l''écriture d''affectation se valide');

-- Pas d'impôt sur les sociétés
select throws_ok(format('insert into public.tax_computations (cabinet_id, entity_id, fiscal_year_id, rules_version, accounting_result, taxable_result, is_rate, minimum_tax_rate, computed_tax, minimum_tax, tax_due, balance_due) values (%L, %L, %L, ''2026'', 0, 0, 0.3, 0.005, 0, 0, 0, 0)', :'a_id', :'sy_id', :'fy_id'), '23514', null,
                 'le calcul de l''impôt sur les sociétés est refusé pour une association');

select * from finish();
rollback;
