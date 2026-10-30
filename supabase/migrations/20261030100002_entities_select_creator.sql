-- Création d'un dossier avec INSERT ... RETURNING (décision D-018).
-- can_access_entity() relit public.entities pour contrôler le cabinet et ne voit pas la ligne que la commande en cours
-- vient d'insérer : le RETURNING échouait pour l'associé comme pour le chef de mission (violation RLS).
-- Le créateur voit donc le dossier qu'il a créé (created_by est renseigné par déclencheur).
drop policy if exists entities_select on public.entities;
create policy entities_select on public.entities for select to authenticated
  using (cabinet_id = public.current_cabinet_id()
         and (public.can_access_entity(id) or created_by = auth.uid()));
