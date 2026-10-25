-- =============================================================================
-- Akonta — Migration 0008 : import Perfecto (module 10, conception §3.7, §10.10)
-- Lots d''import, lignes brutes, table de correspondance éditable, analyse du
-- texte Perfecto (tabulations), scission des comptes de tiers collés,
-- conversion des montants négatifs, contrôles, mode essai, écritures en brouillard.
-- =============================================================================

create type public.import_kind as enum ('journal', 'balance', 'aux_balance', 'open_invoices');
create type public.import_status as enum ('created', 'parsed', 'mapped', 'dry_run', 'applied', 'cancelled');
create type public.import_line_status as enum ('pending', 'mapped', 'error', 'applied');

create table public.import_batches (
  id                 uuid primary key default gen_random_uuid(),
  cabinet_id         uuid not null references public.cabinets (id) on delete cascade,
  entity_id          uuid not null references public.entities (id) on delete cascade,
  kind               public.import_kind not null,
  source_file_name   text,
  source_format      text not null default 'perfecto_txt' check (source_format in ('perfecto_txt', 'csv', 'excel')),
  source_journal     text,                                 -- code du journal dans l''export (ex. BANECO)
  source_label       text,
  period_from        date,
  period_to          date,
  target_journal_id  uuid references public.journals (id),
  status             public.import_status not null default 'created',
  report             jsonb not null default '{}'::jsonb,
  created_by         uuid references public.profiles (id),
  created_at         timestamptz not null default now(),
  applied_at         timestamptz,
  updated_at         timestamptz not null default now()
);
comment on table public.import_batches is 'Lot d''import Perfecto : fichier analysé, correspondances, contrôles, essai puis application en brouillard.';
create index import_batches_entity_idx on public.import_batches (entity_id, created_at desc);
create trigger import_batches_updated_at before update on public.import_batches for each row execute function public.set_updated_at();
create trigger import_batches_cabinet before insert or update on public.import_batches for each row execute function public.check_entity_cabinet();

create table public.import_lines (
  id                      bigint generated always as identity primary key,
  batch_id                uuid not null references public.import_batches (id) on delete cascade,
  line_no                 integer not null,
  piece_ref               text,
  entry_date              date,
  raw_account             text not null,
  raw_label               text,                             -- intitulé du compte dans l''export
  label                   text,                             -- libellé de la ligne
  raw_debit               numeric(18,2) not null default 0,
  raw_credit              numeric(18,2) not null default 0,
  debit                   bigint not null default 0 check (debit >= 0),   -- normalisés : négatifs convertis en sens inverse
  credit                  bigint not null default 0 check (credit >= 0),
  mapped_account_id       uuid references public.accounts (id),
  mapped_third_party_id   uuid references public.third_parties (id),
  status                  public.import_line_status not null default 'pending',
  error                   text,
  unique (batch_id, line_no)
);
create index import_lines_batch_idx on public.import_lines (batch_id, piece_ref);

create table public.import_account_mappings (
  id                  uuid primary key default gen_random_uuid(),
  cabinet_id          uuid not null references public.cabinets (id) on delete cascade,
  entity_id           uuid not null references public.entities (id) on delete cascade,
  raw_account         text not null,
  account_code        text,                                  -- numéro cible dans le plan de l''entité
  third_party_code    text,                                  -- code tiers cible (comptes collés)
  third_party_name    text,                                  -- nom à créer si le tiers n''existe pas
  create_third_party  boolean not null default false,
  note                text,
  updated_by          uuid references public.profiles (id),
  updated_at          timestamptz not null default now(),
  unique (entity_id, raw_account)
);
comment on table public.import_account_mappings is 'Correspondance éditable compte Perfecto → compte (+ tiers) Akonta, mémorisée par entité.';
create trigger import_account_mappings_updated_at before update on public.import_account_mappings for each row execute function public.set_updated_at();
create trigger import_account_mappings_cabinet before insert or update on public.import_account_mappings for each row execute function public.check_entity_cabinet();

-- -----------------------------------------------------------------------------
-- Utilitaires d''analyse
-- -----------------------------------------------------------------------------

-- Scinde un compte Perfecto : « 4110CHU » → (4110, CHU) ; « 401100 » → (401100, null).
create or replace function public.perfecto_split_account(p_raw text, out collective text, out third_party text)
language plpgsql immutable as $$
declare m text[];
begin
  m := regexp_match(upper(trim(p_raw)), '^([1-9][0-9]*)([A-Z][A-Z0-9]*)$');
  if m is not null then
    collective := m[1]; third_party := m[2];
  elsif trim(p_raw) ~ '^[1-9][0-9]*$' then
    collective := trim(p_raw); third_party := null;
  else
    collective := null; third_party := null;
  end if;
end $$;

-- Montant Perfecto → numeric (espaces, espaces insécables, virgule décimale, signe).
create or replace function public.perfecto_parse_amount(p_text text)
returns numeric language sql immutable as $$
  select case when coalesce(trim(p_text), '') = '' then 0
              else replace(replace(replace(replace(trim(p_text), ' ', ''), chr(160), ''), chr(8239), ''), ',', '.')::numeric end;
$$;

create or replace function public.perfecto_parse_date(p_text text)
returns date language sql immutable as $$
  select case when trim(p_text) ~ '^\d{2}/\d{2}/\d{4}$' then to_date(trim(p_text), 'DD/MM/YYYY') end;
$$;

-- Analyse du texte d''un journal Perfecto (déjà décodé de Windows-1252 vers UTF-8).
-- Format §10.10 : en-tête « JOURNAL <CODE> <libellé> », « Pièces du … au … », ligne de titres,
-- lignes Date | N° pièce | Compte | Intitulé | Débit | Crédit | Libellé (tabulations),
-- « Sous-total » après chaque pièce, « Total Journal » en fin. Montants négatifs → sens inverse.
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
    if trim(v_line) = '' then continue; end if;
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

-- Chargement de lignes déjà structurées (CSV / Excel analysés côté application, ou balance).
create or replace function public.import_load_lines(p_batch uuid, p_lines jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare v_batch public.import_batches%rowtype; l jsonb; v_no int := 0; nd bigint; nc bigint;
begin
  select * into v_batch from public.import_batches where id = p_batch for update;
  if v_batch.id is null then raise exception 'Lot inconnu' using errcode = 'P0002'; end if;
  if v_batch.status not in ('created', 'parsed') then raise exception 'Lot déjà traité' using errcode = '23514'; end if;
  if auth.uid() is not null and not public.has_permission(v_batch.entity_id, 'import.perfecto') then
    raise exception 'Permission refusée : importer depuis Perfecto' using errcode = '42501';
  end if;
  delete from public.import_lines where batch_id = p_batch;
  for l in select * from jsonb_array_elements(p_lines) loop
    v_no := v_no + 1;
    nd := round(coalesce((l->>'debit')::numeric, 0)); nc := round(coalesce((l->>'credit')::numeric, 0));
    if nd < 0 then nc := nc - nd; nd := 0; end if;
    if nc < 0 then nd := nd - nc; nc := 0; end if;
    insert into public.import_lines (batch_id, line_no, piece_ref, entry_date, raw_account, raw_label, label, raw_debit, raw_credit, debit, credit)
    values (p_batch, v_no, l->>'piece', (l->>'date')::date, trim(l->>'account'), l->>'account_label', l->>'label',
            coalesce((l->>'debit')::numeric, 0), coalesce((l->>'credit')::numeric, 0), nd, nc);
  end loop;
  update public.import_batches set status = 'parsed', report = jsonb_build_object('lines', v_no) where id = p_batch;
  return v_no;
end $$;

-- Propose les correspondances pour chaque compte brut du lot (D-004) et les mémorise ; renvoie le nombre de comptes à vérifier.
create or replace function public.import_propose_mappings(p_batch uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_batch public.import_batches%rowtype; v_len int; r record; s record;
  v_code text; v_unknown int := 0; v_total int := 0; v_toolong int := 0; v_new_tp int := 0;
begin
  select * into v_batch from public.import_batches where id = p_batch for update;
  if auth.uid() is not null and not public.has_permission(v_batch.entity_id, 'import.perfecto') then
    raise exception 'Permission refusée : importer depuis Perfecto' using errcode = '42501';
  end if;
  select account_length into v_len from public.entities where id = v_batch.entity_id;
  for r in select raw_account, min(raw_label) as raw_label from public.import_lines where batch_id = p_batch group by raw_account loop
    v_total := v_total + 1;
    select * into s from public.perfecto_split_account(r.raw_account);
    if s.collective is null then
      v_unknown := v_unknown + 1;
      insert into public.import_account_mappings (cabinet_id, entity_id, raw_account, note, updated_by)
      values (v_batch.cabinet_id, v_batch.entity_id, r.raw_account, 'Compte illisible : à renseigner', auth.uid())
      on conflict (entity_id, raw_account) do nothing;
      continue;
    end if;
    if length(s.collective) > v_len then
      v_toolong := v_toolong + 1;
      insert into public.import_account_mappings (cabinet_id, entity_id, raw_account, note, updated_by)
      values (v_batch.cabinet_id, v_batch.entity_id, r.raw_account, format('Numéro plus long que la longueur du plan (%s) : à renseigner', v_len), auth.uid())
      on conflict (entity_id, raw_account) do nothing;
      continue;
    end if;
    v_code := public.pad_account_code(s.collective, v_len);
    if not exists (select 1 from public.accounts a where a.entity_id = v_batch.entity_id and a.code = v_code) then
      v_unknown := v_unknown + 1;
    end if;
    if s.third_party is not null and not exists (select 1 from public.third_parties t where t.entity_id = v_batch.entity_id and t.code = s.third_party) then
      v_new_tp := v_new_tp + 1;
    end if;
    insert into public.import_account_mappings (cabinet_id, entity_id, raw_account, account_code, third_party_code, third_party_name, create_third_party, updated_by)
    values (v_batch.cabinet_id, v_batch.entity_id, r.raw_account, v_code, s.third_party,
            case when s.third_party is not null then coalesce(r.raw_label, s.third_party) end,
            s.third_party is not null and not exists (select 1 from public.third_parties t where t.entity_id = v_batch.entity_id and t.code = s.third_party),
            auth.uid())
    on conflict (entity_id, raw_account) do nothing;   -- une correspondance déjà éditée est conservée
  end loop;
  update public.import_batches set status = 'mapped',
         report = report || jsonb_build_object('accounts', v_total, 'unknown_accounts', v_unknown, 'too_long', v_toolong, 'new_third_parties', v_new_tp)
   where id = p_batch;
  return (select report from public.import_batches where id = p_batch);
end $$;

-- Applique le lot : contrôles (correspondances, comptes, équilibre par pièce), création des tiers,
-- écritures en brouillard marquées « générée ». p_dry_run = true : rapport seulement, aucune écriture.
create or replace function public.import_apply(p_batch uuid, p_dry_run boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_batch public.import_batches%rowtype;
  v_len int; v_journal uuid; v_fy public.fiscal_years%rowtype;
  r record; p record;
  v_errors jsonb := '[]'::jsonb; v_entries int := 0; v_tp_created int := 0; v_lines int := 0;
  v_account uuid; v_tp uuid; v_entry uuid; v_collective boolean;
  v_entity_match int;
begin
  select * into v_batch from public.import_batches where id = p_batch for update;
  if v_batch.id is null then raise exception 'Lot inconnu' using errcode = 'P0002'; end if;
  if v_batch.status in ('applied', 'cancelled') then raise exception 'Lot déjà appliqué ou annulé' using errcode = '23514'; end if;
  if auth.uid() is not null and not public.has_permission(v_batch.entity_id, 'import.perfecto') then
    raise exception 'Permission refusée : importer depuis Perfecto' using errcode = '42501';
  end if;
  select account_length into v_len from public.entities where id = v_batch.entity_id;

  -- Journal cible : celui du lot, sinon le journal AN pour une balance
  v_journal := v_batch.target_journal_id;
  if v_journal is null and v_batch.kind in ('balance', 'aux_balance') then
    select id into v_journal from public.journals where entity_id = v_batch.entity_id and type = 'opening';
  end if;
  if v_journal is null then
    raise exception 'Journal cible non défini' using errcode = '23514';
  end if;

  -- 1. Résolution des comptes et tiers ligne par ligne
  update public.import_lines set mapped_account_id = null, mapped_third_party_id = null, status = 'pending', error = null where batch_id = p_batch;
  for r in select l.id, l.line_no, l.raw_account, l.piece_ref, m.account_code, m.third_party_code, m.third_party_name, m.create_third_party
             from public.import_lines l
             left join public.import_account_mappings m on m.entity_id = v_batch.entity_id and m.raw_account = l.raw_account
            where l.batch_id = p_batch loop
    if r.account_code is null then
      update public.import_lines set status = 'error', error = 'Aucune correspondance pour ' || r.raw_account where id = r.id;
      v_errors := v_errors || jsonb_build_object('line', r.line_no, 'error', 'Aucune correspondance pour ' || r.raw_account);
      continue;
    end if;
    select id, is_collective into v_account, v_collective from public.accounts
     where entity_id = v_batch.entity_id and code = r.account_code and is_active;
    if v_account is null then
      update public.import_lines set status = 'error', error = 'Compte inexistant : ' || r.account_code where id = r.id;
      v_errors := v_errors || jsonb_build_object('line', r.line_no, 'error', 'Compte inexistant : ' || r.account_code);
      continue;
    end if;
    v_tp := null;
    if r.third_party_code is not null then
      select id into v_tp from public.third_parties where entity_id = v_batch.entity_id and code = r.third_party_code;
      if v_tp is null then
        if r.create_third_party and not p_dry_run then
          insert into public.third_parties (cabinet_id, entity_id, code, name, type)
          values (v_batch.cabinet_id, v_batch.entity_id, r.third_party_code, coalesce(r.third_party_name, r.third_party_code),
                  (case when r.account_code like '41%' then 'customer' when r.account_code like '40%' then 'supplier'
                        when r.account_code like '42%' then 'employee' else 'other' end)::public.third_party_type)
          returning id into v_tp;
          insert into public.third_party_accounts (third_party_id, account_id) values (v_tp, v_account) on conflict do nothing;
          v_tp_created := v_tp_created + 1;
        elsif r.create_third_party then
          v_tp_created := v_tp_created + 1;   -- serait créé
        else
          update public.import_lines set status = 'error', error = 'Tiers inexistant : ' || r.third_party_code where id = r.id;
          v_errors := v_errors || jsonb_build_object('line', r.line_no, 'error', 'Tiers inexistant : ' || r.third_party_code);
          continue;
        end if;
      elsif not exists (select 1 from public.third_party_accounts where third_party_id = v_tp and account_id = v_account) and not p_dry_run then
        insert into public.third_party_accounts (third_party_id, account_id) values (v_tp, v_account) on conflict do nothing;
      end if;
    elsif v_collective then
      update public.import_lines set status = 'error', error = 'Tiers manquant sur le collectif ' || r.account_code where id = r.id;
      v_errors := v_errors || jsonb_build_object('line', r.line_no, 'error', 'Tiers manquant sur le collectif ' || r.account_code);
      continue;
    end if;
    update public.import_lines set mapped_account_id = v_account, mapped_third_party_id = v_tp, status = 'mapped' where id = r.id;
  end loop;

  -- 2. Équilibre par pièce (journal) ou global (balance)
  for p in select coalesce(piece_ref, '(balance)') as piece, min(entry_date) as d, sum(debit) as sd, sum(credit) as sc, count(*) as n,
                  bool_and(status = 'mapped') as all_mapped, min(line_no) as first_line
             from public.import_lines where batch_id = p_batch
            group by coalesce(piece_ref, '(balance)') order by min(line_no) loop
    if p.sd <> p.sc then
      v_errors := v_errors || jsonb_build_object('piece', p.piece, 'error', format('Pièce déséquilibrée : %s / %s', p.sd, p.sc));
      continue;
    end if;
    if not p.all_mapped then continue; end if;
    v_lines := v_lines + p.n;
    if p_dry_run then v_entries := v_entries + 1; continue; end if;
    -- Date d''écriture : celle de la pièce ; une balance s''inscrit au premier jour de l''exercice
    if v_batch.kind in ('balance', 'aux_balance') then
      select * into v_fy from public.fiscal_years where entity_id = v_batch.entity_id order by start_date desc limit 1;
      p.d := v_fy.start_date;
    end if;
    insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, reference, label,
                                is_generated, generated_source, created_by)
    values (v_batch.cabinet_id, v_batch.entity_id,
            (select id from public.fiscal_years where entity_id = v_batch.entity_id and p.d between start_date and end_date),
            (select id from public.periods where entity_id = v_batch.entity_id and p.d between start_date and end_date),
            v_journal, p.d, nullif(p.piece, '(balance)'),
            case when v_batch.kind in ('balance', 'aux_balance') then 'À-nouveaux importés de Perfecto'
                 else coalesce((select min(label) from public.import_lines where batch_id = p_batch and piece_ref = p.piece), 'Import Perfecto pièce ' || p.piece) end,
            true, 'perfecto:' || p_batch::text, auth.uid())
    returning id into v_entry;
    insert into public.entry_lines (cabinet_id, entity_id, entry_id, line_no, account_id, third_party_id, label, debit, credit)
    select v_batch.cabinet_id, v_batch.entity_id, v_entry, row_number() over (order by line_no), mapped_account_id, mapped_third_party_id,
           coalesce(label, raw_label), debit, credit
      from public.import_lines where batch_id = p_batch and coalesce(piece_ref, '(balance)') = p.piece;
    update public.import_lines set status = 'applied' where batch_id = p_batch and coalesce(piece_ref, '(balance)') = p.piece;
    v_entries := v_entries + 1;
  end loop;

  -- 3. Rapport et statut
  update public.import_batches
     set status = (case when p_dry_run then 'dry_run' else 'applied' end)::public.import_status,
         applied_at = case when p_dry_run then null else now() end,
         report = report || jsonb_build_object('dry_run', p_dry_run, 'entries', v_entries, 'lines_applied', v_lines,
                                               'third_parties_created', v_tp_created, 'errors', v_errors, 'error_count', jsonb_array_length(v_errors))
   where id = p_batch;
  if not p_dry_run then
    insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
    values (v_batch.cabinet_id, auth.uid(), 'import_apply', 'import_batches', p_batch::text, v_batch.entity_id,
            jsonb_build_object('entries', v_entries, 'errors', jsonb_array_length(v_errors)));
  end if;
  return (select report from public.import_batches where id = p_batch);
end $$;

-- Cohérence balance générale ↔ balance auxiliaire d''un lot (§10.10) : écarts par collectif.
create or replace function public.import_check_aux_consistency(p_general uuid, p_aux uuid)
returns table (account_code text, general_balance bigint, auxiliary_balance bigint, difference bigint)
language sql stable security definer set search_path = public as $$
  with g as (
    select m.account_code, sum(l.debit) - sum(l.credit) as bal
      from public.import_lines l join public.import_batches b on b.id = l.batch_id
      join public.import_account_mappings m on m.entity_id = b.entity_id and m.raw_account = l.raw_account
     where l.batch_id = p_general group by m.account_code
  ), a as (
    select m.account_code, sum(l.debit) - sum(l.credit) as bal
      from public.import_lines l join public.import_batches b on b.id = l.batch_id
      join public.import_account_mappings m on m.entity_id = b.entity_id and m.raw_account = l.raw_account
     where l.batch_id = p_aux group by m.account_code
  )
  select coalesce(g.account_code, a.account_code), coalesce(g.bal, 0)::bigint, coalesce(a.bal, 0)::bigint, (coalesce(g.bal, 0) - coalesce(a.bal, 0))::bigint
    from g full join a on a.account_code = g.account_code
   where coalesce(g.bal, 0) <> coalesce(a.bal, 0)
   order by 1;
$$;

-- Journalisation et RLS
create trigger audit_import_batches after insert or update on public.import_batches
  for each row when (pg_trigger_depth() = 0) execute function public.audit_row_change();

alter table public.import_batches          enable row level security;
alter table public.import_lines            enable row level security;
alter table public.import_account_mappings enable row level security;

create policy import_batches_rw on public.import_batches for all to authenticated
  using (public.has_permission(entity_id, 'import.perfecto'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'import.perfecto'));
create policy import_lines_rw on public.import_lines for all to authenticated
  using (exists (select 1 from public.import_batches b where b.id = batch_id and public.has_permission(b.entity_id, 'import.perfecto')))
  with check (exists (select 1 from public.import_batches b where b.id = batch_id and public.has_permission(b.entity_id, 'import.perfecto')));
create policy import_account_mappings_rw on public.import_account_mappings for all to authenticated
  using (public.has_permission(entity_id, 'import.perfecto'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'import.perfecto'));

revoke execute on function public.import_parse_perfecto_journal(uuid, text), public.import_load_lines(uuid, jsonb),
  public.import_propose_mappings(uuid), public.import_apply(uuid, boolean), public.import_check_aux_consistency(uuid, uuid) from public, anon;
grant execute on function public.import_parse_perfecto_journal(uuid, text), public.import_load_lines(uuid, jsonb),
  public.import_propose_mappings(uuid), public.import_apply(uuid, boolean), public.import_check_aux_consistency(uuid, uuid) to authenticated;
