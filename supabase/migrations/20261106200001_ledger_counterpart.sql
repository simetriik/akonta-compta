-- Recette du 05/11/2026, point 2 : colonne « Contrepartie » du grand livre, et nom du tiers.
-- Pour chaque ligne : les comptes de l'écriture portés dans le sens opposé. Contrepartie principale selon la règle du cabinet
-- (provisoire, à valider par la collaboratrice senior) :
--   largest_opposite (défaut) : le compte opposé au montant le plus élevé, ex à égalité le plus petit numéro de compte ;
--   lowest_account            : le plus petit numéro de compte opposé.
-- Plusieurs lignes sur un même compte opposé comptent pour un seul compte (leurs montants s'additionnent).
-- Ajoute aussi le nom du tiers (le code seul n'était pas lisible dans les exports). Aucune donnée n'est modifiée.

alter table public.cabinets add column ledger_counterpart_rule text not null default 'largest_opposite'
  check (ledger_counterpart_rule in ('largest_opposite', 'lowest_account'));
comment on column public.cabinets.ledger_counterpart_rule is 'Règle de la contrepartie principale du grand livre (provisoire, paramétrable).';

drop function public.general_ledger(uuid, date, date, text, text, uuid);

create function public.general_ledger(p_entity uuid, p_from date, p_to date,
                                      p_account_from text default null, p_account_to text default null,
                                      p_third_party uuid default null)
returns table (account_id uuid, account_code text, account_label text, entry_id uuid, line_id uuid, entry_date date,
               journal_code text, number bigint, reference text, label text, third_party_code text,
               debit bigint, credit bigint, running_balance bigint, letter_code text,
               third_party_name text, counterpart_code text, counterpart_more integer, counterparts jsonb)
language plpgsql stable as $$
declare
  v_fy uuid;
  v_rule text;
begin
  perform public.require_ledger_read(p_entity);
  select id into v_fy from public.fiscal_years where entity_id = p_entity and p_from between start_date and end_date;
  select c.ledger_counterpart_rule into v_rule from public.entities e join public.cabinets c on c.id = e.cabinet_id where e.id = p_entity;
  return query
  with opening as (
    select l.account_id, sum(l.debit) - sum(l.credit) as balance
      from public.ledger_lines l
     where l.entity_id = p_entity and l.fiscal_year_id = v_fy and l.entry_date < p_from
       and (p_account_from is null or l.account_code >= p_account_from)
       and (p_account_to is null or l.account_code <= p_account_to)
       and (p_third_party is null or l.third_party_id = p_third_party)
     group by l.account_id
  ), lines as (
    select l.*
      from public.ledger_lines l
     where l.entity_id = p_entity and l.entry_date between p_from and p_to
       and (p_account_from is null or l.account_code >= p_account_from)
       and (p_account_to is null or l.account_code <= p_account_to)
       and (p_third_party is null or l.third_party_id = p_third_party)
  )
  select l.account_id, l.account_code, l.account_label, l.entry_id, l.line_id, l.entry_date, l.journal_code, l.number,
         l.reference, l.label, l.third_party_code, l.debit, l.credit,
         (coalesce(o.balance, 0) + sum(l.debit - l.credit) over (partition by l.account_id order by l.entry_date, l.number, l.line_id
                                                                 rows between unbounded preceding and current row))::bigint,
         l.letter_code,
         l.third_party_name,
         (cp.list -> 0 ->> 'code'),
         greatest(coalesce(jsonb_array_length(cp.list), 0) - 1, 0),
         cp.list
    from lines l
    left join opening o on o.account_id = l.account_id
    left join lateral (
      select jsonb_agg(jsonb_build_object('code', x.code, 'label', x.label, 'amount', x.amount)
                       order by case when v_rule = 'largest_opposite' then -x.amount else 0 end, x.code) as list
        from (
          select o2.account_code as code, max(o2.account_label) as label,
                 sum(case when l.debit > 0 then o2.credit else o2.debit end)::bigint as amount
            from public.ledger_lines o2
           where o2.entry_id = l.entry_id and o2.line_id <> l.line_id
             and ((l.debit > 0 and o2.credit > 0) or (l.credit > 0 and o2.debit > 0))
           group by o2.account_code
        ) x
    ) cp on true
   order by l.account_code, l.entry_date, l.number, l.line_id;
end $$;
grant execute on function public.general_ledger(uuid, date, date, text, text, uuid) to anon, authenticated, service_role;

-- Retour arrière (à exécuter à la main) : recréer general_ledger depuis 20261025200007_consultation.sql, puis
--   alter table public.cabinets drop column ledger_counterpart_rule;
