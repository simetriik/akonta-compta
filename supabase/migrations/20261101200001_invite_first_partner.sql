-- Premier associé du cabinet : l'administrateur technique peut inviter la personne avec le rôle « Associé »
-- tant que le cabinet n'en a aucun (Q-016). Ensuite, seul l'associé affecte les rôles (assignments.manage).

-- Le cabinet de l'appelant a-t-il déjà un associé (affectation de portée cabinet) ?
-- Lisible par l'administrateur technique, qui ne voit pas les affectations (D-017) : d'où security definer.
create or replace function public.cabinet_has_partner()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.assignments a
      join public.roles r on r.id = a.role_id
     where a.cabinet_id = public.current_cabinet_id() and r.code = 'partner');
$$;
revoke all on function public.cabinet_has_partner() from public, anon;
grant execute on function public.cabinet_has_partner() to authenticated;

-- Donne le rôle Associé au premier associé. Réservée au service (Edge Function invite-user, après contrôle de users.manage).
create or replace function public.grant_first_partner(p_cabinet uuid, p_user uuid, p_by uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_role uuid;
begin
  -- Verrou par cabinet : deux invitations simultanées ne peuvent pas créer deux « premiers » associés.
  perform pg_advisory_xact_lock(hashtextextended('first_partner:' || p_cabinet::text, 0));
  select id into v_role from public.roles where cabinet_id = p_cabinet and code = 'partner';
  if v_role is null then
    raise exception 'Rôle Associé introuvable pour ce cabinet' using errcode = '23514';
  end if;
  if exists (select 1 from public.assignments where cabinet_id = p_cabinet and role_id = v_role) then
    raise exception 'Le cabinet a déjà un associé : seul l''associé peut en affecter d''autres' using errcode = '23505';
  end if;
  insert into public.assignments (cabinet_id, user_id, entity_id, role_id, created_by)
  values (p_cabinet, p_user, null, v_role, p_by);
end $$;
revoke all on function public.grant_first_partner(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.grant_first_partner(uuid, uuid, uuid) to service_role;
