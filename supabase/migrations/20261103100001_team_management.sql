-- L'associé gère son équipe (D-039) : il crée, modifie, désactive, supprime et réinitialise le mot de passe des chefs de mission,
-- assistants et stagiaires, et d'eux seuls. L'administrateur technique gère tout le monde et désigne les autres associés.

-- 1. Droit « gérer l'équipe » : associé seulement (non accordable : voir role_permissions_guard).
insert into public.permissions (code, label, category, sort_order)
values ('team.manage', 'Gérer l''équipe (chefs de mission, assistants, stagiaires)', 'cabinet', 153)
on conflict (code) do nothing;
insert into public.role_permissions (role_id, permission_code)
select id, 'team.manage' from public.roles where code = 'partner'
on conflict do nothing;

-- 2. Qui l'appelant peut-il gérer ? Administrateur : tous les membres du cabinet sauf lui-même ; associé : ceux qui n'ont
--    aucun rôle d'associé ni d'administrateur (comptes sans rôle compris), sauf lui-même.
create or replace function public.can_manage_member(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_user is distinct from auth.uid()
     and exists (select 1 from public.profiles t where t.id = p_user and t.cabinet_id = public.current_cabinet_id())
     and (public.has_permission(null, 'users.manage')
          or (public.has_permission(null, 'team.manage')
              and not exists (select 1 from public.assignments a join public.roles r on r.id = a.role_id
                               where a.user_id = p_user and r.code in ('partner', 'tech_admin'))));
$$;
revoke all on function public.can_manage_member(uuid) from public, anon;
grant execute on function public.can_manage_member(uuid) to authenticated;

-- 3. Modification d'un profil : l'administrateur (tous) ou l'associé (son équipe) ; chacun reste maître de son propre nom.
drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin on public.profiles for update to authenticated
  using (cabinet_id = public.current_cabinet_id() and (public.has_permission(null, 'users.manage') or public.can_manage_member(id)))
  with check (cabinet_id = public.current_cabinet_id());

-- L'adresse e-mail et le cabinet d'un profil ne changent pas par l'application ; on ne se désactive pas soi-même.
create or replace function public.profiles_guard_update()
returns trigger language plpgsql set search_path = public as $$
begin
  if auth.uid() is null or public.internal_mode() then return new; end if;
  if new.email is distinct from old.email or new.cabinet_id is distinct from old.cabinet_id or new.id is distinct from old.id then
    raise exception 'L''adresse e-mail et le cabinet d''un membre ne se modifient pas' using errcode = '42501';
  end if;
  if new.is_active is distinct from old.is_active and new.id = auth.uid() then
    raise exception 'Vous ne pouvez pas désactiver votre propre compte' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger profiles_guard_update before update on public.profiles
  for each row execute function public.profiles_guard_update();

-- 4. Suppression d'un membre sans trace : administrateur (tous) ou associé (son équipe).
create or replace function public.delete_member(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cabinet uuid := public.current_cabinet_id();
begin
  if v_cabinet is null then
    raise exception 'Permission refusée' using errcode = '42501';
  end if;
  if p_user = auth.uid() then
    raise exception 'Vous ne pouvez pas supprimer votre propre compte' using errcode = '23514';
  end if;
  if not exists (select 1 from public.profiles where id = p_user and cabinet_id = v_cabinet) then
    raise exception 'Membre introuvable' using errcode = 'P0002';
  end if;
  if not public.can_manage_member(p_user) then
    raise exception 'Vous ne pouvez pas gérer ce membre' using errcode = '42501';
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

-- 5. Désignation d'un associé (administrateur technique seulement, tracée dans l'audit par le déclencheur des affectations).
create or replace function public.designate_partner(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cabinet uuid := public.current_cabinet_id();
  v_role uuid;
begin
  if v_cabinet is null or not public.has_permission(null, 'users.manage') then
    raise exception 'Permission refusée : users.manage' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = p_user and cabinet_id = v_cabinet and is_active) or public.is_tech_admin(p_user) then
    raise exception 'Collaborateur introuvable, désactivé ou administrateur technique' using errcode = 'P0002';
  end if;
  select id into v_role from public.roles where cabinet_id = v_cabinet and code = 'partner';
  perform set_config('akonta.internal', 'on', true);
  insert into public.assignments (cabinet_id, user_id, entity_id, role_id, created_by)
  values (v_cabinet, p_user, null, v_role, auth.uid())
  on conflict do nothing;
  perform set_config('akonta.internal', 'off', true);
end $$;
revoke all on function public.designate_partner(uuid) from public, anon;
grant execute on function public.designate_partner(uuid) to authenticated;

create or replace function public.revoke_partner(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cabinet uuid := public.current_cabinet_id();
  v_role uuid;
begin
  if v_cabinet is null or not public.has_permission(null, 'users.manage') then
    raise exception 'Permission refusée : users.manage' using errcode = '42501';
  end if;
  select id into v_role from public.roles where cabinet_id = v_cabinet and code = 'partner';
  if (select count(*) from public.assignments where role_id = v_role) <= 1 then
    raise exception 'Le cabinet doit garder au moins un associé' using errcode = '23514';
  end if;
  perform set_config('akonta.internal', 'on', true);
  delete from public.assignments where user_id = p_user and role_id = v_role;
  perform set_config('akonta.internal', 'off', true);
end $$;
revoke all on function public.revoke_partner(uuid) from public, anon;
grant execute on function public.revoke_partner(uuid) to authenticated;
