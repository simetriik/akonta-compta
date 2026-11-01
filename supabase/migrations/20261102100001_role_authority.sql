-- Autorité sur les rôles (D-037) : l'associé ne peut ni voir ni attribuer le rôle « administrateur technique »,
-- ni s'accorder des droits d'administration. Constaté le 1er nov. 2026 par un essai annulé : l'associé pouvait donner
-- le rôle d'administrateur technique et ajouter `users.manage` à son propre rôle.
--
-- Règles posées dans la base (l'application ne fait que les refléter) :
--   1. le rôle « administrateur technique » est invisible des autres membres, comme son profil (D-017) ;
--   2. l'associé n'attribue ni ne retire que chef de mission, assistant et stagiaire ;
--   3. les droits des rôles « associé » et « administrateur technique » sont fixes ; les droits d'administration
--      (users.manage, team.manage, roles.manage, assignments.manage) ne s'accordent à aucun autre rôle ;
--   4. plus de rôle sur mesure : un rôle livré ne change que de nom.
-- Les traitements du serveur (auth.uid() nul : fonctions de service, migrations, tests) et le mode interne ne sont pas concernés.

-- 1. Le rôle administrateur technique n'est lisible que par un administrateur technique.
drop policy if exists roles_select on public.roles;
create policy roles_select on public.roles for select to authenticated
  using (cabinet_id = public.current_cabinet_id() and (code <> 'tech_admin' or public.is_tech_admin(auth.uid())));

-- 4. Pas de création ni de suppression de rôle ; seul le nom d'un rôle livré peut changer.
drop policy if exists roles_insert on public.roles;
drop policy if exists roles_delete on public.roles;

create or replace function public.roles_guard_update()
returns trigger language plpgsql set search_path = public as $$
begin
  if auth.uid() is null or public.internal_mode() then return new; end if;
  if new.code is distinct from old.code or new.cabinet_id is distinct from old.cabinet_id or new.is_system is distinct from old.is_system
     or new.grants_all_entities is distinct from old.grants_all_entities or new.requires_mfa is distinct from old.requires_mfa
     or new.accounting_access is distinct from old.accounting_access then
    raise exception 'Seul le nom d''un rôle peut être modifié' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger roles_guard_update before update on public.roles
  for each row execute function public.roles_guard_update();

-- 2. Rôles que l'appelant peut attribuer ou retirer.
create or replace function public.can_assign_role(p_code text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_permission(null, 'assignments.manage') and p_code in ('manager', 'assistant', 'trainee');
$$;
revoke all on function public.can_assign_role(text) from public, anon;
grant execute on function public.can_assign_role(text) to authenticated;

create or replace function public.assignments_authority()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if auth.uid() is null or public.internal_mode() then return coalesce(new, old); end if;
  if tg_op in ('UPDATE', 'DELETE') then
    select code into v_code from public.roles where id = old.role_id;
    if not public.can_assign_role(v_code) then
      raise exception 'Ce rôle ne peut être ni modifié ni retiré par vous' using errcode = '42501';
    end if;
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    select code into v_code from public.roles where id = new.role_id;
    if not public.can_assign_role(v_code) then
      raise exception 'Vous ne pouvez attribuer que les rôles chef de mission, assistant et stagiaire' using errcode = '42501';
    end if;
  end if;
  return coalesce(new, old);
end $$;
create trigger assignments_authority before insert or update or delete on public.assignments
  for each row execute function public.assignments_authority();

-- 3. Droits des rôles : fixes pour associé et administrateur technique ; droits d'administration non accordables.
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
  if v_perm in ('users.manage', 'team.manage', 'roles.manage', 'assignments.manage') then
    raise exception 'Ce droit d''administration ne peut pas être accordé à ce rôle' using errcode = '42501';
  end if;
  return coalesce(new, old);
end $$;
create trigger role_permissions_guard before insert or update or delete on public.role_permissions
  for each row execute function public.role_permissions_guard();

-- La suppression d'un membre sans trace (administrateur technique) retire aussi ses affectations : traitement interne.
create or replace function public.delete_member(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cabinet uuid := public.current_cabinet_id();
begin
  if v_cabinet is null or not public.has_permission(null, 'users.manage') then
    raise exception 'Permission refusée : users.manage' using errcode = '42501';
  end if;
  if p_user = auth.uid() then
    raise exception 'Vous ne pouvez pas supprimer votre propre compte' using errcode = '23514';
  end if;
  if not exists (select 1 from public.profiles where id = p_user and cabinet_id = v_cabinet) then
    raise exception 'Membre introuvable' using errcode = 'P0002';
  end if;
  perform set_config('akonta.internal', 'on', true);
  begin
    delete from public.assignments where user_id = p_user;
    delete from auth.users where id = p_user;   -- le profil suit (on delete cascade)
  exception when foreign_key_violation then
    perform set_config('akonta.internal', 'off', true);
    raise exception 'Ce membre a des traces dans la comptabilité ou la piste d''audit : il ne peut pas être supprimé, désactivez-le' using errcode = '23503';
  end;
  perform set_config('akonta.internal', 'off', true);
end $$;

-- Le créateur d'un dossier (chef de mission) en devient le chef de mission : affectation faite par le système,
-- hors des règles d'attribution ci-dessus.
create or replace function public.entities_assign_creator()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_role uuid;
begin
  if auth.uid() is null or public.grants_all_entities() then return new; end if;
  select r.id into v_role from public.roles r where r.cabinet_id = new.cabinet_id and r.code = 'manager';
  if v_role is not null then
    perform set_config('akonta.internal', 'on', true);
    insert into public.assignments (cabinet_id, user_id, entity_id, role_id, created_by)
    values (new.cabinet_id, auth.uid(), new.id, v_role, auth.uid())
    on conflict do nothing;
    perform set_config('akonta.internal', 'off', true);
  end if;
  return new;
end $$;
