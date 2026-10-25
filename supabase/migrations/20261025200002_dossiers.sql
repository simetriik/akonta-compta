-- =============================================================================
-- Akonta — Migration 0002 : cabinet et dossiers (module 2, conception §3.1, §3.2, §10.2)
-- Entités (fiche R1-R3 + paramètres comptables), dirigeants, historisation,
-- exercices (continuité, statuts), associés de l'exercice, périodes mensuelles
-- avec verrouillage paramétrable.
-- =============================================================================

create extension if not exists btree_gist with schema extensions;

create type public.fiscal_year_status as enum ('open', 'closing', 'closed');
create type public.entity_control_type as enum ('public', 'private');
create type public.entity_control_origin as enum ('national', 'foreign');

-- -----------------------------------------------------------------------------
-- Entités
-- -----------------------------------------------------------------------------

create table public.entities (
  id                    uuid primary key default gen_random_uuid(),
  cabinet_id            uuid not null references public.cabinets (id) on delete cascade,
  -- R1 Identification
  name                  text not null check (length(trim(name)) between 2 and 200),
  acronym               text,
  legal_form            text,
  address               text,
  country_code          char(2) not null default 'BJ',
  tax_id                text,                     -- IFU
  trade_register        text,                     -- RCCM
  tax_regime            text,
  incorporation_date    date,
  establishments_count  smallint check (establishments_count >= 0),
  control_type          public.entity_control_type,
  control_origin        public.entity_control_origin,
  -- R2 Activité
  main_activity         text,
  secondary_activities  text[] not null default '{}',
  activity_code         text,
  -- Paramètres comptables
  accounting_system     text not null default 'normal' check (accounting_system in ('normal')),
  currency_code         char(3) not null default 'XOF',
  account_length        smallint not null check (account_length between 6 and 12),
  monthly_lock_enabled  boolean not null default false,
  is_active             boolean not null default true,
  created_by            uuid references public.profiles (id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
comment on table public.entities is 'Entité (structure permanente). Un dossier = entité + exercice.';

create unique index entities_tax_id_unique on public.entities (cabinet_id, tax_id) where tax_id is not null;
create unique index entities_trade_register_unique on public.entities (cabinet_id, trade_register) where trade_register is not null;
create index entities_cabinet_idx on public.entities (cabinet_id);

create trigger entities_updated_at before update on public.entities
  for each row execute function public.set_updated_at();

-- Longueur des comptes héritée du cabinet si non précisée ; créateur renseigné.
create or replace function public.entities_defaults()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.account_length is null then
    select default_account_length into new.account_length from public.cabinets where id = new.cabinet_id;
  end if;
  if new.created_by is null then new.created_by := auth.uid(); end if;
  new.tax_id := nullif(trim(new.tax_id), '');
  new.trade_register := nullif(trim(new.trade_register), '');
  return new;
end $$;

create trigger entities_defaults before insert on public.entities
  for each row execute function public.entities_defaults();

-- La longueur des comptes ne change plus dès qu''un exercice existe ; les paramètres comptables
-- (longueur, verrouillage mensuel) relèvent de l''associé (« Paramètres cabinet et entité »).
create or replace function public.entities_guard_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.account_length <> old.account_length and exists (select 1 from public.fiscal_years where entity_id = old.id) then
    raise exception 'La longueur des comptes ne peut plus changer : un exercice existe' using errcode = '23514';
  end if;
  if (new.account_length <> old.account_length or new.monthly_lock_enabled <> old.monthly_lock_enabled
      or new.accounting_system <> old.accounting_system or new.currency_code <> old.currency_code)
     and auth.uid() is not null and not public.has_permission(null, 'cabinet.settings') then
    raise exception 'Les paramètres comptables de l''entité sont réservés à l''associé' using errcode = '42501';
  end if;
  new.cabinet_id := old.cabinet_id;
  return new;
end $$;

create trigger entities_guard_update before update on public.entities
  for each row execute function public.entities_guard_update();

-- Le créateur (chef de mission) est affecté au dossier qu''il crée, sauf s''il a déjà accès à tout.
create or replace function public.entities_assign_creator()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_role uuid;
begin
  if auth.uid() is null or public.grants_all_entities() then return new; end if;
  select r.id into v_role from public.roles r where r.cabinet_id = new.cabinet_id and r.code = 'manager';
  if v_role is not null then
    insert into public.assignments (cabinet_id, user_id, entity_id, role_id, created_by)
    values (new.cabinet_id, auth.uid(), new.id, v_role, auth.uid())
    on conflict do nothing;
  end if;
  return new;
end $$;

create trigger entities_assign_creator after insert on public.entities
  for each row execute function public.entities_assign_creator();

-- Lien différé : affectation → entité
alter table public.assignments
  add constraint assignments_entity_fk foreign key (entity_id) references public.entities (id) on delete cascade;

-- Dirigeants et membres du conseil (R3)
create table public.entity_directors (
  id            uuid primary key default gen_random_uuid(),
  cabinet_id    uuid not null references public.cabinets (id) on delete cascade,
  entity_id     uuid not null references public.entities (id) on delete cascade,
  full_name     text not null check (length(trim(full_name)) >= 2),
  position      text not null,          -- qualité (gérant, PDG, administrateur…)
  nationality   text,
  address       text,
  is_board_member boolean not null default false,
  sort_order    smallint not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index entity_directors_entity_idx on public.entity_directors (entity_id);
create trigger entity_directors_updated_at before update on public.entity_directors
  for each row execute function public.set_updated_at();

-- Historisation des modifications de la fiche entité
create table public.entity_history (
  id          bigint generated always as identity primary key,
  cabinet_id  uuid not null,
  entity_id   uuid not null references public.entities (id) on delete cascade,
  changed_at  timestamptz not null default now(),
  changed_by  uuid,
  changes     jsonb not null      -- { "champ": {"old": …, "new": …} }
);
create index entity_history_entity_idx on public.entity_history (entity_id, changed_at desc);

create or replace function public.entities_record_history()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb := to_jsonb(old) - 'updated_at';
  v_new jsonb := to_jsonb(new) - 'updated_at';
  v_changes jsonb := '{}'::jsonb;
  k text;
begin
  for k in select jsonb_object_keys(v_new) loop
    if v_old -> k is distinct from v_new -> k then
      v_changes := v_changes || jsonb_build_object(k, jsonb_build_object('old', v_old -> k, 'new', v_new -> k));
    end if;
  end loop;
  if v_changes <> '{}'::jsonb then
    insert into public.entity_history (cabinet_id, entity_id, changed_by, changes)
    values (new.cabinet_id, new.id, auth.uid(), v_changes);
  end if;
  return null;
end $$;

create trigger entities_history after update on public.entities
  for each row execute function public.entities_record_history();

create or replace function public.entity_history_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'L''historique de la fiche entité est en ajout seul' using errcode = '42501';
end $$;
create trigger entity_history_no_update before update on public.entity_history for each row execute function public.entity_history_immutable();
create trigger entity_history_no_delete before delete on public.entity_history for each row execute function public.entity_history_immutable();

-- -----------------------------------------------------------------------------
-- Exercices
-- -----------------------------------------------------------------------------

create table public.fiscal_years (
  id            uuid primary key default gen_random_uuid(),
  cabinet_id    uuid not null references public.cabinets (id) on delete cascade,
  entity_id     uuid not null references public.entities (id) on delete cascade,
  label         text not null,
  start_date    date not null,
  end_date      date not null,
  status        public.fiscal_year_status not null default 'open',
  capital       bigint check (capital is null or capital >= 0),           -- FCFA entiers
  headcount     integer check (headcount is null or headcount >= 0),
  closed_at     timestamptz,
  closed_by     uuid references public.profiles (id),
  final_closed_at timestamptz,                                           -- arrêté définitif (lot 3)
  final_closed_by uuid references public.profiles (id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (end_date >= start_date),
  check (end_date - start_date < 730),
  unique (entity_id, start_date),
  exclude using gist (entity_id with =, daterange(start_date, end_date, '[]') with &&)
);
comment on table public.fiscal_years is 'Exercice comptable d''une entité : 12 mois civils sauf premier exercice ; sans trou ni chevauchement.';
create index fiscal_years_entity_idx on public.fiscal_years (entity_id, start_date);
create trigger fiscal_years_updated_at before update on public.fiscal_years
  for each row execute function public.set_updated_at();

-- Règles de création : 12 mois (1er janvier – 31 décembre) sauf premier exercice ; continuité avec le précédent.
create or replace function public.fiscal_years_validate()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_prev_end date;
  v_count int;
begin
  if tg_op = 'INSERT' then
    select count(*), max(end_date) into v_count, v_prev_end from public.fiscal_years where entity_id = new.entity_id;
    if v_count > 0 then
      if new.start_date <> v_prev_end + 1 then
        raise exception 'L''exercice doit commencer le lendemain de la fin du précédent (%)', v_prev_end + 1 using errcode = '23514';
      end if;
      if not (extract(month from new.start_date) = 1 and extract(day from new.start_date) = 1
              and new.end_date = make_date(extract(year from new.start_date)::int, 12, 31)) then
        raise exception 'Un exercice courant va du 1er janvier au 31 décembre' using errcode = '23514';
      end if;
    else
      -- Premier exercice : exception de durée, mais il se termine un 31 décembre.
      if not (extract(month from new.end_date) = 12 and extract(day from new.end_date) = 31) then
        raise exception 'Le premier exercice se termine un 31 décembre' using errcode = '23514';
      end if;
    end if;
    if new.cabinet_id <> (select cabinet_id from public.entities where id = new.entity_id) then
      raise exception 'Cabinet incohérent' using errcode = '23514';
    end if;
    if new.label is null or new.label = '' then new.label := to_char(new.end_date, 'YYYY'); end if;
  else
    if old.status = 'closed' then
      raise exception 'Exercice clôturé : intangible' using errcode = '42501';
    end if;
    if new.start_date <> old.start_date or new.end_date <> old.end_date or new.entity_id <> old.entity_id
       or new.cabinet_id <> old.cabinet_id then
      raise exception 'Les dates d''un exercice ne se modifient pas' using errcode = '23514';
    end if;
    -- Transitions de statut : ouvert → en clôture → clôturé ; retour en clôture → ouvert (réouverture) autorisé.
    if new.status <> old.status and not (
         (old.status = 'open' and new.status = 'closing') or
         (old.status = 'closing' and new.status in ('open', 'closed'))) then
      raise exception 'Transition de statut invalide : % → %', old.status, new.status using errcode = '23514';
    end if;
    if new.status = 'closed' and old.status <> 'closed' then
      new.closed_at := now(); new.closed_by := auth.uid();
    end if;
  end if;
  return new;
end $$;

create trigger fiscal_years_validate before insert or update on public.fiscal_years
  for each row execute function public.fiscal_years_validate();

create or replace function public.fiscal_years_no_delete()
returns trigger language plpgsql as $$
begin
  if old.status <> 'open' then
    raise exception 'Un exercice en clôture ou clôturé ne se supprime pas' using errcode = '42501';
  end if;
  return old;
end $$;
create trigger fiscal_years_no_delete before delete on public.fiscal_years
  for each row execute function public.fiscal_years_no_delete();

-- Associés et répartition du capital, rattachés à l''exercice (§3.1)
create table public.fiscal_year_partners (
  id              uuid primary key default gen_random_uuid(),
  cabinet_id      uuid not null references public.cabinets (id) on delete cascade,
  fiscal_year_id  uuid not null references public.fiscal_years (id) on delete cascade,
  name            text not null,
  share_percent   numeric(5,2) not null check (share_percent > 0 and share_percent <= 100),
  created_at      timestamptz not null default now()
);
create index fiscal_year_partners_fy_idx on public.fiscal_year_partners (fiscal_year_id);

-- -----------------------------------------------------------------------------
-- Périodes mensuelles et verrouillage
-- -----------------------------------------------------------------------------

create table public.periods (
  id              uuid primary key default gen_random_uuid(),
  cabinet_id      uuid not null references public.cabinets (id) on delete cascade,
  entity_id       uuid not null references public.entities (id) on delete cascade,
  fiscal_year_id  uuid not null references public.fiscal_years (id) on delete cascade,
  period_no       smallint not null check (period_no between 1 and 24),
  start_date      date not null,
  end_date        date not null,
  is_locked       boolean not null default false,
  locked_at       timestamptz,
  locked_by       uuid references public.profiles (id),
  unlock_reason   text,
  unique (fiscal_year_id, period_no),
  check (end_date >= start_date)
);
comment on table public.periods is 'Périodes mensuelles d''un exercice ; verrouillage paramétrable par entité.';
create index periods_entity_dates_idx on public.periods (entity_id, start_date, end_date);

-- Génération des périodes mensuelles à la création de l''exercice.
create or replace function public.fiscal_years_generate_periods()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_start date := new.start_date;
  v_end date;
  v_no int := 1;
begin
  while v_start <= new.end_date loop
    v_end := least((date_trunc('month', v_start) + interval '1 month - 1 day')::date, new.end_date);
    insert into public.periods (cabinet_id, entity_id, fiscal_year_id, period_no, start_date, end_date)
    values (new.cabinet_id, new.entity_id, new.id, v_no, v_start, v_end);
    v_start := v_end + 1;
    v_no := v_no + 1;
  end loop;
  return new;
end $$;

create trigger fiscal_years_generate_periods after insert on public.fiscal_years
  for each row execute function public.fiscal_years_generate_periods();

-- Verrouillage : associé toujours ; chef de mission si l''option de l''entité est active.
-- Déverrouillage : associé uniquement, motif obligatoire. Les dates et le rattachement sont figés.
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
    if auth.uid() is not null and not (public.has_permission(null, 'cabinet.settings')
         or (v_option and public.has_permission(new.entity_id, 'closing.provisional'))) then
      raise exception 'Verrouillage réservé à l''associé, ou au chef de mission si l''option est active' using errcode = '42501';
    end if;
    new.locked_at := now(); new.locked_by := auth.uid(); new.unlock_reason := null;
  elsif old.is_locked and not new.is_locked then
    if auth.uid() is not null and not public.has_permission(null, 'cabinet.settings') then
      raise exception 'Déverrouillage réservé à l''associé' using errcode = '42501';
    end if;
    if coalesce(trim(new.unlock_reason), '') = '' then
      raise exception 'Motif de déverrouillage obligatoire' using errcode = '23514';
    end if;
    new.locked_at := null; new.locked_by := null;
  end if;
  return new;
end $$;

create trigger periods_guard_update before update on public.periods
  for each row execute function public.periods_guard_update();

create or replace function public.periods_no_delete()
returns trigger language plpgsql as $$
begin
  raise exception 'Les périodes ne se suppriment pas individuellement' using errcode = '42501';
end $$;
create trigger periods_no_delete before delete on public.periods
  for each row when (pg_trigger_depth() = 0) execute function public.periods_no_delete();

-- Une date est-elle saisissable (période ouverte d''un exercice ouvert) ?
create or replace function public.period_open_for(p_entity uuid, p_date date)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.periods p join public.fiscal_years fy on fy.id = p.fiscal_year_id
     where p.entity_id = p_entity and p_date between p.start_date and p.end_date
       and not p.is_locked and fy.status = 'open'
  );
$$;

-- -----------------------------------------------------------------------------
-- Autorisation : l''utilisateur détient-il la permission sur au moins un périmètre ?
-- (utile pour « créer un dossier » avant toute affectation à ce dossier)
-- -----------------------------------------------------------------------------
create or replace function public.has_permission_anywhere(p_code text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.assignments a join public.roles r on r.id = a.role_id
      join public.role_permissions rp on rp.role_id = r.id join public.profiles p on p.id = a.user_id
     where a.user_id = auth.uid() and p.is_active and rp.permission_code = p_code
       and (not r.requires_mfa or public.current_aal() = 'aal2')
  );
$$;

-- -----------------------------------------------------------------------------
-- Journalisation
-- -----------------------------------------------------------------------------
create trigger audit_entities after insert or update or delete on public.entities
  for each row execute function public.audit_row_change();
create trigger audit_entity_directors after insert or update or delete on public.entity_directors
  for each row execute function public.audit_row_change();
create trigger audit_fiscal_years after insert or update or delete on public.fiscal_years
  for each row execute function public.audit_row_change();
create trigger audit_periods after update on public.periods
  for each row execute function public.audit_row_change();

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
alter table public.entities             enable row level security;
alter table public.entity_directors     enable row level security;
alter table public.entity_history       enable row level security;
alter table public.fiscal_years         enable row level security;
alter table public.fiscal_year_partners enable row level security;
alter table public.periods              enable row level security;

create policy entities_select on public.entities for select to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.can_access_entity(id));
create policy entities_insert on public.entities for insert to authenticated
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission_anywhere('entities.manage'));
create policy entities_update on public.entities for update to authenticated
  using (cabinet_id = public.current_cabinet_id() and (public.has_permission(id, 'entities.manage') or public.has_permission(null, 'cabinet.settings')))
  with check (cabinet_id = public.current_cabinet_id());
-- Pas de suppression d''entité (désactivation).

create policy entity_directors_select on public.entity_directors for select to authenticated
  using (public.can_access_entity(entity_id));
create policy entity_directors_write on public.entity_directors for all to authenticated
  using (public.has_permission(entity_id, 'entities.manage'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'entities.manage'));

create policy entity_history_select on public.entity_history for select to authenticated
  using (public.can_access_entity(entity_id));

create policy fiscal_years_select on public.fiscal_years for select to authenticated
  using (public.can_access_entity(entity_id));
create policy fiscal_years_insert on public.fiscal_years for insert to authenticated
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'entities.manage'));
create policy fiscal_years_update on public.fiscal_years for update to authenticated
  using (public.has_permission(entity_id, 'entities.manage'))
  with check (cabinet_id = public.current_cabinet_id());
create policy fiscal_years_delete on public.fiscal_years for delete to authenticated
  using (public.has_permission(entity_id, 'entities.manage'));

create policy fiscal_year_partners_select on public.fiscal_year_partners for select to authenticated
  using (exists (select 1 from public.fiscal_years fy where fy.id = fiscal_year_id and public.can_access_entity(fy.entity_id)));
create policy fiscal_year_partners_write on public.fiscal_year_partners for all to authenticated
  using (exists (select 1 from public.fiscal_years fy where fy.id = fiscal_year_id and public.has_permission(fy.entity_id, 'entities.manage')))
  with check (cabinet_id = public.current_cabinet_id()
              and exists (select 1 from public.fiscal_years fy where fy.id = fiscal_year_id and public.has_permission(fy.entity_id, 'entities.manage')));

create policy periods_select on public.periods for select to authenticated
  using (public.can_access_entity(entity_id));
create policy periods_update on public.periods for update to authenticated
  using (public.has_permission(entity_id, 'closing.provisional') or public.has_permission(null, 'cabinet.settings'))
  with check (cabinet_id = public.current_cabinet_id());

-- -----------------------------------------------------------------------------
-- Redéfinition des fonctions d''autorisation maintenant que public.entities existe :
-- un rôle de portée cabinet n''ouvre que les dossiers de SON cabinet.
-- -----------------------------------------------------------------------------
create or replace function public.has_permission(p_entity uuid, p_code text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.assignments a
      join public.roles r on r.id = a.role_id
      join public.role_permissions rp on rp.role_id = r.id
      join public.profiles p on p.id = a.user_id
     where a.user_id = auth.uid()
       and p.is_active
       and rp.permission_code = p_code
       and (not r.requires_mfa or public.current_aal() = 'aal2')
       and ((p_entity is null and a.entity_id is null)
            or (p_entity is not null and (a.entity_id = p_entity
                 or (a.entity_id is null and exists (select 1 from public.entities e where e.id = p_entity and e.cabinet_id = a.cabinet_id)))))
  );
$$;

create or replace function public.can_access_entity(p_entity uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.assignments a
      join public.roles r on r.id = a.role_id
      join public.profiles p on p.id = a.user_id
      join public.entities e on e.id = p_entity
     where a.user_id = auth.uid()
       and p.is_active
       and r.accounting_access
       and e.cabinet_id = a.cabinet_id
       and (a.entity_id = p_entity or (a.entity_id is null and r.grants_all_entities))
       and (not r.requires_mfa or public.current_aal() = 'aal2')
  );
$$;

create or replace function public.accessible_entity_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select e.id
    from public.entities e
   where e.cabinet_id = public.current_cabinet_id()
     and (public.grants_all_entities()
          or exists (select 1 from public.assignments a join public.roles r on r.id = a.role_id
                      where a.user_id = auth.uid() and a.entity_id = e.id and r.accounting_access
                        and (not r.requires_mfa or public.current_aal() = 'aal2')));
$$;

-- Cohérence des affectations : le dossier appartient au cabinet de l''affectation.
create or replace function public.check_assignment_consistency()
returns trigger language plpgsql as $$
declare
  v_role_cabinet uuid; v_user_cabinet uuid; v_entity_cabinet uuid; v_grants_all boolean; v_accounting boolean;
begin
  select cabinet_id, grants_all_entities, accounting_access into v_role_cabinet, v_grants_all, v_accounting
    from public.roles where id = new.role_id;
  select cabinet_id into v_user_cabinet from public.profiles where id = new.user_id;
  if v_role_cabinet is distinct from new.cabinet_id or v_user_cabinet is distinct from new.cabinet_id then
    raise exception 'Affectation incohérente : rôle, utilisateur et cabinet doivent concorder' using errcode = '23514';
  end if;
  if new.entity_id is not null then
    select cabinet_id into v_entity_cabinet from public.entities where id = new.entity_id;
    if v_entity_cabinet is distinct from new.cabinet_id then
      raise exception 'Affectation incohérente : le dossier appartient à un autre cabinet' using errcode = '23514';
    end if;
  end if;
  if new.entity_id is null and not v_grants_all and v_accounting then
    raise exception 'Ce rôle doit être affecté à un dossier précis' using errcode = '23514';
  end if;
  if new.entity_id is not null and (v_grants_all or not v_accounting) then
    raise exception 'Ce rôle a une portée cabinet : ne pas préciser de dossier' using errcode = '23514';
  end if;
  return new;
end $$;
