-- Avertissement « écriture sans pièce » : actif par défaut, réglable par qui a cabinet.settings.
begin;
select plan(4);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.create_user('assist@a.test',  :'a_id', 'Assistant') as id \gset assist_
select tests.create_entity(:'a_id', 'SARL Test') as id \gset e1_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');

select is((select warn_missing_document from public.cabinets where id = :'a_id'), true, 'avertissement actif par défaut');

select tests.authenticate_as(:'partner_id', 'aal2');
update public.cabinets set warn_missing_document = false where id = :'a_id';
select tests.clear_auth();
select is((select warn_missing_document from public.cabinets where id = :'a_id'), false, 'l''associé peut désactiver l''avertissement');

select tests.authenticate_as(:'assist_id', 'aal1');
update public.cabinets set warn_missing_document = true where id = :'a_id';
select tests.clear_auth();
select is((select warn_missing_document from public.cabinets where id = :'a_id'), false, 'un assistant ne change pas ce réglage');

select tests.authenticate_as(:'assist_id', 'aal1');
select is((select warn_missing_document from public.cabinets where id = :'a_id'), false, 'tout membre lit le réglage (il en a besoin pour valider)');
select tests.clear_auth();

select * from finish();
rollback;
