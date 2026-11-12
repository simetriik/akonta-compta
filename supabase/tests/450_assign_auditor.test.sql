-- Recette 05/11/2026 : le rôle Auditeur doit pouvoir être affecté (par l'associé seulement), dossier par dossier.
-- Les affectations sont faites sous un vrai utilisateur : le mode interne contournerait le contrôle de rôle.
begin;
select plan(7);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.create_user('manager@a.test', :'a_id', 'Chef') as id \gset manager_
select tests.create_user('auditor@a.test', :'a_id', 'Auditeur') as id \gset auditor_
select tests.create_user('assist@a.test',  :'a_id', 'Assistant') as id \gset assist_
select tests.create_entity(:'a_id', 'Dossier 1') as id \gset e1_
select tests.create_entity(:'a_id', 'Dossier 2') as id \gset e2_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
select id as id from public.roles where cabinet_id = :'a_id' and code = 'auditor' \gset ru_

-- Associé : affecte un auditeur sur un dossier
select tests.authenticate_as(:'partner_id', 'aal2');
select lives_ok(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) values (%L, %L, %L, %L)', :'a_id', :'auditor_id', :'e1_id', :'ru_id'),
                'associé : affecte un auditeur à un dossier');
select tests.clear_auth();

-- Chef de mission : ne l'attribue pas, même sur son dossier
select tests.authenticate_as(:'manager_id', 'aal1');
select ok(tests.fails_with(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) values (%L, %L, %L, %L)', :'a_id', :'assist_id', :'e1_id', :'ru_id'), '42501'),
          'chef de mission : ne peut pas affecter un auditeur');
select tests.clear_auth();

-- L'auditeur reste en lecture seule sur le dossier affecté, et ne voit pas l'autre
select tests.authenticate_as(:'auditor_id', 'aal2');
select ok(tests.fails_with(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) values (%L, %L, %L, %L)', :'a_id', :'auditor_id', :'e2_id', :'ru_id'), '42501'),
          'auditeur : ne s''affecte pas lui-même à un autre dossier');
select ok(tests.fails_with(format('insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (%L, %L, ''NEW'', ''Nouveau'', ''customer'')', :'a_id', :'e1_id'), '42501'),
          'auditeur affecté : n''écrit toujours rien');
select ok(public.has_permission(:'e1_id', 'ledger.read'), 'auditeur affecté : lit le dossier 1');
select ok(not public.has_permission(:'e2_id', 'ledger.read'), 'auditeur affecté : ne lit pas le dossier 2');
select tests.clear_auth();

-- Retrait par l'associé
select tests.authenticate_as(:'partner_id', 'aal2');
select lives_ok(format('delete from public.assignments where user_id = %L and entity_id = %L', :'auditor_id', :'e1_id'), 'associé : retire l''auditeur du dossier');

select * from finish();
rollback;
