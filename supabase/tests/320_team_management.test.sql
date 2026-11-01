-- L'associé gère son équipe (D-039) ; l'administrateur gère tout le monde et désigne les associés.
begin;
select plan(22);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('admin@a.test',    :'a_id', 'Admin')      as id \gset admin_
select tests.create_user('partner@a.test',  :'a_id', 'Associé')    as id \gset partner_
select tests.create_user('partner2@a.test', :'a_id', 'Associé 2')  as id \gset partner2_
select tests.create_user('assist@a.test',   :'a_id', 'Assistant')  as id \gset assist_
select tests.create_user('fresh@a.test',    :'a_id', 'Neuf')       as id \gset fresh_
select tests.create_user('norole@a.test',   :'a_id', 'Sans rôle')  as id \gset norole_
select tests.create_entity(:'a_id', 'SARL Test') as id \gset e1_
select tests.assign(:'admin_id', :'a_id', 'tech_admin');
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'partner2_id', :'a_id', 'partner');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'fresh_id', :'a_id', 'assistant', :'e1_id');

-- Associé : qui peut-il gérer ?
select tests.authenticate_as(:'partner_id', 'aal2');
select ok(public.can_manage_member(:'assist_id'), 'associé : gère un assistant');
select ok(public.can_manage_member(:'norole_id'), 'associé : gère un compte sans rôle');
select ok(not public.can_manage_member(:'partner2_id'), 'associé : ne gère pas un autre associé');
select ok(not public.can_manage_member(:'admin_id'), 'associé : ne gère pas l''administrateur');
select ok(not public.can_manage_member(:'partner_id'), 'associé : ne se gère pas lui-même (via cette voie)');

-- Associé : modifier
update public.profiles set full_name = 'Assistant Renommé', job_title = 'Comptable' where id = :'assist_id';
select is((select full_name from public.profiles where id = :'assist_id'), 'Assistant Renommé', 'associé : modifie le nom d''un assistant');
update public.profiles set is_active = false where id = :'assist_id';
select is((select is_active from public.profiles where id = :'assist_id'), false, 'associé : désactive un assistant');
update public.profiles set full_name = 'Piraté' where id = :'partner2_id';
select tests.clear_auth();
select is((select full_name from public.profiles where id = :'partner2_id'), 'Associé 2', 'associé : ne modifie pas un autre associé');
select tests.authenticate_as(:'partner_id', 'aal2');
select ok(tests.fails_with(format('update public.profiles set email = ''autre@a.test'' where id = %L', :'assist_id'), '42501'), 'associé : ne change pas l''adresse e-mail d''un membre');
select ok(tests.fails_with(format('update public.profiles set is_active = false where id = %L', :'partner_id'), '23514'), 'associé : ne se désactive pas lui-même');

-- Associé : supprimer
select lives_ok(format('select public.delete_member(%L)', :'norole_id'), 'associé : supprime un compte sans trace');
select ok(tests.fails_with(format('select public.delete_member(%L)', :'partner2_id'), '42501'), 'associé : ne supprime pas un autre associé');
select ok(tests.fails_with(format('select public.delete_member(%L)', :'admin_id'), '42501'), 'associé : ne supprime pas l''administrateur');

-- Associé : n'est pas administrateur
select ok(tests.fails_with(format('select public.designate_partner(%L)', :'fresh_id'), '42501'), 'associé : ne désigne pas d''associé');
select ok(tests.fails_with(format('select public.revoke_partner(%L)', :'partner2_id'), '42501'), 'associé : ne retire pas le rôle d''un associé');
select tests.clear_auth();

-- Assistant : rien
select tests.authenticate_as(:'fresh_id', 'aal1');
select ok(not public.can_manage_member(:'assist_id'), 'assistant : ne gère personne');
select tests.clear_auth();

-- Administrateur
select tests.authenticate_as(:'admin_id', 'aal2');
select ok(public.can_manage_member(:'partner2_id'), 'administrateur : gère un associé');
select lives_ok(format('select public.designate_partner(%L)', :'fresh_id'), 'administrateur : désigne un associé');
select tests.clear_auth();
select is((select count(*) from public.assignments a join public.roles r on r.id = a.role_id where r.code = 'partner' and a.user_id = :'fresh_id'), 1::bigint, 'le nouvel associé a le rôle de portée cabinet');
select tests.authenticate_as(:'admin_id', 'aal2');
select lives_ok(format('select public.revoke_partner(%L)', :'fresh_id'), 'administrateur : retire le rôle d''associé');
-- Garde-fou : le dernier associé
select lives_ok(format('select public.revoke_partner(%L)', :'partner2_id'), 'administrateur : retire un second associé (il en reste un)');
select ok(tests.fails_with(format('select public.revoke_partner(%L)', :'partner_id'), '23514'), 'administrateur : ne retire pas le dernier associé');
select tests.clear_auth();

select * from finish();
rollback;
