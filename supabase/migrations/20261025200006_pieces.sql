-- =============================================================================
-- Akonta — Migration 0006 : pièces justificatives (module 5, conception §3.6, §10.5)
-- Documents (empreinte SHA-256, 20 Mo max, PDF/JPEG/PNG/HEIC), boîte de réception
-- par dossier, rattachement n-n aux écritures, compartiment Storage privé.
-- =============================================================================

create type public.capture_channel as enum ('desktop', 'mobile', 'import');

create table public.documents (
  id            uuid primary key default gen_random_uuid(),
  cabinet_id    uuid not null references public.cabinets (id) on delete cascade,
  entity_id     uuid not null references public.entities (id) on delete cascade,
  storage_path  text not null unique,                       -- documents/<cabinet>/<entity>/<id>.<ext>
  file_name     text not null check (length(file_name) between 1 and 255),
  mime_type     text not null check (mime_type in ('application/pdf', 'image/jpeg', 'image/png', 'image/heic', 'image/heif')),
  size_bytes    bigint not null check (size_bytes > 0 and size_bytes <= 20 * 1024 * 1024),
  sha256        text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  captured_via  public.capture_channel not null default 'desktop',
  captured_by   uuid references public.profiles (id),
  captured_at   timestamptz not null default now(),
  note          text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on table public.documents is 'Pièce justificative : fichier dans le Storage privé, empreinte SHA-256, conservée 10 ans. Sans rattachement = boîte de réception du dossier.';
create index documents_entity_idx on public.documents (entity_id, captured_at desc);
create index documents_sha_idx on public.documents (entity_id, sha256);
create trigger documents_updated_at before update on public.documents for each row execute function public.set_updated_at();
create trigger documents_cabinet before insert or update on public.documents for each row execute function public.check_entity_cabinet();

create or replace function public.documents_defaults()
returns trigger language plpgsql as $$
begin
  if new.captured_by is null then new.captured_by := auth.uid(); end if;
  if new.storage_path !~ ('^' || new.cabinet_id::text || '/' || new.entity_id::text || '/') then
    raise exception 'Chemin de stockage attendu : <cabinet>/<entité>/…' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger documents_defaults before insert on public.documents for each row execute function public.documents_defaults();

create or replace function public.documents_guard_update()
returns trigger language plpgsql as $$
begin
  if new.storage_path <> old.storage_path or new.sha256 <> old.sha256 or new.size_bytes <> old.size_bytes
     or new.mime_type <> old.mime_type or new.entity_id <> old.entity_id or new.cabinet_id <> old.cabinet_id then
    raise exception 'Le fichier d''une pièce ne se remplace pas : déposer une nouvelle pièce' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger documents_guard_update before update on public.documents for each row execute function public.documents_guard_update();

create table public.entry_documents (
  entry_id     uuid not null references public.entries (id) on delete cascade,
  document_id  uuid not null references public.documents (id),
  attached_by  uuid references public.profiles (id),
  attached_at  timestamptz not null default now(),
  primary key (entry_id, document_id)
);
create index entry_documents_document_idx on public.entry_documents (document_id);

create or replace function public.entry_documents_validate()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_entity uuid;
begin
  if new.attached_by is null then new.attached_by := auth.uid(); end if;
  select entity_id into v_entity from public.entries where id = new.entry_id;
  if not exists (select 1 from public.documents d where d.id = new.document_id and d.entity_id = v_entity) then
    raise exception 'La pièce appartient à un autre dossier' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger entry_documents_validate before insert on public.entry_documents
  for each row execute function public.entry_documents_validate();

-- Pièce liée à une écriture validée : ni détachée, ni supprimée (§10.5).
create or replace function public.entry_documents_guard_delete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.entries e where e.id = old.entry_id and e.status = 'validated') and not public.internal_mode() then
    raise exception 'Pièce liée à une écriture validée : non détachable' using errcode = '42501';
  end if;
  return old;
end $$;
create trigger entry_documents_guard_delete before delete on public.entry_documents
  for each row when (pg_trigger_depth() = 0) execute function public.entry_documents_guard_delete();

create or replace function public.documents_guard_delete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.entry_documents ed join public.entries e on e.id = ed.entry_id
              where ed.document_id = old.id and e.status = 'validated') then
    raise exception 'Pièce liée à une écriture validée : non supprimable' using errcode = '42501';
  end if;
  if exists (select 1 from public.fiscal_years fy where fy.entity_id = old.entity_id and fy.status = 'closed'
                and old.captured_at::date between fy.start_date and fy.end_date) then
    raise exception 'Pièce d''un exercice clôturé : non supprimable' using errcode = '42501';
  end if;
  return old;
end $$;
create trigger documents_guard_delete before delete on public.documents
  for each row when (pg_trigger_depth() = 0) execute function public.documents_guard_delete();

-- Boîte de réception : pièces non rattachées d''un dossier
create or replace view public.document_inbox with (security_invoker = true) as
  select d.*
    from public.documents d
   where not exists (select 1 from public.entry_documents ed where ed.document_id = d.id);

-- Journalisation et RLS
create trigger audit_documents after insert or delete on public.documents
  for each row when (pg_trigger_depth() = 0) execute function public.audit_row_change();

alter table public.documents       enable row level security;
alter table public.entry_documents enable row level security;

create policy documents_select on public.documents for select to authenticated using (public.can_access_entity(entity_id));
create policy documents_insert on public.documents for insert to authenticated
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'documents.attach') and captured_by = auth.uid());
create policy documents_update on public.documents for update to authenticated
  using (public.has_permission(entity_id, 'documents.attach')) with check (public.has_permission(entity_id, 'documents.attach'));
create policy documents_delete on public.documents for delete to authenticated
  using (public.has_permission(entity_id, 'documents.attach'));

create policy entry_documents_select on public.entry_documents for select to authenticated
  using (exists (select 1 from public.entries e where e.id = entry_id and public.can_access_entity(e.entity_id)));
create policy entry_documents_write on public.entry_documents for all to authenticated
  using (exists (select 1 from public.entries e where e.id = entry_id and public.has_permission(e.entity_id, 'documents.attach')))
  with check (exists (select 1 from public.entries e where e.id = entry_id and public.has_permission(e.entity_id, 'documents.attach')));

-- -----------------------------------------------------------------------------
-- Storage : compartiment privé « documents », chemin <cabinet>/<entité>/<fichier>
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documents', 'documents', false, 20 * 1024 * 1024,
        array['application/pdf', 'image/jpeg', 'image/png', 'image/heic', 'image/heif'])
on conflict (id) do nothing;

create or replace function public.storage_entity_of(p_name text)
returns uuid language sql immutable as $$
  select case when (storage.foldername(p_name))[2] ~ '^[0-9a-f-]{36}$' then (storage.foldername(p_name))[2]::uuid end;
$$;

create policy documents_bucket_select on storage.objects for select to authenticated
  using (bucket_id = 'documents' and public.can_access_entity(public.storage_entity_of(name)));
create policy documents_bucket_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'documents'
              and (storage.foldername(name))[1] = public.current_cabinet_id()::text
              and public.has_permission(public.storage_entity_of(name), 'documents.attach'));
create policy documents_bucket_delete on storage.objects for delete to authenticated
  using (bucket_id = 'documents'
         and public.has_permission(public.storage_entity_of(name), 'documents.attach')
         and not exists (select 1 from public.documents d join public.entry_documents ed on ed.document_id = d.id
                           join public.entries e on e.id = ed.entry_id
                          where d.storage_path = name and e.status = 'validated'));
