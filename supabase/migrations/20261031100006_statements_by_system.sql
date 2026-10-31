-- États financiers par référentiel (décision D-024) : la version des correspondances suit le référentiel de l'entité
-- (SYSCOHADA-2017 pour le système normal, SYCEBNL-2024 pour les entités à but non lucratif) et le résultat net implicite
-- du bilan porte le code de poste de sa version (CJ pour le SYSCOHADA, CH pour le SYCEBNL).

create or replace function public.statement_version(p_entity uuid)
returns text language sql stable as $$
  select case e.accounting_system when 'sycebnl' then 'SYCEBNL-2024' else 'SYSCOHADA-2017' end from public.entities e where e.id = p_entity;
$$;

create or replace function public.statement_result_post(p_version text)
returns text language sql immutable as $$ select case p_version when 'SYCEBNL-2024' then 'CH' else 'CJ' end; $$;

-- Résultat net implicite tant que les comptes 13x ne le portent pas (poste du résultat selon la version).
create or replace function public.statement_posts_full(p_entity uuid, p_fiscal_year uuid, p_statement public.statement_kind, p_version text default 'SYSCOHADA-2017')
returns table (post_code text, post_label text, column_role text, amount bigint, sort_order smallint)
language sql stable as $$
  select * from public.statement_posts(p_entity, p_fiscal_year, p_statement, p_version)
   where post_code <> public.statement_result_post(p_version) or p_statement <> 'balance_sheet_liabilities'
  union all
  select public.statement_result_post(p_version), 'Résultat net de l''exercice', 'amount',
         (select -coalesce(sum(b.balance), 0) from public.statement_balances(p_entity, p_fiscal_year) b where left(b.account_code, 1) in ('6', '7', '8'))::bigint,
         (case p_version when 'SYCEBNL-2024' then 70 else 80 end)::smallint
   where p_statement = 'balance_sheet_liabilities'
  order by 5, 3;
$$;

-- Génération des états : la version par défaut est celle du référentiel de l'entité.
create or replace function public.generate_financial_statements(p_entity uuid, p_fiscal_year uuid, p_version text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_prev uuid; v_cabinet uuid; v_data jsonb; v_checks jsonb := '[]'::jsonb; v_id uuid;
        v_assets_net bigint; v_liab bigint; v_result_cr bigint; v_tax bigint; v_version text;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'statements.generate') then
    raise exception 'Permission refusée : générer les états financiers' using errcode = '42501';
  end if;
  v_version := coalesce(p_version, public.statement_version(p_entity));
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  select cabinet_id into v_cabinet from public.entities where id = p_entity;
  select id into v_prev from public.fiscal_years where entity_id = p_entity and end_date = v_fy.start_date - 1;
  v_data := jsonb_build_object(
    'assets', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order, p.column_role), '[]'::jsonb) from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_assets', v_version) p),
    'liabilities', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order), '[]'::jsonb) from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_liabilities', v_version) p),
    'income', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order), '[]'::jsonb) from public.statement_posts_full(p_entity, p_fiscal_year, 'income_statement', v_version) p),
    'previous', case when v_prev is null then null else jsonb_build_object(
        'assets', (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.statement_posts_full(p_entity, v_prev, 'balance_sheet_assets', v_version) p),
        'liabilities', (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.statement_posts_full(p_entity, v_prev, 'balance_sheet_liabilities', v_version) p),
        'income', (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.statement_posts_full(p_entity, v_prev, 'income_statement', v_version) p)) end);
  select coalesce(sum(case when column_role = 'depreciation' then -amount else amount end), 0) into v_assets_net from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_assets', v_version);
  select coalesce(sum(amount), 0) into v_liab from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_liabilities', v_version);
  select coalesce(sum(amount), 0) into v_result_cr from public.statement_posts_full(p_entity, p_fiscal_year, 'income_statement', v_version);
  select coalesce(sum(balance), 0) into v_tax from public.statement_balances(p_entity, p_fiscal_year) where left(account_code, 2) = '89';   -- hors écriture de résultat
  v_checks := v_checks || jsonb_build_object('code', 'balance_sheet_equilibrium', 'label', 'Total actif net = total passif (résultat inclus)',
                 'passed', v_assets_net = v_liab, 'assets', v_assets_net, 'liabilities', v_liab);
  v_checks := v_checks || jsonb_build_object('code', 'income_vs_ledger', 'label', 'Résultat du compte de résultat = résultat comptable après impôt du grand livre',
                 'passed', v_result_cr = public.accounting_result(p_entity, p_fiscal_year) - v_tax, 'income_result', v_result_cr);
  insert into public.financial_statements (cabinet_id, entity_id, fiscal_year_id, mapping_version, generated_by, data, checks)
  values (v_cabinet, p_entity, p_fiscal_year, v_version, auth.uid(), v_data, v_checks) returning id into v_id;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_cabinet, auth.uid(), 'statements', 'financial_statements', v_id::text, p_entity, jsonb_build_object('fiscal_year', v_fy.label, 'checks', v_checks));
  return v_id;
end $$;

grant execute on function public.statement_version(uuid), public.statement_result_post(text) to authenticated;
