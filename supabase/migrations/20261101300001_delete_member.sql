-- Suppression d'un membre par l'administrateur technique. La conception prévoit « désactivation, jamais de suppression »
-- (§10.1) pour préserver la piste d'audit ; on n'autorise donc la suppression que d'un membre SANS AUCUNE TRACE
-- (invitation erronée, compte jamais utilisé). Dès qu'il a créé, validé, importé ou attaché quoi que ce soit,
-- une clé étrangère refuse la suppression et il faut le désactiver. La suppression est journalisée (profil et affectations).
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
  begin
    delete from public.assignments where user_id = p_user;
    delete from auth.users where id = p_user;   -- le profil suit (on delete cascade)
  exception when foreign_key_violation then
    raise exception 'Ce membre a des traces dans la comptabilité ou la piste d''audit : il ne peut pas être supprimé, désactivez-le' using errcode = '23503';
  end;
end $$;
revoke all on function public.delete_member(uuid) from public, anon;
grant execute on function public.delete_member(uuid) to authenticated;
