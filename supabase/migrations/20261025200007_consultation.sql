-- =============================================================================
-- Akonta — Migration 0007 : consultation (module 6, conception §5, §10.6)
-- Grand livre général et auxiliaire, balances générale / auxiliaire / âgée,
-- livre-journal, centralisateur mensuel. Écritures validées uniquement ;
-- calculs côté base, aucun solde stocké.
-- =============================================================================

-- Colonnes de lettrage (utilisées par la balance âgée ; fonctions de lettrage au lot 2)
alter table public.entry_lines
  add column letter_code text,
  add column lettered_at timestamptz;
create index entry_lines_unlettered_idx on public.entry_lines (entity_id, account_id, third_party_id) where letter_code is null;

-- Lignes du grand livre (écritures validées), avec les libellés utiles
create or replace view public.ledger_lines with (security_invoker = true) as
  select l.id as line_id, e.id as entry_id, e.entity_id, e.fiscal_year_id, e.period_id, e.journal_id,
         j.code as journal_code, e.number, e.entry_date, e.reference, coalesce(l.label, e.label) as label,
         l.account_id, a.code as account_code, a.label as account_label, a.class as account_class,
         a.is_collective, l.third_party_id, t.code as third_party_code, t.name as third_party_name,
         l.debit, l.credit, l.currency_code, l.amount_currency, l.exchange_rate, l.letter_code, l.lettered_at,
         e.review_status, e.is_generated, e.reversal_of, e.reversed_by,
         j.type = 'opening' as is_opening
    from public.entry_lines l
    join public.entries e on e.id = l.entry_id and e.status = 'validated'
    join public.journals j on j.id = e.journal_id
    join public.accounts a on a.id = l.account_id
    left join public.third_parties t on t.id = l.third_party_id;
comment on view public.ledger_lines is 'Lignes des écritures validées, prêtes pour le grand livre, le journal et les balances.';

create or replace function public.require_ledger_read(p_entity uuid)
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'ledger.read') then
    raise exception 'Permission refusée : consulter le grand livre et les balances' using errcode = '42501';
  end if;
end $$;

-- Grand livre : lignes d''une plage de comptes et de dates, avec solde progressif par compte.
-- Le report (solde avant p_from) est calculé sur l''exercice contenant p_from.
create or replace function public.general_ledger(p_entity uuid, p_from date, p_to date,
                                                 p_account_from text default null, p_account_to text default null,
                                                 p_third_party uuid default null)
returns table (account_id uuid, account_code text, account_label text, entry_id uuid, line_id uuid, entry_date date,
               journal_code text, number bigint, reference text, label text, third_party_code text,
               debit bigint, credit bigint, running_balance bigint, letter_code text)
language plpgsql stable as $$
declare v_fy uuid;
begin
  perform public.require_ledger_read(p_entity);
  select id into v_fy from public.fiscal_years where entity_id = p_entity and p_from between start_date and end_date;
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
         l.letter_code
    from lines l left join opening o on o.account_id = l.account_id
   order by l.account_code, l.entry_date, l.number, l.line_id;
end $$;

-- Balance générale : à-nouveaux (journal AN) + mouvements antérieurs à p_from dans l''exercice,
-- mouvements de la période, soldes de clôture.
create or replace function public.trial_balance(p_entity uuid, p_from date, p_to date, p_class smallint default null)
returns table (account_id uuid, account_code text, account_label text, account_class smallint,
               opening_debit bigint, opening_credit bigint, period_debit bigint, period_credit bigint,
               closing_debit bigint, closing_credit bigint)
language plpgsql stable as $$
declare v_fy uuid;
begin
  perform public.require_ledger_read(p_entity);
  select id into v_fy from public.fiscal_years where entity_id = p_entity and p_from between start_date and end_date;
  return query
  with agg as (
    select l.account_id,
           sum(case when l.entry_date < p_from or l.is_opening then l.debit else 0 end)  as od,
           sum(case when l.entry_date < p_from or l.is_opening then l.credit else 0 end) as oc,
           sum(case when l.entry_date >= p_from and not l.is_opening then l.debit else 0 end)  as pd,
           sum(case when l.entry_date >= p_from and not l.is_opening then l.credit else 0 end) as pc
      from public.ledger_lines l
     where l.entity_id = p_entity and l.fiscal_year_id = v_fy and l.entry_date <= p_to
       and (p_class is null or l.account_class = p_class)
     group by l.account_id
  )
  select a.id, a.code, a.label, a.class,
         agg.od::bigint, agg.oc::bigint, agg.pd::bigint, agg.pc::bigint,
         greatest(agg.od + agg.pd - agg.oc - agg.pc, 0)::bigint,
         greatest(agg.oc + agg.pc - agg.od - agg.pd, 0)::bigint
    from agg join public.accounts a on a.id = agg.account_id
   order by a.code;
end $$;

-- Balance auxiliaire : par compte collectif et tiers.
create or replace function public.auxiliary_balance(p_entity uuid, p_from date, p_to date, p_account uuid default null)
returns table (account_id uuid, account_code text, third_party_id uuid, third_party_code text, third_party_name text,
               opening_debit bigint, opening_credit bigint, period_debit bigint, period_credit bigint,
               closing_debit bigint, closing_credit bigint)
language plpgsql stable as $$
declare v_fy uuid;
begin
  perform public.require_ledger_read(p_entity);
  select id into v_fy from public.fiscal_years where entity_id = p_entity and p_from between start_date and end_date;
  return query
  with agg as (
    select l.account_id, l.third_party_id,
           sum(case when l.entry_date < p_from or l.is_opening then l.debit else 0 end)  as od,
           sum(case when l.entry_date < p_from or l.is_opening then l.credit else 0 end) as oc,
           sum(case when l.entry_date >= p_from and not l.is_opening then l.debit else 0 end)  as pd,
           sum(case when l.entry_date >= p_from and not l.is_opening then l.credit else 0 end) as pc
      from public.ledger_lines l
     where l.entity_id = p_entity and l.fiscal_year_id = v_fy and l.entry_date <= p_to
       and l.third_party_id is not null and (p_account is null or l.account_id = p_account)
     group by l.account_id, l.third_party_id
  )
  select a.id, a.code, t.id, t.code, t.name,
         agg.od::bigint, agg.oc::bigint, agg.pd::bigint, agg.pc::bigint,
         greatest(agg.od + agg.pd - agg.oc - agg.pc, 0)::bigint,
         greatest(agg.oc + agg.pc - agg.od - agg.pd, 0)::bigint
    from agg join public.accounts a on a.id = agg.account_id join public.third_parties t on t.id = agg.third_party_id
   order by a.code, t.code;
end $$;

-- Balance âgée des lignes non lettrées de tiers à une date : 0-30, 31-60, 61-90, 91-180, > 180 jours.
create or replace function public.aged_balance(p_entity uuid, p_as_of date, p_side public.posting_side default 'debit')
returns table (account_id uuid, account_code text, third_party_id uuid, third_party_code text, third_party_name text,
               not_due bigint, d0_30 bigint, d31_60 bigint, d61_90 bigint, d91_180 bigint, over_180 bigint, total bigint)
language plpgsql stable as $$
begin
  perform public.require_ledger_read(p_entity);
  return query
  with lines as (
    select l.account_id, l.third_party_id, p_as_of - l.entry_date as age,
           case when p_side = 'debit' then l.debit - l.credit else l.credit - l.debit end as amount
      from public.ledger_lines l
     where l.entity_id = p_entity and l.entry_date <= p_as_of and l.third_party_id is not null
       and l.letter_code is null and l.is_collective
  )
  select a.id, a.code, t.id, t.code, t.name,
         0::bigint,
         sum(case when age between 0 and 30 then amount else 0 end)::bigint,
         sum(case when age between 31 and 60 then amount else 0 end)::bigint,
         sum(case when age between 61 and 90 then amount else 0 end)::bigint,
         sum(case when age between 91 and 180 then amount else 0 end)::bigint,
         sum(case when age > 180 then amount else 0 end)::bigint,
         sum(amount)::bigint
    from lines join public.accounts a on a.id = lines.account_id join public.third_parties t on t.id = lines.third_party_id
   group by a.id, a.code, t.id, t.code, t.name
  having sum(amount) <> 0
   order by a.code, t.code;
end $$;

-- Livre-journal : écritures validées d''un journal sur une période, avec leurs lignes.
create or replace function public.journal_book(p_entity uuid, p_journal uuid, p_from date, p_to date)
returns table (entry_id uuid, number bigint, entry_date date, reference text, entry_label text, line_no smallint,
               account_code text, account_label text, third_party_code text, line_label text, debit bigint, credit bigint)
language plpgsql stable as $$
begin
  perform public.require_ledger_read(p_entity);
  return query
  select e.id, e.number, e.entry_date, e.reference, e.label, l.line_no, a.code, a.label, t.code, coalesce(l.label, e.label), l.debit, l.credit
    from public.entries e
    join public.entry_lines l on l.entry_id = e.id
    join public.accounts a on a.id = l.account_id
    left join public.third_parties t on t.id = l.third_party_id
   where e.entity_id = p_entity and e.journal_id = p_journal and e.status = 'validated'
     and e.entry_date between p_from and p_to
   order by e.entry_date, e.number, l.line_no;
end $$;

-- Centralisateur : totaux par journal et par mois d''un exercice (centralisation mensuelle calculée).
create or replace function public.journal_centralization(p_entity uuid, p_fiscal_year uuid)
returns table (journal_id uuid, journal_code text, journal_label text, period_no smallint, month_start date,
               entries_count bigint, total_debit bigint, total_credit bigint)
language plpgsql stable as $$
begin
  perform public.require_ledger_read(p_entity);
  return query
  select j.id, j.code, j.label, p.period_no, p.start_date,
         count(distinct e.id), coalesce(sum(l.debit), 0)::bigint, coalesce(sum(l.credit), 0)::bigint
    from public.journals j
    join public.periods p on p.fiscal_year_id = p_fiscal_year and p.entity_id = p_entity
    left join public.entries e on e.journal_id = j.id and e.period_id = p.id and e.status = 'validated'
    left join public.entry_lines l on l.entry_id = e.id
   where j.entity_id = p_entity
   group by j.id, j.code, j.label, p.period_no, p.start_date
  having count(e.id) > 0
   order by j.code, p.period_no;
end $$;

-- Solde d''un compte à une date (utilitaire pour les contrôles et l''interface).
create or replace function public.account_balance(p_account uuid, p_as_of date)
returns bigint language sql stable as $$
  select coalesce(sum(l.debit) - sum(l.credit), 0)::bigint
    from public.ledger_lines l where l.account_id = p_account and l.entry_date <= p_as_of;
$$;

-- Tableau de bord des dossiers (§10.2) : dernier mois saisi, brouillards, écritures non revues.
create or replace function public.entity_dashboard()
returns table (entity_id uuid, entity_name text, fiscal_year_id uuid, fiscal_year_label text, fiscal_year_status public.fiscal_year_status,
               manager_names text, last_entry_date date, draft_count bigint, unreviewed_count bigint, to_correct_count bigint,
               inbox_count bigint)
language sql stable as $$
  select e.id, e.name, fy.id, fy.label, fy.status,
         (select string_agg(p.full_name, ', ' order by p.full_name)
            from public.assignments a join public.roles r on r.id = a.role_id join public.profiles p on p.id = a.user_id
           where a.entity_id = e.id and r.code = 'manager'),
         (select max(en.entry_date) from public.entries en where en.entity_id = e.id and en.status = 'validated'),
         (select count(*) from public.entries en where en.entity_id = e.id and en.status = 'draft'),
         (select count(*) from public.entries en where en.entity_id = e.id and en.status = 'validated' and en.review_status = 'not_reviewed'),
         (select count(*) from public.entries en where en.entity_id = e.id and en.review_status = 'to_correct'),
         (select count(*) from public.document_inbox d where d.entity_id = e.id)
    from public.entities e
    left join lateral (select * from public.fiscal_years f where f.entity_id = e.id order by f.start_date desc limit 1) fy on true
   where e.is_active and public.can_access_entity(e.id)
   order by e.name;
$$;
