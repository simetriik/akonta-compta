-- Module 2 — Cabinet et dossiers : entités, exercices, périodes, verrouillage, historisation, RLS (§3, §10.2).
begin;
select plan(29);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('partner@a.test', :'a_id') as id \gset partner_
select tests.create_user('manager@a.test', :'a_id') as id \gset manager_
select tests.create_user('assist@a.test',  :'a_id') as id \gset assist_
select tests.create_user('partner@b.test', :'b_id') as id \gset partnerb_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'partnerb_id', :'b_id', 'partner');

-- 1. Création d'entité par l'associé
select tests.authenticate_as(:'partner_id', 'aal2');
insert into public.entities (cabinet_id, name, tax_id, trade_register) values (:'a_id', 'SARL Démo', '3201900000001', 'RB/COT/19 B 1234');
select id as id from public.entities where name = 'SARL Démo' \gset e1_
select is((select account_length from public.entities where id = :'e1_id'), 7::smallint, 'longueur des comptes héritée du cabinet (7)');
select throws_ok(format('insert into public.entities (cabinet_id, name, tax_id) values (%L, %L, %L)', :'a_id', 'Autre', '3201900000001'),
                 '23505', null, 'IFU unique dans le cabinet');
select throws_ok(format('insert into public.entities (cabinet_id, name, trade_register) values (%L, %L, %L)', :'a_id', 'Autre', 'RB/COT/19 B 1234'),
                 '23505', null, 'RCCM unique dans le cabinet');
select throws_ok(format('insert into public.entities (cabinet_id, name, tax_id) values (%L, %L, %L)', :'b_id', 'Autre cabinet', '3201900000001'),
                 '42501', null, 'l''associé de A ne crée rien dans le cabinet B');
select tests.clear_auth();
select lives_ok(format('insert into public.entities (cabinet_id, name, tax_id) values (%L, %L, %L)', :'b_id', 'Autre cabinet', '3201900000001'),
                'le même IFU est admis dans un autre cabinet');

-- 2. Le chef de mission crée un dossier et s'y retrouve affecté
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
select tests.authenticate_as(:'manager_id');
insert into public.entities (cabinet_id, name) values (:'a_id', 'SA Créée par chef');
select id as id from public.entities where name = 'SA Créée par chef' \gset e2_
select ok(public.can_access_entity(:'e2_id'), 'le chef de mission créateur est affecté au nouveau dossier');
select is((select count(*) from public.entities), 2::bigint, 'le chef de mission voit ses deux dossiers');
select tests.authenticate_as(:'assist_id');
select is((select count(*) from public.entities), 0::bigint, 'un assistant sans affectation ne voit aucun dossier');
select throws_ok(format('insert into public.entities (cabinet_id, name) values (%L, %L)', :'a_id', 'Interdit'), '42501', null,
                 'un assistant ne crée pas de dossier');
select tests.clear_auth();

-- 3. Historisation et paramètres comptables réservés à l'associé
select tests.authenticate_as(:'manager_id');
update public.entities set address = 'Cotonou, Haie Vive' where id = :'e1_id';
select is((select count(*) from public.entity_history where entity_id = :'e1_id'), 1::bigint, 'modification de la fiche historisée');
select is((select changes -> 'address' ->> 'new' from public.entity_history where entity_id = :'e1_id'), 'Cotonou, Haie Vive', 'l''historique porte ancienne et nouvelle valeur');
select throws_ok(format('update public.entities set monthly_lock_enabled = true where id = %L', :'e1_id'), '42501', null,
                 'le chef de mission ne change pas les paramètres comptables');
select tests.authenticate_as(:'partner_id', 'aal2');
select lives_ok(format('update public.entities set monthly_lock_enabled = true where id = %L', :'e1_id'), 'l''associé active le verrouillage mensuel');

-- 4. Exercices : premier exercice long, continuité, 12 périodes
insert into public.fiscal_years (cabinet_id, entity_id, label, start_date, end_date) values (:'a_id', :'e1_id', '2025', '2025-07-01', '2025-12-31');
select lives_ok(format('insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (%L, %L, %L, %L)', :'a_id', :'e1_id', '2026-01-01', '2026-12-31'),
                'exercice 2026 à la suite de 2025');
select id as id from public.fiscal_years where entity_id = :'e1_id' and label = '2026' \gset fy26_
select is((select count(*) from public.periods where fiscal_year_id = :'fy26_id'), 12::bigint, '12 périodes mensuelles générées');
select is((select count(*) from public.periods p join public.fiscal_years f on f.id = p.fiscal_year_id where f.label = '2025'), 6::bigint,
          'premier exercice de 6 mois : 6 périodes');
select throws_ok(format('insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (%L, %L, %L, %L)', :'a_id', :'e1_id', '2027-02-01', '2027-12-31'),
                 '23514', null, 'pas de trou entre exercices');
select throws_ok(format('insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (%L, %L, %L, %L)', :'a_id', :'e1_id', '2026-06-01', '2026-12-31'),
                 '23514', null, 'pas de chevauchement (la continuité le refuse en amont)');
select ok(exists (select 1 from pg_constraint where conrelid = 'public.fiscal_years'::regclass and contype = 'x'),
          'contrainte d''exclusion de chevauchement présente en dernier rempart');
select throws_ok(format('update public.fiscal_years set end_date = %L where id = %L', '2026-11-30', :'fy26_id'), '23514', null, 'dates d''exercice figées');
select throws_ok(format('update public.fiscal_years set status = ''closed'' where id = %L', :'fy26_id'), '23514', null, 'ouvert → clôturé sans passer par « en clôture » refusé');
select throws_ok(format('update public.entities set account_length = 8 where id = %L', :'e1_id'), '23514', null, 'longueur des comptes figée dès qu''un exercice existe');

-- 5. Verrouillage de période
select id as id from public.periods where fiscal_year_id = :'fy26_id' and period_no = 1 \gset p1_
select tests.authenticate_as(:'manager_id');
select lives_ok(format('update public.periods set is_locked = true where id = %L', :'p1_id'), 'chef de mission : verrouille (option active)');
select ok(not public.period_open_for(:'e1_id', '2026-01-15'), 'une date d''une période verrouillée n''est plus saisissable');
select ok(public.period_open_for(:'e1_id', '2026-02-15'), 'une date d''une période ouverte est saisissable');
select throws_ok(format('update public.periods set is_locked = false, unlock_reason = ''erreur'' where id = %L', :'p1_id'), '42501', null,
                 'chef de mission : ne déverrouille pas');
select tests.authenticate_as(:'partner_id', 'aal2');
select throws_ok(format('update public.periods set is_locked = false where id = %L', :'p1_id'), '23514', null, 'associé : motif obligatoire au déverrouillage');
select lives_ok(format('update public.periods set is_locked = false, unlock_reason = ''Facture oubliée'' where id = %L', :'p1_id'), 'associé : déverrouille avec motif');
select tests.authenticate_as(:'partnerb_id', 'aal2');
select is((select count(*) from public.periods where entity_id = :'e1_id'), 0::bigint, 'cabinet B : aucune période du cabinet A visible');
select tests.clear_auth();

select * from finish();
rollback;
