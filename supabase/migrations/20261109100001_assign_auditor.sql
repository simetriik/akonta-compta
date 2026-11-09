-- Recette du 09/11/2026 : le rôle Auditeur (migration 20261106400001) ne pouvait pas être affecté,
-- car la liste des rôles que l'associé peut attribuer (can_assign_role) l'ignorait.
-- Seul l'associé (assignments.manage) attribue l'auditeur ; le chef de mission reste limité à assistant et stagiaire.
-- Aucune fonction nouvelle, aucun droit élargi en écriture : on ajoute un code à une liste blanche existante.
create or replace function public.can_assign_role(p_code text, p_entity uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when public.has_permission(null, 'assignments.manage') then p_code in ('manager', 'assistant', 'trainee', 'auditor', 'client_gerant', 'client_saisie')
    when p_entity is not null and public.has_permission(p_entity, 'team.assign') then p_code in ('assistant', 'trainee')
    else false end;
$$;

-- Retour arrière : recréer can_assign_role avec la liste de 20261105100002_client_access.sql (sans 'auditor'),
-- après avoir retiré les affectations du rôle auditor.
