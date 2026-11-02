-- Dépôt de pièces par les clients du cabinet (D-044, tranche 3, étape 4).
-- Même principe que le brouillard : lecture par des politiques supplémentaires étroites, écriture bornée par des politiques
-- restrictives. Un client ne lit, ne modifie et ne supprime que les pièces déposées par les clients de son dossier (le
-- saisisseur : les siennes), jamais celles du cabinet, et rien quand l'accès est suspendu ou fermé.
-- Constat : documents.attach donnait aussi à un client le droit de modifier et supprimer TOUTES les pièces du dossier.

-- Lecture
create policy documents_select_client on public.documents for select to authenticated
  using (public.client_can_read_entity(entity_id)
         and (captured_by = auth.uid()
              or (public.has_permission(entity_id, 'drafts.read_all') and public.is_client_member(captured_by, entity_id))));

-- Écriture : accès actif, et seulement ses propres dépôts pour modifier ou supprimer
create policy documents_client_write_insert on public.documents as restrictive for insert to authenticated
  with check (public.client_write_ok(entity_id));
create policy documents_client_write_update on public.documents as restrictive for update to authenticated
  using (public.client_write_ok(entity_id) and (not public.is_client_member(auth.uid(), entity_id) or captured_by = auth.uid()))
  with check (public.client_write_ok(entity_id) and (not public.is_client_member(auth.uid(), entity_id) or captured_by = auth.uid()));
create policy documents_client_write_delete on public.documents as restrictive for delete to authenticated
  using (public.client_write_ok(entity_id) and (not public.is_client_member(auth.uid(), entity_id) or captured_by = auth.uid()));

-- Rattachement d'une pièce à un brouillard : seulement un brouillard visible, une pièce visible, accès actif
create policy entry_documents_select_client on public.entry_documents for select to authenticated
  using (exists (select 1 from public.entries e where e.id = entry_documents.entry_id));
create policy entry_documents_client_write on public.entry_documents as restrictive for all to authenticated
  using (exists (select 1 from public.entries e where e.id = entry_documents.entry_id
                   and (not public.is_client_member(auth.uid(), e.entity_id) or (e.status = 'draft' and public.client_write_ok(e.entity_id)))))
  with check (exists (select 1 from public.entries e where e.id = entry_documents.entry_id
                        and (not public.is_client_member(auth.uid(), e.entity_id)
                             or (e.status = 'draft' and public.client_write_ok(e.entity_id)
                                 and exists (select 1 from public.documents d where d.id = entry_documents.document_id)))));

-- Stockage : le fichier d'une pièce visible se lit ; on n'envoie que si l'accès est actif ; on ne supprime que ce qu'on a envoyé
create policy documents_bucket_select_client on storage.objects for select to authenticated
  using (bucket_id = 'documents' and public.client_can_read_entity(public.storage_entity_of(name))
         and exists (select 1 from public.documents d where d.storage_path = objects.name));
create policy documents_bucket_client_insert on storage.objects as restrictive for insert to authenticated
  with check (bucket_id <> 'documents' or public.client_write_ok(public.storage_entity_of(name)));
create policy documents_bucket_client_delete on storage.objects as restrictive for delete to authenticated
  using (bucket_id <> 'documents' or (public.client_write_ok(public.storage_entity_of(name))
         and (not public.is_client_member(auth.uid(), public.storage_entity_of(name)) or owner_id = auth.uid()::text)));
