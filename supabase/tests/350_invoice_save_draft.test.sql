-- Enregistrement atomique d'un brouillon de facture : création, remplacement des lignes, refus après émission, droits, retour arrière.
begin;
select plan(11);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('manager@a.test', :'a_id', 'Chef') as id \gset manager_
select tests.create_user('assist@a.test',  :'a_id', 'Assistant') as id \gset assist_
select tests.create_entity(:'a_id', 'SARL Test') as id \gset e1_
update public.entities set tax_id = '3201900000001' where id = :'e1_id';
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
insert into public.emcf_devices (cabinet_id, entity_id, nim, label) values (:'a_id', :'e1_id', 'XX01000001', 'Boutique') returning id as id \gset dev_

select tests.authenticate_as(:'manager_id', 'aal1');
select public.save_invoice_draft(null, jsonb_build_object(
  'cabinet_id', :'a_id', 'entity_id', :'e1_id', 'device_id', :'dev_id', 'type', 'FV', 'operator_name', 'Jacques', 'client_name', 'Supermarché',
  'lines', jsonb_build_array(
    jsonb_build_object('name', 'Jus d''orange', 'price', 1800, 'quantity', 2, 'tax_group', 'B'),
    jsonb_build_object('name', 'Lait 1/1 EX', 'price', 450, 'quantity', 3, 'tax_group', 'A')),
  'payments', jsonb_build_array(jsonb_build_object('name', 'ESPECES', 'amount', 4950)))) as id \gset inv_
select tests.clear_auth();

select is((select count(*) from public.invoice_lines where invoice_id = :'inv_id'), 2::bigint, 'le brouillon est créé avec ses deux lignes');
select is((select string_agg(name || ':' || position, ',' order by position) from public.invoice_lines where invoice_id = :'inv_id'), 'Jus d''orange:1,Lait 1/1 EX:2', 'les lignes gardent leur ordre');
select is((select count(*) from public.invoice_payments where invoice_id = :'inv_id'), 1::bigint, 'le paiement est enregistré');
select is((select seller_ifu from public.invoices where id = :'inv_id'), '3201900000001', 'les règles de la table s''appliquent (IFU du vendeur)');

-- Remplacement
select tests.authenticate_as(:'manager_id', 'aal1');
select public.save_invoice_draft(:'inv_id', jsonb_build_object('operator_name', 'Awa', 'aib', 'A',
  'lines', jsonb_build_array(jsonb_build_object('name', 'Eau 1,5 L', 'price', 500, 'quantity', 1.5, 'tax_group', 'B'))));
select tests.clear_auth();
select is((select count(*) from public.invoice_lines where invoice_id = :'inv_id'), 1::bigint, 'les anciennes lignes sont remplacées');
select is((select quantity from public.invoice_lines where invoice_id = :'inv_id'), 1.500::numeric, 'la quantité décimale est conservée');
select is((select operator_name || '/' || aib from public.invoices where id = :'inv_id'), 'Awa/A', 'les champs de la facture sont mis à jour');
select is((select count(*) from public.invoice_payments where invoice_id = :'inv_id'), 0::bigint, 'les paiements absents du nouveau contenu sont retirés');

-- Retour arrière : une ligne invalide annule tout
select tests.authenticate_as(:'manager_id', 'aal1');
select throws_ok(format($q$select public.save_invoice_draft(%L, '{"operator_name":"Awa","lines":[{"name":"X","price":0,"quantity":1,"tax_group":"B"}]}'::jsonb)$q$, :'inv_id'),
  '23514', null, 'un prix nul est refusé');
select tests.clear_auth();

-- Droits : un assistant ne crée pas de facture ; un avoir ne se crée pas ici
select tests.authenticate_as(:'assist_id', 'aal1');
select throws_ok(format($q$select public.save_invoice_draft(null, jsonb_build_object('cabinet_id', %L, 'entity_id', %L, 'device_id', %L, 'type', 'FV', 'operator_name', 'X', 'lines', '[]'::jsonb))$q$, :'a_id', :'e1_id', :'dev_id'),
  '42501', null, 'un assistant ne crée pas de facture');
select tests.clear_auth();
select tests.authenticate_as(:'manager_id', 'aal1');
select throws_ok(format($q$select public.save_invoice_draft(null, jsonb_build_object('cabinet_id', %L, 'entity_id', %L, 'device_id', %L, 'type', 'FA', 'operator_name', 'X'))$q$, :'a_id', :'e1_id', :'dev_id'),
  '23514', null, 'un avoir ne se crée pas par cette fonction');
select tests.clear_auth();

select * from finish();
rollback;
