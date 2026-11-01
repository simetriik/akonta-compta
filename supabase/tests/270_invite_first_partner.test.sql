-- Premier associé invité par l'administrateur technique (Q-016) : possible une seule fois par cabinet, jamais ailleurs.
begin;
select plan(10);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('admin@a.test',   :'a_id', 'Admin A')  as id \gset admin_
select tests.create_user('first@a.test',   :'a_id', 'Premier')  as id \gset first_
select tests.create_user('second@a.test',  :'a_id', 'Second')   as id \gset second_
select tests.create_user('other@b.test',   :'b_id', 'Autre B')  as id \gset other_
select tests.assign(:'admin_id', :'a_id', 'tech_admin');

-- 1-2. L'administrateur voit que le cabinet n'a pas d'associé, malgré le masquage des affectations
select tests.authenticate_as(:'admin_id', 'aal2');
select is(public.cabinet_has_partner(), false, 'administrateur : le cabinet n''a pas encore d''associé');
select is((select count(*) from public.assignments where user_id = :'first_id'), 0::bigint, 'administrateur : ne voit pas les affectations (inchangé)');
select tests.clear_auth();

-- 3-4. Le premier associé reçoit une affectation de portée cabinet
select lives_ok(format('select public.grant_first_partner(%L, %L, %L)', :'a_id', :'first_id', :'admin_id'), 'premier associé : affectation créée');
select is((select count(*) from public.assignments a join public.roles r on r.id = a.role_id
            where a.user_id = :'first_id' and r.code = 'partner' and a.entity_id is null and a.created_by = :'admin_id'),
          1::bigint, 'premier associé : rôle Associé de portée cabinet, tracé au nom de l''administrateur');

-- 5. Le cabinet a désormais un associé
select tests.authenticate_as(:'admin_id', 'aal2');
select is(public.cabinet_has_partner(), true, 'administrateur : le cabinet a maintenant un associé');
select tests.clear_auth();

-- 6. Un second appel est refusé (seul l'associé affecte ensuite)
select ok(tests.fails_with(format('select public.grant_first_partner(%L, %L, %L)', :'a_id', :'second_id', :'admin_id'), '23505'),
          'second associé : refusé tant qu''un associé existe');

-- 7. Un utilisateur d'un autre cabinet est refusé (cohérence de l'affectation)
select ok(tests.fails_with(format('select public.grant_first_partner(%L, %L, %L)', :'b_id', :'first_id', :'admin_id'), '23514'),
          'utilisateur d''un autre cabinet : refusé');

-- 8-9. Fonction d'écriture fermée aux utilisateurs connectés ; ouverte au service
select is(has_function_privilege('authenticated', 'public.grant_first_partner(uuid,uuid,uuid)', 'execute'), false, 'authenticated : ne peut pas appeler grant_first_partner');
select is(has_function_privilege('service_role', 'public.grant_first_partner(uuid,uuid,uuid)', 'execute'), true, 'service_role : peut appeler grant_first_partner');

-- 10. Le cabinet B n'est pas affecté par l'associé du cabinet A
select tests.authenticate_as(:'other_id', 'aal1');
select is(public.cabinet_has_partner(), false, 'cabinet B : pas d''associé, indépendant du cabinet A');
select tests.clear_auth();

select * from finish();
rollback;
