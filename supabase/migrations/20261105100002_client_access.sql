-- =============================================================================
-- Akonta — Accès des clients du cabinet (D-044, tranche 3, étape 1 : base de données)
-- Un client voit UNIQUEMENT son brouillard et ses factures (décision de Dansi, D-043). Il ne valide jamais.
--   - rôles client_gerant et client_saisie, à droits bornés par une liste fermée ;
--   - accès par dossier : interrupteur disabled / active / suspended (suspendu = lecture seule) ;
--   - lecture ouverte par des politiques SUPPLÉMENTAIRES et étroites ; écriture bornée par des politiques RESTRICTIVES ;
--   - motif « à corriger » renvoyé par le comptable sur un brouillard.
-- can_access_entity() reste faux pour un client : toute politique existante le refuse donc par défaut.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Rôles client
-- -----------------------------------------------------------------------------
alter table public.roles add column is_client boolean not null default false;
comment on column public.roles.is_client is 'Rôle d''un client du cabinet : accès limité à son brouillard et à ses factures (D-044).';

insert into public.permissions (code, label, category, sort_order) values
  ('drafts.read_all',      'Voir tout le brouillard du dossier (client)',         'clients', 200),
  ('client_access.manage', 'Ouvrir, suspendre l''accès des clients d''un dossier', 'clients', 201)
on conflict (code) do nothing;

-- L'associé gère l'accès des clients ; les droits actuels des associés sont complétés.
insert into public.role_permissions (role_id, permission_code)
select id, 'client_access.manage' from public.roles where code = 'partner'
on conflict do nothing;

-- Un rôle client ne reçoit QUE ces droits, quel que soit l'appelant (même en mode interne) : l'associé règle le détail
-- dans cette liste fermée, il ne peut pas ouvrir la comptabilité à un client.
create or replace function public.client_role_permissions_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_client boolean;
begin
  select is_client into v_client from public.roles where id = new.role_id;
  if v_client and new.permission_code not in ('entries.draft', 'documents.attach', 'drafts.read_all', 'invoices.issue') then
    raise exception 'Ce droit ne peut pas être accordé à un rôle client' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger client_role_permissions_guard before insert or update on public.role_permissions
  for each row execute function public.client_role_permissions_guard();

-- Un associé ne change pas la nature d'un rôle.
create or replace function public.roles_guard_update()
returns trigger language plpgsql set search_path = public as $$
begin
  if auth.uid() is null or public.internal_mode() then return new; end if;
  if new.code is distinct from old.code or new.cabinet_id is distinct from old.cabinet_id or new.is_system is distinct from old.is_system
     or new.grants_all_entities is distinct from old.grants_all_entities or new.requires_mfa is distinct from old.requires_mfa
     or new.accounting_access is distinct from old.accounting_access or new.is_client is distinct from old.is_client then
    raise exception 'Seul le nom d''un rôle peut être modifié' using errcode = '42501';
  end if;
  return new;
end $$;

-- Rôles livrés avec chaque cabinet. Le gérant émet des factures : TOTP exigé (D-043). Le saisisseur ne l'exige pas
-- tant qu'il n'émet pas ; l'émission se lui accorde par le droit invoices.issue.
create or replace function public.seed_client_roles(p_cabinet uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r_gerant uuid; r_saisie uuid;
begin
  insert into public.roles (cabinet_id, code, name, is_system, grants_all_entities, requires_mfa, accounting_access, is_client)
  values (p_cabinet, 'client_gerant', 'Client — gérant', true, false, true, false, true)
  on conflict (cabinet_id, code) do nothing;
  insert into public.roles (cabinet_id, code, name, is_system, grants_all_entities, requires_mfa, accounting_access, is_client)
  values (p_cabinet, 'client_saisie', 'Client — saisie', true, false, false, false, true)
  on conflict (cabinet_id, code) do nothing;
  select id into r_gerant from public.roles where cabinet_id = p_cabinet and code = 'client_gerant';
  select id into r_saisie from public.roles where cabinet_id = p_cabinet and code = 'client_saisie';
  insert into public.role_permissions (role_id, permission_code) values
    (r_gerant, 'entries.draft'), (r_gerant, 'documents.attach'), (r_gerant, 'drafts.read_all'), (r_gerant, 'invoices.issue'),
    (r_saisie, 'entries.draft'), (r_saisie, 'documents.attach')
  on conflict do nothing;
end $$;
revoke all on function public.seed_client_roles(uuid) from public, anon, authenticated;

create or replace function public.roles_default_clients()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.seed_client_roles(new.id);
  return null;
end $$;
create trigger on_cabinet_created_client_roles after insert on public.cabinets
  for each row execute function public.roles_default_clients();

select public.seed_client_roles(id) from public.cabinets;

-- -----------------------------------------------------------------------------
-- 2. Affectations : un rôle client vise un dossier précis, et ne se cumule pas avec un rôle du cabinet
-- -----------------------------------------------------------------------------
create or replace function public.check_assignment_consistency()
returns trigger language plpgsql as $$
declare
  v_role_cabinet uuid; v_user_cabinet uuid; v_entity_cabinet uuid; v_grants_all boolean; v_accounting boolean; v_client boolean;
begin
  select cabinet_id, grants_all_entities, accounting_access, is_client into v_role_cabinet, v_grants_all, v_accounting, v_client
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
  if new.entity_id is null and not v_grants_all and (v_accounting or v_client) then
    raise exception 'Ce rôle doit être affecté à un dossier précis' using errcode = '23514';
  end if;
  if new.entity_id is not null and (v_grants_all or not (v_accounting or v_client)) then
    raise exception 'Ce rôle a une portée cabinet : ne pas préciser de dossier' using errcode = '23514';
  end if;
  -- Séparation : un compte est soit du cabinet, soit d'un client, jamais les deux.
  if exists (select 1 from public.assignments a join public.roles r on r.id = a.role_id
              where a.user_id = new.user_id and a.id is distinct from new.id and r.is_client is distinct from v_client) then
    raise exception 'Un compte client ne peut pas porter de rôle du cabinet, ni l''inverse' using errcode = '23514';
  end if;
  return new;
end $$;

-- L'associé attribue aussi les rôles client (qui partent d'un dossier précis).
create or replace function public.can_assign_role(p_code text, p_entity uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when public.has_permission(null, 'assignments.manage') then p_code in ('manager', 'assistant', 'trainee', 'client_gerant', 'client_saisie')
    when p_entity is not null and public.has_permission(p_entity, 'team.assign') then p_code in ('assistant', 'trainee')
    else false end;
$$;

-- -----------------------------------------------------------------------------
-- 3. Interrupteur d'accès par dossier (audité, jamais modifiable directement)
-- -----------------------------------------------------------------------------
alter table public.entities add column client_access text not null default 'disabled'
  check (client_access in ('disabled', 'active', 'suspended'));
comment on column public.entities.client_access is 'Accès des clients : disabled (aucun), active, suspended (lecture seule). Modifié par set_client_access().';

create or replace function public.entities_guard_client_access()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.client_access is distinct from old.client_access and auth.uid() is not null and not public.internal_mode() then
    raise exception 'L''accès des clients se change par set_client_access()' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger entities_guard_client_access before update on public.entities
  for each row execute function public.entities_guard_client_access();

create or replace function public.set_client_access(p_entity uuid, p_status text, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_old text; v_cabinet uuid;
begin
  if p_status not in ('disabled', 'active', 'suspended') then
    raise exception 'État d''accès inconnu' using errcode = '22023';
  end if;
  if auth.uid() is not null and not public.has_permission(p_entity, 'client_access.manage') then
    raise exception 'Permission refusée : client_access.manage' using errcode = '42501';
  end if;
  select client_access, cabinet_id into v_old, v_cabinet from public.entities where id = p_entity;
  if v_cabinet is null then raise exception 'Dossier inconnu' using errcode = 'P0002'; end if;
  if v_old = p_status then return; end if;
  perform set_config('akonta.internal', 'on', true);
  update public.entities set client_access = p_status where id = p_entity;
  perform set_config('akonta.internal', '', true);
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_cabinet, auth.uid(), 'client_access', 'entities', p_entity::text, p_entity,
          jsonb_build_object('from', v_old, 'to', p_status, 'reason', p_reason));
end $$;
revoke all on function public.set_client_access(uuid, text, text) from public, anon;
grant execute on function public.set_client_access(uuid, text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Aides d'accès pour un client (security definer : lisent affectations et dossier à la place de l'appelant)
-- -----------------------------------------------------------------------------
-- Vrai si l'appelant porte un rôle client (sur n'importe quel dossier).
create or replace function public.is_client_user()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.assignments a join public.roles r on r.id = a.role_id
                  where a.user_id = auth.uid() and r.is_client);
$$;

-- Vrai si l'utilisateur donné porte un rôle client sur ce dossier (auteur d'un brouillard de client).
create or replace function public.is_client_member(p_user uuid, p_entity uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.assignments a join public.roles r on r.id = a.role_id
                  where a.user_id = p_user and a.entity_id = p_entity and r.is_client);
$$;

-- État d'accès du dossier pour l'appelant ; null s'il n'est pas un client actif de ce dossier (compte inactif, TOTP manquant…).
create or replace function public.client_entity_status(p_entity uuid)
returns text language sql stable security definer set search_path = public as $$
  select e.client_access
    from public.assignments a
    join public.roles r on r.id = a.role_id
    join public.profiles p on p.id = a.user_id
    join public.entities e on e.id = a.entity_id
   where a.user_id = auth.uid() and a.entity_id = p_entity
     and r.is_client and p.is_active
     and e.cabinet_id = a.cabinet_id
     and (not r.requires_mfa or public.current_aal() = 'aal2');
$$;

create or replace function public.client_can_read_entity(p_entity uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.client_entity_status(p_entity) in ('active', 'suspended'), false);
$$;

-- Garde d'écriture (politiques restrictives) : vrai pour le personnel du cabinet ; pour un client, seulement si l'accès est « active ».
create or replace function public.client_write_ok(p_entity uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when exists (select 1 from public.assignments a join public.roles r on r.id = a.role_id
                  where a.user_id = auth.uid() and a.entity_id = p_entity and r.is_client)
    then coalesce(public.client_entity_status(p_entity) = 'active', false)
    else true end;
$$;

revoke all on function public.is_client_user(), public.is_client_member(uuid, uuid), public.client_entity_status(uuid), public.client_can_read_entity(uuid),
  public.client_write_ok(uuid) from public, anon;
grant execute on function public.is_client_user(), public.is_client_member(uuid, uuid), public.client_entity_status(uuid), public.client_can_read_entity(uuid),
  public.client_write_ok(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Lecture : politiques supplémentaires et étroites (elles s'ajoutent aux politiques du personnel)
-- -----------------------------------------------------------------------------
create policy entities_select_client on public.entities for select to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.client_can_read_entity(id));

-- Brouillard : le gérant voit celui que les clients du dossier ont saisi, le saisisseur le sien. Jamais une écriture
-- validée, ni un brouillard du cabinet (travaux internes, écritures générées par le personnel).
create policy entries_select_client on public.entries for select to authenticated
  using (status = 'draft' and public.client_can_read_entity(entity_id)
         and (created_by = auth.uid()
              or (public.has_permission(entity_id, 'drafts.read_all') and public.is_client_member(created_by, entity_id))));
create policy entry_lines_select_client on public.entry_lines for select to authenticated
  using (public.client_can_read_entity(entity_id)
         and exists (select 1 from public.entries e where e.id = entry_lines.entry_id));

-- Référentiels nécessaires à la saisie d'un brouillard (lecture seule).
create policy accounts_select_client on public.accounts for select to authenticated using (public.client_can_read_entity(entity_id));
create policy journals_select_client on public.journals for select to authenticated using (public.client_can_read_entity(entity_id));
create policy third_parties_select_client on public.third_parties for select to authenticated using (public.client_can_read_entity(entity_id));
create policy fiscal_years_select_client on public.fiscal_years for select to authenticated using (public.client_can_read_entity(entity_id));
create policy periods_select_client on public.periods for select to authenticated using (public.client_can_read_entity(entity_id));

-- Factures : le gérant voit toutes celles du dossier, le saisisseur les siennes.
create policy invoices_select_client on public.invoices for select to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.client_can_read_entity(entity_id)
         and (created_by = auth.uid() or public.has_permission(entity_id, 'drafts.read_all')));
create policy invoice_lines_select_client on public.invoice_lines for select to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_lines.invoice_id));
create policy invoice_payments_select_client on public.invoice_payments for select to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_payments.invoice_id));
create policy emcf_devices_select_client on public.emcf_devices for select to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.client_can_read_entity(entity_id));

-- Annuaire : un client ne voit que son propre profil (ni le personnel du cabinet, ni les autres clients).
create policy profiles_select_client_only_self on public.profiles as restrictive for select to authenticated
  using (not public.is_client_user() or id = auth.uid());

-- -----------------------------------------------------------------------------
-- 6. Écriture : politiques RESTRICTIVES (elles s'ajoutent aux conditions existantes, sans les remplacer)
--    Un client n'écrit que si l'accès de son dossier est « active ».
-- -----------------------------------------------------------------------------
create policy entries_client_write_insert on public.entries as restrictive for insert to authenticated
  with check (public.client_write_ok(entity_id));
create policy entries_client_write_update on public.entries as restrictive for update to authenticated
  using (public.client_write_ok(entity_id)) with check (public.client_write_ok(entity_id));
create policy entries_client_write_delete on public.entries as restrictive for delete to authenticated
  using (public.client_write_ok(entity_id));
create policy entry_lines_client_write on public.entry_lines as restrictive for all to authenticated
  using (public.client_write_ok(entity_id)) with check (public.client_write_ok(entity_id));

create policy invoices_client_write_insert on public.invoices as restrictive for insert to authenticated
  with check (public.client_write_ok(entity_id));
create policy invoices_client_write_update on public.invoices as restrictive for update to authenticated
  using (public.client_write_ok(entity_id)) with check (public.client_write_ok(entity_id));
create policy invoices_client_write_delete on public.invoices as restrictive for delete to authenticated
  using (public.client_write_ok(entity_id));
create policy invoice_lines_client_write on public.invoice_lines as restrictive for all to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_lines.invoice_id and public.client_write_ok(i.entity_id)))
  with check (exists (select 1 from public.invoices i where i.id = invoice_lines.invoice_id and public.client_write_ok(i.entity_id)));
create policy invoice_payments_client_write on public.invoice_payments as restrictive for all to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_payments.invoice_id and public.client_write_ok(i.entity_id)))
  with check (exists (select 1 from public.invoices i where i.id = invoice_payments.invoice_id and public.client_write_ok(i.entity_id)));

-- -----------------------------------------------------------------------------
-- 7. Brouillard renvoyé au client avec un motif (« à corriger »)
-- -----------------------------------------------------------------------------
alter table public.entries
  add column returned_comment text,
  add column returned_by uuid references public.profiles (id),
  add column returned_at timestamptz;
comment on column public.entries.returned_comment is 'Motif renvoyé par le comptable sur un brouillard (client) : à corriger avant validation.';

create or replace function public.return_draft_to_client(p_entry uuid, p_comment text)
returns void language plpgsql security definer set search_path = public as $$
declare v_entry public.entries%rowtype;
begin
  select * into v_entry from public.entries where id = p_entry for update;
  if v_entry.id is null then raise exception 'Écriture inconnue' using errcode = 'P0002'; end if;
  if v_entry.status <> 'draft' then
    raise exception 'Seul un brouillard peut être renvoyé' using errcode = '23514';
  end if;
  if auth.uid() is not null and not public.has_permission(v_entry.entity_id, 'entries.validate') then
    raise exception 'Permission refusée : entries.validate' using errcode = '42501';
  end if;
  if coalesce(trim(p_comment), '') = '' then
    raise exception 'Un motif est obligatoire' using errcode = '23514';
  end if;
  perform set_config('akonta.internal', 'on', true);
  update public.entries set returned_comment = p_comment, returned_by = auth.uid(), returned_at = now() where id = p_entry;
  perform set_config('akonta.internal', '', true);
  if v_entry.created_by is not null then
    insert into public.notifications (cabinet_id, user_id, entity_id, kind, payload)
    values (v_entry.cabinet_id, v_entry.created_by, v_entry.entity_id, 'entry_returned',
            jsonb_build_object('entry_id', p_entry, 'comment', p_comment));
  end if;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_entry.cabinet_id, auth.uid(), 'return_draft', 'entries', p_entry::text, v_entry.entity_id,
          jsonb_build_object('comment', p_comment));
end $$;
revoke all on function public.return_draft_to_client(uuid, text) from public, anon;
grant execute on function public.return_draft_to_client(uuid, text) to authenticated;
