-- Recette du 09/11/2026 (AN-02) : la suppression d'un dossier vide échouait dès qu'un journal de trésorerie existait,
-- car `journals.treasury_account_id` référence un compte du dossier et les comptes étaient supprimés avant les journaux.
-- Correctif : les journaux (sans écriture, déjà vérifié plus haut) partent avant le plan de comptes.
-- Le journal des à-nouveaux est protégé contre la suppression directe : il part en cascade avec le dossier.
create or replace function public.delete_empty_duplicate_entity(p_entity uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cabinet uuid := public.current_cabinet_id();
  v_name text;
  v_table text;
  v_used bigint;
begin
  if v_cabinet is null or not public.has_permission(p_entity, 'entities.manage') then
    raise exception 'Permission refusée : entities.manage' using errcode = '42501';
  end if;
  select name into v_name from public.entities where id = p_entity and cabinet_id = v_cabinet;
  if not found then
    raise exception 'Dossier introuvable' using errcode = 'P0002';
  end if;
  foreach v_table in array array['entries', 'documents', 'third_parties', 'bank_statements', 'import_batches', 'invoices',
                                 'fixed_assets', 'provisions', 'accruals', 'inventory_stocks', 'fx_revaluations',
                                 'financial_statements', 'closing_archives', 'letterings'] loop
    execute format('select count(*) from public.%I where entity_id = $1', v_table) into v_used using p_entity;
    if v_used > 0 then
      raise exception 'Le dossier « % » contient déjà des données (%) : il ne peut pas être supprimé. Archivez-le (désactivation) ou contactez l''administrateur.', v_name, v_table
        using errcode = '23503';
    end if;
  end loop;
  delete from public.assignments where entity_id = p_entity;
  -- Les journaux référencent le compte de trésorerie : ils se suppriment avant le plan de comptes.
  delete from public.journals where entity_id = p_entity and type <> 'opening';
  -- Le plan de comptes se supprime des feuilles vers la racine (un compte à subdivisions ne se supprime pas).
  loop
    delete from public.accounts a where a.entity_id = p_entity
      and not exists (select 1 from public.accounts c where c.parent_id = a.id);
    exit when not found;
  end loop;
  delete from public.entities where id = p_entity;
end $$;
revoke all on function public.delete_empty_duplicate_entity(uuid) from public, anon;
grant execute on function public.delete_empty_duplicate_entity(uuid) to authenticated;

-- Retour arrière : rejouer la définition de 20261106100001_entity_duplicates.sql (sans la ligne de suppression des journaux).
