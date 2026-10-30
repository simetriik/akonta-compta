-- Création d'un dossier avec INSERT ... RETURNING (D-018) : associé et chef de mission, plus isolation entre cabinets.
begin;
select plan(5);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('partner@a.test', :'a_id', 'Associé A') as id \gset partner_
select tests.create_user('manager@a.test', :'a_id', 'Chef A')    as id \gset manager_
select tests.create_user('partner@b.test', :'b_id', 'Associé B') as id \gset partnerb_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.create_entity(:'a_id', 'Dossier existant') as id \gset seed_
select tests.assign(:'manager_id', :'a_id', 'manager', :'seed_id');
select tests.assign(:'partnerb_id', :'b_id', 'partner');

select tests.authenticate_as(:'partner_id', 'aal2');
select lives_ok(format($q$insert into public.entities (cabinet_id, name, account_length) values (%L, 'Dossier associé', 7) returning id$q$, :'a_id'),
                'associé : crée un dossier avec RETURNING');
select tests.clear_auth();

select tests.authenticate_as(:'manager_id');
select lives_ok(format($q$insert into public.entities (cabinet_id, name, account_length) values (%L, 'Dossier chef', 7) returning id$q$, :'a_id'),
                'chef de mission : crée un dossier avec RETURNING');
select is((select count(*) from public.entities where name = 'Dossier chef'), 1::bigint, 'chef de mission : voit le dossier créé (affecté par déclencheur)');
select tests.clear_auth();

select tests.authenticate_as(:'partnerb_id', 'aal2');
select is((select count(*) from public.entities where cabinet_id = :'a_id'), 0::bigint, 'autre cabinet : ne voit aucun dossier du cabinet A');
select tests.clear_auth();

select tests.authenticate_as(:'partner_id', 'aal1');
select throws_ok(format($q$insert into public.entities (cabinet_id, name, account_length) values (%L, 'Sans TOTP', 7)$q$, :'a_id'), '42501', null,
                 'associé sans TOTP (aal1) : création refusée');
select tests.clear_auth();

select * from finish();
rollback;
