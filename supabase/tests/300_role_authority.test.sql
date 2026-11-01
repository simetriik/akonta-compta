-- Autorité sur les rôles (D-037) : l'associé n'attribue que chef de mission, assistant, stagiaire ; il ne voit pas le rôle
-- d'administrateur technique ; les droits d'administration et les rôles associé / administrateur sont hors de sa portée.
begin;
select plan(17);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('admin@a.test',   :'a_id', 'Admin')    as id \gset admin_
select tests.create_user('partner@a.test', :'a_id', 'Associé')  as id \gset partner_
select tests.create_user('partner2@a.test',:'a_id', 'Associé 2') as id \gset partner2_
select tests.create_user('member@a.test',  :'a_id', 'Membre')   as id \gset member_
select tests.create_user('fresh@a.test',   :'a_id', 'Neuf')     as id \gset fresh_
select tests.create_entity(:'a_id', 'SARL Test') as id \gset e1_
select tests.assign(:'admin_id', :'a_id', 'tech_admin');
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'partner2_id', :'a_id', 'partner');
select tests.assign(:'fresh_id', :'a_id', 'assistant', :'e1_id');

-- Identifiant du rôle administrateur technique, connu ici (hors RLS) pour tenter de le contourner
select id as id from public.roles where cabinet_id = :'a_id' and code = 'tech_admin' \gset ta_

-- Visibilité du rôle
select tests.authenticate_as(:'partner_id', 'aal2');
select is((select count(*) from public.roles where code = 'tech_admin'), 0::bigint, 'associé : ne voit pas le rôle administrateur technique');
select is((select count(*) from public.roles where code in ('partner', 'manager', 'assistant', 'trainee')), 4::bigint, 'associé : voit les autres rôles');

-- Attributions
select ok(tests.fails_with(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) values (%L, %L, null, %L)', :'a_id', :'member_id', :'ta_id'), '42501'),
          'associé : ne peut pas donner le rôle administrateur technique, même en connaissant son identifiant');
select ok(tests.fails_with(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) select %L, %L, null, id from public.roles where cabinet_id = %L and code = ''partner''', :'a_id', :'member_id', :'a_id'), '42501'),
          'associé : ne peut pas créer un autre associé');
select lives_ok(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) select %L, %L, %L, id from public.roles where cabinet_id = %L and code = ''manager''', :'a_id', :'member_id', :'e1_id', :'a_id'),
                'associé : peut affecter un chef de mission');
select ok(tests.fails_with(format('delete from public.assignments where user_id = %L', :'partner2_id'), '42501'),
          'associé : ne peut pas retirer le rôle d''un autre associé');
select lives_ok(format('delete from public.assignments where user_id = %L', :'fresh_id'), 'associé : peut retirer une affectation d''assistant');

-- Droits des rôles
select ok(tests.fails_with(format('insert into public.role_permissions select id, ''users.manage'' from public.roles where cabinet_id = %L and code = ''partner''', :'a_id'), '42501'),
          'associé : ne peut pas ajouter users.manage à son rôle');
select ok(tests.fails_with(format('insert into public.role_permissions select id, ''users.manage'' from public.roles where cabinet_id = %L and code = ''manager''', :'a_id'), '42501'),
          'associé : ne peut pas accorder users.manage au chef de mission');
select ok(tests.fails_with(format('delete from public.role_permissions rp using public.roles r where r.id = rp.role_id and r.code = ''partner'' and r.cabinet_id = %L and rp.permission_code = ''closing.final''', :'a_id'), '42501'),
          'associé : ne peut pas retirer un droit au rôle associé');
select lives_ok(format('insert into public.role_permissions select id, ''closing.final'' from public.roles where cabinet_id = %L and code = ''manager''', :'a_id'),
                'associé : peut ajuster un droit ordinaire du chef de mission');

-- Rôles eux-mêmes
select ok(tests.fails_with(format('update public.roles set requires_mfa = false where cabinet_id = %L and code = ''partner''', :'a_id'), '42501'),
          'associé : ne peut pas désactiver la double authentification de son rôle');
select ok(tests.fails_with(format('update public.roles set grants_all_entities = true where cabinet_id = %L and code = ''assistant''', :'a_id'), '42501'),
          'associé : ne peut pas ouvrir tous les dossiers à l''assistant');
select lives_ok(format('update public.roles set name = ''Chef de mission principal'' where cabinet_id = %L and code = ''manager''', :'a_id'), 'associé : peut renommer un rôle');
select ok(tests.fails_with(format('insert into public.roles (cabinet_id, code, name) values (%L, ''sur_mesure'', ''Sur mesure'')', :'a_id'), '42501'),
          'associé : ne peut pas créer de rôle sur mesure');
select tests.clear_auth();

-- Administrateur technique
select tests.authenticate_as(:'admin_id', 'aal2');
select is((select count(*) from public.roles where code = 'tech_admin'), 1::bigint, 'administrateur : voit son propre rôle');
select tests.clear_auth();

-- Suppression d'un membre sans trace par l'administrateur, malgré une affectation de dossier
select tests.assign(:'fresh_id', :'a_id', 'assistant', :'e1_id');
select tests.authenticate_as(:'admin_id', 'aal2');
select lives_ok(format('select public.delete_member(%L)', :'fresh_id'), 'administrateur : supprime un membre sans trace, affectations comprises');
select tests.clear_auth();

select * from finish();
rollback;
