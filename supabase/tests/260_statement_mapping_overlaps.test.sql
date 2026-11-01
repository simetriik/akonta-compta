-- Correspondances comptes → postes : aucun compte compté deux fois ; un bilan déséquilibré ne se clôt pas (recette du 1er nov. 2026, A11 et A12).
begin;
select plan(7);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id') as id \gset partner_
select tests.create_user('manager@a.test', :'a_id') as id \gset manager_
select tests.create_user('assist@a.test',  :'a_id') as id \gset assist_
select tests.create_entity(:'a_id', 'SARL Véhicules') as id \gset e1_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'e1_id' \gset fy_
select public.create_journals_from_template(:'e1_id', null);

-- 1. Aucun compte du plan n'entre dans deux postes d'un même état et d'une même colonne (sens compatibles)
select is((select count(*)::int
             from public.accounts a
             join public.statement_mappings m1 on m1.cabinet_id is null and m1.valid_to is null and m1.version = 'SYSCOHADA-2017'
                  and left(a.code, length(m1.account_from)) >= m1.account_from and left(a.code, length(m1.account_to)) <= m1.account_to
             join public.statement_mappings m2 on m2.cabinet_id is null and m2.valid_to is null and m2.version = 'SYSCOHADA-2017'
                  and m2.statement = m1.statement and m2.column_role = m1.column_role and m2.post_code > m1.post_code
                  and left(a.code, length(m2.account_from)) >= m2.account_from and left(a.code, length(m2.account_to)) <= m2.account_to
            where a.entity_id = :'e1_id' and a.allow_posting and a.class between 1 and 8
              and (m1.balance_side = 'any' or m2.balance_side = 'any' or m1.balance_side = m2.balance_side)), 0,
          'aucun compte du plan n''est compté dans deux postes (état, colonne et sens compatibles)');

-- 2. Dossier avec du matériel de transport (245) et son amortissement (2845) : le bilan s'équilibre
select tests.make_entry(:'e1_id', 'AN', '2026-01-01', 'AN', '[{"account":"5210000","debit":30000000},{"account":"1011000","credit":30000000}]', :'assist_id') as id \gset an_
select tests.make_entry(:'e1_id', 'OD', '2026-02-20', 'Véhicule', '[{"account":"2451000","debit":20000000},{"account":"5210000","credit":20000000}]', :'assist_id') as id \gset v_
select tests.make_entry(:'e1_id', 'OD', '2026-12-31', 'Dotation véhicule', '[{"account":"6813000","debit":4000000},{"account":"2845000","credit":4000000}]', :'assist_id') as id \gset d_
select tests.make_entry(:'e1_id', 'OD', '2026-03-01', 'Mobilier', '[{"account":"2441000","debit":2000000},{"account":"5210000","credit":2000000}]', :'assist_id') as id \gset m_
select public.validate_entries(array[:'an_id', :'v_id', :'d_id', :'m_id']::uuid[]);
select tests.authenticate_as(:'manager_id');
select public.generate_financial_statements(:'e1_id', :'fy_id') as id \gset fs_
select is((select amount from public.statement_posts(:'e1_id', :'fy_id', 'balance_sheet_assets') where post_code = 'AN' and column_role = 'gross'), 20000000::bigint, 'matériel de transport : brut 20 M au poste AN');
select is((select amount from public.statement_posts(:'e1_id', :'fy_id', 'balance_sheet_assets') where post_code = 'AM' and column_role = 'gross'), 2000000::bigint, 'matériel et mobilier : seulement 2 M au poste AM (245 exclu)');
select ok((select bool_and((c->>'passed')::boolean) from public.financial_statements f, jsonb_array_elements(f.checks) c where f.id = :'fs_id'), 'bilan équilibré avec du matériel de transport');

-- 3. États en échec : ni clôture provisoire ni arrêté
select public.generate_result_entry(:'e1_id', :'fy_id') as id \gset res_
select public.validate_entry(:'res_id');
select public.review_entry(id, 'reviewed') from public.entries where entity_id = :'e1_id' and status = 'validated' and review_status = 'not_reviewed';
update public.closing_checks set status = 'waived', waive_comment = 'test' where fiscal_year_id = :'fy_id' and severity = 'warning' and status = 'failed';
select public.run_closing_checks(:'e1_id', :'fy_id');
update public.closing_checks set status = 'waived', waive_comment = 'test' where fiscal_year_id = :'fy_id' and severity = 'warning' and status = 'failed';
select tests.clear_auth();
update public.financial_statements set checks = checks || jsonb_build_array(jsonb_build_object('code', 'balance_sheet_equilibrium', 'label', 'Total actif net = total passif', 'passed', false)) where id = :'fs_id';
select tests.authenticate_as(:'partner_id', 'aal2');
select throws_ok(format('select public.close_provisional(%L, %L)', :'e1_id', :'fy_id'), '23514', null, 'clôture provisoire refusée : états financiers en échec');
select tests.clear_auth();
update public.financial_statements set checks = (select jsonb_agg(c) from jsonb_array_elements(checks) c where (c->>'passed') <> 'false') where id = :'fs_id';
select tests.authenticate_as(:'partner_id', 'aal2');
select lives_ok(format('select public.close_provisional(%L, %L)', :'e1_id', :'fy_id'), 'clôture provisoire acceptée une fois les états en règle');
select tests.clear_auth();
update public.financial_statements set checks = checks || jsonb_build_array(jsonb_build_object('code', 'balance_sheet_equilibrium', 'label', 'Total actif net = total passif', 'passed', false)) where id = :'fs_id';
select tests.authenticate_as(:'partner_id', 'aal2');
select throws_ok(format('select public.close_final(%L, %L, ''ARRETER 2026'')', :'e1_id', :'fy_id'), '23514', null, 'arrêté définitif refusé : états financiers en échec');

select * from finish();
rollback;
