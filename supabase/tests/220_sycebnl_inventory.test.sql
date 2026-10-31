-- Inventaire d'une entité à but non lucratif (D-025) : amortissements et cessions sur le plan SYCEBNL ; compte 6812 pour les
-- immobilisations incorporelles (régression : 6811 n'existe dans aucun des deux plans).
begin;
select plan(7);

select tests.create_cabinet('Cabinet A') as id \gset a_
insert into public.entities (cabinet_id, name, accounting_system) values (:'a_id', 'Association Espoir', 'sycebnl') returning id as sy_id \gset
insert into public.entities (cabinet_id, name) values (:'a_id', 'Société Normale') returning id as no_id \gset
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'sy_id', '2026-01-01', '2026-12-31'), (:'a_id', :'no_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'sy_id' \gset sfy_
select id as id from public.fiscal_years where entity_id = :'no_id' \gset nfy_
select public.create_journals_from_template(:'sy_id', null);
select public.create_journals_from_template(:'no_id', null);

-- Association : logiciel 600 000 sur 36 mois (200 000 par an) et matériel informatique 900 000 sur 36 mois (300 000 par an)
insert into public.fixed_assets (cabinet_id, entity_id, code, designation, asset_account_id, acquisition_date, service_date, gross_value, duration_months)
  select :'a_id', :'sy_id', 'LOG-01', 'Logiciel de gestion', id, '2026-01-01', '2026-01-01', 600000, 36 from public.accounts where entity_id = :'sy_id' and code = '2131000';
insert into public.fixed_assets (cabinet_id, entity_id, code, designation, asset_account_id, acquisition_date, service_date, gross_value, duration_months)
  select :'a_id', :'sy_id', 'MAT-01', 'Ordinateurs', id, '2026-01-01', '2026-01-01', 900000, 36 from public.accounts where entity_id = :'sy_id' and code = '2442000';
select public.generate_depreciation(:'sy_id', :'sfy_id') as id \gset dep_
select is((select string_agg(a.code || '=' || l.debit || '/' || l.credit, ', ' order by a.code) from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'dep_id'),
          '2813000=0/200000, 2844000=0/300000, 6812000=200000/0, 6813000=300000/0',
          'SYCEBNL : dotations 6812 / 2813 (logiciel) et 6813 / 2844 (matériel)');

-- Société du système normal : une immobilisation incorporelle est aussi amortissable (régression 6811)
select code as code from public.accounts where entity_id = :'no_id' and code like '213%' and allow_posting order by code limit 1 \gset noasset_
insert into public.fixed_assets (cabinet_id, entity_id, code, designation, asset_account_id, acquisition_date, service_date, gross_value, duration_months)
  select :'a_id', :'no_id', 'LOG-01', 'Logiciel', id, '2026-01-01', '2026-01-01', 600000, 36 from public.accounts where entity_id = :'no_id' and code = :'noasset_code';
select lives_ok(format('select public.generate_depreciation(%L, %L)', :'no_id', :'nfy_id'), 'SYSCOHADA : amortissement d''une immobilisation incorporelle');
select is((select sum(l.debit) from public.entry_lines l join public.entries e on e.id = l.entry_id join public.accounts a on a.id = l.account_id
            where e.entity_id = :'no_id' and e.generated_source = 'depreciation:' || :'nfy_id' and a.code = '6812000'), 200000::numeric, 'SYSCOHADA : dotation au compte 6812');

-- Cession du matériel au 31 décembre : prix 400 000 à recevoir (485) ; la dotation 2026 est complétée jusqu'à la date de cession
select id as id from public.fixed_assets where entity_id = :'sy_id' and code = 'MAT-01' \gset mat_
select public.dispose_asset(:'mat_id', '2026-12-31', 400000) as id \gset cess_
-- Dotation complémentaire de l'exercice (300 000), puis sortie : valeur nette 600 000 en 812, cumul repris en 2844
select is((select string_agg(code || '=' || net, ', ' order by code)
             from (select a.code, sum(l.debit - l.credit) as net from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'cess_id' group by a.code having sum(l.debit - l.credit) <> 0) x),
          '2442000=-900000, 4850000=400000, 6813000=300000, 8120000=600000, 8220000=-400000',
          'cession : sortie 2442, dotation 6813, valeur nette 812, créance 485, produit 822');
select is((select sum(debit) - sum(credit) from public.entry_lines where entry_id = :'cess_id'), 0::numeric, 'cession : écriture équilibrée');

-- Provisions sur créances : comptes 4911 et 6594 présents au plan SYCEBNL
select is((select count(*) from public.accounts where entity_id = :'sy_id' and code in ('4911000', '6594000', '7594000', '6591000', '1940000', '4780000', '4790000')), 7::bigint,
          'comptes de provisions et d''écarts de conversion utilisés par l''inventaire présents au plan SYCEBNL');
select is((select count(*) from public.accounts where entity_id = :'sy_id' and code in ('6031000', '6032000') and allow_posting), 2::bigint, 'comptes de variation de stocks 6031 et 6032 imputables');

select * from finish();
rollback;
