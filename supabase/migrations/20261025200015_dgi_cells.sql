-- =============================================================================
-- Akonta — Migration 0015 : cellules de la liasse DGI et ajustements des états (module 9, §10.9)
-- `dgi_cells` : valeurs à écrire dans le modèle Excel (postes N et N-1, identification) ;
-- résultat net au passif (CJ) même avant l''écriture de détermination ; correction DQ / DR.
-- =============================================================================

-- Trésorerie-passif selon la liasse : DQ = crédits d''escompte (565) ; DR = banques, établissements financiers et crédits de trésorerie (56 hors 565, découverts 52-55)
delete from public.statement_mappings where cabinet_id is null and version = 'SYSCOHADA-2017' and post_code in ('DQ', 'DR');
insert into public.statement_mappings (cabinet_id, version, statement, post_code, post_label, account_from, account_to, balance_side, sign, column_role, sort_order) values
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DQ', 'Banques, crédits d''escompte', '565', '565', 'credit', 1, 'amount', 190),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DR', 'Banques, établissements financiers et crédits de trésorerie', '561', '564', 'credit', 1, 'amount', 195),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DR', 'Banques, établissements financiers et crédits de trésorerie', '566', '569', 'credit', 1, 'amount', 195),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DR', 'Banques, établissements financiers et crédits de trésorerie', '52', '55', 'credit', 1, 'amount', 195),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DB', 'Dettes de location-acquisition', '17', '17', 'any', 1, 'amount', 112);
update public.statement_mappings set account_to = '16' where cabinet_id is null and version = 'SYSCOHADA-2017' and post_code = 'DA';
insert into public.statement_mappings (cabinet_id, version, statement, post_code, post_label, account_from, account_to, balance_side, sign, column_role, sort_order) values
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DA', 'Emprunts et dettes financières diverses', '18', '18', 'any', 1, 'amount', 110);

-- Postes avec résultat net implicite : tant que les comptes 13x ne portent pas le résultat (écriture de détermination
-- non validée), le poste CJ reçoit le résultat net du compte de résultat.
create or replace function public.statement_posts_full(p_entity uuid, p_fiscal_year uuid, p_statement public.statement_kind, p_version text default 'SYSCOHADA-2017')
returns table (post_code text, post_label text, column_role text, amount bigint, sort_order smallint)
language sql stable as $$
  select * from public.statement_posts(p_entity, p_fiscal_year, p_statement, p_version)
  union all
  select 'CJ', 'Résultat net de l''exercice', 'amount',
         (select -coalesce(sum(b.balance), 0) from public.closing_balances(p_entity, p_fiscal_year) b where left(b.account_code, 1) in ('6', '7', '8'))::bigint, 80::smallint
   where p_statement = 'balance_sheet_liabilities'
     and not exists (select 1 from public.statement_posts(p_entity, p_fiscal_year, p_statement, p_version) sp where sp.post_code = 'CJ' and sp.amount <> 0)
     and (select coalesce(sum(b.balance), 0) from public.closing_balances(p_entity, p_fiscal_year) b where left(b.account_code, 1) in ('6', '7', '8')) <> 0
  order by 5, 3;
$$;

create or replace function public.generate_financial_statements(p_entity uuid, p_fiscal_year uuid, p_version text default 'SYSCOHADA-2017')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_prev uuid; v_cabinet uuid; v_data jsonb; v_checks jsonb := '[]'::jsonb; v_id uuid;
        v_assets_net bigint; v_liab bigint; v_result_cr bigint; v_tax bigint;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'statements.generate') then
    raise exception 'Permission refusée : générer les états financiers' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  select cabinet_id into v_cabinet from public.entities where id = p_entity;
  select id into v_prev from public.fiscal_years where entity_id = p_entity and end_date = v_fy.start_date - 1;
  v_data := jsonb_build_object(
    'assets', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order, p.column_role), '[]'::jsonb) from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_assets', p_version) p),
    'liabilities', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order), '[]'::jsonb) from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_liabilities', p_version) p),
    'income', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order), '[]'::jsonb) from public.statement_posts_full(p_entity, p_fiscal_year, 'income_statement', p_version) p),
    'previous', case when v_prev is null then null else jsonb_build_object(
        'assets', (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.statement_posts_full(p_entity, v_prev, 'balance_sheet_assets', p_version) p),
        'liabilities', (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.statement_posts_full(p_entity, v_prev, 'balance_sheet_liabilities', p_version) p),
        'income', (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.statement_posts_full(p_entity, v_prev, 'income_statement', p_version) p)) end);
  select coalesce(sum(case when column_role = 'depreciation' then -amount else amount end), 0) into v_assets_net from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_assets', p_version);
  select coalesce(sum(amount), 0) into v_liab from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_liabilities', p_version);
  select coalesce(sum(amount), 0) into v_result_cr from public.statement_posts_full(p_entity, p_fiscal_year, 'income_statement', p_version);
  select coalesce(sum(debit - credit), 0) into v_tax from public.ledger_lines where entity_id = p_entity and fiscal_year_id = p_fiscal_year and left(account_code, 2) = '89';
  v_checks := v_checks || jsonb_build_object('code', 'balance_sheet_equilibrium', 'label', 'Total actif net = total passif (résultat inclus)',
                 'passed', v_assets_net = v_liab, 'assets', v_assets_net, 'liabilities', v_liab);
  v_checks := v_checks || jsonb_build_object('code', 'income_vs_ledger', 'label', 'Résultat du compte de résultat = résultat comptable après impôt du grand livre',
                 'passed', v_result_cr = public.accounting_result(p_entity, p_fiscal_year) - v_tax, 'income_result', v_result_cr);
  insert into public.financial_statements (cabinet_id, entity_id, fiscal_year_id, mapping_version, generated_by, data, checks)
  values (v_cabinet, p_entity, p_fiscal_year, p_version, auth.uid(), v_data, v_checks) returning id into v_id;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_cabinet, auth.uid(), 'statements', 'financial_statements', v_id::text, p_entity, jsonb_build_object('fiscal_year', v_fy.label, 'checks', v_checks));
  return v_id;
end $$;

-- Cellules à écrire dans la liasse DGI : états financiers les plus récents de l''exercice (N) et de l''exercice précédent (N-1),
-- champs d''identification de l''entité ; les cellules cartographiées sans valeur sont renvoyées vides (effacement des exemples du modèle).
create or replace function public.dgi_cells(p_entity uuid, p_fiscal_year uuid, p_version text default 'SN-2025')
returns table (sheet text, cell text, value text)
language plpgsql stable security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_prev public.fiscal_years%rowtype; e public.entities%rowtype; v_fs jsonb; d record;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'statements.generate') then
    raise exception 'Permission refusée : générer les états financiers' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  select * into v_prev from public.fiscal_years where entity_id = p_entity and end_date = v_fy.start_date - 1;
  select * into e from public.entities where id = p_entity;
  select data into v_fs from public.financial_statements where fiscal_year_id = p_fiscal_year order by generated_at desc limit 1;
  if v_fs is null then raise exception 'Générer les états financiers avant la liasse DGI' using errcode = '23514'; end if;
  select full_name, position, address into d from public.entity_directors where entity_id = p_entity order by sort_order, created_at limit 1;
  return query
  with posts as (
    select 'N' as yr, x->>'post_code' as code, x->>'column_role' as role, (x->>'amount')::bigint as amount from jsonb_array_elements(v_fs->'assets') x
    union all select 'N', x->>'post_code', 'amount', (x->>'amount')::bigint from jsonb_array_elements(v_fs->'liabilities') x
    union all select 'N', x->>'post_code', 'amount', (x->>'amount')::bigint from jsonb_array_elements(v_fs->'income') x
    union all select 'N-1', x->>'post_code', x->>'column_role', (x->>'amount')::bigint from jsonb_array_elements(coalesce(v_fs->'previous'->'assets', '[]'::jsonb)) x
    union all select 'N-1', x->>'post_code', 'amount', (x->>'amount')::bigint from jsonb_array_elements(coalesce(v_fs->'previous'->'liabilities', '[]'::jsonb)) x
    union all select 'N-1', x->>'post_code', 'amount', (x->>'amount')::bigint from jsonb_array_elements(coalesce(v_fs->'previous'->'income', '[]'::jsonb)) x
  ), by_post as (
    select yr, code, sum(amount) filter (where role = 'gross') as gross, sum(amount) filter (where role = 'depreciation') as dep, sum(amount) filter (where role = 'amount') as amt
      from posts group by yr, code
  )
  select m.sheet_name, m.cell_ref,
         case
           when m.field_code is not null then
             case m.field_code
               when 'fiscal_year.start_date' then to_char(v_fy.start_date, 'DD/MM/YYYY')
               when 'fiscal_year.end_date' then to_char(v_fy.end_date, 'DD/MM/YYYY')
               when 'previous_year.end_date' then to_char(v_prev.end_date, 'DD/MM/YYYY')
               when 'previous_year.months' then case when v_prev.id is null then null else ((extract(year from v_prev.end_date) - extract(year from v_prev.start_date)) * 12 + extract(month from v_prev.end_date) - extract(month from v_prev.start_date) + 1)::int::text end
               when 'entity.registry_office' then case when e.country_code = 'BJ' then 'RB' else e.country_code end
               when 'entity.trade_register' then e.trade_register
               when 'entity.tax_id' then e.tax_id
               when 'entity.activity_code' then e.activity_code
               when 'entity.address' then e.address
               when 'entity.legal_form' then e.legal_form
               when 'entity.tax_regime' then e.tax_regime
               when 'entity.country' then case when e.country_code = 'BJ' then 'Bénin' else e.country_code end
               when 'entity.establishments_count' then e.establishments_count::text
               when 'entity.incorporation_year' then to_char(e.incorporation_date, 'YYYY')
               when 'entity.control' then case when e.control_type = 'public' then 'Entité sous contrôle public' when e.control_origin = 'foreign' then 'Entité sous contrôle privé étranger' when e.control_type = 'private' then 'Entité sous contrôle privé national' end
               when 'director.name' then d.full_name
               when 'director.address' then d.address
               when 'director.position' then d.position
             end
           when m.column_role = 'gross' then coalesce(b.gross, 0)::text
           when m.column_role = 'depreciation' then coalesce(b.dep, 0)::text
           when m.column_role = 'net' and m.sheet_name = 'BILAN' and m.cell_ref ~ '^[FGHI]' then (coalesce(b.gross, 0) - coalesce(b.dep, 0))::text   -- actif : net N-1
           when m.column_role in ('net', 'amount') then coalesce(b.amt, 0)::text
         end
    from public.dgi_cell_mappings m
    left join by_post b on b.code = m.post_code and b.yr = m.column_year
   where m.version = p_version
   order by m.sheet_name, m.cell_ref;
end $$;

grant execute on function public.statement_posts_full(uuid, uuid, public.statement_kind, text), public.dgi_cells(uuid, uuid, text) to authenticated;
