-- =============================================================================
-- Akonta — Migration 0017 : date d'écriture libre pour une écriture créée depuis une ligne de relevé
-- La ligne de relevé peut dater d'une période déjà verrouillée (ex. agios découverts tardivement) :
-- l'écriture est alors datée dans une période ouverte, au choix de l'utilisateur. Par défaut, la
-- date d'opération de la ligne est conservée.
-- =============================================================================
drop function if exists public.entry_from_statement_line(bigint, uuid, uuid, text, boolean);

create or replace function public.entry_from_statement_line(
  p_line bigint, p_account uuid, p_third_party uuid default null, p_label text default null,
  p_validate boolean default false, p_entry_date date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_l public.bank_statement_lines%rowtype; v_s public.bank_statements%rowtype; v_j public.journals%rowtype;
        v_date date; v_entry uuid; v_line uuid;
begin
  select * into v_l from public.bank_statement_lines where id = p_line;
  if v_l.id is null then raise exception 'Ligne de relevé inconnue' using errcode = 'P0002'; end if;
  select * into v_s from public.bank_statements where id = v_l.statement_id;
  select * into v_j from public.journals where id = v_s.journal_id;
  if auth.uid() is not null and not public.has_permission(v_j.entity_id, 'reconciliation.manage') then
    raise exception 'Permission refusée : rapprocher' using errcode = '42501';
  end if;
  if exists (select 1 from public.reconciliation_match_statement_lines where statement_line_id = p_line) then
    raise exception 'Ligne déjà pointée' using errcode = '23514';
  end if;
  v_date := coalesce(p_entry_date, v_l.operation_date);
  insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, reference, label, is_generated, generated_source, created_by)
  select v_j.cabinet_id, v_j.entity_id, fy.id, p.id, v_j.id, v_date, v_l.reference, coalesce(p_label, v_l.label), true, 'bank_statement:' || p_line, auth.uid()
    from public.fiscal_years fy join public.periods p on p.fiscal_year_id = fy.id
   where fy.entity_id = v_j.entity_id and v_date between p.start_date and p.end_date
  returning id into v_entry;
  if v_entry is null then raise exception 'Aucun exercice ne couvre la date %', v_date using errcode = '23514'; end if;
  insert into public.entry_lines (cabinet_id, entity_id, entry_id, line_no, account_id, third_party_id, debit, credit)
  values (v_j.cabinet_id, v_j.entity_id, v_entry, 1, p_account, p_third_party, v_l.debit, v_l.credit);
  insert into public.entry_lines (cabinet_id, entity_id, entry_id, line_no, account_id, debit, credit)
  values (v_j.cabinet_id, v_j.entity_id, v_entry, 2, v_j.treasury_account_id, v_l.credit, v_l.debit)
  returning id into v_line;
  if p_validate then
    perform public.validate_entry(v_entry);
    perform public.match_bank_lines(v_j.id, array[p_line], array[v_line], 'créée depuis le relevé');
  end if;
  return v_entry;
end $$;

grant execute on function public.entry_from_statement_line(bigint, uuid, uuid, text, boolean, date) to authenticated;
