-- Module 1 — Socle : rôles par défaut (§8), autorisations, piste d'audit chaînée (§10.1), RLS cabinet.
begin;
select plan(34);

-- Jeu de données
select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('partner@a.test', :'a_id', 'Associé A') as id \gset partner_
select tests.create_user('admin@a.test',   :'a_id', 'Admin A')   as id \gset admin_
select tests.create_user('manager@a.test', :'a_id', 'Chef A')    as id \gset manager_
select tests.create_user('assist@a.test',  :'a_id', 'Assistant A') as id \gset assist_
select tests.create_user('trainee@a.test', :'a_id', 'Stagiaire A') as id \gset trainee_
select tests.create_user('partner@b.test', :'b_id', 'Associé B') as id \gset partnerb_
select gen_random_uuid() as id \gset dossier1_
select gen_random_uuid() as id \gset dossier2_

-- 1. Rôles par défaut créés avec le cabinet
select is((select count(*) from public.roles where cabinet_id = :'a_id'), 5::bigint, '5 rôles par défaut créés pour un nouveau cabinet');
select is((select count(*) from public.permissions), 21::bigint, '21 permissions unitaires au catalogue');
select ok((select requires_mfa from public.roles where cabinet_id = :'a_id' and code = 'partner'), 'l''associé exige le TOTP');
select ok((select requires_mfa from public.roles where cabinet_id = :'a_id' and code = 'tech_admin'), 'l''administrateur exige le TOTP');
select ok(not (select accounting_access from public.roles where cabinet_id = :'a_id' and code = 'tech_admin'), 'l''administrateur n''a pas accès aux données comptables');

-- Matrice §8 : quelques cellules représentatives
select ok(exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id
                   where r.cabinet_id = :'a_id' and r.code = 'trainee' and rp.permission_code = 'entries.draft'),
          'stagiaire : saisit ses brouillards');
select ok(not exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id
                   where r.cabinet_id = :'a_id' and r.code = 'trainee' and rp.permission_code = 'entries.validate'),
          'stagiaire : ne valide pas');
select ok(exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id
                   where r.cabinet_id = :'a_id' and r.code = 'assistant' and rp.permission_code = 'entries.validate'),
          'assistant : valide ses écritures');
select ok(not exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id
                   where r.cabinet_id = :'a_id' and r.code = 'assistant' and rp.permission_code = 'entries.review'),
          'assistant : pas de revue');
select ok(exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id
                   where r.cabinet_id = :'a_id' and r.code = 'manager' and rp.permission_code = 'closing.provisional'),
          'chef de mission : clôture provisoire');
select ok(not exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id
                   where r.cabinet_id = :'a_id' and r.code = 'manager' and rp.permission_code = 'closing.final'),
          'chef de mission : pas d''arrêté définitif');
select ok(exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id
                   where r.cabinet_id = :'a_id' and r.code = 'partner' and rp.permission_code = 'closing.final'),
          'associé : arrêté définitif');
select ok(not exists (select 1 from public.role_permissions rp join public.roles r on r.id = rp.role_id
                   where r.cabinet_id = :'a_id' and r.code = 'partner' and rp.permission_code = 'users.manage'),
          'associé : ne gère pas les utilisateurs');
select is((select count(*) from public.role_permissions rp join public.roles r on r.id = rp.role_id
            where r.cabinet_id = :'a_id' and r.code = 'tech_admin'), 1::bigint, 'administrateur : uniquement la gestion des utilisateurs');

-- 2. Profils créés par le déclencheur Auth
select is((select cabinet_id from public.profiles where id = :'partner_id'), :'a_id'::uuid, 'profil créé dans le bon cabinet à la création Auth');

-- 3. Affectations : cohérence
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'admin_id',   :'a_id', 'tech_admin');
select tests.assign(:'manager_id', :'a_id', 'manager',   :'dossier1_id');
select tests.assign(:'assist_id',  :'a_id', 'assistant', :'dossier1_id');
select tests.assign(:'trainee_id', :'a_id', 'trainee',   :'dossier2_id');
select tests.assign(:'partnerb_id', :'b_id', 'partner');

select ok(tests.fails_with(format('select tests.assign(%L, %L, %L)', :'assist_id', :'a_id', 'assistant'), '23514'),
          'un rôle de dossier ne peut pas être affecté sans dossier');
select ok(tests.fails_with(format('select tests.assign(%L, %L, %L, %L)', :'partner_id', :'a_id', 'partner', :'dossier1_id'), '23514'),
          'l''associé ne s''affecte pas à un dossier précis');
select ok(tests.fails_with(format('insert into public.assignments (cabinet_id, user_id, entity_id, role_id) select %L, %L, %L, id from public.roles where cabinet_id = %L and code = ''assistant''',
                                  :'a_id', :'partnerb_id', :'dossier1_id', :'a_id'), '23514'),
          'un utilisateur du cabinet B ne peut pas être affecté dans le cabinet A');

-- 4. Autorisations
select tests.authenticate_as(:'assist_id');
select ok(public.has_permission(:'dossier1_id', 'entries.validate'), 'assistant : valide sur son dossier');
select ok(not public.has_permission(:'dossier2_id', 'entries.validate'), 'assistant : rien sur un autre dossier');
select ok(public.can_access_entity(:'dossier1_id') and not public.can_access_entity(:'dossier2_id'), 'assistant : accès limité à son dossier');

select tests.authenticate_as(:'partner_id', 'aal1');
select ok(not public.has_permission(null, 'closing.final'), 'associé en aal1 : aucune permission tant que le TOTP n''est pas vérifié');
select ok(not public.can_access_entity(:'dossier1_id'), 'associé en aal1 : pas d''accès aux dossiers');
select tests.authenticate_as(:'partner_id', 'aal2');
select ok(public.has_permission(null, 'closing.final') and public.has_permission(:'dossier2_id', 'entries.review'), 'associé en aal2 : permissions cabinet et dossier');
select ok(public.can_access_entity(:'dossier1_id') and public.can_access_entity(:'dossier2_id'), 'associé : accès à tous les dossiers');

select tests.authenticate_as(:'admin_id', 'aal2');
select ok(public.has_permission(null, 'users.manage') and not public.can_access_entity(:'dossier1_id'), 'administrateur : gère les utilisateurs, aucune donnée comptable');

-- 5. RLS cabinet
select tests.authenticate_as(:'assist_id');
select is((select count(*) from public.cabinets), 1::bigint, 'un membre ne voit que son cabinet');
select is((select count(*) from public.profiles where cabinet_id = :'b_id'), 0::bigint, 'aucun profil du cabinet B visible depuis A');
select is((select count(*) from public.audit_log), 0::bigint, 'assistant : piste d''audit invisible');
select tests.authenticate_as(:'partner_id', 'aal2');
select ok((select count(*) from public.audit_log) > 0 and (select count(*) from public.audit_log where cabinet_id = :'b_id') = 0,
          'associé : piste d''audit de son cabinet uniquement');
select tests.clear_auth();

-- 6. Piste d'audit : ajout seul et chaîne intègre
select tests.authenticate_as(:'assist_id');
select ok(public.log_audit_event('login', '{"ip":"127.0.0.1"}'::jsonb) > 0, 'événement explicite journalisé');
select tests.clear_auth();
select throws_ok(format('update public.audit_log set action = ''x'' where cabinet_id = %L', :'a_id'), '42501', null, 'piste d''audit : modification interdite');
select throws_ok(format('delete from public.audit_log where cabinet_id = %L', :'a_id'), '42501', null, 'piste d''audit : suppression interdite');
select is(public.audit_chain_verify(:'a_id'), null::bigint, 'chaîne SHA-256 du cabinet A intègre');

select * from finish();
rollback;
