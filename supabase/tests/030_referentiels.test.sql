-- Module 3 — Référentiels : plan de référence, plan d'entité à longueur fixe, tiers, journaux, taux, modèles (§3.3, §3.4, §10.3).
begin;
select plan(32);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('partner@a.test', :'a_id') as id \gset partner_
select tests.create_user('manager@a.test', :'a_id') as id \gset manager_
select tests.create_user('assist@a.test',  :'a_id') as id \gset assist_
select tests.create_user('partner@b.test', :'b_id') as id \gset partnerb_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'partnerb_id', :'b_id', 'partner');
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
select tests.assign(:'assist_id',  :'a_id', 'assistant', :'e1_id');

-- 1. Plan de référence seedé
select is((select count(*) from public.reference_accounts), 1339::bigint, '1 339 comptes de référence seedés');
select is((select normal_side::text from public.reference_accounts where code = '4011'), 'credit', '4011 fournisseurs : sens créditeur');
select is((select normal_side::text from public.reference_accounts where code = '4111'), 'debit', '4111 clients : sens débiteur');
select ok((select is_collective from public.reference_accounts where code = '4011'), '4011 est un collectif');
select is((select parent_code from public.reference_accounts where code = '4452'), '445', 'parent de 4452 = 445');

-- 2. Copie du plan dans l'entité à la longueur fixe
select is((select count(*) from public.accounts where entity_id = :'e1_id'),
          (select count(distinct rpad(code, 7, '0')) from public.reference_accounts where class between 1 and 8), 'plan de référence (classes 1-8) copié dans l''entité, un compte par numéro complété');
select ok(exists (select 1 from public.accounts where entity_id = :'e1_id' and code = '4011000' and label = 'Fournisseurs'), 'numéros complétés à 7 chiffres (4011 → 4011000)');
select is((select p.code from public.accounts a join public.accounts p on p.id = a.parent_id where a.entity_id = :'e1_id' and a.code = '4011000'),
          '4010000', 'hiérarchie reprise : 4011000 a pour parent 4010000');
select ok(not (select allow_posting from public.accounts where entity_id = :'e1_id' and code = '4000000'), 'les comptes de 1 et 2 chiffres ne sont pas imputables');

-- 3. Subdivision : parent, héritage du sens, longueur fixe
select tests.authenticate_as(:'manager_id');
insert into public.accounts (cabinet_id, entity_id, code, label, nature, normal_side) values (:'a_id', :'e1_id', '4011100', 'Fournisseurs locaux', 'income', 'debit');
select is((select p.code || '/' || a.normal_side::text from public.accounts a join public.accounts p on p.id = a.parent_id where a.entity_id = :'e1_id' and a.code = '4011100'),
          '4011000/credit', 'subdivision rattachée au parent et sens hérité (jamais de changement de sens)');
select throws_ok(format('insert into public.accounts (cabinet_id, entity_id, code, label, nature, normal_side) values (%L, %L, %L, %L, %L, %L)', :'a_id', :'e1_id', '40111', 'Trop court', 'balance_sheet', 'credit'),
                 '23514', null, 'longueur fixe : 5 chiffres refusés');
select throws_ok(format('update public.accounts set normal_side = ''debit'' where entity_id = %L and code = ''4011100''', :'e1_id'),
                 '23514', null, 'le sens d''un compte ne change pas');
select throws_ok(format('delete from public.accounts where entity_id = %L and code = ''4011000''', :'e1_id'),
                 '23503', null, 'un compte avec subdivisions ne se supprime pas');
select lives_ok(format('update public.accounts set is_active = false where entity_id = %L and code = ''4011100''', :'e1_id'), 'désactivation d''un compte');
select tests.authenticate_as(:'assist_id');
select throws_ok(format('insert into public.accounts (cabinet_id, entity_id, code, label, nature, normal_side) values (%L, %L, %L, %L, %L, %L)', :'a_id', :'e1_id', '4011200', 'Interdit', 'balance_sheet', 'credit'),
                 '42501', null, 'un assistant ne crée pas de compte');
select tests.authenticate_as(:'partnerb_id', 'aal2');
select is((select count(*) from public.accounts where entity_id = :'e1_id'), 0::bigint, 'cabinet B : aucun compte du cabinet A visible');
select tests.clear_auth();

-- 4. Journaux : AN imposé, modèle du cabinet, trésorerie reliée à un compte de classe 5
select is((select count(*) from public.journals where entity_id = :'e1_id'), 1::bigint, 'le journal des à-nouveaux est créé avec l''entité');
select is((select type::text from public.journals where entity_id = :'e1_id'), 'opening', '… et c''est bien un journal de type à-nouveaux');
select throws_ok(format('insert into public.journals (cabinet_id, entity_id, code, label, type) values (%L, %L, ''AN2'', ''Doublon'', ''opening'')', :'a_id', :'e1_id'),
                 '23505', null, 'un seul journal des à-nouveaux par entité');
select throws_ok(format('delete from public.journals where entity_id = %L and type = ''opening''', :'e1_id'), '42501', null, 'le journal AN ne se supprime pas');
select is(public.create_journals_from_template(:'e1_id', null), 3, 'modèle du cabinet : AC, VT, OD créés (BQ/CA attendent un compte, PA non coché)');
select throws_ok(format('insert into public.journals (cabinet_id, entity_id, code, label, type) values (%L, %L, ''BQ'', ''Banque'', ''bank'')', :'a_id', :'e1_id'),
                 '23514', null, 'un journal de banque exige un compte de trésorerie');
select throws_ok(format('insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id) select %L, %L, ''BQ'', ''Banque'', ''bank'', id from public.accounts where entity_id = %L and code = ''4011000''', :'a_id', :'e1_id', :'e1_id'),
                 '23514', null, 'le compte de trésorerie doit être de classe 5');
select lives_ok(format('insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id) select %L, %L, ''BQ'', ''Ecobank'', ''bank'', id from public.accounts where entity_id = %L and code = ''5210000''', :'a_id', :'e1_id', :'e1_id'),
                'journal de banque relié au compte 5210000');

-- 5. Tiers : code alphanumérique, rattachement à un collectif
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'e1_id', 'CHU', 'CHU - Parakou', 'customer');
select throws_ok(format('insert into public.third_parties (cabinet_id, entity_id, code, name) values (%L, %L, ''chu-2'', ''minuscules'')', :'a_id', :'e1_id'),
                 '23514', null, 'code tiers : majuscules et chiffres uniquement');
select throws_ok(format('insert into public.third_party_accounts select t.id, a.id from public.third_parties t, public.accounts a where t.code = ''CHU'' and a.entity_id = %L and a.code = ''6011000''', :'e1_id'),
                 '23514', null, 'un tiers ne se rattache pas à un compte non collectif');
select lives_ok(format('insert into public.third_party_accounts select t.id, a.id from public.third_parties t, public.accounts a where t.code = ''CHU'' and a.entity_id = %L and a.code = ''4111000''', :'e1_id'),
                'tiers rattaché au collectif 4111000');

-- 6. Taux et modèles d'écritures
select is(public.tax_rate_at(:'a_id', 'TVA', '2026-06-30'), 0.18::numeric, 'TVA 18 % en vigueur');
select throws_ok(format('insert into public.tax_rates (cabinet_id, code, label, rate, valid_from) values (%L, ''TVA'', ''TVA bis'', 0.2, ''2026-01-01'')', :'a_id'),
                 '23P01', null, 'pas de chevauchement de validité pour un même taux');
select is((select count(*) from public.entry_templates where cabinet_id = :'a_id' and entity_id is null), 30::bigint, '30 modèles d''écritures fournis au cabinet (5 de base + bibliothèque)');
select is((select count(*) from public.entry_template_lines l join public.entry_templates t on t.id = l.template_id where t.cabinet_id = :'a_id' and t.code = 'SALAIRES'), 6::bigint,
          'modèle salaires : 6 lignes');
select is((select count(*) from public.journal_templates where cabinet_id = :'a_id'), 7::bigint, '7 journaux dans le modèle du cabinet');

select * from finish();
rollback;
