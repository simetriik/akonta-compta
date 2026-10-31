-- États financiers SYCEBNL (D-024) : couverture des comptes par les correspondances, version choisie selon le référentiel,
-- bilan et compte de résultat d'une association, contrôles de cohérence.
begin;
select plan(14);

-- 1. Couverture : tout compte imputable du plan SYCEBNL (classes 1 à 8, hors 58 virements internes) est repris une fois et une seule
--    par un poste lorsque son solde est dans son sens normal, et jamais deux fois dans le sens inverse (un solde anormal reste hors des
--    postes : le contrôle « actif = passif » le signale).
select is((
  with leaf as (
    select rpad(r.code, 7, '0') as code, r.class, r.normal_side::text as normal_side from public.reference_accounts r
     where r.system = 'sycebnl' and r.class between 1 and 8 and r.code not like '58%'
       and not exists (select 1 from public.reference_accounts c where c.system = 'sycebnl' and c.parent_code = r.code)
  ), hits as (
    select l.code, l.normal_side, s.side, (select count(*) from public.statement_mappings m
                             where m.version = 'SYCEBNL-2024' and m.cabinet_id is null and m.balance_side in ('any', s.side)
                               and left(l.code, length(m.account_from)) >= m.account_from and left(l.code, length(m.account_to)) <= m.account_to
                               and (m.statement = 'income_statement') = (l.class >= 6)) as n
      from leaf l cross join (values ('debit'), ('credit')) as s(side)
  ) select string_agg(code || '/' || side || '=' || n, ', ' order by code, side) from hits where n > 1 or (n = 0 and side = normal_side)
), null, 'chaque compte imputable du plan SYCEBNL est repris exactement une fois par les états');

select is((select count(distinct post_code) from public.statement_mappings where version = 'SYCEBNL-2024' and statement = 'balance_sheet_assets'), 22::bigint, '22 postes d''actif (hors totaux)');
select is((select count(distinct post_code) from public.statement_mappings where version = 'SYCEBNL-2024' and statement = 'balance_sheet_liabilities'), 20::bigint, '20 postes de passif (hors totaux et résultat)');
select is((select count(distinct post_code) from public.statement_mappings where version = 'SYCEBNL-2024' and statement = 'income_statement'), 22::bigint, '22 postes de compte de résultat (hors soldes)');

-- 2. Version selon le référentiel
select tests.create_cabinet('Cabinet A') as id \gset a_
insert into public.entities (cabinet_id, name, accounting_system) values (:'a_id', 'Association Espoir', 'sycebnl') returning id as sy_id \gset
insert into public.entities (cabinet_id, name) values (:'a_id', 'Société Normale') returning id as no_id \gset
select is(public.statement_version(:'sy_id'), 'SYCEBNL-2024', 'une association utilise les correspondances SYCEBNL');
select is(public.statement_version(:'no_id'), 'SYSCOHADA-2017', 'une société garde les correspondances SYSCOHADA');
select is(public.statement_result_post('SYCEBNL-2024') || public.statement_result_post('SYSCOHADA-2017'), 'CHCJ', 'le résultat net est CH (SYCEBNL) ou CJ (SYSCOHADA)');

-- 3. Exercice d'une association : dotation 1 M, cotisations 400 k, don 100 k, subvention 300 k, achat à crédit 150 k, loyer 120 k
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'sy_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'sy_id' \gset fy_
select public.create_journals_from_template(:'sy_id', null);
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'sy_id', 'BQ', 'Banque', 'bank', id from public.accounts where entity_id = :'sy_id' and code = '5211000';
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'sy_id', 'SOB', 'SOBEBRA', 'supplier');

select tests.make_entry(:'sy_id', 'AN', '2026-01-01', 'Dotation', '[{"account":"5211000","debit":1000000},{"account":"1011000","credit":1000000}]') as id \gset e1_
select tests.make_entry(:'sy_id', 'BQ', '2026-02-10', 'Cotisations', '[{"account":"5211000","debit":400000},{"account":"7010000","credit":400000}]') as id \gset e2_
select tests.make_entry(:'sy_id', 'BQ', '2026-03-10', 'Don', '[{"account":"5211000","debit":100000},{"account":"7041000","credit":100000}]') as id \gset e3_
select tests.make_entry(:'sy_id', 'BQ', '2026-04-10', 'Subvention', '[{"account":"5211000","debit":300000},{"account":"7130000","credit":300000}]') as id \gset e4_
select tests.make_entry(:'sy_id', 'AC', '2026-05-10', 'Achat', '[{"account":"6011000","debit":150000},{"account":"4011000","tp":"SOB","credit":150000}]') as id \gset e5_
select tests.make_entry(:'sy_id', 'BQ', '2026-06-10', 'Loyer', '[{"account":"6222000","debit":120000},{"account":"5211000","credit":120000}]') as id \gset e6_
select public.validate_entries(array[:'e1_id', :'e2_id', :'e3_id', :'e4_id', :'e5_id', :'e6_id']::uuid[]);

select public.generate_financial_statements(:'sy_id', :'fy_id') as id \gset st_
select is((select mapping_version from public.financial_statements where id = :'st_id'), 'SYCEBNL-2024', 'les états de l''association sont générés avec SYCEBNL-2024');
select is((select (e->>'amount')::bigint from public.financial_statements s, jsonb_array_elements(s.data->'assets') e where s.id = :'st_id' and e->>'post_code' = 'BW' and e->>'column_role' = 'gross'),
          1680000::bigint, 'actif : banques 1 680 000');
select is((select (e->>'amount')::bigint from public.financial_statements s, jsonb_array_elements(s.data->'liabilities') e where s.id = :'st_id' and e->>'post_code' = 'CA'),
          1000000::bigint, 'passif : dotation non consomptible sans droit de reprise 1 000 000');
select is((select (e->>'amount')::bigint from public.financial_statements s, jsonb_array_elements(s.data->'liabilities') e where s.id = :'st_id' and e->>'post_code' = 'DH'),
          150000::bigint, 'passif : fournisseurs 150 000');
select is((select (e->>'amount')::bigint from public.financial_statements s, jsonb_array_elements(s.data->'liabilities') e where s.id = :'st_id' and e->>'post_code' = 'CH'),
          530000::bigint, 'passif : résultat net de l''exercice (excédent) 530 000');
select is((select string_agg(e->>'post_code' || '=' || (e->>'amount'), ', ' order by e->>'post_code') from public.financial_statements s, jsonb_array_elements(s.data->'income') e where s.id = :'st_id'),
          'RA=400000, RC=100000, RF=300000, TA=-150000, TG=-120000', 'compte de résultat : cotisations, générosité, subvention, achats, loyer');
select is((select count(*) from public.financial_statements s, jsonb_array_elements(s.checks) c where s.id = :'st_id' and (c->>'passed')::boolean is not true),
          0::bigint, 'les contrôles de cohérence passent (actif = passif, résultat = grand livre)');

select * from finish();
rollback;
