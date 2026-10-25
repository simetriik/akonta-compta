-- Module 5 — Pièces justificatives : formats, empreinte, boîte de réception, rattachement, non-suppression (§3.6, §10.5).
begin;
select plan(14);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('assist@a.test',  :'a_id') as id \gset assist_
select tests.create_user('trainee@a.test', :'a_id') as id \gset trainee_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.create_entity(:'a_id', 'Autre dossier') as id \gset e2_
select tests.assign(:'assist_id',  :'a_id', 'assistant', :'e1_id');
select tests.assign(:'trainee_id', :'a_id', 'trainee',   :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select public.create_journals_from_template(:'e1_id', null);
select tests.make_entry(:'e1_id', 'OD', '2026-01-10', 'Loyer', '[{"account":"6221000","debit":100000},{"account":"4710000","credit":100000}]', :'assist_id') as id \gset od1_
select tests.make_entry(:'e1_id', 'OD', '2026-01-11', 'Brouillard', '[{"account":"6221000","debit":5000},{"account":"4710000","credit":5000}]', :'assist_id') as id \gset od2_

select is((select exists (select 1 from storage.buckets where id = 'documents' and not public)), true, 'compartiment privé « documents » créé');
select tests.authenticate_as(:'assist_id');
-- Dépôt
insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256, captured_via)
values (:'a_id', :'e1_id', :'a_id' || '/' || :'e1_id' || '/piece1.pdf', 'facture-loyer.pdf', 'application/pdf', 123456, repeat('ab', 32), 'mobile');
select id as id from public.documents where file_name = 'facture-loyer.pdf' \gset d1_
select throws_ok(format('insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256) values (%L, %L, %L, ''x.docx'', ''application/msword'', 10, %L)', :'a_id', :'e1_id', :'a_id' || '/' || :'e1_id' || '/x.docx', repeat('cd', 32)),
                 '23514', null, 'format non admis (Word) refusé');
select throws_ok(format('insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256) values (%L, %L, %L, ''gros.pdf'', ''application/pdf'', %s, %L)', :'a_id', :'e1_id', :'a_id' || '/' || :'e1_id' || '/gros.pdf', 21 * 1024 * 1024, repeat('ef', 32)),
                 '23514', null, 'plus de 20 Mo refusé');
select throws_ok(format('insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256) values (%L, %L, %L, ''hash.pdf'', ''application/pdf'', 10, ''pasunhash'')', :'a_id', :'e1_id', :'a_id' || '/' || :'e1_id' || '/hash.pdf'),
                 '23514', null, 'empreinte SHA-256 obligatoire (64 hexadécimaux)');
select throws_ok(format('insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256) values (%L, %L, ''ailleurs/piece.pdf'', ''p.pdf'', ''application/pdf'', 10, %L)', :'a_id', :'e1_id', repeat('01', 32)),
                 '23514', null, 'chemin de stockage hors du dossier refusé');
select is((select count(*) from public.document_inbox where entity_id = :'e1_id'), 1::bigint, 'pièce non rattachée = boîte de réception');

-- Rattachement
insert into public.entry_documents (entry_id, document_id) values (:'od1_id', :'d1_id');
select is((select count(*) from public.document_inbox where entity_id = :'e1_id'), 0::bigint, 'pièce rattachée : sortie de la boîte de réception');
select throws_ok(format('update public.documents set sha256 = %L where id = %L', repeat('ff', 32), :'d1_id'), '23514', null, 'le fichier d''une pièce ne se remplace pas');
select lives_ok(format('delete from public.entry_documents where entry_id = %L and document_id = %L', :'od1_id', :'d1_id'), 'détachement possible tant que l''écriture est en brouillard');
insert into public.entry_documents (entry_id, document_id) values (:'od1_id', :'d1_id');
select public.validate_entry(:'od1_id');
select throws_ok(format('delete from public.entry_documents where entry_id = %L and document_id = %L', :'od1_id', :'d1_id'), '42501', null, 'pièce liée à une écriture validée : non détachable');
select throws_ok(format('delete from public.documents where id = %L', :'d1_id'), '42501', null, 'pièce liée à une écriture validée : non supprimable');
select tests.clear_auth();
insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256)
values (:'a_id', :'e2_id', :'a_id' || '/' || :'e2_id' || '/autre.pdf', 'autre.pdf', 'application/pdf', 10, repeat('03', 32));
select throws_ok(format('insert into public.entry_documents (entry_id, document_id) select %L, id from public.documents where file_name = ''autre.pdf''', :'od2_id'), '23514', null,
                 'une pièce ne se rattache pas à l''écriture d''un autre dossier');

-- Permissions
select tests.authenticate_as(:'trainee_id');
select throws_ok(format('insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256) values (%L, %L, %L, ''t.pdf'', ''application/pdf'', 10, %L)', :'a_id', :'e1_id', :'a_id' || '/' || :'e1_id' || '/t.pdf', repeat('02', 32)),
                 '42501', null, 'stagiaire : ne joint pas de pièces');
select is((select count(*) from public.documents), 1::bigint, 'stagiaire : consulte les pièces de son dossier');
select tests.clear_auth();

select * from finish();
rollback;
