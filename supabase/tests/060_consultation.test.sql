-- Module 6 — Consultation : grand livre, balances générale / auxiliaire / âgée, journal, centralisateur, tableau de bord (§5, §10.6).
begin;
select plan(17);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('assist@a.test',  :'a_id') as id \gset assist_
select tests.create_user('manager@a.test', :'a_id') as id \gset manager_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'assist_id',  :'a_id', 'assistant', :'e1_id');
select tests.assign(:'manager_id', :'a_id', 'manager',   :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'e1_id' \gset fy_
select public.create_journals_from_template(:'e1_id', null);
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'e1_id', 'BQ', 'Ecobank', 'bank', id from public.accounts where entity_id = :'e1_id' and code = '5210000';
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'e1_id', 'CHU', 'CHU - Parakou', 'customer'), (:'a_id', :'e1_id', 'NSIA', 'NSIA Assurances', 'supplier');

-- À-nouveaux : capital 1 000 000 en banque
select tests.make_entry(:'e1_id', 'AN', '2026-01-01', 'À-nouveaux', '[{"account":"5210000","debit":1000000},{"account":"1011000","credit":1000000}]', :'assist_id') as id \gset an_
-- Janvier : vente CHU 1 180 000 TTC ; février : vente CHU 590 000 ; encaissement partiel 500 000 le 20 mars ; achat NSIA 121 000 le 5 janvier
select tests.make_entry(:'e1_id', 'VT', '2026-01-10', 'Facture 001', '[{"account":"4111000","tp":"CHU","debit":1180000},{"account":"7011000","credit":1000000},{"account":"4431000","credit":180000}]', :'assist_id') as id \gset v1_
select tests.make_entry(:'e1_id', 'VT', '2026-02-15', 'Facture 002', '[{"account":"4111000","tp":"CHU","debit":590000},{"account":"7011000","credit":500000},{"account":"4431000","credit":90000}]', :'assist_id') as id \gset v2_
select tests.make_entry(:'e1_id', 'BQ', '2026-03-20', 'Règlement partiel CHU', '[{"account":"5210000","debit":500000},{"account":"4111000","tp":"CHU","credit":500000}]', :'assist_id') as id \gset b1_
select tests.make_entry(:'e1_id', 'AC', '2026-01-05', 'Prime NSIA', '[{"account":"6251000","debit":121000},{"account":"4011000","tp":"NSIA","credit":121000}]', :'assist_id') as id \gset a1_
select tests.make_entry(:'e1_id', 'OD', '2026-03-25', 'Brouillard non pris en compte', '[{"account":"6251000","debit":999999},{"account":"4710000","credit":999999}]', :'assist_id') as id \gset draft_
select public.validate_entries(array[:'an_id', :'v1_id', :'v2_id', :'b1_id', :'a1_id']::uuid[]);

select tests.authenticate_as(:'assist_id');
-- 1. Grand livre
select is((select count(*) from public.general_ledger(:'e1_id', '2026-01-01', '2026-12-31')), 12::bigint, 'grand livre : 12 lignes validées (le brouillard est exclu)');
select is((select running_balance from public.general_ledger(:'e1_id', '2026-01-01', '2026-12-31', '4111000', '4111000') order by entry_date desc, number desc limit 1), 1270000::bigint,
          'solde progressif du compte client 4111000 = 1 270 000');
select is((select running_balance from public.general_ledger(:'e1_id', '2026-03-01', '2026-03-31', '5210000', '5210000') limit 1), 1500000::bigint,
          'report avant la période + mouvement : banque = 1 500 000 fin mars');
-- 2. Balance générale
select is((select sum(closing_debit) - sum(closing_credit) from public.trial_balance(:'e1_id', '2026-01-01', '2026-12-31')), 0::numeric, 'balance générale équilibrée');
select is((select opening_debit from public.trial_balance(:'e1_id', '2026-02-01', '2026-02-28') where account_code = '5210000'), 1000000::bigint, 'à-nouveaux en colonne d''ouverture');
select is((select period_debit from public.trial_balance(:'e1_id', '2026-02-01', '2026-02-28') where account_code = '4111000'), 590000::bigint, 'mouvements de la période seule (février)');
select is((select opening_debit from public.trial_balance(:'e1_id', '2026-02-01', '2026-02-28') where account_code = '4111000'), 1180000::bigint, 'mouvements antérieurs à la période en ouverture');
select is((select count(*) from public.trial_balance(:'e1_id', '2026-01-01', '2026-12-31', 7::smallint)), 1::bigint, 'filtre par classe (classe 7)');
-- 3. Balance auxiliaire et âgée
select is((select closing_debit from public.auxiliary_balance(:'e1_id', '2026-01-01', '2026-12-31') where third_party_code = 'CHU'), 1270000::bigint, 'balance auxiliaire : CHU doit 1 270 000');
select is((select closing_credit from public.auxiliary_balance(:'e1_id', '2026-01-01', '2026-12-31') where third_party_code = 'NSIA'), 121000::bigint, 'balance auxiliaire : NSIA créditeur 121 000');
select is((select d91_180 from public.aged_balance(:'e1_id', '2026-05-31') where third_party_code = 'CHU'), 1770000::bigint, 'balance âgée au 31/05 : factures de janvier et février dans 91-180 jours');
select is((select d61_90 from public.aged_balance(:'e1_id', '2026-05-31') where third_party_code = 'CHU'), -500000::bigint, 'balance âgée : règlement de mars (72 jours) en 61-90, non lettré');
select is((select over_180 from public.aged_balance(:'e1_id', '2026-09-30') where third_party_code = 'CHU'), 1270000::bigint, 'balance âgée au 30/09 : tout a plus de 180 jours');
-- 4. Journal et centralisateur
select is((select count(distinct entry_id) from public.journal_book(:'e1_id', (select id from public.journals where entity_id = :'e1_id' and code = 'VT'), '2026-01-01', '2026-12-31')), 2::bigint, 'livre-journal VT : 2 écritures');
select is((select total_debit from public.journal_centralization(:'e1_id', :'fy_id') where journal_code = 'VT' and period_no = 1), 1180000::bigint, 'centralisateur VT janvier = 1 180 000');
-- 5. Tableau de bord et permission
select is((select draft_count from public.entity_dashboard() where entity_id = :'e1_id'), 1::bigint, 'tableau de bord : 1 brouillard');
select tests.clear_auth();
delete from public.role_permissions rp using public.roles r where r.id = rp.role_id and r.cabinet_id = :'a_id' and r.code = 'assistant' and rp.permission_code = 'ledger.read';
select tests.authenticate_as(:'assist_id');
select throws_ok(format('select * from public.trial_balance(%L, ''2026-01-01'', ''2026-12-31'')', :'e1_id'), '42501', null, 'sans « consulter grand livre, balance », la balance est refusée');
select tests.clear_auth();

select * from finish();
rollback;
