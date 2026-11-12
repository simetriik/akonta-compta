-- Résultat comptable, soldes des états et flux de trésorerie : la contre-passation de l'écriture de détermination du résultat
-- est ignorée comme l'écriture elle-même. Sinon, après « contre-passer le résultat puis le régénérer » (réouverture de
-- l'exercice), les comptes de gestion étaient comptés deux fois dans le résultat comptable (recette du 12/11/2026, AN-35).

CREATE OR REPLACE FUNCTION public.accounting_result(p_entity uuid, p_fiscal_year uuid, p_as_of date DEFAULT NULL::date)
 RETURNS bigint
 LANGUAGE sql
 STABLE
AS $function$
  select coalesce(sum(case when l.account_class = 7 or left(l.account_code, 2) in ('82', '84', '86', '88') then l.credit - l.debit
                           when l.account_class = 6 or left(l.account_code, 2) in ('81', '83', '85', '87') then -(l.debit - l.credit) else 0 end), 0)::bigint
    from public.ledger_lines l
    join public.entries e on e.id = l.entry_id
    join public.fiscal_years fy on fy.id = p_fiscal_year
   where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year and l.entry_date <= coalesce(p_as_of, fy.end_date)
     and coalesce(e.generated_source, '') not like 'result:%'
     and not exists (select 1 from public.entries o where o.id = e.reversal_of and o.generated_source like 'result:%');
$function$;

CREATE OR REPLACE FUNCTION public.statement_balances(p_entity uuid, p_fiscal_year uuid)
 RETURNS TABLE(account_code text, balance bigint)
 LANGUAGE sql
 STABLE
AS $function$
  select l.account_code, (sum(l.debit) - sum(l.credit))::bigint
    from public.ledger_lines l
    join public.entries e on e.id = l.entry_id
   where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year
     and coalesce(e.generated_source, '') not like 'result:%'
     and not exists (select 1 from public.entries o where o.id = e.reversal_of and o.generated_source like 'result:%')
   group by l.account_code having sum(l.debit) - sum(l.credit) <> 0;
$function$;

CREATE OR REPLACE FUNCTION public.cash_flow_posts(p_entity uuid, p_fiscal_year uuid)
 RETURNS TABLE(post_code text, post_label text, column_role text, amount bigint, sort_order smallint)
 LANGUAGE sql
 STABLE
AS $function$
  with lines as (
    select l.entry_id, l.account_code, l.debit, l.credit, l.is_opening
      from public.ledger_lines l
      join public.entries e on e.id = l.entry_id
     where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year
       and coalesce(e.generated_source, '') not like 'result:%'
     and not exists (select 1 from public.entries o where o.id = e.reversal_of and o.generated_source like 'result:%')
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
$function$;

-- Retour arrière : recréer ces trois fonctions sans la clause « not exists » (voir 20261026090003, 20261031300001).
