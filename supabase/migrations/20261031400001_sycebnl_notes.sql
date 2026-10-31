-- Notes annexes SYCEBNL calculables depuis le grand livre (décision D-028).
-- Catalogue versionné des lignes de notes (comptes → lignes, totaux et sous-totaux), fonction de calcul `note_posts` et intégration aux états.
-- Seules les notes de type « libellé, année N, année N-1 » sont produites ; échéances, mouvements d'immobilisations et rubriques à saisie libre
-- ne le sont pas (Q-021).

create table public.statement_note_lines (
  id             uuid primary key default gen_random_uuid(),
  cabinet_id     uuid references public.cabinets (id) on delete cascade,      -- null = livré avec l'application
  version        text not null,
  note_code      text not null,
  note_title     text not null,
  line_code      text not null,
  label          text not null,
  kind           text not null check (kind in ('line', 'subtotal', 'total')),
  account_from   text,                        -- préfixe de début (ligne)
  account_to     text,                        -- préfixe de fin inclus (ligne)
  balance_side   text not null default 'any' check (balance_side in ('debit', 'credit', 'any')),
  sign           smallint not null default 1 check (sign in (-1, 1)),   -- 1 : solde débiteur positif ; -1 : solde créditeur positif
  sum_of         text,                        -- sous-total ou total : codes de lignes séparés par des virgules ; « - » devant un code = soustraction
  sort_order     integer not null,
  check ((kind = 'line' and account_from is not null and account_to is not null) or (kind <> 'line' and sum_of is not null))
);
comment on table public.statement_note_lines is 'Catalogue des notes annexes : lignes par plage de comptes et sens du solde, totaux, versionné (comme statement_mappings).';
create index statement_note_lines_version_idx on public.statement_note_lines (version, note_code, sort_order);
alter table public.statement_note_lines enable row level security;
create policy statement_note_lines_select on public.statement_note_lines for select to authenticated using (cabinet_id is null or cabinet_id = public.current_cabinet_id());
create policy statement_note_lines_write on public.statement_note_lines for all to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'cabinet.settings'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'cabinet.settings'));

-- Lignes, sous-totaux et totaux des notes d'un exercice (montants en FCFA, signe selon le sens retenu pour chaque ligne).
create or replace function public.note_posts(p_entity uuid, p_fiscal_year uuid, p_version text default null)
returns table (note_code text, note_title text, line_code text, label text, kind text, amount bigint, sort_order integer)
language plpgsql stable set search_path = public as $$
declare
  v_version text := coalesce(p_version, public.statement_version(p_entity));
  v_cabinet uuid := (select e.cabinet_id from public.entities e where e.id = p_entity);
  r record; v_amounts jsonb := '{}'::jsonb; v_total bigint; v_code text; v_neg boolean;
begin
  for r in
    with bal as (select b.account_code, b.balance from public.statement_balances(p_entity, p_fiscal_year) b)
    select n.note_code, n.note_title, n.line_code, n.label, n.kind, n.sum_of, min(n.sort_order) as ord,
           coalesce(sum(case when n.kind = 'line' then n.sign * x.amt end), 0)::bigint as amt
      from public.statement_note_lines n
      left join lateral (
        select sum(case when (n.balance_side = 'debit' and b.balance < 0) or (n.balance_side = 'credit' and b.balance > 0) then 0 else b.balance end) as amt
          from bal b
         where n.kind = 'line' and left(b.account_code, length(n.account_from)) >= n.account_from and left(b.account_code, length(n.account_to)) <= n.account_to
      ) x on true
     where n.version = v_version and (n.cabinet_id is null or n.cabinet_id = v_cabinet)
     group by n.note_code, n.note_title, n.line_code, n.label, n.kind, n.sum_of
     order by min(n.sort_order)
  loop
    if r.kind = 'line' then
      v_total := r.amt;
    else
      v_total := 0;
      foreach v_code in array string_to_array(r.sum_of, ',') loop
        v_neg := left(v_code, 1) = '-';
        v_total := v_total + case when v_neg then -1 else 1 end * coalesce((v_amounts ->> case when v_neg then substr(v_code, 2) else v_code end)::bigint, 0);
      end loop;
    end if;
    v_amounts := v_amounts || jsonb_build_object(r.line_code, v_total);
    note_code := r.note_code; note_title := r.note_title; line_code := r.line_code; label := r.label; kind := r.kind; amount := v_total; sort_order := r.ord;
    return next;
  end loop;
end $$;
grant execute on function public.note_posts(uuid, uuid, text) to authenticated;

-- Génération des états : les notes annexes calculables s'ajoutent pour le référentiel SYCEBNL.
create or replace function public.generate_financial_statements(p_entity uuid, p_fiscal_year uuid, p_version text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_prev uuid; v_cabinet uuid; v_data jsonb; v_checks jsonb := '[]'::jsonb; v_id uuid;
        v_assets_net bigint; v_liab bigint; v_result_cr bigint; v_tax bigint; v_version text; v_cash_close bigint; v_cash_sheet bigint;
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
  -- Tableau des flux de trésorerie (SYCEBNL) : N et, s'il existe, N-1
  if v_version = 'SYCEBNL-2024' then
    v_data := v_data || jsonb_build_object('cash_flow', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order), '[]'::jsonb) from public.cash_flow_posts(p_entity, p_fiscal_year) p));
    -- Notes annexes calculables : montants de N et de N-1 (null si aucun exercice précédent)
    v_data := v_data || jsonb_build_object('notes', (
      select coalesce(jsonb_agg(jsonb_build_object('note_code', n.note_code, 'note_title', n.note_title, 'line_code', n.line_code, 'label', n.label,
                                                   'kind', n.kind, 'amount', n.amount, 'previous', case when v_prev is null then null else p.amount end,
                                                   'sort_order', n.sort_order) order by n.sort_order), '[]'::jsonb)
        from public.note_posts(p_entity, p_fiscal_year) n
        left join public.note_posts(p_entity, v_prev) p on p.line_code = n.line_code));
    if v_prev is not null then
      v_data := jsonb_set(v_data, '{previous,cash_flow}', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order), '[]'::jsonb) from public.cash_flow_posts(p_entity, v_prev) p));
    end if;
  end if;
  select coalesce(sum(case when column_role = 'depreciation' then -amount else amount end), 0) into v_assets_net from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_assets', v_version);
  select coalesce(sum(amount), 0) into v_liab from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_liabilities', v_version);
  select coalesce(sum(amount), 0) into v_result_cr from public.statement_posts_full(p_entity, p_fiscal_year, 'income_statement', v_version);
  select coalesce(sum(balance), 0) into v_tax from public.statement_balances(p_entity, p_fiscal_year) where left(account_code, 2) = '89';   -- hors écriture de résultat
  v_checks := v_checks || jsonb_build_object('code', 'balance_sheet_equilibrium', 'label', 'Total actif net = total passif (résultat inclus)',
                 'passed', v_assets_net = v_liab, 'assets', v_assets_net, 'liabilities', v_liab);
  v_checks := v_checks || jsonb_build_object('code', 'income_vs_ledger', 'label', 'Résultat du compte de résultat = résultat comptable après impôt du grand livre',
                 'passed', v_result_cr = public.accounting_result(p_entity, p_fiscal_year) - v_tax, 'income_result', v_result_cr);
  if v_version = 'SYCEBNL-2024' then
    select coalesce(sum(balance), 0) into v_cash_close from public.statement_balances(p_entity, p_fiscal_year) where left(account_code, 2) between '50' and '57';
    select coalesce(sum(case when p.column_role = 'depreciation' then -p.amount else p.amount end), 0) into v_cash_sheet
      from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_assets', v_version) p where p.post_code in ('BU', 'BV', 'BW');
    v_cash_sheet := v_cash_sheet - coalesce((select sum(p.amount) from public.statement_posts_full(p_entity, p_fiscal_year, 'balance_sheet_liabilities', v_version) p where p.post_code = 'DW'), 0);
    v_checks := v_checks || jsonb_build_object('code', 'cash_flow_vs_ledger', 'label', 'Trésorerie du tableau des flux = trésorerie des comptes 50 à 57 du grand livre',
                   'passed', (select amount from public.cash_flow_posts(p_entity, p_fiscal_year) where post_code = 'ZG') = v_cash_close, 'ledger', v_cash_close);
    v_checks := v_checks || jsonb_build_object('code', 'cash_flow_vs_balance_sheet', 'label', 'Trésorerie du tableau des flux = trésorerie du bilan (actif - passif)',
                   'passed', (select amount from public.cash_flow_posts(p_entity, p_fiscal_year) where post_code = 'ZG') = v_cash_sheet, 'balance_sheet', v_cash_sheet);
  end if;
  insert into public.financial_statements (cabinet_id, entity_id, fiscal_year_id, mapping_version, generated_by, data, checks)
  values (v_cabinet, p_entity, p_fiscal_year, v_version, auth.uid(), v_data, v_checks) returning id into v_id;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_cabinet, auth.uid(), 'statements', 'financial_statements', v_id::text, p_entity, jsonb_build_object('fiscal_year', v_fy.label, 'checks', v_checks));
  return v_id;
end $$;
