-- Facturation e-MECeF (D-043) : droits, RLS, jeton inaccessible, immutabilité, calcul de contrôle, avoir.
begin;
select plan(23);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.create_user('manager@a.test', :'a_id', 'Chef') as id \gset manager_
select tests.create_user('assist@a.test',  :'a_id', 'Assistant') as id \gset assist_
select tests.create_user('partner@b.test', :'b_id', 'Associé B') as id \gset partnerb_
select tests.create_entity(:'a_id', 'SARL Test') as id \gset e1_
select tests.create_entity(:'b_id', 'SARL Autre') as id \gset e2_
update public.entities set tax_id = '3201900000001' where id = :'e1_id';
update public.entities set tax_id = '3201900000002' where id = :'e2_id';
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'partnerb_id', :'b_id', 'partner');

-- Droits
select ok((select count(*) from public.role_permissions rp join public.roles r on r.id = rp.role_id
            where r.cabinet_id = :'a_id' and r.code = 'manager' and rp.permission_code = 'invoices.issue') = 1, 'le chef de mission émet des factures');
select ok((select count(*) from public.role_permissions rp join public.roles r on r.id = rp.role_id
            where r.cabinet_id = :'a_id' and r.code = 'manager' and rp.permission_code = 'emcf.manage') = 0, 'le chef de mission ne gère pas les e-MCF');
select ok((select count(*) from public.role_permissions rp join public.roles r on r.id = rp.role_id
            where r.cabinet_id = :'a_id' and r.code = 'partner' and rp.permission_code in ('invoices.issue', 'emcf.manage')) = 2, 'l''associé a les deux droits');

-- e-MCF : seul l'associé (emcf.manage) en crée
select tests.authenticate_as(:'partner_id', 'aal2');
insert into public.emcf_devices (cabinet_id, entity_id, nim, label, mode) values (:'a_id', :'e1_id', 'XX01000001', 'Boutique principale', 'test') returning id as id \gset dev_
select tests.clear_auth();
select ok(:'dev_id' is not null, 'l''associé crée un e-MCF');

select tests.authenticate_as(:'manager_id', 'aal1');
select throws_ok(format($q$insert into public.emcf_devices (cabinet_id, entity_id, nim, label) values (%L, %L, 'XX01000002', 'Autre')$q$, :'a_id', :'e1_id'),
  '42501', null, 'un chef de mission ne crée pas d''e-MCF');
select tests.clear_auth();

-- Jeton : écrit par la clé de service, illisible par l'application
insert into public.emcf_device_tokens (device_id, token) values (:'dev_id', 'jeton.secret.valeur');
select tests.authenticate_as(:'partner_id', 'aal2');
select throws_ok($q$select token from public.emcf_device_tokens$q$, '42501', null, 'l''associé ne peut pas lire les jetons (accès refusé)');
select tests.clear_auth();

-- Facture : création par un chef de mission, refus à un assistant
select tests.authenticate_as(:'manager_id', 'aal1');
insert into public.invoices (cabinet_id, entity_id, device_id, type, operator_name, client_name, aib)
values (:'a_id', :'e1_id', :'dev_id', 'FV', 'Jacques', 'Supermarché SARL', null) returning id as id \gset inv_
insert into public.invoice_lines (invoice_id, position, name, price, quantity, tax_group) values
  (:'inv_id', 1, 'Jus d''orange', 1800, 2, 'B'), (:'inv_id', 2, 'Lait 1/1 EX', 450, 3, 'A');
select tests.clear_auth();
select is((select seller_ifu from public.invoices where id = :'inv_id'), '3201900000001', 'l''IFU du vendeur est repris du dossier');
select is((select is_test from public.invoices where id = :'inv_id'), true, 'facture de test : mode copié de l''e-MCF');

select tests.authenticate_as(:'assist_id', 'aal1');
select throws_ok(format($q$insert into public.invoices (cabinet_id, entity_id, device_id, type, operator_name) values (%L, %L, %L, 'FV', 'X')$q$, :'a_id', :'e1_id', :'dev_id'),
  '42501', null, 'un assistant n''émet pas de facture');
select is((select count(*) from public.invoices), 1::bigint, 'un assistant voit les factures de son dossier');
select tests.clear_auth();

-- Autre cabinet : rien de visible
select tests.authenticate_as(:'partnerb_id', 'aal2');
select is((select count(*) from public.invoices) + (select count(*) from public.emcf_devices), 0::bigint, 'un autre cabinet ne voit ni factures ni e-MCF');
select tests.clear_auth();

-- Calcul de contrôle : exemple de la spécification (tab 3600, hab 3051, vab 549, taa 1350, total 4950)
select tests.authenticate_as(:'manager_id', 'aal1');
select is((select (taa, tab, hab, vab, total) from public.invoice_expected_totals(:'inv_id'))::text, '(1350,3600,3051,549,4950)', 'totaux de contrôle conformes à l''exemple de la spécification');
select tests.clear_auth();

-- Émission : réservée à la clé de service
select tests.authenticate_as(:'manager_id', 'aal1');
select throws_ok(format($q$update public.invoices set status = 'confirmed' where id = %L$q$, :'inv_id'), '42501', null, 'la confirmation directe est refusée');
select throws_ok(format($q$select public.invoice_mark_pending(%L, 'uid-1', '{"total": 4950}')$q$, :'inv_id'), '42501', null, 'invoice_mark_pending est réservée à la clé de service');
select tests.clear_auth();

select public.invoice_mark_pending(:'inv_id', 'ac33f8fe-9735-4ed6-a9c3-df58a908ccd3', '{"total": 4950, "aib": 0}'::jsonb);
select is((select status::text from public.invoices where id = :'inv_id'), 'pending', 'facture en cours d''émission');
select tests.authenticate_as(:'manager_id', 'aal1');
select throws_ok(format($q$update public.invoices set client_name = 'X' where id = %L$q$, :'inv_id'), '42501', null, 'facture en cours d''émission : modification refusée');
select tests.clear_auth();

select public.invoice_mark_confirmed(:'inv_id', '{"codeMECeFDGI": "X537-E4DB-AJUU-HHXN-FWIS-FEKJ", "qrCode": "F;IN01000005;X537E4DBAJUUHHXNFWISFEKJ;3201900000001;20261104131708", "counters": "64/64 FV", "nim": "XX01000001", "dateTime": "04/11/2026 13:17:08", "issuedAt": "2026-11-04T13:17:08+01:00"}'::jsonb);
select tests.authenticate_as(:'manager_id', 'aal1');
select throws_ok(format($q$update public.invoices set client_name = 'X' where id = %L$q$, :'inv_id'), '42501', null, 'facture confirmée : intangible');
delete from public.invoices where id = :'inv_id';
select is((select count(*) from public.invoices where id = :'inv_id'), 1::bigint, 'facture confirmée : la suppression n''enlève rien (RLS, brouillons seulement)');
select throws_ok(format($q$update public.invoice_lines set price = 1 where invoice_id = %L$q$, :'inv_id'), '42501', null, 'lignes d''une facture confirmée : intangibles');

-- Avoir
select lives_ok(format($q$select public.create_credit_note(%L)$q$, :'inv_id'), 'avoir créé depuis une facture confirmée');
select tests.clear_auth();
select is((select reference from public.invoices where type = 'FA' limit 1), 'X537E4DBAJUUHHXNFWISFEKJ', 'référence de l''avoir = code MECeF sans tirets (24 caractères)');
select is((select count(*) from public.invoice_lines l join public.invoices i on i.id = l.invoice_id where i.type = 'FA'), 2::bigint, 'les lignes de la facture d''origine sont reprises');

select tests.authenticate_as(:'assist_id', 'aal1');
select throws_ok(format($q$select public.create_credit_note(%L)$q$, :'inv_id'), '42501', null, 'un assistant ne crée pas d''avoir');
select tests.clear_auth();

select * from finish();
rollback;
