-- =============================================================================
-- Akonta — Migration 0010 : lettrage (module 7, conception §5, §10.7)
-- Lettrage manuel, partiel, tolérance par entité avec écart généré en brouillard,
-- propositions (même tiers et montant ; facture = règlement + retenues),
-- délettrage tracé et impossible après clôture.
-- =============================================================================

-- Code de lettrage suivant pour un compte (et tiers) : A … Z, AA, AB …
create or replace function public.next_letter_code(p_account uuid, p_third_party uuid)
returns text language plpgsql as $$
declare v_n int; v_code text := ''; v_k int;
begin
  select count(*) into v_n from public.letterings where account_id = p_account and third_party_id is not distinct from p_third_party;
  v_k := v_n;
  loop
    v_code := chr(65 + (v_k % 26)) || v_code;
    v_k := v_k / 26 - 1;
    exit when v_k < 0;
  end loop;
  return v_code;
end $$;

-- Lettrage d''un ensemble de lignes : même dossier, même compte lettrable, même tiers, écritures validées,
-- non déjà lettrées. Soldé si |débit - crédit| ≤ tolérance (un écart non nul génère un brouillard d''OD),
-- sinon partiel (p_allow_partial) ou refus.
create or replace function public.letter_lines(p_line_ids uuid[], p_allow_partial boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_entity uuid; v_cabinet uuid; v_account uuid; v_tp uuid; v_debit bigint; v_credit bigint; v_count int; v_distinct int;
  v_tolerance bigint; v_diff bigint; v_code text; v_id uuid; v_partial boolean; v_gap_entry uuid; v_od uuid; v_gap_account uuid;
begin
  if p_line_ids is null or array_length(p_line_ids, 1) < 2 then
    raise exception 'Un lettrage porte sur au moins deux lignes' using errcode = '23514';
  end if;
  select count(*), count(distinct (l.entity_id, l.account_id, coalesce(l.third_party_id, '00000000-0000-0000-0000-000000000000'::uuid))),
         min(l.entity_id::text)::uuid, min(l.account_id::text)::uuid, min(l.third_party_id::text)::uuid, sum(l.debit), sum(l.credit), min(l.cabinet_id::text)::uuid
    into v_count, v_distinct, v_entity, v_account, v_tp, v_debit, v_credit, v_cabinet
    from public.entry_lines l join public.entries e on e.id = l.entry_id
   where l.id = any (p_line_ids) and e.status = 'validated';
  if v_count <> array_length(p_line_ids, 1) then
    raise exception 'Lignes inconnues ou écritures non validées' using errcode = '23514';
  end if;
  if v_distinct <> 1 then
    raise exception 'Toutes les lignes doivent porter le même compte et le même tiers' using errcode = '23514';
  end if;
  if exists (select 1 from public.entry_lines where id = any (p_line_ids) and lettering_id is not null) then
    raise exception 'Une ligne est déjà lettrée' using errcode = '23514';
  end if;
  if not (select is_letterable from public.accounts where id = v_account) then
    raise exception 'Compte non lettrable' using errcode = '23514';
  end if;
  if auth.uid() is not null and not public.has_permission(v_entity, 'lettering.manage') then
    raise exception 'Permission refusée : lettrer' using errcode = '42501';
  end if;
  select lettering_tolerance into v_tolerance from public.entities where id = v_entity;
  v_diff := v_debit - v_credit;
  v_partial := abs(v_diff) > v_tolerance;
  if v_partial and not p_allow_partial then
    raise exception 'Lettrage non soldé (écart %) : confirmer un lettrage partiel', v_diff using errcode = '23514';
  end if;

  v_code := public.next_letter_code(v_account, v_tp);
  insert into public.letterings (cabinet_id, entity_id, account_id, third_party_id, code, is_partial, total_debit, total_credit, created_by)
  values (v_cabinet, v_entity, v_account, v_tp, v_code, v_partial, v_debit, v_credit, auth.uid())
  returning id into v_id;

  perform set_config('akonta.internal', 'on', true);
  update public.entry_lines set lettering_id = v_id, letter_code = v_code, lettered_at = now() where id = any (p_line_ids);

  -- Écart dans la tolérance : brouillard d''OD (658 charge / 758 produit) qui solde le tiers, lettré avec le groupe.
  if not v_partial and v_diff <> 0 then
    select id into v_od from public.journals where entity_id = v_entity and type = 'misc' and is_active order by code limit 1;
    select id into v_gap_account from public.accounts where entity_id = v_entity and code = public.pad_account_code(case when v_diff > 0 then '658' else '758' end, length((select code from public.accounts where id = v_account)));
    if v_od is not null and v_gap_account is not null then
      insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, label, is_generated, generated_source, created_by)
      select v_cabinet, v_entity, fy.id, p.id, v_od, current_date, 'Écart de règlement (lettrage ' || v_code || ')', true, 'lettering_gap', auth.uid()
        from public.fiscal_years fy join public.periods p on p.fiscal_year_id = fy.id
       where fy.entity_id = v_entity and current_date between p.start_date and p.end_date
      returning id into v_gap_entry;
      if v_gap_entry is not null then
        insert into public.entry_lines (cabinet_id, entity_id, entry_id, line_no, account_id, third_party_id, debit, credit)
        values (v_cabinet, v_entity, v_gap_entry, 1, v_gap_account, null, greatest(v_diff, 0), greatest(-v_diff, 0)),
               (v_cabinet, v_entity, v_gap_entry, 2, v_account, v_tp, greatest(-v_diff, 0), greatest(v_diff, 0));
      end if;
    end if;
  end if;
  perform set_config('akonta.internal', 'off', true);

  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_cabinet, auth.uid(), 'letter', 'letterings', v_id::text, v_entity,
          jsonb_build_object('code', v_code, 'lines', to_jsonb(p_line_ids), 'debit', v_debit, 'credit', v_credit, 'partial', v_partial, 'gap_entry', v_gap_entry));
  return v_id;
end $$;

-- Délettrage : tracé (motif), impossible si l''exercice d''une des lignes est clôturé.
create or replace function public.unletter(p_lettering uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v public.letterings%rowtype;
begin
  select * into v from public.letterings where id = p_lettering for update;
  if v.id is null then raise exception 'Lettrage inconnu' using errcode = 'P0002'; end if;
  if v.unlettered_at is not null then raise exception 'Déjà délettré' using errcode = '23514'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'Motif de délettrage obligatoire' using errcode = '23514'; end if;
  if auth.uid() is not null and not public.has_permission(v.entity_id, 'lettering.manage') then
    raise exception 'Permission refusée : lettrer' using errcode = '42501';
  end if;
  if exists (select 1 from public.entry_lines l join public.entries e on e.id = l.entry_id join public.fiscal_years fy on fy.id = e.fiscal_year_id
              where l.lettering_id = p_lettering and fy.status = 'closed') then
    raise exception 'Délettrage impossible : exercice clôturé' using errcode = '42501';
  end if;
  perform set_config('akonta.internal', 'on', true);
  update public.entry_lines set lettering_id = null, letter_code = null, lettered_at = null where lettering_id = p_lettering;
  perform set_config('akonta.internal', 'off', true);
  update public.letterings set unlettered_at = now(), unlettered_by = auth.uid(), unlettered_reason = p_reason where id = p_lettering;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v.cabinet_id, auth.uid(), 'unletter', 'letterings', p_lettering::text, v.entity_id, jsonb_build_object('code', v.code, 'reason', p_reason));
end $$;

-- Lignes non lettrées d''un compte lettrable (et tiers), avec leur écriture.
create or replace function public.unlettered_lines(p_entity uuid, p_account uuid, p_third_party uuid default null)
returns table (line_id uuid, entry_id uuid, entry_date date, journal_code text, number bigint, reference text, label text,
               third_party_id uuid, third_party_code text, debit bigint, credit bigint)
language sql stable as $$
  select l.line_id, l.entry_id, l.entry_date, l.journal_code, l.number, l.reference, l.label, l.third_party_id, l.third_party_code, l.debit, l.credit
    from public.ledger_lines l
   where l.entity_id = p_entity and l.account_id = p_account and l.letter_code is null
     and (p_third_party is null or l.third_party_id = p_third_party)
   order by l.third_party_code, l.entry_date, l.number;
$$;

-- Propositions de lettrage (D-009) :
--   règle 1 : une ligne débit et une ligne crédit de même montant, même tiers ;
--   règle 2 : facture (débit) = règlement (crédit net) + retenues (crédit du tiers dans une écriture
--             qui débite un compte 447x / 445x : AIB, TVA retenue).
create or replace function public.lettering_proposals(p_entity uuid, p_account uuid, p_third_party uuid default null)
returns table (debit_line_id uuid, credit_line_ids uuid[], third_party_code text, amount bigint, rule text)
language sql stable as $$
  with un as (
    select * from public.unlettered_lines(p_entity, p_account, p_third_party)
  ), debits as (select * from un where debit > 0), credits as (select * from un where credit > 0),
  withholding_credits as (
    select c.* from credits c
     where exists (select 1 from public.entry_lines x join public.accounts a on a.id = x.account_id
                    where x.entry_id = c.entry_id and x.id <> c.line_id and x.debit > 0 and (a.code like '447%' or a.code like '445%'))
  ), rule1 as (
    select distinct on (d.line_id) d.line_id as debit_line_id, array[c.line_id] as credit_line_ids, d.third_party_code, d.debit as amount, 'same_amount'::text as rule
      from debits d join credits c on c.credit = d.debit and c.third_party_id is not distinct from d.third_party_id
     order by d.line_id, abs(c.entry_date - d.entry_date)
  ), rule2 as (
    select distinct on (d.line_id) d.line_id, array[c.line_id, w.line_id], d.third_party_code, d.debit, 'invoice_equals_payment_plus_withholdings'::text
      from debits d
      join credits c on c.third_party_id is not distinct from d.third_party_id and c.line_id not in (select line_id from withholding_credits)
      join withholding_credits w on w.third_party_id is not distinct from d.third_party_id and w.line_id <> c.line_id and c.credit + w.credit = d.debit
     where d.line_id not in (select rule1.debit_line_id from rule1)
     order by d.line_id, abs(c.entry_date - d.entry_date)
  )
  select * from rule1 union all select * from rule2 order by 3, 4;
$$;

grant execute on function public.letter_lines(uuid[], boolean), public.unletter(uuid, text), public.unlettered_lines(uuid, uuid, uuid),
  public.lettering_proposals(uuid, uuid, uuid), public.next_letter_code(uuid, uuid) to authenticated;
revoke execute on function public.letter_lines(uuid[], boolean), public.unletter(uuid, text) from anon;
