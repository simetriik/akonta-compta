-- Recette 05/11/2026, point 1 : qui crée les modèles d'écriture communs (associé, chefs de mission) et ceux d'un dossier (tout collaborateur).
begin;
select plan(9);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.create_user('manager@a.test', :'a_id', 'Chef') as id \gset manager_
select tests.create_user('assist@a.test',  :'a_id', 'Assistant') as id \gset assist_
select tests.create_user('trainee@a.test', :'a_id', 'Stagiaire') as id \gset trainee_
select tests.create_entity(:'a_id', 'Dossier 1') as id \gset e1_
select tests.create_entity(:'a_id', 'Dossier 2') as id \gset e2_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
select tests.assign(:'assist_id',  :'a_id', 'assistant', :'e1_id');
select tests.assign(:'trainee_id', :'a_id', 'trainee', :'e1_id');

select ok((select count(*) = 2 from public.permissions where code like 'templates.manage_%'), 'les deux permissions existent');
select ok((select count(*) = 4 from public.role_permissions rp join public.roles r on r.id = rp.role_id
            where r.cabinet_id = :'a_id' and rp.permission_code = 'templates.manage_entity'), 'le droit « dossier » est donné aux quatre rôles comptables');
select ok((select count(*) = 2 from public.role_permissions rp join public.roles r on r.id = rp.role_id
            where r.cabinet_id = :'a_id' and rp.permission_code = 'templates.manage_common'), 'le droit « communs » est donné à l''associé et au chef de mission seulement');

-- Chef de mission (senior) : crée un modèle commun
select tests.authenticate_as(:'manager_id', 'aal2');
select lives_ok(format($$insert into public.entry_templates (cabinet_id, entity_id, code, label) values (%L, null, 'COMMUN1', 'Commun du chef')$$, :'a_id'), 'un chef de mission crée un modèle commun');
select tests.clear_auth();

-- Assistant : modèle de dossier oui, modèle commun non
select tests.authenticate_as(:'assist_id', 'aal1');
select lives_ok(format($$insert into public.entry_templates (cabinet_id, entity_id, code, label) values (%L, %L, 'DOSSIER1', 'Modèle du dossier')$$, :'a_id', :'e1_id'), 'un assistant crée un modèle de son dossier');
select throws_ok(format($$insert into public.entry_templates (cabinet_id, entity_id, code, label) values (%L, null, 'COMMUN2', 'Interdit')$$, :'a_id'), '42501', null, 'un assistant ne crée pas de modèle commun');
select throws_ok(format($$insert into public.entry_templates (cabinet_id, entity_id, code, label) values (%L, %L, 'AUTRE', 'Autre dossier')$$, :'a_id', :'e2_id'), '42501', null, 'ni un modèle sur un dossier qui n''est pas le sien');
select tests.clear_auth();

-- Stagiaire : modèle de dossier oui
select tests.authenticate_as(:'trainee_id', 'aal1');
select lives_ok(format($$insert into public.entry_templates (cabinet_id, entity_id, code, label) values (%L, %L, 'STAGE1', 'Modèle du stagiaire')$$, :'a_id', :'e1_id'), 'un stagiaire crée un modèle de son dossier');
select tests.clear_auth();

-- Droits paramétrables : l'associé retire le droit aux assistants
delete from public.role_permissions rp using public.roles r
 where r.id = rp.role_id and r.cabinet_id = :'a_id' and r.code = 'assistant' and rp.permission_code = 'templates.manage_entity';
select tests.authenticate_as(:'assist_id', 'aal1');
select throws_ok(format($$insert into public.entry_templates (cabinet_id, entity_id, code, label) values (%L, %L, 'DOSSIER2', 'Retiré')$$, :'a_id', :'e1_id'), '42501', null, 'le droit retiré à un rôle ferme l''accès (paramétrable)');
select tests.clear_auth();

select * from finish();
rollback;
