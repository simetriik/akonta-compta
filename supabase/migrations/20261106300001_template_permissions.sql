-- Recette du 05/11/2026, point 1 : droits sur les modèles d'écriture (décision provisoire, paramétrable).
--   modèles communs du cabinet : associé et chefs de mission (« seniors ») ;
--   modèles d'un dossier       : tout collaborateur affecté au dossier (stagiaire, assistant, chef de mission, associé).
-- Les deux droits sont des permissions comme les autres : l'associé les retire ou les donne par rôle (roles.manage).
-- Les anciens droits (cabinet.settings, references.manage) restent acceptés : rien ne se ferme pour qui écrivait déjà.

insert into public.permissions (code, label, category, sort_order) values
  ('templates.manage_common', 'Gérer les modèles d''écriture communs du cabinet', 'referentiels', 91),
  ('templates.manage_entity', 'Gérer les modèles d''écriture d''un dossier',       'referentiels', 92);

-- Droits par défaut, rôle par rôle (cabinets existants), puis pour chaque nouveau cabinet.
create or replace function public.seed_template_permissions(p_cabinet uuid)
returns void language sql security definer set search_path = public as $$
  insert into public.role_permissions (role_id, permission_code)
  select r.id, v.code
    from public.roles r
    join (values
      ('partner', 'templates.manage_common'), ('manager', 'templates.manage_common'),
      ('partner', 'templates.manage_entity'), ('manager', 'templates.manage_entity'),
      ('assistant', 'templates.manage_entity'), ('trainee', 'templates.manage_entity')
    ) as v(role_code, code) on v.role_code = r.code
   where r.cabinet_id = p_cabinet
  on conflict do nothing;
$$;
revoke all on function public.seed_template_permissions(uuid) from public, anon, authenticated;

select public.seed_template_permissions(id) from public.cabinets;

create or replace function public.handle_new_cabinet_templates()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.seed_template_permissions(new.id);
  return new;
end $$;
-- Le nom place ce déclencheur après on_cabinet_created, qui crée les rôles.
create trigger on_cabinet_created_templates after insert on public.cabinets
  for each row execute function public.handle_new_cabinet_templates();

-- Le droit est-il accordé à l'utilisateur sur un dossier quelconque, ou à l'échelle du cabinet ?
-- (Les chefs de mission sont affectés dossier par dossier : « senior » se lit sur au moins une affectation.)
create or replace function public.has_permission_anywhere(p_code text)
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
  );
$$;
revoke all on function public.has_permission_anywhere(text) from public, anon;
grant execute on function public.has_permission_anywhere(text) to authenticated;

-- Droit d'écriture sur un modèle (commun si entity_id est nul).
create or replace function public.can_write_template(p_cabinet uuid, p_entity uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_cabinet = public.current_cabinet_id() and case
    when p_entity is null then public.has_permission(null, 'cabinet.settings') or public.has_permission_anywhere('templates.manage_common')
    else public.has_permission(p_entity, 'references.manage') or public.has_permission(p_entity, 'templates.manage_entity')
  end;
$$;
revoke all on function public.can_write_template(uuid, uuid) from public, anon;
grant execute on function public.can_write_template(uuid, uuid) to authenticated;

drop policy entry_templates_write on public.entry_templates;
create policy entry_templates_write on public.entry_templates for all
  using (public.can_write_template(cabinet_id, entity_id))
  with check (public.can_write_template(cabinet_id, entity_id));

drop policy entry_template_lines_write on public.entry_template_lines;
create policy entry_template_lines_write on public.entry_template_lines for all
  using (exists (select 1 from public.entry_templates t where t.id = template_id and public.can_write_template(t.cabinet_id, t.entity_id)))
  with check (exists (select 1 from public.entry_templates t where t.id = template_id and public.can_write_template(t.cabinet_id, t.entity_id)));

-- Retour arrière (à exécuter à la main) : recréer les deux politiques d'origine (voir 20261025200003_referentiels.sql), puis
--   drop function public.can_write_template(uuid, uuid); drop function public.has_permission_anywhere(text);
--   drop trigger on_cabinet_created_templates on public.cabinets; drop function public.handle_new_cabinet_templates();
--   drop function public.seed_template_permissions(uuid);
--   delete from public.role_permissions where permission_code like 'templates.manage_%';
--   delete from public.permissions where code like 'templates.manage_%';
