-- Recette 05/11/2026, point 4 (comptabilité) : auditeur en lecture seule, piste d'audit par dossier, contrôles automatiques.
begin;
select plan(13);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.create_user('assist@a.test',  :'a_id', 'Awa Assistante') as id \gset assist_
select tests.create_user('auditor@a.test', :'a_id', 'Auditeur Externe') as id \gset auditor_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.create_entity(:'a_id', 'SARL Autre') as id \gset e2_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'auditor_id', :'a_id', 'auditor', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'e1_id' \gset fy_
select public.create_journals_from_template(:'e1_id', null);
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'e1_id', 'CHU', 'CHU Parakou', 'customer');

-- Écritures : une vente validée, un règlement trop élevé (client créditeur), une caisse créditrice
select tests.make_entry(:'e1_id', 'VT', '2026-03-10', 'Facture 1', '[{"account":"4111000","tp":"CHU","debit":1000},{"account":"7011000","credit":1000}]', :'assist_id') as id \gset v1_
select tests.make_entry(:'e1_id', 'OD', '2026-03-11', 'Règlement excessif', '[{"account":"5710000","credit":1500},{"account":"4111000","tp":"CHU","credit":1500},{"account":"6011000","debit":3000}]', :'assist_id') as id \gset o1_
-- La validation est faite par l'assistante : c'est elle que la piste d'audit doit nommer.
select tests.authenticate_as(:'assist_id', 'aal1');
select public.validate_entries(array[:'v1_id', :'o1_id']::uuid[]);
select tests.clear_auth();

-- 1. Rôle auditeur : seuls ledger.read et audit.read
select is((select string_agg(rp.permission_code, ',' order by rp.permission_code) from public.role_permissions rp join public.roles r on r.id = rp.role_id where r.cabinet_id = :'a_id' and r.code = 'auditor'),
          'audit.read,ledger.read', 'l''auditeur n''a que la lecture du grand livre et de la piste d''audit');

-- 2. Lecture seule
select tests.authenticate_as(:'auditor_id', 'aal2');
select ok((select count(*) > 0 from public.general_ledger(:'e1_id', '2026-01-01', '2026-12-31')), 'l''auditeur lit le grand livre de son dossier');
select throws_ok(format($$insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, label, currency_code)
                          select cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, 'Interdit', 'XOF' from public.entries where id = %L$$, :'v1_id'),
                 '42501', null, 'l''auditeur ne crée pas d''écriture');
select throws_ok(format($$insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (%L, %L, 'NEW', 'Nouveau', 'customer')$$, :'a_id', :'e1_id'), '42501', null, 'l''auditeur ne crée pas de tiers');
select throws_ok(format($$select public.general_ledger(%L, '2026-01-01', '2026-12-31')$$, :'e2_id'), '42501', null, 'l''auditeur ne lit pas un dossier qui ne lui est pas affecté');
select is((select count(*) from public.entries where entity_id = :'e1_id'), 2::bigint, 'il voit les écritures de son dossier');
select tests.clear_auth();

-- 3. Piste d'audit par dossier
select tests.authenticate_as(:'auditor_id', 'aal2');
select ok((select count(*) >= 2 from public.entry_audit_trail(:'e1_id', '2000-01-01', '2100-01-01')), 'la piste d''audit du dossier est lisible par l''auditeur');
select ok((select bool_or(event = 'validated' and actor_label = 'Awa Assistante') from public.entry_audit_trail(:'e1_id', '2000-01-01', '2100-01-01')), 'elle dit qui a validé');
select ok((select bool_or(event = 'created' and label = 'Facture 1' and journal_code = 'VT') from public.entry_audit_trail(:'e1_id', '2000-01-01', '2100-01-01')), 'elle dit qui a saisi, quoi et dans quel journal');
select throws_ok(format($$select * from public.entry_audit_trail(%L, '2000-01-01', '2100-01-01')$$, :'e2_id'), '42501', null, 'pas de piste d''audit sur un dossier non affecté');
select tests.clear_auth();
select tests.authenticate_as(:'assist_id', 'aal1');
select throws_ok(format($$select * from public.entry_audit_trail(%L, '2000-01-01', '2100-01-01')$$, :'e1_id'), '42501', null, 'un assistant ne lit pas la piste d''audit');
select tests.clear_auth();

-- 4. Contrôles automatiques
select tests.authenticate_as(:'auditor_id', 'aal2');
select ok((select count(*) = 1 from public.accounting_controls(:'e1_id', :'fy_id') where control_code = 'abnormal_balance' and account_code = '4111000' and detail = 'credit'), 'client créditeur signalé');
select ok((select count(*) = 1 from public.accounting_controls(:'e1_id', :'fy_id') where control_code = 'abnormal_balance' and account_code = '5710000'), 'caisse créditrice signalée');
select tests.clear_auth();

select * from finish();
rollback;
