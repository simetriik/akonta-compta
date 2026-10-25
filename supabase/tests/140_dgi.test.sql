-- Liasse DGI : cartographie versionnée des cellules et valeurs produites depuis les états financiers (§10.9, D-012).
begin;
select plan(8);

select ok((select count(*) from public.dgi_cell_mappings where version = 'SN-2025') > 200, 'cartographie SN-2025 chargée (> 200 cellules)');
select is((select sheet_name || '!' || cell_ref from public.dgi_cell_mappings where version = 'SN-2025' and post_code = 'BS' and column_role = 'gross' and column_year = 'N'), 'BILAN!F36', 'trésorerie-actif brut N → BILAN!F36');
select is((select sheet_name || '!' || cell_ref from public.dgi_cell_mappings where version = 'SN-2025' and post_code = 'DJ' and column_year = 'N'), 'BILAN!M29', 'fournisseurs N → BILAN!M29 (suivi du renvoi PASSIF → BILAN)');
select is((select count(*) from public.dgi_cell_mappings where version = 'SN-2025' and post_code = 'AD'), 0::bigint, 'les totaux (AD = somme) ne sont pas cartographiés : formules du modèle');

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('manager@a.test', :'a_id') as id \gset manager_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
update public.entities set tax_id = '3202600000011', trade_register = 'RB/COT/20 B 1234', legal_form = 'SARL' where id = :'e1_id';
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'e1_id' \gset fy_
select public.create_journals_from_template(:'e1_id', null);
select tests.make_entry(:'e1_id', 'AN', '2026-01-01', 'AN', '[{"account":"5210000","debit":10000000},{"account":"1011000","credit":10000000}]', :'manager_id') as id \gset an_
select tests.make_entry(:'e1_id', 'OD', '2026-03-10', 'Vente', '[{"account":"4710000","debit":1000000},{"account":"7011000","credit":1000000}]', :'manager_id') as id \gset v_
select public.validate_entries(array[:'an_id', :'v_id']::uuid[]);
select tests.authenticate_as(:'manager_id');
select throws_ok(format('select * from public.dgi_cells(%L, %L)', :'e1_id', :'fy_id'), '23514', null, 'liasse refusée tant que les états ne sont pas générés');
select public.generate_financial_statements(:'e1_id', :'fy_id');
select is((select amount from public.statement_posts_full(:'e1_id', :'fy_id', 'balance_sheet_liabilities') where post_code = 'CJ'), 1000000::bigint, 'résultat net implicite au passif (CJ) avant l''écriture de détermination');
select is((select value from public.dgi_cells(:'e1_id', :'fy_id') where sheet = 'BILAN' and cell = 'F36'), '10000000', 'cellule BILAN!F36 = trésorerie 10 000 000');
select is((select value from public.dgi_cells(:'e1_id', :'fy_id') where sheet = 'FICHE R1' and cell = 'K14'), '3202600000011', 'IFU dans la fiche R1');
select tests.clear_auth();

select * from finish();
rollback;
