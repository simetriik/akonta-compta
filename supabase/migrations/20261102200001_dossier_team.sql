-- Équipe d'un dossier (D-038) : le chef de mission affecte assistants et stagiaires sur SON dossier ; un seul chef de mission
-- par dossier ; l'associé remplace le chef de mission ; la personne affectée est prévenue.

-- 1. Droit « affecter assistants et stagiaires à ses dossiers » : chef de mission (et associé, qui a déjà tout).
insert into public.permissions (code, label, category, sort_order)
values ('team.assign', 'Affecter assistants et stagiaires à ses dossiers', 'cabinet', 152)
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_code)
select id, 'team.assign' from public.roles where code in ('manager', 'partner')
on conflict do nothing;

-- Nouveaux cabinets : le chef de mission reçoit le droit à la création de son rôle (l'associé reçoit déjà tous les droits du catalogue).
create or replace function public.roles_default_team_assign()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.code = 'manager' then
    insert into public.role_permissions (role_id, permission_code) values (new.id, 'team.assign') on conflict do nothing;
  end if;
  return null;
end $$;
create trigger roles_default_team_assign after insert on public.roles
  for each row execute function public.roles_default_team_assign();

-- Ce droit n'est pas modifiable depuis l'application (il fait partie des droits d'administration de l'équipe).
create or replace function public.role_permissions_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_code text; v_role uuid; v_perm text;
begin
  if auth.uid() is null or public.internal_mode() then return coalesce(new, old); end if;
  v_role := coalesce(new.role_id, old.role_id);
  v_perm := coalesce(new.permission_code, old.permission_code);
  select code into v_code from public.roles where id = v_role;
  if v_code in ('partner', 'tech_admin') then
    raise exception 'Les droits de ce rôle sont fixes' using errcode = '42501';
  end if;
  if v_perm in ('users.manage', 'team.manage', 'team.assign', 'roles.manage', 'assignments.manage') then
    raise exception 'Ce droit d''administration ne peut pas être accordé à ce rôle' using errcode = '42501';
  end if;
  return coalesce(new, old);
end $$;

-- 2. Qui peut attribuer quoi : l'associé (assignments.manage) les trois rôles ; le chef de mission (team.assign sur le dossier)
--    assistant et stagiaire de son dossier seulement.
drop function if exists public.can_assign_role(text);
create or replace function public.can_assign_role(p_code text, p_entity uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when public.has_permission(null, 'assignments.manage') then p_code in ('manager', 'assistant', 'trainee')
    when p_entity is not null and public.has_permission(p_entity, 'team.assign') then p_code in ('assistant', 'trainee')
    else false end;
$$;
revoke all on function public.can_assign_role(text, uuid) from public, anon;
grant execute on function public.can_assign_role(text, uuid) to authenticated;

create or replace function public.assignments_authority()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if auth.uid() is null or public.internal_mode() then return coalesce(new, old); end if;
  if tg_op in ('UPDATE', 'DELETE') then
    select code into v_code from public.roles where id = old.role_id;
    if not public.can_assign_role(v_code, old.entity_id) then
      raise exception 'Ce rôle ne peut être ni modifié ni retiré par vous' using errcode = '42501';
    end if;
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    select code into v_code from public.roles where id = new.role_id;
    if not public.can_assign_role(v_code, new.entity_id) then
      raise exception 'Vous ne pouvez attribuer ici que les rôles que votre fonction permet' using errcode = '42501';
    end if;
  end if;
  return coalesce(new, old);
end $$;

-- Politiques d'écriture : associé (portée cabinet) ou chef de mission sur le dossier concerné.
drop policy if exists assignments_insert on public.assignments;
drop policy if exists assignments_update on public.assignments;
drop policy if exists assignments_delete on public.assignments;
create policy assignments_insert on public.assignments for insert to authenticated
  with check (cabinet_id = public.current_cabinet_id()
              and (public.has_permission(null, 'assignments.manage') or (entity_id is not null and public.has_permission(entity_id, 'team.assign'))));
create policy assignments_update on public.assignments for update to authenticated
  using (cabinet_id = public.current_cabinet_id()
         and (public.has_permission(null, 'assignments.manage') or (entity_id is not null and public.has_permission(entity_id, 'team.assign')))
         and (not public.is_tech_admin(user_id) or public.is_tech_admin(auth.uid())))
  with check (cabinet_id = public.current_cabinet_id()
              and (public.has_permission(null, 'assignments.manage') or (entity_id is not null and public.has_permission(entity_id, 'team.assign'))));
create policy assignments_delete on public.assignments for delete to authenticated
  using (cabinet_id = public.current_cabinet_id()
         and (public.has_permission(null, 'assignments.manage') or (entity_id is not null and public.has_permission(entity_id, 'team.assign')))
         and (not public.is_tech_admin(user_id) or public.is_tech_admin(auth.uid())));

-- 3. Un seul chef de mission par dossier (vaut aussi pour les traitements internes).
create or replace function public.assignments_one_manager()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.entity_id is not null
     and exists (select 1 from public.roles r where r.id = new.role_id and r.code = 'manager')
     and exists (select 1 from public.assignments a join public.roles r on r.id = a.role_id
                  where a.entity_id = new.entity_id and r.code = 'manager' and a.id <> new.id) then
    raise exception 'Ce dossier a déjà un chef de mission : remplacez-le au lieu d''en ajouter un second' using errcode = '23505';
  end if;
  return new;
end $$;
create trigger assignments_one_manager before insert or update on public.assignments
  for each row execute function public.assignments_one_manager();

-- Remplacement du chef de mission (associé seulement) : retire l'ancien et pose le nouveau en une transaction.
create or replace function public.replace_manager(p_entity uuid, p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cabinet uuid := public.current_cabinet_id();
  v_role uuid;
begin
  if v_cabinet is null or not public.has_permission(null, 'assignments.manage') then
    raise exception 'Permission refusée : assignments.manage' using errcode = '42501';
  end if;
  if not exists (select 1 from public.entities where id = p_entity and cabinet_id = v_cabinet) then
    raise exception 'Dossier introuvable' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.profiles where id = p_user and cabinet_id = v_cabinet and is_active) or public.is_tech_admin(p_user) then
    raise exception 'Collaborateur introuvable ou désactivé' using errcode = 'P0002';
  end if;
  select id into v_role from public.roles where cabinet_id = v_cabinet and code = 'manager';
  perform set_config('akonta.internal', 'on', true);
  delete from public.assignments where entity_id = p_entity and role_id = v_role;
  insert into public.assignments (cabinet_id, user_id, entity_id, role_id, created_by)
  values (v_cabinet, p_user, p_entity, v_role, auth.uid());
  perform set_config('akonta.internal', 'off', true);
end $$;
revoke all on function public.replace_manager(uuid, uuid) from public, anon;
grant execute on function public.replace_manager(uuid, uuid) to authenticated;

-- 4. La personne affectée à un dossier en est prévenue (sauf si elle s'affecte elle-même ou si c'est un traitement système).
create or replace function public.assignments_notify()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.entity_id is null or auth.uid() is null or new.user_id = auth.uid() then return null; end if;
  insert into public.notifications (cabinet_id, user_id, entity_id, kind, payload)
  select new.cabinet_id, new.user_id, new.entity_id, 'assigned',
         jsonb_build_object('role_code', r.code, 'role', r.name, 'entity', e.name,
                            'by', (select coalesce(nullif(p.full_name, ''), p.email) from public.profiles p where p.id = auth.uid()))
    from public.roles r, public.entities e
   where r.id = new.role_id and e.id = new.entity_id;
  return null;
end $$;
create trigger assignments_notify after insert on public.assignments
  for each row execute function public.assignments_notify();

-- 5. Collaborateurs affectables à un dossier : actifs, ni associés (déjà partout), ni administrateurs techniques, ni déjà dans l'équipe.
--    Une fonction dédiée, car le chef de mission ne lit pas les affectations des associés (portée cabinet).
create or replace function public.team_candidates(p_entity uuid, p_role text default null)
returns table (id uuid, full_name text, email text, job_title text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.has_permission(null, 'assignments.manage') or public.has_permission(p_entity, 'team.assign')) then
    raise exception 'Permission refusée : affectation sur ce dossier' using errcode = '42501';
  end if;
  return query
    select p.id, p.full_name, p.email, p.job_title
      from public.profiles p
     where p.cabinet_id = public.current_cabinet_id() and p.is_active
       and not public.is_tech_admin(p.id)
       and not exists (select 1 from public.assignments a join public.roles r on r.id = a.role_id
                        where a.user_id = p.id and r.code = 'partner')
       -- déjà dans l'équipe : pour un rôle précis (ex. remplacer le chef de mission), seuls ceux qui ont déjà ce rôle sont écartés
       and not exists (select 1 from public.assignments a join public.roles r on r.id = a.role_id
                        where a.user_id = p.id and a.entity_id = p_entity and (p_role is null or r.code = p_role))
     order by lower(coalesce(nullif(p.full_name, ''), p.email));
end $$;
revoke all on function public.team_candidates(uuid, text) from public, anon;
grant execute on function public.team_candidates(uuid, text) to authenticated;
