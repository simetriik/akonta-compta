-- =============================================================================
-- Akonta — Migration 0011 : rapprochement bancaire (module 7, conception §5, §10.7)
-- Import de relevés (lignes déjà analysées selon le gabarit), propositions de pointage
-- (montant + date ± 5 jours), pointage 1-1 ou plusieurs-à-plusieurs, état mensuel,
-- création d''écriture depuis une ligne de relevé, état figé.
-- =============================================================================

-- Enregistre un relevé et ses lignes (point de vue entreprise : debit = sortie, credit = entrée).
create or replace function public.import_bank_statement(p_journal uuid, p_from date, p_to date, p_lines jsonb,
                                                        p_opening bigint default null, p_closing bigint default null,
                                                        p_template uuid default null, p_file_name text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_j public.journals%rowtype; v_id uuid; l jsonb; v_no int := 0; v_d bigint; v_c bigint;
begin
  select * into v_j from public.journals where id = p_journal;
  if v_j.id is null or v_j.type not in ('bank', 'cash') then
    raise exception 'Journal de trésorerie attendu' using errcode = '23514';
  end if;
  if auth.uid() is not null and not public.has_permission(v_j.entity_id, 'reconciliation.manage') then
    raise exception 'Permission refusée : rapprocher' using errcode = '42501';
  end if;
  insert into public.bank_statements (cabinet_id, entity_id, journal_id, template_id, period_from, period_to, opening_balance, closing_balance, source_file_name, imported_by)
  values (v_j.cabinet_id, v_j.entity_id, p_journal, p_template, p_from, p_to, p_opening, p_closing, p_file_name, auth.uid())
  returning id into v_id;
  for l in select * from jsonb_array_elements(p_lines) loop
    v_no := v_no + 1;
    v_d := coalesce((l->>'debit')::bigint, 0); v_c := coalesce((l->>'credit')::bigint, 0);
    if l ? 'amount' then
      -- montant signé : négatif = sortie
      if (l->>'amount')::bigint < 0 then v_d := -(l->>'amount')::bigint; v_c := 0; else v_c := (l->>'amount')::bigint; v_d := 0; end if;
    end if;
    if v_d = 0 and v_c = 0 then continue; end if;
    insert into public.bank_statement_lines (statement_id, entity_id, line_no, operation_date, value_date, label, reference, debit, credit)
    values (v_id, v_j.entity_id, v_no, (l->>'date')::date, nullif(l->>'value_date', '')::date, coalesce(l->>'label', ''), l->>'reference', v_d, v_c);
  end loop;
  return v_id;
end $$;

-- Lignes de relevé non pointées d''un journal (toutes périodes confondues).
create or replace function public.unmatched_statement_lines(p_journal uuid, p_until date default null)
returns table (line_id bigint, statement_id uuid, operation_date date, value_date date, label text, reference text, debit bigint, credit bigint)
language sql stable as $$
  select l.id, l.statement_id, l.operation_date, l.value_date, l.label, l.reference, l.debit, l.credit
    from public.bank_statement_lines l join public.bank_statements s on s.id = l.statement_id
   where s.journal_id = p_journal and (p_until is null or l.operation_date <= p_until)
     and not exists (select 1 from public.reconciliation_match_statement_lines m where m.statement_line_id = l.id)
   order by l.operation_date, l.id;
$$;

-- Lignes comptables non pointées du compte de trésorerie du journal (écritures validées).
create or replace function public.unmatched_book_lines(p_journal uuid, p_until date default null)
returns table (line_id uuid, entry_id uuid, entry_date date, number bigint, reference text, label text, debit bigint, credit bigint)
language sql stable as $$
  select l.line_id, l.entry_id, l.entry_date, l.number, l.reference, l.label, l.debit, l.credit
    from public.ledger_lines l join public.journals j on j.id = p_journal
   where l.entity_id = j.entity_id and l.account_id = j.treasury_account_id and (p_until is null or l.entry_date <= p_until)
     and not l.is_opening   -- les à-nouveaux sont représentés par le solde d''ouverture du relevé (D-010)
     and not exists (select 1 from public.reconciliation_match_entry_lines m where m.entry_line_id = l.line_id)
   order by l.entry_date, l.number;
$$;

-- Propositions : même montant (sortie banque = crédit comptable, entrée = débit) et date à ± 5 jours.
create or replace function public.reconciliation_proposals(p_journal uuid, p_until date default null)
returns table (statement_line_id bigint, entry_line_id uuid, amount bigint, day_gap int)
language sql stable as $$
  select distinct on (s.line_id) s.line_id, b.line_id, greatest(s.debit, s.credit), abs(s.operation_date - b.entry_date)
    from public.unmatched_statement_lines(p_journal, p_until) s
    join public.unmatched_book_lines(p_journal, p_until) b
      on (s.debit > 0 and b.credit = s.debit) or (s.credit > 0 and b.debit = s.credit)
   where abs(s.operation_date - b.entry_date) <= 5
   order by s.line_id, abs(s.operation_date - b.entry_date), b.entry_date;
$$;

-- Pointage : n lignes de relevé ↔ m lignes comptables, totaux égaux (net entreprise).
create or replace function public.match_bank_lines(p_journal uuid, p_statement_line_ids bigint[], p_entry_line_ids uuid[], p_note text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_j public.journals%rowtype; v_id uuid; v_s bigint; v_b bigint; v_ns int; v_nb int;
begin
  select * into v_j from public.journals where id = p_journal;
  if v_j.id is null then raise exception 'Journal inconnu' using errcode = 'P0002'; end if;
  if auth.uid() is not null and not public.has_permission(v_j.entity_id, 'reconciliation.manage') then
    raise exception 'Permission refusée : rapprocher' using errcode = '42501';
  end if;
  if coalesce(array_length(p_statement_line_ids, 1), 0) = 0 or coalesce(array_length(p_entry_line_ids, 1), 0) = 0 then
    raise exception 'Un pointage relie au moins une ligne de relevé et une ligne comptable' using errcode = '23514';
  end if;
  select count(*), coalesce(sum(credit - debit), 0) into v_ns, v_s from public.unmatched_statement_lines(p_journal) where line_id = any (p_statement_line_ids);
  select count(*), coalesce(sum(debit - credit), 0) into v_nb, v_b from public.unmatched_book_lines(p_journal) where line_id = any (p_entry_line_ids);
  if v_ns <> array_length(p_statement_line_ids, 1) or v_nb <> array_length(p_entry_line_ids, 1) then
    raise exception 'Ligne déjà pointée ou hors de ce journal' using errcode = '23514';
  end if;
  if v_s <> v_b then
    raise exception 'Pointage déséquilibré : relevé % ≠ comptabilité %', v_s, v_b using errcode = '23514';
  end if;
  insert into public.reconciliation_matches (cabinet_id, entity_id, journal_id, matched_by, note)
  values (v_j.cabinet_id, v_j.entity_id, p_journal, auth.uid(), p_note) returning id into v_id;
  insert into public.reconciliation_match_statement_lines select v_id, unnest(p_statement_line_ids);
  insert into public.reconciliation_match_entry_lines select v_id, unnest(p_entry_line_ids);
  return v_id;
end $$;

create or replace function public.unmatch_bank_lines(p_match uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v public.reconciliation_matches%rowtype;
begin
  select * into v from public.reconciliation_matches where id = p_match;
  if v.id is null then raise exception 'Pointage inconnu' using errcode = 'P0002'; end if;
  if auth.uid() is not null and not public.has_permission(v.entity_id, 'reconciliation.manage') then
    raise exception 'Permission refusée : rapprocher' using errcode = '42501';
  end if;
  if exists (select 1 from public.reconciliations r where r.journal_id = v.journal_id and r.status = 'final' and r.as_of >= v.matched_at::date) then
    raise exception 'Pointage couvert par un état de rapprochement figé' using errcode = '42501';
  end if;
  delete from public.reconciliation_matches where id = p_match;
end $$;

-- État de rapprochement à une date : solde comptable, solde banque, suspens, écart.
-- Solde banque = dernier solde de clôture de relevé ≤ date ; sinon reconstitué depuis les lignes de relevé.
create or replace function public.reconciliation_state(p_journal uuid, p_as_of date)
returns table (book_balance bigint, bank_balance bigint, deposits_in_transit bigint, outstanding_payments bigint,
               unmatched_bank_credits bigint, unmatched_bank_debits bigint, difference bigint)
language plpgsql stable as $$
declare v_j public.journals%rowtype; v_book bigint; v_bank bigint; v_dep bigint; v_out bigint; v_ubc bigint; v_ubd bigint;
begin
  select * into v_j from public.journals where id = p_journal;
  v_book := public.account_balance(v_j.treasury_account_id, p_as_of);
  select s.closing_balance into v_bank from public.bank_statements s where s.journal_id = p_journal and s.period_to <= p_as_of and s.closing_balance is not null order by s.period_to desc limit 1;
  if v_bank is null then
    select coalesce(sum(l.credit - l.debit), 0) into v_bank from public.bank_statement_lines l join public.bank_statements s on s.id = l.statement_id
     where s.journal_id = p_journal and l.operation_date <= p_as_of;
  end if;
  -- Encaissements comptabilisés non crédités par la banque / décaissements non débités
  select coalesce(sum(debit), 0), coalesce(sum(credit), 0) into v_dep, v_out from public.unmatched_book_lines(p_journal, p_as_of);
  -- Mouvements bancaires non comptabilisés
  select coalesce(sum(credit), 0), coalesce(sum(debit), 0) into v_ubc, v_ubd from public.unmatched_statement_lines(p_journal, p_as_of);
  return query select v_book, v_bank, v_dep, v_out, v_ubc, v_ubd, (v_bank + v_dep - v_out + v_ubd - v_ubc) - v_book;
end $$;

-- Écriture comptable depuis une ligne de relevé non pointée (frais, agios, virement reçu…) : brouillard dans le journal de banque, puis pointage.
create or replace function public.entry_from_statement_line(p_line bigint, p_account uuid, p_third_party uuid default null, p_label text default null, p_validate boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_l public.bank_statement_lines%rowtype; v_s public.bank_statements%rowtype; v_j public.journals%rowtype; v_entry uuid; v_line uuid;
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
  insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, reference, label, is_generated, generated_source, created_by)
  select v_j.cabinet_id, v_j.entity_id, fy.id, p.id, v_j.id, v_l.operation_date, v_l.reference, coalesce(p_label, v_l.label), true, 'bank_statement:' || p_line, auth.uid()
    from public.fiscal_years fy join public.periods p on p.fiscal_year_id = fy.id
   where fy.entity_id = v_j.entity_id and v_l.operation_date between p.start_date and p.end_date
  returning id into v_entry;
  if v_entry is null then raise exception 'Aucun exercice ne couvre la date %', v_l.operation_date using errcode = '23514'; end if;
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

-- Figer l''état mensuel : écart nul obligatoire ; l''état est archivé (PDF rattaché ensuite par l''application).
create or replace function public.finalize_reconciliation(p_journal uuid, p_as_of date, p_statement uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_j public.journals%rowtype; st record; v_id uuid;
begin
  select * into v_j from public.journals where id = p_journal;
  if auth.uid() is not null and not public.has_permission(v_j.entity_id, 'reconciliation.manage') then
    raise exception 'Permission refusée : rapprocher' using errcode = '42501';
  end if;
  select * into st from public.reconciliation_state(p_journal, p_as_of);
  if st.difference <> 0 then
    raise exception 'Écart de rapprochement non nul (%) : état non figé', st.difference using errcode = '23514';
  end if;
  insert into public.reconciliations (cabinet_id, entity_id, journal_id, statement_id, as_of, book_balance, bank_balance, outstanding_debits, outstanding_credits, difference, status, finalized_by, finalized_at, details)
  values (v_j.cabinet_id, v_j.entity_id, p_journal, p_statement, p_as_of, st.book_balance, st.bank_balance, st.deposits_in_transit, st.outstanding_payments, 0, 'final', auth.uid(), now(),
          jsonb_build_object('unmatched_bank_credits', st.unmatched_bank_credits, 'unmatched_bank_debits', st.unmatched_bank_debits,
                             'outstanding_book_lines', (select coalesce(jsonb_agg(to_jsonb(b)), '[]'::jsonb) from public.unmatched_book_lines(p_journal, p_as_of) b),
                             'unmatched_statement_lines', (select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb) from public.unmatched_statement_lines(p_journal, p_as_of) s)))
  on conflict (journal_id, as_of) do update set book_balance = excluded.book_balance, bank_balance = excluded.bank_balance,
     outstanding_debits = excluded.outstanding_debits, outstanding_credits = excluded.outstanding_credits, status = 'final',
     finalized_by = excluded.finalized_by, finalized_at = excluded.finalized_at, details = excluded.details
  returning id into v_id;
  update public.bank_statements set status = 'reconciled' where journal_id = p_journal and period_to <= p_as_of and status <> 'archived';
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_j.cabinet_id, auth.uid(), 'reconciliation_final', 'reconciliations', v_id::text, v_j.entity_id, jsonb_build_object('as_of', p_as_of, 'book', st.book_balance, 'bank', st.bank_balance));
  return v_id;
end $$;

-- Un état figé est intangible (sauf rattachement du PDF archivé).
create or replace function public.reconciliations_guard()
returns trigger language plpgsql as $$
begin
  if old.status = 'final' and (new.book_balance <> old.book_balance or new.bank_balance <> old.bank_balance or new.as_of <> old.as_of or new.status <> old.status) and not public.internal_mode() then
    raise exception 'État de rapprochement figé : intangible' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger reconciliations_guard before update on public.reconciliations for each row execute function public.reconciliations_guard();

grant execute on function public.import_bank_statement(uuid, date, date, jsonb, bigint, bigint, uuid, text), public.unmatched_statement_lines(uuid, date),
  public.unmatched_book_lines(uuid, date), public.reconciliation_proposals(uuid, date), public.match_bank_lines(uuid, bigint[], uuid[], text),
  public.unmatch_bank_lines(uuid), public.reconciliation_state(uuid, date), public.entry_from_statement_line(bigint, uuid, uuid, text, boolean),
  public.finalize_reconciliation(uuid, date, uuid) to authenticated;
