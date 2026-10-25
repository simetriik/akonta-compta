-- =============================================================================
-- Akonta — Migration 0001 : socle (module 1, conception §8, §10.1, §11.2)
-- Cabinets, profils, rôles et permissions unitaires, affectations, piste d'audit
-- en ajout seul chaînée par SHA-256, fonctions d'autorisation utilisées par RLS.
-- =============================================================================

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pgtap with schema extensions;

-- -----------------------------------------------------------------------------
-- Utilitaires
-- -----------------------------------------------------------------------------

-- Met à jour la colonne updated_at à chaque modification.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Niveau d'assurance de la session (aal1 = mot de passe seul, aal2 = TOTP vérifié).
create or replace function public.current_aal()
returns text language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'aal', 'aal1');
$$;

-- -----------------------------------------------------------------------------
-- Cabinets et profils
-- -----------------------------------------------------------------------------

create table public.cabinets (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null check (length(trim(name)) between 2 and 200),
  logo_path           text,
  address             text,
  phone               text,
  email               text,
  country_code        char(2) not null default 'BJ',
  -- Paramètres par défaut appliqués aux nouvelles entités (§10.2)
  default_account_length   smallint not null default 7 check (default_account_length between 6 and 12),
  inactivity_minutes       smallint not null default 30 check (inactivity_minutes between 5 and 480),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
comment on table public.cabinets is 'Cabinet d''expertise comptable : locataire (tenant) de toutes les données.';

create trigger cabinets_updated_at before update on public.cabinets
  for each row execute function public.set_updated_at();

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  cabinet_id  uuid not null references public.cabinets (id),
  email       text not null,
  full_name   text not null default '',
  job_title   text,
  is_active   boolean not null default true,   -- désactivation, jamais de suppression (§10.1)
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (cabinet_id, email)
);
comment on table public.profiles is 'Collaborateur d''un cabinet (miroir applicatif de auth.users).';

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Création automatique du profil à l''invitation : l''Edge Function place
-- cabinet_id et full_name dans les métadonnées de l''utilisateur Auth.
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_cabinet uuid := nullif(new.raw_user_meta_data ->> 'cabinet_id', '')::uuid;
begin
  if v_cabinet is null then
    return new; -- utilisateur hors cabinet (ex. compte technique) : pas de profil
  end if;
  insert into public.profiles (id, cabinet_id, email, full_name, job_title)
  values (new.id, v_cabinet, new.email,
          coalesce(new.raw_user_meta_data ->> 'full_name', ''),
          new.raw_user_meta_data ->> 'job_title')
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- Cabinet de l''utilisateur courant (null si non connecté ou sans profil).
create or replace function public.current_cabinet_id()
returns uuid language sql stable security definer set search_path = public as $$
  select cabinet_id from public.profiles where id = auth.uid() and is_active;
$$;

-- -----------------------------------------------------------------------------
-- Permissions unitaires et rôles (paquets par défaut ajustables, §8)
-- -----------------------------------------------------------------------------

create table public.permissions (
  code        text primary key,
  label       text not null,
  category    text not null,
  sort_order  smallint not null
);
comment on table public.permissions is 'Permissions unitaires de la matrice §8 de la conception.';

insert into public.permissions (code, label, category, sort_order) values
  ('entries.draft',            'Saisir / modifier ses brouillards',              'saisie',       10),
  ('ledger.read',              'Consulter grand livre, balance',                 'consultation', 20),
  ('entries.validate',         'Valider ses écritures',                          'saisie',       30),
  ('entries.reverse',          'Contre-passer / reclasser (avec motif)',         'saisie',       40),
  ('lettering.manage',         'Lettrer',                                        'lettrage',     50),
  ('reconciliation.manage',    'Rapprocher',                                     'lettrage',     51),
  ('documents.attach',         'Joindre des pièces',                             'pieces',       52),
  ('inventory.prepare',        'Préparer les travaux d''inventaire',             'inventaire',   60),
  ('entries.review',           'Revue des écritures',                            'revue',        70),
  ('closing.override_alerts',  'Lever les alertes de clôture',                   'cloture',      80),
  ('references.manage',        'Créer journaux, comptes, tiers, modèles',        'referentiels', 90),
  ('entities.manage',          'Créer un dossier / un exercice',                 'dossiers',    100),
  ('closing.provisional',      'Clôture provisoire / réouverture',               'cloture',     110),
  ('statements.generate',      'Générer les états financiers',                   'cloture',     120),
  ('import.perfecto',          'Importer depuis Perfecto',                       'import',      130),
  ('cabinet.settings',         'Paramètres cabinet et entité',                   'cabinet',     140),
  ('assignments.manage',       'Affecter les dossiers',                          'cabinet',     150),
  ('roles.manage',             'Ajuster les paquets de permissions des rôles',   'cabinet',     151),
  ('closing.final',            'Arrêté définitif',                               'cloture',     160),
  ('audit.read',               'Consulter la piste d''audit',                    'cabinet',     170),
  ('users.manage',             'Gérer utilisateurs et sécurité',                 'securite',    180);

create table public.roles (
  id                    uuid primary key default gen_random_uuid(),
  cabinet_id            uuid not null references public.cabinets (id) on delete cascade,
  code                  text not null check (code ~ '^[a-z_]{3,30}$'),
  name                  text not null,
  is_system             boolean not null default false,   -- rôle livré, non supprimable
  grants_all_entities   boolean not null default false,   -- associé : accès à tous les dossiers du cabinet
  requires_mfa          boolean not null default false,   -- associé et administrateur : TOTP obligatoire
  accounting_access     boolean not null default true,    -- administrateur technique : false
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (cabinet_id, code)
);
comment on table public.roles is 'Rôles d''un cabinet : paquets de permissions par défaut ajustables par l''associé.';

create trigger roles_updated_at before update on public.roles
  for each row execute function public.set_updated_at();

create table public.role_permissions (
  role_id          uuid not null references public.roles (id) on delete cascade,
  permission_code  text not null references public.permissions (code),
  primary key (role_id, permission_code)
);

-- Paquets par défaut de la matrice §8, créés pour chaque nouveau cabinet.
create or replace function public.seed_default_roles(p_cabinet uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  r_trainee uuid; r_assistant uuid; r_manager uuid; r_partner uuid; r_admin uuid;
begin
  insert into public.roles (cabinet_id, code, name, is_system, grants_all_entities, requires_mfa, accounting_access) values
    (p_cabinet, 'trainee',    'Stagiaire',                 true, false, false, true)  returning id into r_trainee;
  insert into public.roles (cabinet_id, code, name, is_system, grants_all_entities, requires_mfa, accounting_access) values
    (p_cabinet, 'assistant',  'Assistant',                 true, false, false, true)  returning id into r_assistant;
  insert into public.roles (cabinet_id, code, name, is_system, grants_all_entities, requires_mfa, accounting_access) values
    (p_cabinet, 'manager',    'Chef de mission',           true, false, false, true)  returning id into r_manager;
  insert into public.roles (cabinet_id, code, name, is_system, grants_all_entities, requires_mfa, accounting_access) values
    (p_cabinet, 'partner',    'Associé',                   true, true,  true,  true)  returning id into r_partner;
  insert into public.roles (cabinet_id, code, name, is_system, grants_all_entities, requires_mfa, accounting_access) values
    (p_cabinet, 'tech_admin', 'Administrateur technique',  true, false, true,  false) returning id into r_admin;

  -- Stagiaire
  insert into public.role_permissions values
    (r_trainee, 'entries.draft'), (r_trainee, 'ledger.read');
  -- Assistant
  insert into public.role_permissions select r_assistant, code from public.permissions where code in
    ('entries.draft','ledger.read','entries.validate','entries.reverse','lettering.manage',
     'reconciliation.manage','documents.attach','inventory.prepare');
  -- Chef de mission
  insert into public.role_permissions select r_manager, code from public.permissions where code in
    ('entries.draft','ledger.read','entries.validate','entries.reverse','lettering.manage',
     'reconciliation.manage','documents.attach','inventory.prepare','entries.review',
     'closing.override_alerts','references.manage','entities.manage','closing.provisional',
     'statements.generate','import.perfecto');
  -- Associé : tout sauf la gestion technique des utilisateurs
  insert into public.role_permissions select r_partner, code from public.permissions where code <> 'users.manage';
  -- Administrateur technique
  insert into public.role_permissions values (r_admin, 'users.manage');
end $$;

create or replace function public.handle_new_cabinet()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.seed_default_roles(new.id);
  return new;
end $$;

create trigger on_cabinet_created after insert on public.cabinets
  for each row execute function public.handle_new_cabinet();

-- -----------------------------------------------------------------------------
-- Affectations (utilisateur, dossier, rôle) — entity_id null = portée cabinet
-- (le lien vers public.entities est ajouté par la migration des dossiers)
-- -----------------------------------------------------------------------------

create table public.assignments (
  id          uuid primary key default gen_random_uuid(),
  cabinet_id  uuid not null references public.cabinets (id) on delete cascade,
  user_id     uuid not null references public.profiles (id),
  entity_id   uuid,
  role_id     uuid not null references public.roles (id),
  created_by  uuid references public.profiles (id),
  created_at  timestamptz not null default now()
);
comment on table public.assignments is 'Affectation (utilisateur, dossier, rôle). entity_id null = rôle de portée cabinet (associé, administrateur).';

create unique index assignments_unique_scope on public.assignments (user_id, role_id, coalesce(entity_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index assignments_user_idx on public.assignments (user_id, entity_id);
create index assignments_entity_idx on public.assignments (entity_id);

-- Cohérence : rôle, utilisateur et cabinet de l''affectation concordent.
create or replace function public.check_assignment_consistency()
returns trigger language plpgsql as $$
declare
  v_role_cabinet uuid; v_user_cabinet uuid; v_grants_all boolean; v_accounting boolean;
begin
  select cabinet_id, grants_all_entities, accounting_access into v_role_cabinet, v_grants_all, v_accounting
    from public.roles where id = new.role_id;
  select cabinet_id into v_user_cabinet from public.profiles where id = new.user_id;
  if v_role_cabinet is distinct from new.cabinet_id or v_user_cabinet is distinct from new.cabinet_id then
    raise exception 'Affectation incohérente : rôle, utilisateur et cabinet doivent concorder' using errcode = '23514';
  end if;
  if new.entity_id is null and not v_grants_all and v_accounting then
    raise exception 'Ce rôle doit être affecté à un dossier précis' using errcode = '23514';
  end if;
  if new.entity_id is not null and (v_grants_all or not v_accounting) then
    raise exception 'Ce rôle a une portée cabinet : ne pas préciser de dossier' using errcode = '23514';
  end if;
  return new;
end $$;

create trigger assignments_consistency before insert or update on public.assignments
  for each row execute function public.check_assignment_consistency();

-- -----------------------------------------------------------------------------
-- Fonctions d''autorisation (utilisées par les politiques RLS et l''application)
-- -----------------------------------------------------------------------------

-- L''utilisateur courant détient-il la permission p_code ?
--   p_entity non null : via une affectation sur ce dossier ou un rôle de portée cabinet ;
--   p_entity null     : via un rôle de portée cabinet uniquement.
-- Un rôle marqué requires_mfa n''accorde rien tant que la session n''est pas en aal2.
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
       and (a.entity_id is null or a.entity_id = p_entity)
       and (not r.requires_mfa or public.current_aal() = 'aal2')
  );
$$;

-- L''utilisateur courant peut-il voir les données comptables de ce dossier ?
create or replace function public.can_access_entity(p_entity uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.assignments a
      join public.roles r on r.id = a.role_id
      join public.profiles p on p.id = a.user_id
     where a.user_id = auth.uid()
       and p.is_active
       and r.accounting_access
       and (a.entity_id = p_entity or (a.entity_id is null and r.grants_all_entities))
       and (not r.requires_mfa or public.current_aal() = 'aal2')
  );
$$;

-- Identifiants des dossiers accessibles (pour les listes).
create or replace function public.accessible_entity_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select distinct a.entity_id
    from public.assignments a
    join public.roles r on r.id = a.role_id
    join public.profiles p on p.id = a.user_id
   where a.user_id = auth.uid() and p.is_active and r.accounting_access and a.entity_id is not null
     and (not r.requires_mfa or public.current_aal() = 'aal2');
$$;

create or replace function public.grants_all_entities()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.assignments a join public.roles r on r.id = a.role_id
      join public.profiles p on p.id = a.user_id
     where a.user_id = auth.uid() and p.is_active and a.entity_id is null and r.grants_all_entities
       and (not r.requires_mfa or public.current_aal() = 'aal2')
  );
$$;

-- -----------------------------------------------------------------------------
-- Piste d''audit : ajout seul, chaînage SHA-256 par cabinet (§10.1, §11.2)
-- -----------------------------------------------------------------------------

create table public.audit_log (
  id           bigint generated always as identity primary key,
  cabinet_id   uuid not null,
  occurred_at  timestamptz not null default clock_timestamp(),
  actor_id     uuid,                     -- auth.uid() ; null pour les traitements système
  action       text not null,            -- insert | update | delete | login | export | validate | …
  table_name   text,
  record_id    text,
  entity_id    uuid,
  payload      jsonb not null default '{}'::jsonb,
  prev_hash    text,
  hash         text not null
);
comment on table public.audit_log is 'Piste d''audit en ajout seul. hash = sha256(prev_hash || contenu) ; chaîne par cabinet.';
create index audit_log_cabinet_time_idx on public.audit_log (cabinet_id, occurred_at desc);
create index audit_log_record_idx on public.audit_log (table_name, record_id);
create index audit_log_entity_idx on public.audit_log (entity_id, occurred_at desc);

-- Contenu canonique haché : indépendant de l''ordre des clés jsonb (jsonb normalise déjà).
create or replace function public.audit_content(p_cabinet uuid, p_occurred timestamptz, p_actor uuid, p_action text,
                                                p_table text, p_record text, p_entity uuid, p_payload jsonb)
returns text language sql immutable as $$
  select concat_ws('|', p_cabinet::text, to_char(p_occurred at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
                   coalesce(p_actor::text, ''), p_action, coalesce(p_table, ''), coalesce(p_record, ''),
                   coalesce(p_entity::text, ''), p_payload::text);
$$;

-- Calcule prev_hash et hash avant insertion, sous verrou par cabinet pour garantir la chaîne.
create or replace function public.audit_log_chain()
returns trigger language plpgsql as $$
declare
  v_prev text;
begin
  perform pg_advisory_xact_lock(hashtext('audit_log:' || new.cabinet_id::text));
  select hash into v_prev from public.audit_log where cabinet_id = new.cabinet_id order by id desc limit 1;
  new.prev_hash := v_prev;
  new.hash := encode(extensions.digest(
      coalesce(v_prev, '') || public.audit_content(new.cabinet_id, new.occurred_at, new.actor_id, new.action,
                                                   new.table_name, new.record_id, new.entity_id, new.payload),
      'sha256'), 'hex');
  return new;
end $$;

create trigger audit_log_chain before insert on public.audit_log
  for each row execute function public.audit_log_chain();

create or replace function public.audit_log_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'La piste d''audit est en ajout seul (%)', tg_op using errcode = '42501';
end $$;

create trigger audit_log_no_update before update on public.audit_log
  for each row execute function public.audit_log_immutable();
create trigger audit_log_no_delete before delete on public.audit_log
  for each row execute function public.audit_log_immutable();
create trigger audit_log_no_truncate before truncate on public.audit_log
  for each statement execute function public.audit_log_immutable();

-- Écriture explicite d''un événement (connexion, export, action sensible) par l''application.
create or replace function public.log_audit_event(p_action text, p_payload jsonb default '{}'::jsonb,
                                                  p_entity uuid default null, p_table text default null,
                                                  p_record text default null)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  v_cabinet uuid := public.current_cabinet_id();
  v_id bigint;
begin
  if v_cabinet is null then
    raise exception 'Aucun cabinet pour l''utilisateur courant' using errcode = '42501';
  end if;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_cabinet, auth.uid(), p_action, p_table, p_record, p_entity, coalesce(p_payload, '{}'::jsonb))
  returning id into v_id;
  return v_id;
end $$;

-- Déclencheur générique de journalisation des lignes (insert / update / delete).
-- Argument optionnel : nom de la colonne portant l''identifiant du dossier (défaut : entity_id si présente).
create or replace function public.audit_row_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_row jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) else null end;
  v_cabinet uuid;
  v_entity uuid;
  v_payload jsonb;
begin
  v_cabinet := coalesce((v_row ->> 'cabinet_id')::uuid, public.current_cabinet_id());
  if v_cabinet is null and tg_table_name = 'cabinets' then v_cabinet := (v_row ->> 'id')::uuid; end if;
  if v_cabinet is null then
    return null; -- rien à journaliser hors cabinet
  end if;
  v_entity := case when v_row ? 'entity_id' then (v_row ->> 'entity_id')::uuid
                   when tg_table_name = 'entities' then (v_row ->> 'id')::uuid end;
  v_payload := case tg_op
    when 'UPDATE' then jsonb_build_object('old', v_old, 'new', v_row)
    else jsonb_build_object('row', v_row) end;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_cabinet, auth.uid(), lower(tg_op), tg_table_name, v_row ->> 'id', v_entity, v_payload);
  return null;
end $$;

-- Vérification de l''intégrité de la chaîne d''un cabinet : renvoie l''identifiant du premier maillon rompu, sinon null.
create or replace function public.audit_chain_verify(p_cabinet uuid)
returns bigint language plpgsql stable security definer set search_path = public as $$
declare
  r record; v_prev text := null; v_expected text;
begin
  for r in select * from public.audit_log where cabinet_id = p_cabinet order by id loop
    v_expected := encode(extensions.digest(coalesce(v_prev, '') || public.audit_content(r.cabinet_id, r.occurred_at,
                    r.actor_id, r.action, r.table_name, r.record_id, r.entity_id, r.payload), 'sha256'), 'hex');
    if r.prev_hash is distinct from v_prev or r.hash <> v_expected then
      return r.id;
    end if;
    v_prev := r.hash;
  end loop;
  return null;
end $$;

-- Journalisation des tables du socle
create trigger audit_cabinets after insert or update or delete on public.cabinets
  for each row execute function public.audit_row_change();
create trigger audit_profiles after insert or update or delete on public.profiles
  for each row execute function public.audit_row_change();
create trigger audit_roles after insert or update or delete on public.roles
  for each row execute function public.audit_row_change();
create trigger audit_assignments after insert or update or delete on public.assignments
  for each row execute function public.audit_row_change();

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------

alter table public.cabinets          enable row level security;
alter table public.profiles          enable row level security;
alter table public.permissions       enable row level security;
alter table public.roles             enable row level security;
alter table public.role_permissions  enable row level security;
alter table public.assignments       enable row level security;
alter table public.audit_log         enable row level security;

-- Cabinets : lecture par ses membres, modification par l''associé (paramètres cabinet).
create policy cabinets_select on public.cabinets for select to authenticated
  using (id = public.current_cabinet_id());
create policy cabinets_update on public.cabinets for update to authenticated
  using (id = public.current_cabinet_id() and public.has_permission(null, 'cabinet.settings'))
  with check (id = public.current_cabinet_id());

-- Profils : visibles dans le cabinet ; gestion par l''administrateur technique ; chacun édite son nom.
create policy profiles_select on public.profiles for select to authenticated
  using (cabinet_id = public.current_cabinet_id());
create policy profiles_update_admin on public.profiles for update to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'users.manage'))
  with check (cabinet_id = public.current_cabinet_id());
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and cabinet_id = public.current_cabinet_id());
-- Pas de suppression (désactivation uniquement) ; insertion par le déclencheur Auth (security definer).

-- Permissions : catalogue lisible par tous les connectés.
create policy permissions_select on public.permissions for select to authenticated using (true);

-- Rôles : lecture dans le cabinet ; ajustement par l''associé.
create policy roles_select on public.roles for select to authenticated
  using (cabinet_id = public.current_cabinet_id());
create policy roles_insert on public.roles for insert to authenticated
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'roles.manage') and not is_system);
create policy roles_update on public.roles for update to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'roles.manage'))
  with check (cabinet_id = public.current_cabinet_id());
create policy roles_delete on public.roles for delete to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'roles.manage') and not is_system);

create policy role_permissions_select on public.role_permissions for select to authenticated
  using (exists (select 1 from public.roles r where r.id = role_id and r.cabinet_id = public.current_cabinet_id()));
create policy role_permissions_write on public.role_permissions for all to authenticated
  using (exists (select 1 from public.roles r where r.id = role_id and r.cabinet_id = public.current_cabinet_id())
         and public.has_permission(null, 'roles.manage'))
  with check (exists (select 1 from public.roles r where r.id = role_id and r.cabinet_id = public.current_cabinet_id())
         and public.has_permission(null, 'roles.manage'));

-- Affectations : chacun voit les siennes ; l''associé et l''administrateur voient tout le cabinet ;
-- les membres d''un dossier voient l''équipe du dossier ; écriture réservée à « Affecter les dossiers ».
create policy assignments_select on public.assignments for select to authenticated
  using (cabinet_id = public.current_cabinet_id()
         and (user_id = auth.uid()
              or public.has_permission(null, 'assignments.manage')
              or public.has_permission(null, 'users.manage')
              or (entity_id is not null and public.can_access_entity(entity_id))));
create policy assignments_write on public.assignments for all to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'assignments.manage'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'assignments.manage'));

-- Piste d''audit : lecture par l''associé (permission audit.read, aal2 via le rôle) ; aucune écriture directe.
create policy audit_log_select on public.audit_log for select to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'audit.read'));

-- Droits d''exécution : les fonctions sensibles ne sont pas appelables par anon.
revoke execute on function public.seed_default_roles(uuid) from public, anon, authenticated;
revoke execute on function public.audit_chain_verify(uuid) from public, anon;
grant  execute on function public.audit_chain_verify(uuid) to authenticated;
revoke execute on function public.log_audit_event(text, jsonb, uuid, text, text) from public, anon;
grant  execute on function public.log_audit_event(text, jsonb, uuid, text, text) to authenticated;
