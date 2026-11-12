-- Module 4 — Saisie : contrôles, validation et numérotation sans trou, immutabilité, contre-passation, revue, devises (§4, §10.4, §11.2).
begin;
select plan(47);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('partner@a.test', :'a_id') as id \gset partner_
select tests.create_user('manager@a.test', :'a_id') as id \gset manager_
select tests.create_user('assist@a.test',  :'a_id') as id \gset assist_
select tests.create_user('trainee@a.test', :'a_id') as id \gset trainee_
select tests.create_user('partner@b.test', :'b_id') as id \gset partnerb_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'partnerb_id', :'b_id', 'partner');
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'manager_id', :'a_id', 'manager',   :'e1_id');
select tests.assign(:'assist_id',  :'a_id', 'assistant', :'e1_id');
select tests.assign(:'trainee_id', :'a_id', 'trainee',   :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select public.create_journals_from_template(:'e1_id', null);
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'e1_id', 'BQ', 'Ecobank', 'bank', id from public.accounts where entity_id = :'e1_id' and code = '5210000';
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'e1_id', 'CHU', 'CHU - Parakou', 'customer');
insert into public.third_party_accounts select t.id, a.id from public.third_parties t, public.accounts a where t.code = 'CHU' and a.entity_id = :'e1_id' and a.code = '4111000';

-- 1. Contraintes de ligne : débit OU crédit, strictement positif, jamais négatif
select throws_ok(format('select tests.make_entry(%L, ''VT'', ''2026-01-10'', ''Négatif'', %L)', :'e1_id', '[{"account":"7011000","debit":-5}]'), '23514', null, 'montant négatif interdit');
select throws_ok(format('select tests.make_entry(%L, ''VT'', ''2026-01-10'', ''Les deux'', %L)', :'e1_id', '[{"account":"7011000","debit":5,"credit":5}]'), '23514', null, 'débit et crédit sur la même ligne interdits');
select throws_ok(format('select tests.make_entry(%L, ''VT'', ''2026-01-10'', ''Zéro'', %L)', :'e1_id', '[{"account":"7011000","debit":0,"credit":0}]'), '23514', null, 'ligne à zéro interdite');
select throws_ok(format('select tests.make_entry(%L, ''VT'', ''2025-06-10'', ''Hors exercice'', %L)', :'e1_id', '[]'), '23514', null, 'date hors de tout exercice refusée dès le brouillard');

-- 2. Brouillard puis validation : numéro séquentiel par journal et exercice
select tests.make_entry(:'e1_id', 'VT', '2026-01-10', 'Facture CHU 001', '[{"account":"4111000","tp":"CHU","debit":1180000},{"account":"7011000","credit":1000000},{"account":"4431000","credit":180000}]', :'assist_id') as id \gset v1_
select tests.make_entry(:'e1_id', 'VT', '2026-01-12', 'Facture CHU 002', '[{"account":"4111000","tp":"CHU","debit":590000},{"account":"7011000","credit":500000},{"account":"4431000","credit":90000}]', :'assist_id') as id \gset v2_
select tests.make_entry(:'e1_id', 'VT', '2026-01-15', 'Déséquilibrée', '[{"account":"4111000","tp":"CHU","debit":100},{"account":"7011000","credit":90}]', :'assist_id') as id \gset bad_
select tests.make_entry(:'e1_id', 'BQ', '2026-01-20', 'Encaissement CHU', '[{"account":"5210000","debit":1180000},{"account":"4111000","tp":"CHU","credit":1180000}]', :'assist_id') as id \gset b1_

select tests.authenticate_as(:'assist_id');
select is((select status::text from public.entries where id = :'v1_id'), 'draft', 'une écriture naît en brouillard');
select is(public.validate_entry(:'v1_id'), 1::bigint, 'première validation : n° 1 dans le journal VT');
select is(public.validate_entry(:'v2_id'), 2::bigint, 'deuxième validation : n° 2');
select throws_ok(format('select public.validate_entry(%L)', :'bad_id'), '23514', null, 'écriture déséquilibrée refusée');
select is(public.validate_entry(:'b1_id'), 1::bigint, 'le journal BQ a sa propre séquence : n° 1');
select tests.make_entry(:'e1_id', 'VT', '2026-01-18', 'Facture CHU 003', '[{"account":"4111000","tp":"CHU","debit":100},{"account":"7011000","credit":100}]', :'assist_id') as id \gset v3_
select is(public.validate_entry(:'v3_id'), 3::bigint, 'l''échec précédent n''a consommé aucun numéro : n° 3 (sans trou)');
select throws_ok(format('select public.validate_entry(%L)', :'v1_id'), '23514', null, 'une écriture validée ne se revalide pas');
select is((select last_number from public.journal_sequences js join public.journals j on j.id = js.journal_id where j.entity_id = :'e1_id' and j.code = 'VT'), 3::bigint, 'séquence VT = 3');
select tests.clear_auth();
select ok(exists (select 1 from public.audit_log where action = 'validate' and record_id = :'v1_id'::text), 'validation tracée dans la piste d''audit');
select tests.authenticate_as(:'assist_id');

-- 3. Contrôles de validation
select tests.make_entry(:'e1_id', 'VT', '2026-02-01', 'Sans tiers', '[{"account":"4111000","debit":100},{"account":"7011000","credit":100}]', :'assist_id') as id \gset notp_
select throws_ok(format('select public.validate_entry(%L)', :'notp_id'), '23514', null, 'tiers obligatoire sur un compte collectif');
select tests.make_entry(:'e1_id', 'OD', '2026-02-01', 'Tête de chapitre', '[{"account":"6000000","debit":100},{"account":"4700000","credit":100}]', :'assist_id') as id \gset head_
select throws_ok(format('select public.validate_entry(%L)', :'head_id'), '23514', null, 'compte non imputable refusé');
select tests.make_entry(:'e1_id', 'OD', '2026-02-01', 'Une ligne', '[{"account":"6011000","debit":100}]', :'assist_id') as id \gset one_
select throws_ok(format('select public.validate_entry(%L)', :'one_id'), '23514', null, 'au moins deux lignes');
select tests.clear_auth();
update public.periods set is_locked = true where entity_id = :'e1_id' and period_no = 3;
select tests.make_entry(:'e1_id', 'OD', '2026-03-05', 'Période verrouillée', '[{"account":"6011000","debit":100},{"account":"5210000","credit":100}]', :'assist_id') as id \gset locked_
select tests.authenticate_as(:'assist_id');
select throws_ok(format('select public.validate_entry(%L)', :'locked_id'), '23514', null, 'date dans une période verrouillée refusée à la validation');

-- 4. Immutabilité d'une écriture validée (déclencheurs, indépendamment de la RLS)
select tests.clear_auth();
select throws_ok(format('update public.entries set label = ''Modifiée'' where id = %L', :'v1_id'), '42501', null, 'écriture validée : libellé immuable');
select throws_ok(format('delete from public.entries where id = %L', :'v1_id'), '42501', null, 'écriture validée : suppression interdite');
select throws_ok(format('delete from public.entry_lines where entry_id = %L', :'v1_id'), '42501', null, 'écriture validée : lignes non supprimables');
select throws_ok(format('insert into public.entry_lines (entry_id, account_id, debit) select %L, id, 10 from public.accounts where entity_id = %L and code = ''6011000''', :'v1_id', :'e1_id'), '42501', null, 'écriture validée : pas d''ajout de ligne');
select throws_ok(format('update public.entries set status = ''validated'', number = 99 where id = %L', :'bad_id'), '42501', null, 'validation directe (hors fonction) refusée');
select tests.authenticate_as(:'assist_id');
select lives_ok(format('update public.entries set label = ''Corrigée'' where id = %L', :'bad_id'), 'un brouillard reste modifiable par son auteur');
select tests.clear_auth();
select throws_ok(format('delete from public.accounts where entity_id = %L and code = ''7011000''', :'e1_id'), '23503', null, 'un compte mouvementé ne se supprime pas');

-- 5. Permissions : stagiaire, assistant (ses écritures), chef de mission
select tests.make_entry(:'e1_id', 'VT', '2026-02-02', 'Par le chef', '[{"account":"4111000","tp":"CHU","debit":100},{"account":"7011000","credit":100}]', :'manager_id') as id \gset m1_
select tests.authenticate_as(:'trainee_id');
select throws_ok(format('select public.validate_entry(%L)', :'bad_id'), '42501', null, 'stagiaire : ne valide pas');
select tests.authenticate_as(:'assist_id');
select throws_ok(format('select public.validate_entry(%L)', :'m1_id'), '42501', null, 'assistant : ne valide que ses propres écritures');
update public.entries set label = 'Tentative' where id = :'m1_id';
select is((select label from public.entries where id = :'m1_id'), 'Par le chef', 'assistant : ne modifie pas le brouillard d''un autre (RLS)');
select tests.authenticate_as(:'manager_id');
select lives_ok(format('select public.validate_entry(%L)', :'m1_id'), 'chef de mission : valide');
select tests.authenticate_as(:'manager_id');
select tests.make_entry(:'e1_id', 'VT', '2026-02-03', 'Assistant puis chef', '[{"account":"4111000","tp":"CHU","debit":100},{"account":"7011000","credit":100}]', :'assist_id') as id \gset a2_
select lives_ok(format('select public.validate_entry(%L)', :'a2_id'), 'chef de mission : valide aussi les écritures des assistants (revue)');

-- 6. Contre-passation
select tests.authenticate_as(:'assist_id');
select throws_ok(format('select public.reverse_entry(%L, '''')', :'v1_id'), '23514', null, 'contre-passation : motif obligatoire');
select throws_ok(format('select public.reverse_entry(%L, ''x'')', :'bad_id'), '23514', null, 'un brouillard ne se contre-passe pas');
select public.reverse_entry(:'v1_id', 'Doublon de facture', '2026-02-10') as id \gset rev_
select is((select status::text from public.entries where id = :'rev_id'), 'validated', 'l''écriture inverse est validée');
select is((select reversed_by from public.entries where id = :'v1_id'), :'rev_id'::uuid, 'l''originale pointe vers sa contre-passation');
select is((select sum(credit)::bigint from public.entry_lines where entry_id = :'rev_id' and account_id = (select account_id from public.entry_lines where entry_id = :'v1_id' and debit > 0)), 1180000::bigint, 'les sens sont inversés');
select throws_ok(format('select public.reverse_entry(%L, ''encore'')', :'v1_id'), '23514', null, 'pas de double contre-passation');
select throws_ok(format('select public.reverse_entry(%L, ''annuler l''''annulation'')', :'rev_id'), '23514', null, 'AN-20 : une contre-passation ne se contre-passe pas');
select tests.authenticate_as(:'trainee_id');
select throws_ok(format('select public.reverse_entry(%L, ''x'')', :'v2_id'), '42501', null, 'stagiaire : ne contre-passe pas');

-- 7. Revue
select tests.authenticate_as(:'assist_id');
select throws_ok(format('select public.review_entry(%L, ''reviewed'')', :'v2_id'), '42501', null, 'assistant : pas de revue');
select tests.authenticate_as(:'manager_id');
select throws_ok(format('select public.review_entry(%L, ''to_correct'')', :'v2_id'), '23514', null, '« à corriger » exige un commentaire');
select lives_ok(format('select public.review_entry(%L, ''to_correct'', ''Compte 7011 au lieu de 7061'')', :'v2_id'), 'revue « à corriger » avec commentaire');
select tests.authenticate_as(:'assist_id');
select is((select count(*) from public.notifications where kind = 'entry_to_correct'), 1::bigint, 'l''auteur est notifié (et ne voit que ses notifications)');
select tests.authenticate_as(:'manager_id');
select lives_ok(format('select public.review_entry(%L, ''reviewed'')', :'v3_id'), 'revue « revue »');

-- 8. Devises
select tests.clear_auth();
select throws_ok(format('select tests.make_entry(%L, ''BQ'', ''2026-02-05'', ''Euro mauvais cours'', %L)', :'e1_id', '[{"account":"5210000","debit":65600,"currency":"EUR","amount":100,"rate":656}]'), '23514', null, 'euro : parité fixe 655,957 imposée');
select throws_ok(format('select tests.make_entry(%L, ''BQ'', ''2026-02-05'', ''Contre-valeur fausse'', %L)', :'e1_id', '[{"account":"5210000","debit":70000,"currency":"EUR","amount":100,"rate":655.957}]'), '23514', null, 'contre-valeur FCFA incohérente refusée');
select lives_ok(format('select tests.make_entry(%L, ''BQ'', ''2026-02-05'', ''100 EUR'', %L)', :'e1_id', '[{"account":"5210000","debit":65596,"currency":"EUR","amount":100,"rate":655.957},{"account":"4111000","tp":"CHU","credit":65596,"currency":"EUR","amount":100,"rate":655.957}]'), '100 EUR = 65 596 FCFA (arrondi à l''unité)');

-- 9. Cloisonnement
select tests.authenticate_as(:'trainee_id');
select ok((select count(*) from public.entries where entity_id = :'e1_id') > 5, 'stagiaire : consulte les écritures de son dossier');
select tests.authenticate_as(:'partnerb_id', 'aal2');
select is((select count(*) from public.entries), 0::bigint, 'cabinet B : aucune écriture du cabinet A');
select tests.clear_auth();

select * from finish();
rollback;
