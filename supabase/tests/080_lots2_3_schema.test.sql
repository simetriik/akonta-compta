-- Schéma des lots 2 et 3 : présence des tables, contraintes clés, RLS et cloisonnement (§12.1 : schéma complet avant l'interface).
begin;
select plan(14);

select has_table('public', 'letterings', 'table letterings (lot 2)');
select has_table('public', 'bank_statements', 'table bank_statements (lot 2)');
select has_table('public', 'reconciliations', 'table reconciliations (lot 2)');
select has_table('public', 'fixed_assets', 'table fixed_assets (lot 3)');
select has_table('public', 'provisions', 'table provisions (lot 3)');
select has_table('public', 'accruals', 'table accruals (lot 3)');
select has_table('public', 'closing_checks', 'table closing_checks (lot 3)');
select has_table('public', 'statement_mappings', 'table statement_mappings versionnée (lot 3)');
select has_column('public', 'entry_lines', 'lettering_id', 'lignes d''écriture rattachables à un lettrage');

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('assist@a.test', :'a_id') as id \gset assist_
select tests.create_user('partner@b.test', :'b_id') as id \gset partnerb_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'partnerb_id', :'b_id', 'partner');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');

insert into public.fixed_assets (cabinet_id, entity_id, code, designation, asset_account_id, acquisition_date, service_date, gross_value, duration_months)
select :'a_id', :'e1_id', 'IMMO-001', 'Véhicule', id, '2026-03-01', '2026-03-01', 12000000, 60 from public.accounts where entity_id = :'e1_id' and code = '2451000';
select throws_ok(format('insert into public.fixed_assets (cabinet_id, entity_id, code, designation, asset_account_id, acquisition_date, service_date, gross_value, duration_months) select %L, %L, ''IMMO-002'', ''Négatif'', id, ''2026-03-01'', ''2026-03-01'', -5, 60 from public.accounts where entity_id = %L and code = ''2451000''', :'a_id', :'e1_id', :'e1_id'),
                 '23514', null, 'valeur brute strictement positive');
select throws_ok(format('insert into public.closing_checks (cabinet_id, entity_id, fiscal_year_id, code, label, severity, status) select %L, %L, id, ''drafts_pending'', ''Brouillards'', ''blocking'', ''waived'' from public.fiscal_years where entity_id = %L', :'a_id', :'e1_id', :'e1_id'),
                 '23514', null, 'un contrôle bloquant ne se lève pas');

select tests.authenticate_as(:'assist_id');
select is((select count(*) from public.fixed_assets), 1::bigint, 'assistant : lit les immobilisations de son dossier');
select throws_ok(format('insert into public.closing_archives (cabinet_id, entity_id, fiscal_year_id, manifest, hash) select %L, %L, id, ''{}'', ''x'' from public.fiscal_years where entity_id = %L', :'a_id', :'e1_id', :'e1_id'),
                 '42501', null, 'assistant : n''archive pas une clôture (arrêté définitif réservé à l''associé)');
select tests.authenticate_as(:'partnerb_id', 'aal2');
select is((select count(*) from public.fixed_assets), 0::bigint, 'cabinet B : aucune immobilisation du cabinet A');
select tests.clear_auth();

select * from finish();
rollback;
