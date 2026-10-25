-- =============================================================================
-- Akonta — Migration 0018 : états financiers et résultat comptable calculés hors écriture de
-- détermination du résultat.
-- L'écriture « 6/7/8 → 13 » (generated_source 'result:<exercice>') solde les comptes de gestion :
-- après sa validation, le compte de résultat généré était vide et le contrôle « résultat du compte
-- de résultat = résultat comptable » ne pouvait plus être satisfait. Elle n'est pas une opération
-- de l'exercice : les états et le résultat comptable l'ignorent ; le résultat net du bilan (poste CJ)
-- est alors porté soit par les comptes 13x (écriture validée), soit implicitement (statement_posts_full).
-- =============================================================================

-- Soldes servant aux états financiers : écriture de détermination du résultat exclue.
create or replace function public.statement_balances(p_entity uuid, p_fiscal_year uuid)
returns table (account_code text, balance bigint)
language sql stable as $$
  select l.account_code, (sum(l.debit) - sum(l.credit))::bigint
    from public.ledger_lines l
    join public.entries e on e.id = l.entry_id
   where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year
     and coalesce(e.generated_source, '') not like 'result:%'
   group by l.account_code having sum(l.debit) - sum(l.credit) <> 0;
$$;

-- Résultat comptable (produits - charges, impôt 89 exclu) : même exclusion.
create or replace function public.accounting_result(p_entity uuid, p_fiscal_year uuid, p_as_of date default null)
returns bigint language sql stable as $$
  select coalesce(sum(case when l.account_class = 7 or left(l.account_code, 2) in ('82', '84', '86', '88') then l.credit - l.debit
                           when l.account_class = 6 or left(l.account_code, 2) in ('81', '83', '85', '87') then -(l.debit - l.credit) else 0 end), 0)::bigint
    from public.ledger_lines l
    join public.entries e on e.id = l.entry_id
    join public.fiscal_years fy on fy.id = p_fiscal_year
   where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year and l.entry_date <= coalesce(p_as_of, fy.end_date)
     and coalesce(e.generated_source, '') not like 'result:%';
$$;

-- Postes d'un état (même logique que la version 0013, sur statement_balances).
create or replace function public.statement_posts(p_entity uuid, p_fiscal_year uuid, p_statement public.statement_kind, p_version text default 'SYSCOHADA-2017')
returns table (post_code text, post_label text, column_role text, amount bigint, sort_order smallint)
language sql stable as $$
  with bal as (select * from public.statement_balances(p_entity, p_fiscal_year)),
  maps as (
    select m.* from public.statement_mappings m
     where m.version = p_version and m.statement = p_statement
       and (m.cabinet_id is null or m.cabinet_id = (select cabinet_id from public.entities where id = p_entity))
  ),
  matched as (
    select m.post_code, m.post_label, m.column_role, m.sort_order,
           sum(case when (m.balance_side = 'debit' and b.balance < 0) or (m.balance_side = 'credit' and b.balance > 0) then 0 else b.balance end) as amt
      from maps m
      join bal b on left(b.account_code, length(m.account_from)) >= m.account_from and left(b.account_code, length(m.account_to)) <= m.account_to
     group by m.post_code, m.post_label, m.column_role, m.sort_order
  )
  select post_code, post_label, column_role,
         case p_statement
           when 'balance_sheet_assets' then case when column_role = 'depreciation' then abs(amt) else amt end
           else -amt end::bigint,
         sort_order
    from matched
   order by sort_order, column_role;
$$;

-- Résultat net implicite (poste CJ) tant que les comptes 13x ne le portent pas.
create or replace function public.statement_posts_full(p_entity uuid, p_fiscal_year uuid, p_statement public.statement_kind, p_version text default 'SYSCOHADA-2017')
returns table (post_code text, post_label text, column_role text, amount bigint, sort_order smallint)
language sql stable as $$
  select * from public.statement_posts(p_entity, p_fiscal_year, p_statement, p_version)
  union all
  select 'CJ', 'Résultat net de l''exercice', 'amount',
         (select -coalesce(sum(b.balance), 0) from public.statement_balances(p_entity, p_fiscal_year) b where left(b.account_code, 1) in ('6', '7', '8'))::bigint, 80::smallint
   where p_statement = 'balance_sheet_liabilities'
     and not exists (select 1 from public.statement_posts(p_entity, p_fiscal_year, p_statement, p_version) sp where sp.post_code = 'CJ' and sp.amount <> 0)
     and (select coalesce(sum(b.balance), 0) from public.statement_balances(p_entity, p_fiscal_year) b where left(b.account_code, 1) in ('6', '7', '8')) <> 0
  order by 5, 3;
$$;

grant execute on function public.statement_balances(uuid, uuid) to authenticated;

-- Génération des états : l'impôt (89) est lu hors écriture de résultat, comme le reste.
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
  select coalesce(sum(balance), 0) into v_tax from public.statement_balances(p_entity, p_fiscal_year) where left(account_code, 2) = '89';   -- hors écriture de résultat
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
