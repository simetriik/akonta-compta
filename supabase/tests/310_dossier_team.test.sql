-- Équipe d'un dossier (D-038) : le chef de mission affecte assistants et stagiaires sur son dossier ; un seul chef de mission
-- par dossier ; remplacement par l'associé ; notification de la personne affectée.
begin;
select plan(22);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test',  :'a_id', 'Associé')   as id \gset partner_
select tests.create_user('manager@a.test',  :'a_id', 'Chef')      as id \gset manager_
select tests.create_user('manager2@a.test', :'a_id', 'Chef 2')    as id \gset manager2_
select tests.create_user('assist@a.test',   :'a_id', 'Assistant') as id \gset assist_
select tests.create_user('assist2@a.test',  :'a_id', 'Assistant 2') as id \gset assist2_
select tests.create_user('trainee@a.test',  :'a_id', 'Stagiaire') as id \gset trainee_
select tests.create_entity(:'a_id', 'Dossier 1') as id \gset e1_
select tests.create_entity(:'a_id', 'Dossier 2') as id \gset e2_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select id as id from public.roles where cabinet_id = :'a_id' and code = 'assistant' \gset ra_
select id as id from public.roles where cabinet_id = :'a_id' and code = 'trainee' \gset rt_
select id as id from public.roles where cabinet_id = :'a_id' and code = 'manager' \gset rm_

-- Chef de mission sur son dossier
select tests.authenticate_as(:'manager_id', 'aal1');
select lives_ok(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) values (%L, %L, %L, %L)', :'a_id', :'assist2_id', :'e1_id', :'ra_id'),
                'chef de mission : affecte un assistant à son dossier');
select lives_ok(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) values (%L, %L, %L, %L)', :'a_id', :'trainee_id', :'e1_id', :'rt_id'),
                'chef de mission : affecte un stagiaire à son dossier');
select ok(tests.fails_with(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) values (%L, %L, %L, %L)', :'a_id', :'manager2_id', :'e1_id', :'rm_id'), '42501'),
          'chef de mission : ne peut pas affecter un chef de mission');
select ok(tests.fails_with(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) values (%L, %L, %L, %L)', :'a_id', :'assist2_id', :'e2_id', :'ra_id'), '42501'),
          'chef de mission : ne peut pas affecter sur un dossier qui n''est pas le sien');
select is((select count(*) from public.assignments where entity_id = :'e1_id'), 4::bigint, 'chef de mission : voit l''équipe de son dossier');
select lives_ok(format('delete from public.assignments where user_id = %L and entity_id = %L', :'trainee_id', :'e1_id'), 'chef de mission : retire un stagiaire de son dossier');
select ok(tests.fails_with(format('delete from public.assignments where user_id = %L and entity_id = %L', :'manager_id', :'e1_id'), '42501'),
          'chef de mission : ne peut pas se retirer ni retirer un chef de mission');
select tests.clear_auth();

-- Assistant : aucun pouvoir d'affectation
select tests.authenticate_as(:'assist_id', 'aal1');
select ok(tests.fails_with(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) values (%L, %L, %L, %L)', :'a_id', :'trainee_id', :'e1_id', :'rt_id'), '42501'),
          'assistant : ne peut pas affecter');
select tests.clear_auth();

-- Droit non accordable
select tests.authenticate_as(:'partner_id', 'aal2');
select ok(tests.fails_with(format('insert into public.role_permissions select id, ''team.assign'' from public.roles where cabinet_id = %L and code = ''assistant''', :'a_id'), '42501'),
          'associé : ne peut pas accorder team.assign à l''assistant');

-- Un seul chef de mission par dossier
select ok(tests.fails_with(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) values (%L, %L, %L, %L)', :'a_id', :'manager2_id', :'e1_id', :'rm_id'), '23505'),
          'un second chef de mission sur le même dossier est refusé');
select lives_ok(format('select public.replace_manager(%L, %L)', :'e1_id', :'manager2_id'), 'associé : remplace le chef de mission');
select tests.clear_auth();
select is((select user_id::text from public.assignments where entity_id = :'e1_id' and role_id = :'rm_id'), :'manager2_id', 'le nouveau chef de mission est en place');
select is((select count(*) from public.assignments where entity_id = :'e1_id' and role_id = :'rm_id'), 1::bigint, 'il n''y a toujours qu''un chef de mission');

-- Le chef de mission ne remplace pas le chef de mission
select tests.authenticate_as(:'manager2_id', 'aal1');
select ok(tests.fails_with(format('select public.replace_manager(%L, %L)', :'e1_id', :'manager_id'), '42501'), 'chef de mission : ne peut pas remplacer le chef de mission');
select tests.clear_auth();

-- Notifications
select is((select count(*) from public.notifications where user_id = :'assist2_id' and kind = 'assigned' and payload ->> 'role_code' = 'assistant' and payload ->> 'entity' = 'Dossier 1'), 1::bigint,
          'l''assistant affecté est prévenu, avec le rôle et le dossier');
select is((select count(*) from public.notifications where user_id = :'manager2_id' and kind = 'assigned'), 1::bigint, 'le nouveau chef de mission est prévenu');
select is((select count(*) from public.notifications where user_id = :'manager_id' and kind = 'assigned'), 0::bigint, 'pas de notification pour une affectation faite hors application (système)');

-- Candidats à l'affectation
select tests.authenticate_as(:'manager2_id', 'aal1');
select is((select array_agg(email order by email) from public.team_candidates(:'e1_id')), array['manager@a.test', 'trainee@a.test'],
          'candidats : ni associé, ni membre déjà dans l''équipe du dossier (assistants, nouveau chef de mission)');
select is((select array_agg(email order by email) from public.team_candidates(:'e1_id', 'manager')), array['assist@a.test', 'assist2@a.test', 'manager@a.test', 'trainee@a.test'],
          'candidats au rôle de chef de mission : les assistants du dossier peuvent être promus, seul le chef de mission en place est écarté');
select tests.clear_auth();
select tests.authenticate_as(:'partner_id', 'aal2');
select is((select count(*) from public.team_candidates(:'e2_id')), 5::bigint, 'candidats pour un dossier sans équipe : tous sauf les associés');
select tests.clear_auth();
select tests.authenticate_as(:'assist_id', 'aal1');
select ok(tests.fails_with(format('select * from public.team_candidates(%L)', :'e1_id'), '42501'), 'un assistant ne peut pas lister les candidats');
select tests.clear_auth();
select tests.authenticate_as(:'manager2_id', 'aal1');
select ok(tests.fails_with(format('select * from public.team_candidates(%L)', :'e2_id'), '42501'), 'un chef de mission ne liste pas les candidats d''un autre dossier');
select tests.clear_auth();

select * from finish();
rollback;
