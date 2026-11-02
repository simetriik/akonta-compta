-- Pont facturation → comptabilité (D-043) : écriture générée en brouillard depuis une facture confirmée.
begin;
select plan(21);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('manager@a.test', :'a_id', 'Chef') as id \gset manager_
select tests.create_user('assist@a.test',  :'a_id', 'Assistant') as id \gset assist_
select tests.create_user('partner@b.test', :'b_id', 'Associé B') as id \gset partnerb_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
update public.entities set tax_id = '3201900000001' where id = :'e1_id';
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'partnerb_id', :'b_id', 'partner');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select public.create_journals_from_template(:'e1_id', null);
insert into public.third_parties (cabinet_id, entity_id, code, name, type, tax_id) values (:'a_id', :'e1_id', 'SUPER', 'Supermarché SARL', 'customer', '3201900000002');
insert into public.emcf_devices (cabinet_id, entity_id, nim, label, mode) values (:'a_id', :'e1_id', 'XX01000001', 'Boutique', 'production') returning id as id \gset prod_
insert into public.emcf_devices (cabinet_id, entity_id, nim, label, mode) values (:'a_id', :'e1_id', 'XX01000002', 'Essai', 'test') returning id as id \gset test_

-- Facture confirmée de production (exemple de la spécification : A 1350, B 3600 dont HT 3051 et TVA 549)
create function pg_temp.confirmed_invoice(p_device uuid, p_ifu text, p_client text, p_issued text, p_code text, p_aib bigint default 0)
returns uuid language plpgsql as $$
declare v_id uuid; v_resp jsonb;
begin
  insert into public.invoices (cabinet_id, entity_id, device_id, type, operator_name, client_ifu, client_name, aib)
  values (current_setting('t.cab')::uuid, current_setting('t.ent')::uuid, p_device, 'FV', 'Jacques', p_ifu, p_client, case when p_aib > 0 then 'A' end) returning id into v_id;
  insert into public.invoice_lines (invoice_id, position, name, price, quantity, tax_group) values (v_id, 1, 'Jus', 1800, 2, 'B'), (v_id, 2, 'Lait', 450, 3, 'A');
  v_resp := jsonb_build_object('taa', 1350, 'tab', 3600, 'hab', 3051, 'vab', 549, 'total', 4950, 'aib', p_aib);
  perform public.invoice_mark_pending(v_id, 'uid-' || p_code, v_resp);
  perform public.invoice_mark_confirmed(v_id, jsonb_build_object('codeMECeFDGI', p_code, 'qrCode', 'F;x', 'counters', '1/1 FV', 'nim', 'XX01000001', 'dateTime', 'x', 'issuedAt', p_issued));
  return v_id;
end $$;
select set_config('t.cab', :'a_id', false), set_config('t.ent', :'e1_id', false);

select pg_temp.confirmed_invoice(:'prod_id', '3201900000002', 'Supermarché SARL', '2026-01-12T10:00:00+01:00', 'AAAA-BBBB-CCCC-DDDD-EEEE-FFFF') as id \gset inv_
select pg_temp.confirmed_invoice(:'test_id', null, 'Essai', '2026-01-12T10:00:00+01:00', 'TEST-BBBB-CCCC-DDDD-EEEE-FFFF') as id \gset tinv_

-- 1. Sans paramètres, la génération est refusée avec une consigne claire
select tests.authenticate_as(:'manager_id', 'aal1');
select throws_ok(format('select public.generate_invoice_entry(%L)', :'inv_id'), '23514', 'Définissez d''abord les comptes de facturation du dossier (paramètres de facturation)', 'sans paramètres : refus avec consigne');
select tests.clear_auth();

-- 2. Paramètres : le chef de mission (references.manage) les définit, l'assistant non
create temp table acc as select code, id from public.accounts where entity_id = :'e1_id';
grant select on acc to authenticated;
select tests.authenticate_as(:'assist_id', 'aal1');
select throws_ok(format($q$insert into public.invoice_account_settings (cabinet_id, entity_id, valid_from, client_account_id, sales_exempt_account_id, sales_taxable_account_id, vat_account_id)
  select %L, %L, '2026-01-01', (select id from acc where code='4111000'), (select id from acc where code='7011000'), (select id from acc where code='7011000'), (select id from acc where code='4431000')$q$, :'a_id', :'e1_id'),
  '42501', null, 'un assistant ne définit pas les comptes de facturation');
select tests.clear_auth();
select tests.authenticate_as(:'manager_id', 'aal1');
insert into public.invoice_account_settings (cabinet_id, entity_id, valid_from, client_account_id, sales_exempt_account_id, sales_taxable_account_id, vat_account_id, aib_account_id)
  select :'a_id', :'e1_id', '2026-01-01', (select id from acc where code='4111000'), (select id from acc where code='7011000'), (select id from acc where code='7011000'),
         (select id from acc where code='4431000'), (select id from acc where code='4428000');
select throws_ok(format($q$insert into public.invoice_account_settings (cabinet_id, entity_id, valid_from, client_account_id, sales_exempt_account_id, sales_taxable_account_id, vat_account_id)
  select %L, %L, '2026-02-01', (select id from acc where code='4111000'), (select id from acc where code='7011000'), (select id from acc where code='7011000'), gen_random_uuid()$q$, :'a_id', :'e1_id'),
  '23514', null, 'un compte inconnu est refusé');
select tests.clear_auth();

-- 3. Génération : écriture équilibrée, client rapproché par IFU, journal de ventes
select tests.authenticate_as(:'manager_id', 'aal1');
select public.generate_invoice_entry(:'inv_id') as id \gset en_
select tests.clear_auth();
select ok(:'en_id' is not null, 'une écriture est générée');
select is((select status::text || '/' || is_generated::text from public.entries where id = :'en_id'), 'draft/true', 'en brouillard, marquée « générée »');
select is((select sum(debit) || '/' || sum(credit) from public.entry_lines where entry_id = :'en_id'), '4950/4950', 'équilibrée : 4 950 au débit comme au crédit');
select is((select debit from public.entry_lines l join acc on acc.id = l.account_id where l.entry_id = :'en_id' and acc.code = '4111000'), 4950::bigint, 'client débité du total TTC');
select is((select string_agg(acc.code || ':' || l.credit, ',' order by acc.code, l.credit) from public.entry_lines l join acc on acc.id = l.account_id where l.entry_id = :'en_id' and l.credit > 0),
          '4431000:549,7011000:1350,7011000:3051', 'ventes exonérées 1 350, ventes taxables HT 3 051, TVA 549');
select is((select t.code from public.entry_lines l join public.third_parties t on t.id = l.third_party_id where l.entry_id = :'en_id'), 'SUPER', 'le client est rapproché par son IFU');
select is((select j.code || '/' || e.reference || '/' || e.entry_date from public.entries e join public.journals j on j.id = e.journal_id where e.id = :'en_id'), 'VT/AAAA-BBBB-CCCC-DDDD-EEEE-FFFF/2026-01-12', 'journal de ventes, référence = code MECeF/DGI, date de l''émission');

-- 4. Régénération : le brouillard est remplacé, pas dupliqué ; lecture de l'écriture liée
select tests.authenticate_as(:'manager_id', 'aal1');
select public.generate_invoice_entry(:'inv_id');
select is((select count(*) from public.entries where generated_source = 'invoice:' || :'inv_id'), 1::bigint, 'régénérer remplace le brouillard (une seule écriture)');
select is((select status::text from public.invoice_entry(:'inv_id')), 'draft', 'invoice_entry renvoie l''écriture liée');

-- 5. Une écriture validée n'est jamais régénérée
select public.validate_entry((select entry_id from public.invoice_entry(:'inv_id')));
select throws_ok(format('select public.generate_invoice_entry(%L)', :'inv_id'), '23514', null, 'écriture validée : régénération refusée');
select tests.clear_auth();

-- 6. Factures de test, non confirmées et hors cabinet
select tests.authenticate_as(:'manager_id', 'aal1');
select throws_ok(format('select public.generate_invoice_entry(%L)', :'tinv_id'), '23514', 'Facture émise en test : aucune écriture comptable', 'une facture de test ne se comptabilise pas');
insert into public.invoices (cabinet_id, entity_id, device_id, type, operator_name) values (:'a_id', :'e1_id', :'prod_id', 'FV', 'Awa') returning id as id \gset draft_
select throws_ok(format('select public.generate_invoice_entry(%L)', :'draft_id'), '23514', 'Seule une facture confirmée par la DGI se comptabilise', 'un brouillon de facture ne se comptabilise pas');
select tests.clear_auth();
select tests.authenticate_as(:'partnerb_id', 'aal2');
select throws_ok(format('select public.generate_invoice_entry(%L)', :'inv_id'), '42501', null, 'un autre cabinet ne peut pas générer');
select tests.clear_auth();

-- 7. Avoir : même montants, sens inversé (client au crédit)
select tests.authenticate_as(:'manager_id', 'aal1');
select public.create_credit_note(:'inv_id') as id \gset cn_
select tests.clear_auth();
select public.invoice_mark_pending(:'cn_id', 'uid-cn', '{"taa":1350,"tab":3600,"hab":3051,"vab":549,"total":4950,"aib":0}'::jsonb);
select public.invoice_mark_confirmed(:'cn_id', '{"codeMECeFDGI":"CCCC-BBBB-CCCC-DDDD-EEEE-FFFF","qrCode":"F;x","counters":"1/1 FA","nim":"XX01000001","dateTime":"x","issuedAt":"2026-01-20T10:00:00+01:00"}'::jsonb);
select tests.authenticate_as(:'manager_id', 'aal1');
select public.generate_invoice_entry(:'cn_id') as id \gset cne_
select tests.clear_auth();
select is((select l.credit from public.entry_lines l join acc on acc.id = l.account_id where l.entry_id = :'cne_id' and acc.code = '4111000'), 4950::bigint, 'avoir : client au crédit');
select is((select sum(debit)::bigint from public.entry_lines l join acc on acc.id = l.account_id where l.entry_id = :'cne_id' and acc.code in ('7011000', '4431000')), 4950::bigint, 'avoir : ventes et TVA au débit');

-- 8. AIB : compte obligatoire ; paramètres versionnés par date d'effet
insert into public.invoice_account_settings (cabinet_id, entity_id, valid_from, client_account_id, sales_exempt_account_id, sales_taxable_account_id, vat_account_id)
  select :'a_id', :'e1_id', '2026-07-01', (select id from acc where code='4111000'), (select id from acc where code='7011000'), (select id from acc where code='7011000'), (select id from acc where code='4431000');
select pg_temp.confirmed_invoice(:'prod_id', null, 'Client inconnu', '2026-07-10T10:00:00+01:00', 'DDDD-BBBB-CCCC-DDDD-EEEE-FFFF', 50) as id \gset aib_
select tests.authenticate_as(:'manager_id', 'aal1');
select throws_ok(format('select public.generate_invoice_entry(%L)', :'aib_id'), '23514', null, 'AIB sans compte dans les paramètres en vigueur : refus (versionnement par date)');
select tests.clear_auth();
select pg_temp.confirmed_invoice(:'prod_id', null, 'Client inconnu', '2026-02-10T10:00:00+01:00', 'EEEE-BBBB-CCCC-DDDD-EEEE-FFFF', 50) as id \gset aib2_
select tests.authenticate_as(:'manager_id', 'aal1');
select public.generate_invoice_entry(:'aib2_id') as id \gset aibe_
select tests.clear_auth();
select is((select sum(debit) || '/' || sum(credit) from public.entry_lines where entry_id = :'aibe_id'), '5000/5000', 'AIB (50) en plus : équilibrée à 5 000 avec le compte de l''AIB');
select is((select count(*) from public.entry_lines where entry_id = :'aibe_id' and third_party_id is null and debit > 0), 1::bigint, 'client non reconnu : tiers laissé au comptable');

select * from finish();
rollback;
