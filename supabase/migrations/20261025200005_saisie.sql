-- =============================================================================
-- Akonta — Migration 0005 : saisie (module 4, conception §4, §10.4, §11.2)
-- Écritures et lignes, séquences par journal et exercice, validation transactionnelle
-- (équilibre, période, comptes, numéro sans trou), immutabilité, contre-passation,
-- revue, devises, notifications.
-- =============================================================================

create extension if not exists pg_trgm with schema extensions;

create type public.entry_status as enum ('draft', 'validated');
create type public.review_status as enum ('not_reviewed', 'reviewed', 'to_correct');

-- Indicateur de session : les transitions réservées (validation, revue, contre-passation)
-- ne sont acceptées par les déclencheurs que lorsqu''une fonction interne les porte.
create or replace function public.internal_mode()
returns boolean language sql stable as $$
  select coalesce(current_setting('akonta.internal', true), '') = 'on';
$$;

-- -----------------------------------------------------------------------------
-- Écritures
-- -----------------------------------------------------------------------------
create table public.entries (
  id               uuid primary key default gen_random_uuid(),
  cabinet_id       uuid not null references public.cabinets (id) on delete cascade,
  entity_id        uuid not null references public.entities (id) on delete cascade,
  fiscal_year_id   uuid not null references public.fiscal_years (id),
  period_id        uuid not null references public.periods (id),
  journal_id       uuid not null references public.journals (id),
  entry_date       date not null,
  number           bigint,                                  -- attribué à la validation, séquence par journal et exercice
  reference        text,                                    -- référence du justificatif
  label            text not null check (length(trim(label)) >= 1),
  status           public.entry_status not null default 'draft',
  review_status    public.review_status not null default 'not_reviewed',
  review_comment   text,
  reviewed_by      uuid references public.profiles (id),
  reviewed_at      timestamptz,
  currency_code    char(3) not null default 'XOF',
  is_generated     boolean not null default false,          -- écriture générée (inventaire, import, à-nouveaux…)
  generated_source text,
  reversal_of      uuid references public.entries (id),      -- écriture contre-passée par celle-ci
  reversed_by      uuid references public.entries (id),      -- écriture qui contre-passe celle-ci
  reversal_reason  text,
  created_by       uuid references public.profiles (id),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  validated_by     uuid references public.profiles (id),
  validated_at     timestamptz,
  check (status = 'draft' or number is not null),
  check (reversal_of is null or reversal_reason is not null)
);
comment on table public.entries is 'Écriture comptable : brouillard puis validée (numéro séquentiel par journal et exercice, sans trou). Immuable une fois validée.';
create unique index entries_number_unique on public.entries (journal_id, fiscal_year_id, number) where number is not null;
create index entries_entity_date_idx on public.entries (entity_id, entry_date);
create index entries_entity_status_idx on public.entries (entity_id, status, review_status);
create index entries_journal_idx on public.entries (journal_id, entry_date);
create index entries_label_trgm on public.entries using gin (label extensions.gin_trgm_ops);
create trigger entries_updated_at before update on public.entries for each row execute function public.set_updated_at();

create table public.journal_sequences (
  journal_id      uuid not null references public.journals (id) on delete cascade,
  fiscal_year_id  uuid not null references public.fiscal_years (id) on delete cascade,
  last_number     bigint not null default 0,
  primary key (journal_id, fiscal_year_id)
);
comment on table public.journal_sequences is 'Dernier numéro attribué par journal et par exercice (verrouillé ligne par ligne à la validation).';

-- -----------------------------------------------------------------------------
-- Lignes
-- -----------------------------------------------------------------------------
create table public.entry_lines (
  id               uuid primary key default gen_random_uuid(),
  cabinet_id       uuid not null references public.cabinets (id) on delete cascade,
  entity_id        uuid not null references public.entities (id) on delete cascade,
  entry_id         uuid not null references public.entries (id) on delete cascade,
  line_no          smallint not null check (line_no between 1 and 500),
  account_id       uuid not null references public.accounts (id),
  third_party_id   uuid references public.third_parties (id),
  label            text,
  debit            bigint not null default 0 check (debit >= 0),
  credit           bigint not null default 0 check (credit >= 0),
  currency_code    char(3) not null default 'XOF',
  amount_currency  numeric(18,2) check (amount_currency is null or amount_currency > 0),
  exchange_rate    numeric(18,6) check (exchange_rate is null or exchange_rate > 0),
  created_at       timestamptz not null default now(),
  unique (entry_id, line_no),
  check ((debit > 0 and credit = 0) or (credit > 0 and debit = 0)),                 -- débit OU crédit, strictement positif
  check ((currency_code = 'XOF' and amount_currency is null and exchange_rate is null)
         or (currency_code <> 'XOF' and amount_currency is not null and exchange_rate is not null))
);
comment on table public.entry_lines is 'Ligne d''écriture : compte (+ tiers si collectif), débit ou crédit en FCFA entiers ; devise, montant et cours conservés.';
create index entry_lines_entry_idx on public.entry_lines (entry_id, line_no);
create index entry_lines_account_idx on public.entry_lines (account_id, entry_id);
create index entry_lines_third_party_idx on public.entry_lines (third_party_id) where third_party_id is not null;
create index entry_lines_entity_account_idx on public.entry_lines (entity_id, account_id);

-- -----------------------------------------------------------------------------
-- Déclencheurs : cohérence et immutabilité des écritures
-- -----------------------------------------------------------------------------
create or replace function public.entries_before_write()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_fy public.fiscal_years%rowtype;
  v_journal public.journals%rowtype;
begin
  if tg_op = 'UPDATE' then
    if old.status = 'validated' then
      -- Écriture validée : seules les fonctions internes touchent la revue et le lien de contre-passation.
      if not public.internal_mode() then
        raise exception 'Écriture validée : immuable (correction par contre-passation)' using errcode = '42501';
      end if;
      if new.entry_date <> old.entry_date or new.journal_id <> old.journal_id or new.number <> old.number
         or new.label <> old.label or new.reference is distinct from old.reference or new.status <> old.status
         or new.entity_id <> old.entity_id or new.fiscal_year_id <> old.fiscal_year_id or new.currency_code <> old.currency_code then
        raise exception 'Écriture validée : contenu immuable' using errcode = '42501';
      end if;
      return new;
    end if;
    -- Brouillard : la validation ne passe que par la fonction dédiée.
    if new.status = 'validated' and not public.internal_mode() then
      raise exception 'La validation passe par validate_entry()' using errcode = '42501';
    end if;
    if new.number is not null and not public.internal_mode() then
      raise exception 'Le numéro est attribué à la validation' using errcode = '42501';
    end if;
    if new.entity_id <> old.entity_id or new.cabinet_id <> old.cabinet_id then
      raise exception 'Une écriture ne change pas de dossier' using errcode = '23514';
    end if;
  else
    if new.status <> 'draft' and not public.internal_mode() then
      raise exception 'Une écriture naît en brouillard' using errcode = '42501';
    end if;
    if new.created_by is null then new.created_by := auth.uid(); end if;
  end if;

  -- Journal de l''entité, actif
  select * into v_journal from public.journals where id = new.journal_id;
  if v_journal.id is null or v_journal.entity_id <> new.entity_id then
    raise exception 'Journal inconnu dans ce dossier' using errcode = '23503';
  end if;
  if not v_journal.is_active then
    raise exception 'Journal désactivé' using errcode = '23514';
  end if;
  if new.cabinet_id <> v_journal.cabinet_id then
    raise exception 'Cabinet incohérent' using errcode = '23514';
  end if;
  -- Exercice et période déduits de la date
  select * into v_fy from public.fiscal_years
   where entity_id = new.entity_id and new.entry_date between start_date and end_date;
  if v_fy.id is null then
    raise exception 'Aucun exercice ne couvre la date %', new.entry_date using errcode = '23514';
  end if;
  if v_fy.status = 'closed' then
    raise exception 'Exercice clôturé : intangible' using errcode = '42501';
  end if;
  new.fiscal_year_id := v_fy.id;
  select id into new.period_id from public.periods where fiscal_year_id = v_fy.id and new.entry_date between start_date and end_date;
  if new.currency_code = 'EUR' then null; end if;
  return new;
end $$;

create trigger entries_before_write before insert or update on public.entries
  for each row execute function public.entries_before_write();

create or replace function public.entries_before_delete()
returns trigger language plpgsql as $$
begin
  if old.status = 'validated' then
    raise exception 'Écriture validée : suppression interdite (contre-passation)' using errcode = '42501';
  end if;
  return old;
end $$;
create trigger entries_before_delete before delete on public.entries
  for each row when (pg_trigger_depth() = 0) execute function public.entries_before_delete();

-- Lignes : compte du dossier, tiers cohérent, devise, et parent en brouillard.
create or replace function public.entry_lines_before_write()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_entry public.entries%rowtype;
  v_account public.accounts%rowtype;
  v_fcfa bigint;
begin
  select * into v_entry from public.entries where id = new.entry_id;
  if v_entry.id is null then raise exception 'Écriture inconnue' using errcode = '23503'; end if;
  if v_entry.status = 'validated' and not public.internal_mode() then
    raise exception 'Écriture validée : lignes immuables' using errcode = '42501';
  end if;
  new.entity_id := v_entry.entity_id;
  new.cabinet_id := v_entry.cabinet_id;
  if new.line_no is null then
    select coalesce(max(line_no), 0) + 1 into new.line_no from public.entry_lines where entry_id = new.entry_id;
  end if;
  select * into v_account from public.accounts where id = new.account_id;
  if v_account.id is null or v_account.entity_id <> new.entity_id then
    raise exception 'Compte inconnu dans ce dossier' using errcode = '23503';
  end if;
  if new.third_party_id is not null then
    if not exists (select 1 from public.third_parties t where t.id = new.third_party_id and t.entity_id = new.entity_id) then
      raise exception 'Tiers inconnu dans ce dossier' using errcode = '23503';
    end if;
    if not v_account.is_collective then
      raise exception 'Un tiers ne s''impute que sur un compte collectif' using errcode = '23514';
    end if;
  end if;
  -- Devises : euro à parité fixe ; contre-valeur FCFA arrondie à l''unité (écart d''arrondi toléré : 1)
  if new.currency_code <> 'XOF' then
    if new.currency_code = 'EUR' and new.exchange_rate <> 655.957 then
      raise exception 'L''euro est à parité fixe : 655,957' using errcode = '23514';
    end if;
    v_fcfa := round(new.amount_currency * new.exchange_rate);
    if abs(greatest(new.debit, new.credit) - v_fcfa) > 1 then
      raise exception 'Contre-valeur FCFA incohérente (% attendu)', v_fcfa using errcode = '23514';
    end if;
  end if;
  if coalesce(new.label, '') = '' then new.label := v_entry.label; end if;
  return new;
end $$;

create trigger entry_lines_before_write before insert or update on public.entry_lines
  for each row execute function public.entry_lines_before_write();

create or replace function public.entry_lines_before_delete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.entries e where e.id = old.entry_id and e.status = 'validated') then
    raise exception 'Écriture validée : lignes immuables' using errcode = '42501';
  end if;
  return old;
end $$;
create trigger entry_lines_before_delete before delete on public.entry_lines
  for each row when (pg_trigger_depth() = 0) execute function public.entry_lines_before_delete();

-- Un compte mouvementé ne se supprime pas (§10.3) ; un tiers mouvementé non plus.
create or replace function public.accounts_guard_delete()
returns trigger language plpgsql as $$
begin
  if exists (select 1 from public.accounts where parent_id = old.id) then
    raise exception 'Ce compte a des subdivisions : désactivez-le plutôt' using errcode = '23503';
  end if;
  if exists (select 1 from public.entry_lines where account_id = old.id) then
    raise exception 'Ce compte a des mouvements : désactivez-le plutôt' using errcode = '23503';
  end if;
  return old;
end $$;

-- -----------------------------------------------------------------------------
-- Droits d''édition d''un brouillard : son auteur, ou un réviseur
-- -----------------------------------------------------------------------------
create or replace function public.can_edit_draft(p_entry uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.entries e
     where e.id = p_entry and e.status = 'draft'
       and public.has_permission(e.entity_id, 'entries.draft')
       and (e.created_by = auth.uid() or public.has_permission(e.entity_id, 'entries.review'))
  );
$$;

-- -----------------------------------------------------------------------------
-- Validation : contrôles puis numéro séquentiel dans la même transaction (§11.2)
-- -----------------------------------------------------------------------------
create or replace function public.validate_entry(p_entry uuid)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  v_entry public.entries%rowtype;
  v_debit bigint; v_credit bigint; v_lines int;
  v_bad text;
  v_number bigint;
begin
  select * into v_entry from public.entries where id = p_entry for update;
  if v_entry.id is null then raise exception 'Écriture inconnue' using errcode = 'P0002'; end if;
  if v_entry.status <> 'draft' then
    raise exception 'Écriture déjà validée (n° %)', v_entry.number using errcode = '23514';
  end if;
  if auth.uid() is not null then
    if not public.has_permission(v_entry.entity_id, 'entries.validate') then
      raise exception 'Permission refusée : valider des écritures' using errcode = '42501';
    end if;
    if v_entry.created_by <> auth.uid() and not public.has_permission(v_entry.entity_id, 'entries.review') then
      raise exception 'Vous ne validez que vos propres écritures' using errcode = '42501';
    end if;
  end if;
  -- Période ouverte
  if not public.period_open_for(v_entry.entity_id, v_entry.entry_date) then
    raise exception 'La date % n''est pas dans une période ouverte', v_entry.entry_date using errcode = '23514';
  end if;
  -- Lignes : au moins deux, équilibre, comptes actifs et imputables, tiers sur collectif
  select count(*), coalesce(sum(debit), 0), coalesce(sum(credit), 0) into v_lines, v_debit, v_credit
    from public.entry_lines where entry_id = p_entry;
  if v_lines < 2 then
    raise exception 'Une écriture comporte au moins deux lignes' using errcode = '23514';
  end if;
  if v_debit <> v_credit then
    raise exception 'Écriture déséquilibrée : débit % ≠ crédit %', v_debit, v_credit using errcode = '23514';
  end if;
  select string_agg(a.code, ', ') into v_bad
    from public.entry_lines l join public.accounts a on a.id = l.account_id
   where l.entry_id = p_entry and (not a.is_active or not a.allow_posting);
  if v_bad is not null then
    raise exception 'Comptes inactifs ou non imputables : %', v_bad using errcode = '23514';
  end if;
  select string_agg(a.code, ', ') into v_bad
    from public.entry_lines l join public.accounts a on a.id = l.account_id
   where l.entry_id = p_entry and a.is_collective and l.third_party_id is null;
  if v_bad is not null then
    raise exception 'Tiers obligatoire sur les comptes collectifs : %', v_bad using errcode = '23514';
  end if;
  -- Numéro séquentiel : verrou sur la séquence du journal pour l''exercice
  insert into public.journal_sequences (journal_id, fiscal_year_id, last_number)
  values (v_entry.journal_id, v_entry.fiscal_year_id, 0)
  on conflict (journal_id, fiscal_year_id) do nothing;
  select last_number + 1 into v_number from public.journal_sequences
   where journal_id = v_entry.journal_id and fiscal_year_id = v_entry.fiscal_year_id for update;
  update public.journal_sequences set last_number = v_number
   where journal_id = v_entry.journal_id and fiscal_year_id = v_entry.fiscal_year_id;

  perform set_config('akonta.internal', 'on', true);
  update public.entries
     set status = 'validated', number = v_number, validated_by = auth.uid(), validated_at = now()
   where id = p_entry;
  perform set_config('akonta.internal', 'off', true);

  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_entry.cabinet_id, auth.uid(), 'validate', 'entries', p_entry::text, v_entry.entity_id,
          jsonb_build_object('number', v_number, 'journal_id', v_entry.journal_id, 'entry_date', v_entry.entry_date,
                             'debit', v_debit, 'credit', v_credit,
                             'lines', (select jsonb_agg(jsonb_build_object('account', a.code, 'third_party', t.code, 'debit', l.debit, 'credit', l.credit) order by l.line_no)
                                         from public.entry_lines l join public.accounts a on a.id = l.account_id
                                         left join public.third_parties t on t.id = l.third_party_id where l.entry_id = p_entry)));
  return v_number;
end $$;

-- Validation par lot : tout ou rien.
create or replace function public.validate_entries(p_entries uuid[])
returns table (entry_id uuid, number bigint) language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  foreach v in array p_entries loop
    entry_id := v; number := public.validate_entry(v);
    return next;
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- Contre-passation : écriture inverse liée, dans une période ouverte, motif obligatoire
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- Revue par le chef de mission (§10.4) et notification à l''auteur
-- -----------------------------------------------------------------------------
create table public.notifications (
  id          bigint generated always as identity primary key,
  cabinet_id  uuid not null references public.cabinets (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  entity_id   uuid references public.entities (id) on delete cascade,
  kind        text not null,
  payload     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  read_at     timestamptz
);
create index notifications_user_idx on public.notifications (user_id, read_at, created_at desc);

create or replace function public.review_entry(p_entry uuid, p_status public.review_status, p_comment text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_entry public.entries%rowtype;
begin
  select * into v_entry from public.entries where id = p_entry for update;
  if v_entry.id is null then raise exception 'Écriture inconnue' using errcode = 'P0002'; end if;
  if v_entry.status <> 'validated' then
    raise exception 'La revue porte sur les écritures validées' using errcode = '23514';
  end if;
  if auth.uid() is not null and not public.has_permission(v_entry.entity_id, 'entries.review') then
    raise exception 'Permission refusée : revue des écritures' using errcode = '42501';
  end if;
  if p_status = 'to_correct' and coalesce(trim(p_comment), '') = '' then
    raise exception 'Un commentaire est obligatoire pour « à corriger »' using errcode = '23514';
  end if;
  perform set_config('akonta.internal', 'on', true);
  update public.entries
     set review_status = p_status, review_comment = p_comment,
         reviewed_by = case when p_status = 'not_reviewed' then null else auth.uid() end,
         reviewed_at = case when p_status = 'not_reviewed' then null else now() end
   where id = p_entry;
  perform set_config('akonta.internal', 'off', true);
  if p_status = 'to_correct' and v_entry.created_by is not null then
    insert into public.notifications (cabinet_id, user_id, entity_id, kind, payload)
    values (v_entry.cabinet_id, v_entry.created_by, v_entry.entity_id, 'entry_to_correct',
            jsonb_build_object('entry_id', p_entry, 'number', v_entry.number, 'comment', p_comment));
  end if;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_entry.cabinet_id, auth.uid(), 'review', 'entries', p_entry::text, v_entry.entity_id,
          jsonb_build_object('review_status', p_status, 'comment', p_comment));
end $$;

-- -----------------------------------------------------------------------------
-- Journalisation et RLS
-- -----------------------------------------------------------------------------
create trigger audit_entries after insert or update or delete on public.entries
  for each row when (pg_trigger_depth() = 0) execute function public.audit_row_change();

alter table public.entries           enable row level security;
alter table public.entry_lines       enable row level security;
alter table public.journal_sequences enable row level security;
alter table public.notifications     enable row level security;

create policy entries_select on public.entries for select to authenticated using (public.can_access_entity(entity_id));
create policy entries_insert on public.entries for insert to authenticated
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'entries.draft')
              and status = 'draft' and created_by = auth.uid());
create policy entries_update on public.entries for update to authenticated
  using (public.can_edit_draft(id)) with check (status = 'draft' and public.has_permission(entity_id, 'entries.draft'));
create policy entries_delete on public.entries for delete to authenticated using (public.can_edit_draft(id));

create policy entry_lines_select on public.entry_lines for select to authenticated using (public.can_access_entity(entity_id));
create policy entry_lines_write on public.entry_lines for all to authenticated
  using (public.can_edit_draft(entry_id)) with check (public.can_edit_draft(entry_id));

create policy journal_sequences_select on public.journal_sequences for select to authenticated
  using (exists (select 1 from public.journals j where j.id = journal_id and public.can_access_entity(j.entity_id)));

create policy notifications_select on public.notifications for select to authenticated using (user_id = auth.uid());
create policy notifications_update on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke execute on function public.validate_entry(uuid) from public, anon;
revoke execute on function public.validate_entries(uuid[]) from public, anon;
revoke execute on function public.reverse_entry(uuid, text, date, boolean) from public, anon;
revoke execute on function public.review_entry(uuid, public.review_status, text) from public, anon;
grant execute on function public.validate_entry(uuid), public.validate_entries(uuid[]),
                          public.reverse_entry(uuid, text, date, boolean), public.review_entry(uuid, public.review_status, text)
  to authenticated;
