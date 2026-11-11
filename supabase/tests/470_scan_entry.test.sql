-- Saisie par scan : l'écriture proposée à partir d'une pièce est un brouillard « généré », équilibré, lié à la pièce,
-- jamais écrasé par un second scan, et soumis aux droits de saisie.
begin;
select plan(12);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('assist@a.test', :'a_id', 'Assistant') as id \gset assist_
select tests.create_user('audit@a.test',  :'a_id', 'Auditeur') as id \gset audit_
select tests.create_user('saisie@c.test', :'a_id', 'Saisie client') as id \gset saisie_
select tests.create_user('other@b.test',  :'b_id', 'Autre') as id \gset other_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'audit_id', :'a_id', 'auditor', :'e1_id');
select tests.assign(:'saisie_id', :'a_id', 'client_saisie', :'e1_id');
select tests.assign(:'other_id', :'b_id', 'partner');
select public.set_client_access(:'e1_id', 'active');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2027-01-01', '2027-12-31');
select public.create_journals_from_template(:'e1_id', null);
create temp table acc as select code, id from public.accounts where entity_id = :'e1_id';
grant select on acc to authenticated;

insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256, captured_by)
select :'a_id', :'e1_id', :'a_id' || '/' || :'e1_id' || '/' || n || '.pdf', n || '.pdf', 'application/pdf', 10, encode(sha256(n::bytea), 'hex'), u::uuid
  from (values ('cabinet', :'assist_id'), ('client', :'saisie_id')) v(n, u);
select id as id from public.documents where file_name = 'cabinet.pdf' \gset doc_
select id as id from public.documents where file_name = 'client.pdf' \gset cdoc_

select format($j$ {"date": "2027-01-03", "label": "Cimenterie du Golfe FA-FCG-0215", "reference": "FA-FCG-0215", "journal_type": "purchases",
  "lines": [ {"account_id": "%s", "debit": 4200000, "label": "Achat"}, {"account_id": "%s", "debit": 756000, "label": "TVA"},
             {"account_id": "%s", "credit": 4956000, "label": "Fournisseur"} ] } $j$,
  (select id from acc where code = '6011000'), (select id from acc where code = '4452000'), (select id from acc where code = '4011000')) as p \gset good_
select format($j$ {"date": "2027-01-03", "label": "Déséquilibrée", "lines": [ {"account_id": "%s", "debit": 100}, {"account_id": "%s", "credit": 90} ] } $j$,
  (select id from acc where code = '6011000'), (select id from acc where code = '4011000')) as p \gset bad_

-- 1-2. Droits : l'auditeur (lecture seule) et un autre cabinet sont refusés
select tests.authenticate_as(:'audit_id', 'aal1');
select throws_ok(format('select public.generate_scan_entry(%L, %L::jsonb)', :'doc_id', :'good_p'), '42501', null, 'un auditeur ne génère pas de brouillard');
select tests.clear_auth();
select tests.authenticate_as(:'other_id', 'aal2');
select throws_ok(format('select public.generate_scan_entry(%L, %L::jsonb)', :'doc_id', :'good_p'), '42501', null, 'un autre cabinet ne voit pas la pièce');
select tests.clear_auth();

-- 3. Proposition déséquilibrée refusée, rien n'est créé
select tests.authenticate_as(:'assist_id', 'aal1');
select throws_ok(format('select public.generate_scan_entry(%L, %L::jsonb)', :'doc_id', :'bad_p'), '23514', null, 'une proposition déséquilibrée est refusée');
select is((select count(*) from public.entries where generated_source = 'document:' || :'doc_id'), 0::bigint, 'aucune écriture créée après le refus');

-- 5-8. Génération nominale
select public.generate_scan_entry(:'doc_id', :'good_p'::jsonb) as id \gset entry_
select is((select status::text from public.entries where id = :'entry_id'), 'draft', 'l''écriture est en brouillard');
select ok((select is_generated and generated_source = 'document:' || :'doc_id' and reference = 'FA-FCG-0215' from public.entries where id = :'entry_id'), 'marquée « générée », source document:<id>, référence reprise');
select is((select count(*) from public.entry_documents where entry_id = :'entry_id' and document_id = :'doc_id'), 1::bigint, 'la pièce est liée à l''écriture');
select is((select sum(debit) - sum(credit) from public.entry_lines where entry_id = :'entry_id')::bigint, 0::bigint, 'écriture équilibrée');

-- 9-10. Un second scan ne réécrit pas le brouillard retouché par le comptable
update public.entries set label = 'Libellé retouché' where id = :'entry_id';
select is(public.generate_scan_entry(:'doc_id', :'good_p'::jsonb), :'entry_id'::uuid, 'second scan : même écriture renvoyée');
select is((select label from public.entries where id = :'entry_id'), 'Libellé retouché', 'la retouche du comptable est conservée');
select tests.clear_auth();

-- 11-12. Client : sa propre pièce oui, celle du cabinet non
select tests.authenticate_as(:'saisie_id', 'aal1');
select throws_ok(format('select public.generate_scan_entry(%L, %L::jsonb)', :'doc_id', :'good_p'), '42501', null, 'le client ne traite pas une pièce du cabinet');
select lives_ok(format('select public.generate_scan_entry(%L, %L::jsonb)', :'cdoc_id', :'good_p'), 'le client traite sa propre pièce (brouillard)');
select tests.clear_auth();

select * from finish();
rollback;
