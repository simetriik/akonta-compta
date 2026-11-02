-- Accès des clients (D-044) : pièces. (La suppression d'un fichier de stockage ne se teste pas en SQL : Storage l'interdit hors API ;
-- elle est vérifiée par l'essai réel contre l'API.)
-- Accès des clients : pièces. Le client voit et supprime ses propres dépôts, jamais ceux du cabinet ;
-- rien quand l'accès est suspendu ou fermé ; le fichier de stockage suit les mêmes règles.
begin;
select plan(12);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.create_user('assist@a.test',  :'a_id', 'Assistant') as id \gset assist_
select tests.create_user('gerant@c1.test', :'a_id', 'Gérant client') as id \gset gerant_
select tests.create_user('saisie@c1.test', :'a_id', 'Saisie client') as id \gset saisie_
select tests.create_entity(:'a_id', 'Client 1 SARL') as id \gset e1_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'gerant_id', :'a_id', 'client_gerant', :'e1_id');
select tests.assign(:'saisie_id', :'a_id', 'client_saisie', :'e1_id');
select public.set_client_access(:'e1_id', 'active');

-- Pièces : une du cabinet, une du gérant, une du saisisseur (insérées hors RLS, avec leur fichier)
insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256, captured_by)
select :'a_id', :'e1_id', :'a_id' || '/' || :'e1_id' || '/' || n || '.pdf', n || '.pdf', 'application/pdf', 10, encode(sha256(n::bytea), 'hex'), u::uuid
  from (values ('cabinet', :'assist_id'), ('gerant', :'gerant_id'), ('saisie', :'saisie_id')) v(n, u);
insert into storage.objects (bucket_id, name, owner_id)
values ('documents', :'a_id' || '/' || :'e1_id' || '/cabinet.pdf', :'assist_id'),
       ('documents', :'a_id' || '/' || :'e1_id' || '/gerant.pdf', :'gerant_id'),
       ('documents', :'a_id' || '/' || :'e1_id' || '/saisie.pdf', :'saisie_id');

select tests.authenticate_as(:'gerant_id', 'aal2');
select is((select string_agg(file_name, ',' order by file_name) from public.documents), 'gerant.pdf,saisie.pdf', 'le gérant voit les dépôts des clients, pas ceux du cabinet');
select is((select count(*) from storage.objects where bucket_id = 'documents'), 2::bigint, 'le gérant lit les fichiers des pièces qu''il voit seulement');
delete from public.documents where file_name = 'cabinet.pdf';
select tests.clear_auth();
select is((select count(*) from public.documents where file_name = 'cabinet.pdf'), 1::bigint, 'le gérant ne supprime pas une pièce du cabinet');

select tests.authenticate_as(:'saisie_id', 'aal1');
select is((select string_agg(file_name, ',') from public.documents), 'saisie.pdf', 'le saisisseur ne voit que ses propres dépôts');
delete from public.documents where file_name = 'gerant.pdf';
select tests.clear_auth();
select is((select count(*) from public.documents where file_name = 'gerant.pdf'), 1::bigint, 'le saisisseur ne supprime pas la pièce d''un autre');

select tests.authenticate_as(:'saisie_id', 'aal1');
select lives_ok(format($q$insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256, captured_by)
  values (%L, %L, %L, 'nouvelle.pdf', 'application/pdf', 10, repeat('a', 64), %L)$q$, :'a_id', :'e1_id', :'a_id' || '/' || :'e1_id' || '/nouvelle.pdf', :'saisie_id'), 'le client dépose une pièce');
select lives_ok(format($q$insert into storage.objects (bucket_id, name, owner_id) values ('documents', %L, %L)$q$, :'a_id' || '/' || :'e1_id' || '/nouvelle.pdf', :'saisie_id'), 'et envoie son fichier');
delete from public.documents where file_name = 'nouvelle.pdf';
select tests.clear_auth();
select is((select count(*) from public.documents where file_name = 'nouvelle.pdf'), 0::bigint, 'il supprime sa propre pièce');

select public.set_client_access(:'e1_id', 'suspended');
select tests.authenticate_as(:'saisie_id', 'aal1');
select throws_ok(format($q$insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256, captured_by)
  values (%L, %L, %L, 'refusee.pdf', 'application/pdf', 10, repeat('b', 64), %L)$q$, :'a_id', :'e1_id', :'a_id' || '/' || :'e1_id' || '/refusee.pdf', :'saisie_id'), '42501', null, 'suspendu : plus de dépôt');
select throws_ok(format($q$insert into storage.objects (bucket_id, name, owner_id) values ('documents', %L, %L)$q$, :'a_id' || '/' || :'e1_id' || '/refusee.pdf', :'saisie_id'), '42501', null, 'suspendu : plus d''envoi de fichier');
select is((select count(*) from public.documents), 1::bigint, 'suspendu : il relit ses pièces');
select tests.clear_auth();

select public.set_client_access(:'e1_id', 'disabled');
select tests.authenticate_as(:'saisie_id', 'aal1');
select is((select count(*) from public.documents) + (select count(*) from storage.objects), 0::bigint, 'fermé : plus rien');
select tests.clear_auth();

select * from finish();
rollback;
