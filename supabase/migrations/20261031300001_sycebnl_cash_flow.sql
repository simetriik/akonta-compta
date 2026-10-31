-- Tableau des flux de trésorerie SYCEBNL, méthode directe (décision D-027).
-- Le texte officiel (partie 4, p. 348) donne les lignes FA à FQ mais aucune correspondance comptes → flux : la règle de classement
-- ci-dessous est celle du dépôt, à faire valider par ABC (Q-020). Principe : pour chaque écriture validée de l'exercice qui touche la
-- trésorerie (comptes 50 à 57), chaque ligne de contrepartie (hors trésorerie et hors virements internes 58) apporte au flux son montant
-- signé (crédit - débit) ; comme l'écriture est équilibrée, la somme des contreparties égale la variation de trésorerie de l'écriture.
-- Sont exclues les écritures d'à-nouveaux (ouverture) et de détermination du résultat.

-- Poste du tableau des flux pour un compte de contrepartie et le montant signé (crédit - débit) de sa ligne.
create or replace function public.cash_flow_post(p_code text, p_amount bigint)
returns text language sql immutable as $$
  select case
    when p_code ~ '^(14|4731)' then 'FN'                                   -- subventions d'investissement reçues
    when p_code ~ '^(71|88|473|4491)' then 'FB'                            -- subventions d'exploitation et d'équilibre
    when p_code ~ '^(701|411)' then 'FA'                                   -- cotisations (appelées ou directes)
    when p_code ~ '^(704|475)' then 'FC'                                   -- revenus liés à la générosité
    when p_code ~ '^706' then 'FD'                                         -- revenus des manifestations
    when p_code ~ '^(26|27|826)' then case when p_amount > 0 then 'FL' else 'FJ' end   -- immobilisations financières
    when p_code ~ '^(21|22|23|24|25|82|485)' then case when p_amount > 0 then 'FK' else 'FI' end   -- immobilisations incorporelles et corporelles
    when p_code ~ '^481' then 'FI'                                         -- fournisseurs d'investissements
    when p_code ~ '^(10|11|12|13|16|17|45|46)' then case when p_amount > 0 then 'FM' else 'FO' end   -- dotations, fonds, apporteurs
    when p_code ~ '^18' then case when p_amount > 0 then 'FP' else 'FQ' end   -- emprunts et dettes financières
    when p_code ~ '^(42|43|66)' then 'FG'                                  -- personnel et organismes sociaux
    when p_code ~ '^(40|60|61|62|63|3[1-8])' then 'FF'                     -- fournisseurs, achats, services, stocks
    when p_code ~ '^(64|65|67)' then 'FH'                                  -- impôts, autres charges, frais financiers
    when p_code ~ '^(7|84|86|41)' then 'FE'                                -- autres revenus et créances adhérents, clients-usagers
    else case when p_amount > 0 then 'FE' else 'FH' end
  end;
$$;

-- Lignes et totaux du tableau des flux d'un exercice (montants signés : encaissement +, décaissement -).
create or replace function public.cash_flow_posts(p_entity uuid, p_fiscal_year uuid)
returns table (post_code text, post_label text, column_role text, amount bigint, sort_order smallint)
language sql stable as $$
  with lines as (
    select l.entry_id, l.account_code, l.debit, l.credit, l.is_opening
      from public.ledger_lines l
      join public.entries e on e.id = l.entry_id
     where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year
       and coalesce(e.generated_source, '') not like 'result:%'
  ),
  cash_entries as (
    select distinct entry_id from lines where not is_opening and left(account_code, 2) between '50' and '57'
  ),
  flows as (
    select public.cash_flow_post(l.account_code, (l.credit - l.debit)::bigint) as post, sum(l.credit - l.debit)::bigint as amt
      from lines l join cash_entries c on c.entry_id = l.entry_id
     where left(l.account_code, 2) not between '50' and '58'
     group by 1
  ),
  opening as (
    select coalesce(sum(debit - credit), 0)::bigint as amt from lines where is_opening and left(account_code, 2) between '50' and '57'
  ),
  grid (code, label, ord) as (values
    ('FA', '+ Encaissement des cotisations', 20), ('FB', '+ Encaissement des subventions d''exploitation et d''équilibre', 30),
    ('FC', '+ Encaissement des revenus liés à la générosité', 40), ('FD', '+ Encaissement des revenus des manifestations', 50),
    ('FE', '+ Encaissement des autres revenus', 60), ('FF', '- Décaissement des sommes versées aux fournisseurs (hors fournisseurs d''investissements)', 70),
    ('FG', '- Décaissement des sommes versées au personnel', 80), ('FH', '- Autres décaissements', 90),
    ('FI', '- Décaissements liés aux acquisitions d''immobilisations incorporelles et corporelles', 110),
    ('FJ', '- Décaissements liés aux acquisitions d''immobilisations financières', 120),
    ('FK', '+ Encaissements liés aux cessions d''immobilisations incorporelles et corporelles', 130),
    ('FL', '+ Encaissements liés aux cessions d''immobilisations financières', 140),
    ('FM', '+ Encaissement des dotations et autres fonds propres', 160), ('FN', '+ Subventions d''investissement reçues', 170),
    ('FO', '- Décaissement des dotations et autres fonds propres', 180),
    ('FP', '+ Encaissement provenant des emprunts et des autres dettes financières', 200),
    ('FQ', '- Remboursements des emprunts et autres dettes financières', 210)
  ),
  lines_amounts as (
    select g.code, g.label, g.ord, coalesce(f.amt, 0)::bigint as amt from grid g left join flows f on f.post = g.code
  ),
  totals as (
    select
      (select amt from opening) as za,
      coalesce(sum(amt) filter (where code between 'FA' and 'FH'), 0)::bigint as zb,
      coalesce(sum(amt) filter (where code between 'FI' and 'FL'), 0)::bigint as zc,
      coalesce(sum(amt) filter (where code between 'FM' and 'FO'), 0)::bigint as zd,
      coalesce(sum(amt) filter (where code between 'FP' and 'FQ'), 0)::bigint as ze
    from lines_amounts
  )
  select x.code, x.label, 'amount', x.amt, x.ord::smallint from (
    select code, label, ord, amt from lines_amounts
    union all select 'ZA', 'Trésorerie nette au 1er janvier (trésorerie actif N-1 - trésorerie passif N-1)', 10, za from totals
    union all select 'ZB', 'Flux de trésorerie provenant des activités opérationnelles (somme FA à FH)', 100, zb from totals
    union all select 'ZC', 'Flux de trésorerie provenant des activités d''investissement (somme FI à FL)', 150, zc from totals
    union all select 'ZD', 'Flux de trésorerie provenant des fonds propres (somme FM à FO)', 190, zd from totals
    union all select 'ZE', 'Trésorerie provenant des fonds étrangers (somme FP à FQ)', 220, ze from totals
    union all select 'ZDE', 'Flux de trésorerie provenant des activités de financement (D+E)', 230, zd + ze from totals
    union all select 'ZF', 'Variation de la trésorerie nette de la période (B+C+D+E)', 240, zb + zc + zd + ze from totals
    union all select 'ZG', 'Trésorerie nette au 31 décembre (variation + trésorerie au 1er janvier)', 250, za + zb + zc + zd + ze from totals
  ) x order by x.ord;
$$;

grant execute on function public.cash_flow_post(text, bigint), public.cash_flow_posts(uuid, uuid) to authenticated;

-- Génération des états : le tableau des flux et ses contrôles s'ajoutent pour le référentiel SYCEBNL.
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
