-- Affectations : la politique FOR ALL « assignments_write » incluait la lecture et donnait à l'associé toutes les lignes,
-- dont celle de l'administrateur technique, contournant assignments_select (décision D-019).
-- On la remplace par trois politiques d'écriture ; la lecture ne dépend plus que de assignments_select.
-- L'affectation d'un administrateur technique n'est modifiable que par un administrateur technique.
drop policy if exists assignments_write on public.assignments;

create policy assignments_insert on public.assignments for insert to authenticated
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'assignments.manage'));

create policy assignments_update on public.assignments for update to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'assignments.manage')
         and (not public.is_tech_admin(user_id) or public.is_tech_admin(auth.uid())))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'assignments.manage'));

create policy assignments_delete on public.assignments for delete to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'assignments.manage')
         and (not public.is_tech_admin(user_id) or public.is_tech_admin(auth.uid())));
