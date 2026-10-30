-- L'administrateur technique est invisible des membres du cabinet (décision D-017, question Q-017).
-- Il reste visible de lui-même et des autres administrateurs techniques ; ses actions restent dans la piste d'audit
-- sous un libellé générique pour les autres membres.

-- Vrai si l'utilisateur porte un rôle « administrateur technique ».
create or replace function public.is_tech_admin(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.assignments a join public.roles r on r.id = a.role_id
     where a.user_id = p_user and r.code = 'tech_admin');
$$;

-- Profils : un membre ne voit pas le profil d'un administrateur technique (sauf si lui-même en est un).
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (cabinet_id = public.current_cabinet_id()
         and (id = auth.uid() or not public.is_tech_admin(id) or public.is_tech_admin(auth.uid())));

-- Affectations : celles d'un administrateur technique sont masquées de la même manière.
drop policy if exists assignments_select on public.assignments;
create policy assignments_select on public.assignments for select to authenticated
  using (cabinet_id = public.current_cabinet_id()
         and (user_id = auth.uid() or not public.is_tech_admin(user_id) or public.is_tech_admin(auth.uid()))
         and (user_id = auth.uid()
              or public.has_permission(null, 'assignments.manage')
              or public.has_permission(null, 'users.manage')
              or (entity_id is not null and public.can_access_entity(entity_id))));

-- Libellés des auteurs d'actions pour la piste d'audit : un administrateur technique apparaît sous un nom générique
-- aux membres qui ne le sont pas. Limité au cabinet de l'appelant.
create or replace function public.actor_labels(p_ids uuid[])
returns table (id uuid, label text) language sql stable security definer set search_path = public as $$
  select p.id,
         case when public.is_tech_admin(p.id) and not public.is_tech_admin(auth.uid()) and p.id <> auth.uid()
              then 'Administration technique'
              else coalesce(nullif(p.full_name, ''), p.email) end
    from public.profiles p
   where p.id = any (p_ids) and p.cabinet_id = public.current_cabinet_id();
$$;
revoke all on function public.actor_labels(uuid[]) from public, anon;
grant execute on function public.actor_labels(uuid[]) to authenticated;
