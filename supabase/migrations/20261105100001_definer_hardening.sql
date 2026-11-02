-- Durcissement de trois fonctions security definer appelables en RPC (D-044, tranche 3 : accès des clients).
-- Avant : copy_reference_plan, create_journals_from_template et audit_chain_verify ne contrôlaient aucun droit ;
-- tout utilisateur connecté pouvait écrire dans le plan de comptes ou les journaux de n'importe quel dossier,
-- ou vérifier la piste d'audit de n'importe quel cabinet. Il faut le corriger avant d'ouvrir des comptes aux clients.
--
-- Méthode : le corps existant devient une fonction interne que personne n'appelle directement (déclencheurs seulement) ;
-- la fonction publique, de même signature, devient une garde mince qui vérifie le droit puis délègue.

-- 1. Corps existants → fonctions internes, fermées à tous les rôles de l'API
alter function public.copy_reference_plan(uuid) rename to internal_copy_reference_plan;
alter function public.create_journals_from_template(uuid, text[]) rename to internal_create_journals_from_template;
alter function public.audit_chain_verify(uuid) rename to internal_audit_chain_verify;

revoke all on function public.internal_copy_reference_plan(uuid) from public, anon, authenticated;
revoke all on function public.internal_create_journals_from_template(uuid, text[]) from public, anon, authenticated;
revoke all on function public.internal_audit_chain_verify(uuid) from public, anon, authenticated;

-- 2. Le déclencheur de création d'un dossier appelle directement les fonctions internes (il n'a pas de droit à vérifier)
create or replace function public.entities_init_referentials()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.internal_copy_reference_plan(new.id);
  perform public.internal_create_journals_from_template(new.id, '{}');   -- uniquement les journaux imposés (AN)
  return new;
end $$;

-- 3. Gardes publiques : même signature qu'avant, droit vérifié sur le dossier ou le cabinet visé
create or replace function public.copy_reference_plan(p_entity uuid)
returns integer language plpgsql security definer set search_path = public as $$
begin
  -- Sans utilisateur connecté (clé de service, administration de la base) l'appelant est de confiance.
  if auth.uid() is not null and not public.has_permission(p_entity, 'references.manage') then
    raise exception 'Droit insuffisant sur ce dossier' using errcode = '42501';
  end if;
  return public.internal_copy_reference_plan(p_entity);
end $$;

create or replace function public.create_journals_from_template(p_entity uuid, p_codes text[] default null)
returns integer language plpgsql security definer set search_path = public as $$
begin
  -- Sans utilisateur connecté (clé de service, administration de la base) l'appelant est de confiance.
  if auth.uid() is not null and not public.has_permission(p_entity, 'references.manage') then
    raise exception 'Droit insuffisant sur ce dossier' using errcode = '42501';
  end if;
  return public.internal_create_journals_from_template(p_entity, p_codes);
end $$;

create or replace function public.audit_chain_verify(p_cabinet uuid)
returns bigint language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is not null
     and (p_cabinet is distinct from public.current_cabinet_id() or not public.has_permission(null, 'audit.read')) then
    raise exception 'Droit insuffisant sur ce cabinet' using errcode = '42501';
  end if;
  return public.internal_audit_chain_verify(p_cabinet);
end $$;

revoke all on function public.copy_reference_plan(uuid) from public, anon;
revoke all on function public.create_journals_from_template(uuid, text[]) from public, anon;
revoke all on function public.audit_chain_verify(uuid) from public, anon;
grant execute on function public.copy_reference_plan(uuid) to authenticated;
grant execute on function public.create_journals_from_template(uuid, text[]) to authenticated;
grant execute on function public.audit_chain_verify(uuid) to authenticated;
