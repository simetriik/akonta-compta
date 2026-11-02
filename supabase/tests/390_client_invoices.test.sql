-- Accès des clients (D-044) : factures. Le gérant voit et émet celles de son dossier, le saisisseur les siennes
-- (et n'émet que si le droit lui est accordé), plus rien quand l'accès est suspendu ou fermé.
begin;
select plan(15);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.create_user('assist@a.test',  :'a_id', 'Assistant') as id \gset assist_
select tests.create_user('gerant@c1.test', :'a_id', 'Gérant client') as id \gset gerant_
select tests.create_user('saisie@c1.test', :'a_id', 'Saisie client') as id \gset saisie_
select tests.create_user('gerant@c2.test', :'a_id', 'Gérant autre client') as id \gset gerant2_
select tests.create_entity(:'a_id', 'Client 1 SARL') as id \gset e1_
select tests.create_entity(:'a_id', 'Client 2 SARL') as id \gset e2_
update public.entities set tax_id = '3201900000001' where id = :'e1_id';
update public.entities set tax_id = '3201900000002' where id = :'e2_id';
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'gerant_id', :'a_id', 'client_gerant', :'e1_id');
select tests.assign(:'saisie_id', :'a_id', 'client_saisie', :'e1_id');
select tests.assign(:'gerant2_id', :'a_id', 'client_gerant', :'e2_id');
select public.set_client_access(:'e1_id', 'active');
select public.set_client_access(:'e2_id', 'active');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select public.create_journals_from_template(:'e1_id', null);

insert into public.emcf_devices (cabinet_id, entity_id, nim, label, mode) values (:'a_id', :'e1_id', 'XX01000001', 'Boutique 1', 'test') returning id as id \gset d1_
insert into public.emcf_devices (cabinet_id, entity_id, nim, label, mode) values (:'a_id', :'e2_id', 'XX01000002', 'Boutique 2', 'test') returning id as id \gset d2_

-- Le gérant émet (brouillon) pour son dossier
select tests.authenticate_as(:'gerant_id', 'aal2');
select lives_ok(format($q$insert into public.invoices (cabinet_id, entity_id, device_id, type, operator_name, client_name, created_by)
  values (%L, %L, %L, 'FV', 'Gérant', 'Acheteur 1', %L)$q$, :'a_id', :'e1_id', :'d1_id', :'gerant_id'), 'le gérant crée une facture pour son dossier');
select is((select count(*) from public.emcf_devices), 1::bigint, 'le gérant voit l''e-MCF de son dossier, pas celui d''un autre');
select throws_ok(format($q$insert into public.invoices (cabinet_id, entity_id, device_id, type, operator_name, created_by)
  values (%L, %L, %L, 'FV', 'X', %L)$q$, :'a_id', :'e2_id', :'d2_id', :'gerant_id'), '42501', null, 'le gérant n''émet pas pour le dossier d''un autre client');
select throws_ok(format($q$select token from public.emcf_device_tokens$q$), '42501', null, 'jamais d''accès aux jetons');
select tests.clear_auth();

-- Une facture du cabinet pour le même dossier, une facture du saisisseur (droit accordé temporairement)
insert into public.invoices (cabinet_id, entity_id, device_id, type, operator_name, client_name, created_by)
values (:'a_id', :'e1_id', :'d1_id', 'FV', 'Assistant', 'Acheteur cabinet', :'assist_id');

select tests.authenticate_as(:'gerant_id', 'aal2');
select is((select count(*) from public.invoices), 2::bigint, 'le gérant voit toutes les factures de son dossier');
select tests.clear_auth();

select tests.authenticate_as(:'saisie_id', 'aal1');
select is((select count(*) from public.invoices), 0::bigint, 'le saisisseur ne voit pas les factures des autres');
select throws_ok(format($q$insert into public.invoices (cabinet_id, entity_id, device_id, type, operator_name, created_by)
  values (%L, %L, %L, 'FV', 'X', %L)$q$, :'a_id', :'e1_id', :'d1_id', :'saisie_id'), '42501', null, 'le saisisseur n''émet pas sans le droit invoices.issue');
select tests.clear_auth();

-- Autre client : ne voit rien du dossier 1
select tests.authenticate_as(:'gerant2_id', 'aal2');
select is((select count(*) from public.invoices), 0::bigint, 'un autre client ne voit aucune facture du dossier 1');
select tests.clear_auth();

-- Suspension : lecture oui, nouvelle facture non
select public.set_client_access(:'e1_id', 'suspended');
select tests.authenticate_as(:'gerant_id', 'aal2');
select is((select count(*) from public.invoices), 2::bigint, 'suspendu : le gérant relit ses factures');
select throws_ok(format($q$insert into public.invoices (cabinet_id, entity_id, device_id, type, operator_name, created_by)
  values (%L, %L, %L, 'FV', 'X', %L)$q$, :'a_id', :'e1_id', :'d1_id', :'gerant_id'), '42501', null, 'suspendu : plus de nouvelle facture');
select tests.clear_auth();

-- Fermé : plus rien
select public.set_client_access(:'e1_id', 'disabled');
select tests.authenticate_as(:'gerant_id', 'aal2');
select is((select count(*) from public.invoices), 0::bigint, 'fermé : aucune facture visible');
select tests.clear_auth();

-- Tableau de bord : le client ne reçoit que ses compteurs de brouillard et l'état de l'accès
select public.set_client_access(:'e1_id', 'active');
select tests.make_entry(:'e1_id', 'VT', '2026-02-01', 'Brouillard client', '[{"account":"5210000","debit":10},{"account":"7011000","credit":10}]', :'gerant_id') as id \gset dr_
select tests.make_entry(:'e1_id', 'VT', '2026-02-02', 'Validée cabinet', '[{"account":"5210000","debit":20},{"account":"7011000","credit":20}]', :'assist_id') as id \gset va_
select public.validate_entry(:'va_id');
select tests.authenticate_as(:'gerant_id', 'aal2');
select is((select count(*) from public.entity_dashboard()), 1::bigint, 'le client voit son dossier au tableau de bord');
select is((select draft_count from public.entity_dashboard()), 1::bigint, 'compteur de brouillards : le sien seulement');
select is((select coalesce(unreviewed_count, 0) + coalesce(inbox_count, 0) from public.entity_dashboard()), 0::bigint, 'aucun compteur sur la validation ni sur la revue');
select is((select client_access from public.entity_dashboard()), 'active', 'l''état de l''accès est exposé');
select tests.clear_auth();

select * from finish();
rollback;
