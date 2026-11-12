-- Recette interne du 11/11/2026 : AN-20 (une contre-passation ne se contre-passe pas), AN-06 (import Perfecto : lignes vides et totaux ignorés).

-- AN-20
create or replace function public.reverse_entry(p_entry uuid, p_reason text, p_date date default current_date, p_validate boolean default true)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_entry public.entries%rowtype;
  v_new uuid;
begin
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Motif de contre-passation obligatoire' using errcode = '23514';
  end if;
  select * into v_entry from public.entries where id = p_entry for update;
  if v_entry.id is null then raise exception 'Écriture inconnue' using errcode = 'P0002'; end if;
  if v_entry.status <> 'validated' then
    raise exception 'Seule une écriture validée se contre-passe (un brouillard se modifie)' using errcode = '23514';
  end if;
  if v_entry.reversed_by is not null then
    raise exception 'Écriture déjà contre-passée' using errcode = '23514';
  end if;
  if v_entry.reversal_of is not null then
    raise exception 'Une contre-passation ne se contre-passe pas : saisissez une nouvelle écriture' using errcode = '23514';
  end if;
  if auth.uid() is not null and not public.has_permission(v_entry.entity_id, 'entries.reverse') then
    raise exception 'Permission refusée : contre-passer' using errcode = '42501';
  end if;
  if not public.period_open_for(v_entry.entity_id, p_date) then
    raise exception 'La date % n''est pas dans une période ouverte', p_date using errcode = '23514';
  end if;
  insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, reference, label,
                              currency_code, reversal_of, reversal_reason, created_by)
  values (v_entry.cabinet_id, v_entry.entity_id, v_entry.fiscal_year_id, v_entry.period_id, v_entry.journal_id, p_date,
          v_entry.reference, 'Contre-passation n° ' || v_entry.number || ' : ' || v_entry.label,
          v_entry.currency_code, v_entry.id, p_reason, auth.uid())
  returning id into v_new;
  insert into public.entry_lines (cabinet_id, entity_id, entry_id, line_no, account_id, third_party_id, label, debit, credit,
                                  currency_code, amount_currency, exchange_rate)
  select cabinet_id, entity_id, v_new, line_no, account_id, third_party_id, label, credit, debit,
         currency_code, amount_currency, exchange_rate
    from public.entry_lines where entry_id = p_entry;
  perform set_config('akonta.internal', 'on', true);
  update public.entries set reversed_by = v_new where id = p_entry;
  perform set_config('akonta.internal', 'off', true);
  if p_validate then
    perform public.validate_entry(v_new);
  end if;
  return v_new;
end $$;

-- AN-06
create or replace function public.import_parse_perfecto_journal(p_batch uuid, p_text text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_batch public.import_batches%rowtype;
  v_line text; v_no int := 0; v_data int := 0; v_pieces int := 0; v_subtotal_errors int := 0;
  cols text[]; m text[];
  v_date date; v_debit numeric; v_credit numeric; nd bigint; nc bigint;
  v_piece text; v_sum_d bigint := 0; v_sum_c bigint := 0; v_raw_d numeric := 0; v_raw_c numeric := 0; v_current_piece text := null;
  v_errors jsonb := '[]'::jsonb;
begin
  select * into v_batch from public.import_batches where id = p_batch for update;
  if v_batch.id is null then raise exception 'Lot inconnu' using errcode = 'P0002'; end if;
  if v_batch.status not in ('created', 'parsed') then
    raise exception 'Lot déjà traité (%)', v_batch.status using errcode = '23514';
  end if;
  if auth.uid() is not null and not public.has_permission(v_batch.entity_id, 'import.perfecto') then
    raise exception 'Permission refusée : importer depuis Perfecto' using errcode = '42501';
  end if;
  delete from public.import_lines where batch_id = p_batch;

  foreach v_line in array regexp_split_to_array(replace(p_text, chr(13), ''), E'\n') loop
    v_no := v_no + 1;
    -- Lignes vides ou faites de tabulations seules, et totaux de fin de journal : ignorées, ce ne sont pas des écritures (AN-06).
    if btrim(v_line, E' \t') = '' or v_line ~* '^\s*total\M' then continue; end if;
    cols := string_to_array(v_line, E'\t');
    -- En-têtes
    m := regexp_match(cols[1], '^JOURNAL\s*<([^>]+)>\s*(.*)$');
    if m is not null then
      update public.import_batches set source_journal = m[1], source_label = nullif(trim(m[2]), '') where id = p_batch;
      continue;
    end if;
    m := regexp_match(cols[1], '^Pi[èe]ces du (\d{2}/\d{2}/\d{4})\s+au (\d{2}/\d{2}/\d{4})');
    if m is not null then
      update public.import_batches set period_from = public.perfecto_parse_date(m[1]), period_to = public.perfecto_parse_date(m[2]) where id = p_batch;
      continue;
    end if;
    if cols[1] ~ '^Date$' or cols[1] ~ '^Total Journal' then continue; end if;
    -- Sous-total : contrôle d''équilibre de la pièce
    if cols[1] ~ '^Sous-total' then
      v_pieces := v_pieces + 1;
      v_debit := public.perfecto_parse_amount(cols[5]); v_credit := public.perfecto_parse_amount(cols[6]);
      if v_sum_d <> v_sum_c or round(v_debit) <> round(v_raw_d) or round(v_credit) <> round(v_raw_c) then
        v_subtotal_errors := v_subtotal_errors + 1;
        v_errors := v_errors || jsonb_build_object('line', v_no, 'piece', v_current_piece, 'error',
                      format('Sous-total incohérent : lignes %s / %s, annoncé %s / %s', round(v_raw_d), round(v_raw_c), round(v_debit), round(v_credit)));
      end if;
      v_sum_d := 0; v_sum_c := 0; v_raw_d := 0; v_raw_c := 0; v_current_piece := null;
      continue;
    end if;
    -- Ligne de données
    if array_length(cols, 1) < 6 then
      v_errors := v_errors || jsonb_build_object('line', v_no, 'error', 'Ligne illisible (moins de 6 colonnes)');
      continue;
    end if;
    v_date := public.perfecto_parse_date(cols[1]);
    if v_date is null then
      v_errors := v_errors || jsonb_build_object('line', v_no, 'error', 'Date illisible : ' || cols[1]);
      continue;
    end if;
    v_piece := trim(cols[2]);
    v_debit := public.perfecto_parse_amount(cols[5]); v_credit := public.perfecto_parse_amount(cols[6]);
    -- Normalisation : montants entiers FCFA, négatifs convertis en sens inverse
    nd := round(v_debit); nc := round(v_credit);
    if nd < 0 then nc := nc - nd; nd := 0; end if;
    if nc < 0 then nd := nd - nc; nc := 0; end if;
    v_data := v_data + 1;
    v_current_piece := v_piece;
    v_sum_d := v_sum_d + nd; v_sum_c := v_sum_c + nc; v_raw_d := v_raw_d + v_debit; v_raw_c := v_raw_c + v_credit;
    insert into public.import_lines (batch_id, line_no, piece_ref, entry_date, raw_account, raw_label, label, raw_debit, raw_credit, debit, credit)
    values (p_batch, v_no, v_piece, v_date, trim(cols[3]), nullif(trim(cols[4]), ''), nullif(trim(coalesce(cols[7], '')), ''), v_debit, v_credit, nd, nc);
  end loop;

  update public.import_batches
     set status = 'parsed',
         report = jsonb_build_object('lines', v_data, 'pieces', v_pieces, 'subtotal_errors', v_subtotal_errors, 'parse_errors', v_errors)
   where id = p_batch;
  return (select report from public.import_batches where id = p_batch);
end $$;
