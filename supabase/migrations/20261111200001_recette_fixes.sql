-- Recette interne du 11/11/2026 : AN-21 (régénération après contre-passation), AN-24 (tiers sur compte non collectif),
-- AN-29 (réouverture sans déverrouillage des périodes), AN-16 (lettrage sans les deux sens).

-- AN-21 : l''écriture générée déjà contre-passée n''empêche plus la régénération.
create or replace function public.generated_entry(p_entity uuid, p_date date, p_label text, p_source text, p_lines jsonb, p_journal_type public.journal_type default 'misc')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_cabinet uuid; v_journal uuid; v_old uuid; v_id uuid; l jsonb; v_n int := 0;
begin
  select cabinet_id into v_cabinet from public.entities where id = p_entity;
  select id into v_journal from public.journals where entity_id = p_entity and type = p_journal_type and is_active order by code limit 1;
  if v_journal is null then raise exception 'Aucun journal % actif dans ce dossier', p_journal_type using errcode = '23514'; end if;
  -- Une écriture déjà contre-passée est écartée : on peut régénérer une écriture annulée (AN-21).
  select id into v_old from public.entries where entity_id = p_entity and generated_source = p_source and reversed_by is null;
  if v_old is not null then
    if (select status from public.entries where id = v_old) = 'validated' then
      raise exception 'L''écriture générée « % » est déjà validée : contre-passez-la avant de régénérer', p_label using errcode = '23514';
    end if;
    delete from public.entries where id = v_old;
  end if;
  if jsonb_array_length(p_lines) = 0 then return null; end if;
  insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, label, is_generated, generated_source, created_by)
  select v_cabinet, p_entity, fy.id, p.id, v_journal, p_date, p_label, true, p_source, auth.uid()
    from public.fiscal_years fy join public.periods p on p.fiscal_year_id = fy.id
   where fy.entity_id = p_entity and p_date between p.start_date and p.end_date
  returning id into v_id;
  if v_id is null then raise exception 'Aucun exercice ne couvre la date %', p_date using errcode = '23514'; end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    if coalesce((l->>'debit')::bigint, 0) = 0 and coalesce((l->>'credit')::bigint, 0) = 0 then continue; end if;
    v_n := v_n + 1;
    insert into public.entry_lines (cabinet_id, entity_id, entry_id, line_no, account_id, third_party_id, label, debit, credit)
    values (v_cabinet, p_entity, v_id, v_n, (l->>'account_id')::uuid, nullif(l->>'third_party_id', '')::uuid, l->>'label', coalesce((l->>'debit')::bigint, 0), coalesce((l->>'credit')::bigint, 0));
  end loop;
  if v_n = 0 then delete from public.entries where id = v_id; return null; end if;
  return v_id;
end $$;

-- AN-24 : pas de tiers sur un compte de provision non collectif.
create or replace function public.generate_provision_entries(p_entity uuid, p_fiscal_year uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare p record; v_collective boolean; v_fy public.fiscal_years%rowtype; v_lines jsonb := '[]'::jsonb; v_delta bigint; v_entry uuid;
begin
  perform public.require_inventory(p_entity);
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  if v_fy.status = 'closed' then raise exception 'Exercice clôturé' using errcode = '42501'; end if;
  for p in select * from public.provisions where fiscal_year_id = p_fiscal_year loop
    v_delta := p.amount - p.previous_amount;
    -- Le tiers ne se rattache qu''à un compte collectif (AN-24) : 4911000 ne l''est pas.
    select is_collective into v_collective from public.accounts where id = p.provision_account_id;
    if not coalesce(v_collective, false) then p.third_party_id := null; end if;
    if v_delta > 0 then
      v_lines := v_lines || jsonb_build_object('account_id', p.expense_account_id, 'debit', v_delta, 'label', 'Dotation provision ' || p.kind)
                         || jsonb_build_object('account_id', p.provision_account_id, 'third_party_id', p.third_party_id, 'credit', v_delta, 'label', 'Provision ' || p.kind);
    elsif v_delta < 0 then
      v_lines := v_lines || jsonb_build_object('account_id', p.provision_account_id, 'third_party_id', p.third_party_id, 'debit', -v_delta, 'label', 'Reprise provision ' || p.kind)
                         || jsonb_build_object('account_id', p.reversal_account_id, 'credit', -v_delta, 'label', 'Reprise provision ' || p.kind);
    end if;
  end loop;
  v_entry := public.generated_entry(p_entity, v_fy.end_date, 'Provisions ' || v_fy.label, 'provisions:' || p_fiscal_year, v_lines);
  update public.provisions set entry_id = v_entry where fiscal_year_id = p_fiscal_year;
  return v_entry;
end $$;

-- AN-29 : la clôture provisoire mémorise les périodes qu''elle verrouille.
create or replace function public.close_provisional(p_entity uuid, p_fiscal_year uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_blocking int; v_failed text; v_locked uuid[];
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture provisoire' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity for update;
  if v_fy.status <> 'open' then raise exception 'L''exercice n''est pas ouvert' using errcode = '23514'; end if;
  perform public.run_closing_checks(p_entity, p_fiscal_year);
  select count(*) into v_blocking from public.closing_checks where fiscal_year_id = p_fiscal_year and status = 'failed' and severity = 'blocking';
  if v_blocking > 0 then raise exception '% contrôle(s) bloquant(s) en échec', v_blocking using errcode = '23514'; end if;
  if exists (select 1 from public.closing_checks where fiscal_year_id = p_fiscal_year and status = 'failed' and severity = 'warning') then
    raise exception 'Des alertes ne sont pas levées : commenter chaque levée' using errcode = '23514';
  end if;
  v_failed := public.latest_statements_failed_check(p_fiscal_year);
  if v_failed is not null then
    raise exception 'États financiers en échec : « % ». Corriger puis régénérer les états avant la clôture', v_failed using errcode = '23514';
  end if;
  update public.fiscal_years set status = 'closing' where id = p_fiscal_year;
  -- On retient les périodes verrouillées ici pour les déverrouiller à la réouverture (AN-29).
  perform set_config('akonta.internal', 'on', true);
  with locked as (update public.periods set is_locked = true, locked_at = now(), locked_by = auth.uid() where fiscal_year_id = p_fiscal_year and not is_locked returning id)
  select coalesce(array_agg(id), '{}') into v_locked from locked;
  perform set_config('akonta.internal', 'off', true);
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_fy.cabinet_id, auth.uid(), 'close_provisional', 'fiscal_years', p_fiscal_year::text, p_entity, jsonb_build_object('label', v_fy.label, 'locked_periods', to_jsonb(v_locked)));
end $$;

-- AN-29 : la réouverture déverrouille ces périodes.
create or replace function public.reopen_fiscal_year(p_entity uuid, p_fiscal_year uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_locked uuid[];
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : réouverture' using errcode = '42501';
  end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'Motif de réouverture obligatoire' using errcode = '23514'; end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity for update;
  if v_fy.status <> 'closing' then raise exception 'Seul un exercice en clôture provisoire se rouvre' using errcode = '23514'; end if;
  update public.fiscal_years set status = 'open' where id = p_fiscal_year;
  -- Déverrouille les périodes verrouillées par la clôture provisoire ; celles verrouillées à la main restent verrouillées (AN-29).
  select coalesce(array(select jsonb_array_elements_text(payload -> 'locked_periods')::uuid), '{}') into v_locked
    from public.audit_log where action = 'close_provisional' and table_name = 'fiscal_years' and record_id = p_fiscal_year::text
   order by occurred_at desc limit 1;
  perform set_config('akonta.internal', 'on', true);
  update public.periods set is_locked = false, unlock_reason = 'Réouverture de l''exercice : ' || p_reason
   where fiscal_year_id = p_fiscal_year and id = any (coalesce(v_locked, '{}')) and is_locked;
  perform set_config('akonta.internal', 'off', true);
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_fy.cabinet_id, auth.uid(), 'reopen', 'fiscal_years', p_fiscal_year::text, p_entity, jsonb_build_object('label', v_fy.label, 'reason', p_reason));
end $$;

-- Le verrouillage et le déverrouillage internes (clôture provisoire, réouverture) ne demandent pas le droit d''associé : le droit de clôture suffit.
create or replace function public.periods_guard_update()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_option boolean;
begin
  if new.start_date <> old.start_date or new.end_date <> old.end_date or new.fiscal_year_id <> old.fiscal_year_id
     or new.entity_id <> old.entity_id or new.cabinet_id <> old.cabinet_id or new.period_no <> old.period_no then
    raise exception 'Une période ne se redéfinit pas' using errcode = '23514';
  end if;
  if new.is_locked and not old.is_locked then
    select monthly_lock_enabled into v_option from public.entities where id = new.entity_id;
    if auth.uid() is not null and current_setting('akonta.internal', true) is distinct from 'on' and not (public.has_permission(null, 'cabinet.settings')
         or (v_option and public.has_permission(new.entity_id, 'closing.provisional'))) then
      raise exception 'Verrouillage réservé à l''associé, ou au chef de mission si l''option est active' using errcode = '42501';
    end if;
    new.locked_at := now(); new.locked_by := auth.uid(); new.unlock_reason := null;
  elsif old.is_locked and not new.is_locked then
    if auth.uid() is not null and current_setting('akonta.internal', true) is distinct from 'on' and not public.has_permission(null, 'cabinet.settings') then
      raise exception 'Déverrouillage réservé à l''associé' using errcode = '42501';
    end if;
    if coalesce(trim(new.unlock_reason), '') = '' then
      raise exception 'Motif de déverrouillage obligatoire' using errcode = '23514';
    end if;
    new.locked_at := null; new.locked_by := null;
  end if;
  return new;
end $$;

-- AN-16 : un lettrage exige les deux sens.
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
  if v_debit = 0 or v_credit = 0 then
    raise exception 'Un lettrage associe au moins une ligne au débit et une ligne au crédit' using errcode = '23514';
  end if;
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
