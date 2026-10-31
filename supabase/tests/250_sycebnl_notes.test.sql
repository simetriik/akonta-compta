-- Notes annexes SYCEBNL (D-028) : catalogue cohérent avec le plan, calcul des lignes et totaux, rapprochement avec les états, intégration à la génération.
begin;
select plan(14);

-- Catalogue : chaque ligne vise au moins un compte du plan SYCEBNL ; chaque total ne cite que des lignes de sa note
select is((select string_agg(line_code, ', ') from (
              select n.line_code from public.statement_note_lines n where n.version = 'SYCEBNL-2024' and n.kind = 'line'
               group by n.line_code
              having not bool_or(exists (select 1 from public.reference_accounts r where r.system = 'sycebnl'
                                           and left(r.code, length(n.account_from)) >= n.account_from and left(r.code, length(n.account_to)) <= n.account_to))) x),
          null, 'chaque ligne de note vise au moins un compte du plan SYCEBNL');
select is((select string_agg(distinct n.line_code, ', ') from public.statement_note_lines n, unnest(string_to_array(n.sum_of, ',')) c
            where n.version = 'SYCEBNL-2024' and n.kind <> 'line'
              and not exists (select 1 from public.statement_note_lines m where m.version = n.version and m.note_code = n.note_code
                                 and m.line_code = case when left(c, 1) = '-' then substr(c, 2) else c end)),
          null, 'chaque total ne cite que des lignes de sa note');
select is((select count(distinct note_code) from public.statement_note_lines where version = 'SYCEBNL-2024'), 23::bigint, '23 notes au catalogue');

-- Exercice d'une association (le même que pour le tableau des flux)
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
select tests.make_entry(:'sy_id', 'BQ', '2026-09-10', 'Emprunt', '[{"account":"5211000","debit":500000},{"account":"1820000","credit":500000}]') as id \gset e09_
select tests.make_entry(:'sy_id', 'OD', '2026-11-10', 'Versement à la caisse', '[{"account":"5710000","debit":30000},{"account":"5211000","credit":30000}]') as id \gset e10_
select public.validate_entries(array[:'e01_id', :'e02_id', :'e03_id', :'e04_id', :'e05_id', :'e06_id', :'e07_id', :'e08_id', :'e09_id', :'e10_id']::uuid[]);

create or replace function pg_temp.amt(p_entity uuid, p_fy uuid, p_line text) returns bigint language sql as $$
  select amount from public.note_posts(p_entity, p_fy) where line_code = p_line;
$$;

select is(pg_temp.amt(:'sy_id', :'fy_id', '13-1'), 1970000::bigint, 'note 13 : banques locales (5211)');
select is(pg_temp.amt(:'sy_id', :'fy_id', '13-N'), 2000000::bigint, 'note 13 : total net des disponibilités (banque et caisse)');
select is(pg_temp.amt(:'sy_id', :'fy_id', '23-T'), 800000::bigint, 'note 23 : total des revenus et autres produits');
select is(pg_temp.amt(:'sy_id', :'fy_id', '23-1') || '/' || pg_temp.amt(:'sy_id', :'fy_id', '23-3') || '/' || pg_temp.amt(:'sy_id', :'fy_id', '23-7'),
          '400000/100000/300000', 'note 23 : cotisations, générosité, subventions');
select is(pg_temp.amt(:'sy_id', :'fy_id', '19-T'), 50000::bigint, 'note 19 : fournisseurs (dette de 150 000 réglée à 100 000)');
select is(pg_temp.amt(:'sy_id', :'fy_id', '18A-182'), 500000::bigint, 'note 18A : emprunt auprès des établissements de crédit');
select is(pg_temp.amt(:'sy_id', :'fy_id', '26-T') || '/' || pg_temp.amt(:'sy_id', :'fy_id', '29A-T') || '/' || pg_temp.amt(:'sy_id', :'fy_id', '24-T'),
          '120000/80000/150000', 'notes 26, 29A et 24 : loyer, salaires, achats');

-- Rapprochement avec les états financiers
select is((select -amount from public.statement_posts_full(:'sy_id', :'fy_id', 'income_statement', 'SYCEBNL-2024') where post_code = 'TJ'), pg_temp.amt(:'sy_id', :'fy_id', '29A-T'),
          'note 29A = poste TJ du compte de résultat');
select is((select sum(amount)::bigint from public.statement_posts_full(:'sy_id', :'fy_id', 'income_statement', 'SYCEBNL-2024') where post_code in ('RA', 'RB', 'RC', 'RD', 'RE', 'RF', 'RG')), pg_temp.amt(:'sy_id', :'fy_id', '23-T'),
          'note 23 = revenus RA à RG du compte de résultat');

-- Intégration aux états
select public.generate_financial_statements(:'sy_id', :'fy_id') as id \gset st_
select is((select count(*) from public.financial_statements s, jsonb_array_elements(s.data->'notes') n where s.id = :'st_id' and n->>'line_code' = '23-T' and (n->>'amount')::bigint = 800000 and n->'previous' = 'null'::jsonb),
          1::bigint, 'les notes sont enregistrées avec les états (sans exercice précédent : montant N-1 absent)');
select is((select count(*) from public.financial_statements s, jsonb_array_elements(s.data->'notes') n where s.id = :'st_id'), (select count(*) from public.note_posts(:'sy_id', :'fy_id')),
          'toutes les lignes du catalogue sont enregistrées');

select * from finish();
rollback;
