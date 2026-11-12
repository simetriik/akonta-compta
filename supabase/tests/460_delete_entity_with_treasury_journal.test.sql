-- Recette 09/11/2026, AN-02 : un dossier vide ouvert par l'assistant (plan copié + journal de trésorerie) se supprime.
begin;
select plan(5);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.assign(:'partner_id', :'a_id', 'partner');

select tests.create_entity(:'a_id', 'Dossier ouvert par l''assistant') as id \gset e_
select public.create_journals_from_template(:'e_id', null);
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'e_id', 'BQ', 'Ecobank', 'bank', id from public.accounts where entity_id = :'e_id' and code = '5210000';

select ok(exists (select 1 from public.journals where entity_id = :'e_id' and treasury_account_id is not null), 'le dossier a un journal de trésorerie lié à un compte');

select tests.authenticate_as(:'partner_id', 'aal2');
select lives_ok(format($$select public.delete_empty_duplicate_entity(%L)$$, :'e_id'), 'l''associé supprime le dossier vide malgré le journal de trésorerie');
select tests.clear_auth();

select is((select count(*) from public.entities where id = :'e_id'), 0::bigint, 'le dossier a disparu');
select is((select count(*) from public.journals where entity_id = :'e_id'), 0::bigint, 'ses journaux ont disparu');
select is((select count(*) from public.accounts where entity_id = :'e_id'), 0::bigint, 'son plan de comptes a disparu');

select * from finish();
rollback;
