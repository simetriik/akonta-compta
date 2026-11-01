-- Suppression d'un membre : réservée à l'administrateur technique, limitée aux membres sans trace.
begin;
select plan(9);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('admin@a.test',   :'a_id', 'Admin A')  as id \gset admin_
select tests.create_user('partner@a.test', :'a_id', 'Associé')  as id \gset partner_
select tests.create_user('fresh@a.test',   :'a_id', 'Neuf')     as id \gset fresh_
select tests.create_user('busy@a.test',    :'a_id', 'Actif')    as id \gset busy_
select tests.create_user('other@b.test',   :'b_id', 'Autre B')  as id \gset other_
select tests.create_entity(:'a_id', 'SARL Test') as id \gset e1_
select tests.assign(:'admin_id', :'a_id', 'tech_admin');
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'fresh_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'busy_id', :'a_id', 'assistant', :'e1_id');
-- « busy » laisse une trace : un document capturé
insert into public.documents (cabinet_id, entity_id, storage_path, file_name, mime_type, size_bytes, sha256, captured_by)
values (:'a_id', :'e1_id', (:'a_id' || '/' || :'e1_id' || '/b.pdf'), 'b.pdf', 'application/pdf', 10, repeat('a', 64), :'busy_id');

-- Un assistant n'a aucun droit de gestion (l'associé, lui, gère son équipe : voir 320_team_management)
select tests.authenticate_as(:'busy_id', 'aal1');
select ok(tests.fails_with(format('select public.delete_member(%L)', :'fresh_id'), '42501'), 'assistant : suppression refusée');
select tests.clear_auth();

select tests.authenticate_as(:'admin_id', 'aal2');
select ok(tests.fails_with(format('select public.delete_member(%L)', :'admin_id'), '23514'), 'administrateur : ne peut pas se supprimer lui-même');
select ok(tests.fails_with(format('select public.delete_member(%L)', :'other_id'), 'P0002'), 'administrateur : ne peut pas supprimer un membre d''un autre cabinet');
select ok(tests.fails_with(format('select public.delete_member(%L)', :'busy_id'), '23503'), 'membre avec trace : suppression refusée');
select lives_ok(format('select public.delete_member(%L)', :'fresh_id'), 'membre sans trace : supprimé');
select tests.clear_auth();

select is((select count(*) from public.profiles where id = :'fresh_id'), 0::bigint, 'le profil a disparu');
select is((select count(*) from auth.users where id = :'fresh_id'), 0::bigint, 'le compte de connexion a disparu (l''e-mail peut être réinvité)');
select is((select count(*) from public.assignments where user_id = :'fresh_id'), 0::bigint, 'ses affectations ont disparu');
select is((select count(*) from public.audit_log where table_name = 'profiles' and action = 'delete' and record_id = :'fresh_id'), 1::bigint, 'la suppression est dans la piste d''audit');

select * from finish();
rollback;
