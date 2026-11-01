-- Modification d'un membre : l'administrateur technique change nom et fonction ; un associé ne modifie pas les autres ; le cabinet ne change pas.
begin;
select plan(5);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('admin@a.test',   :'a_id', 'Admin A')  as id \gset admin_
select tests.create_user('partner@a.test', :'a_id', 'Associé')  as id \gset partner_
select tests.create_user('member@a.test',  :'a_id', 'Membre')   as id \gset member_
select tests.assign(:'admin_id', :'a_id', 'tech_admin');
select tests.assign(:'partner_id', :'a_id', 'partner');

select tests.authenticate_as(:'admin_id', 'aal2');
update public.profiles set full_name = 'Membre Modifié', job_title = 'Comptable' where id = :'member_id';
select is((select full_name || '|' || job_title from public.profiles where id = :'member_id'), 'Membre Modifié|Comptable', 'administrateur : modifie nom et fonction');
select throws_ok(format('update public.profiles set cabinet_id = %L where id = %L', :'b_id', :'member_id'), '42501', null, 'administrateur : ne peut pas déplacer un membre vers un autre cabinet');
select tests.clear_auth();

select tests.authenticate_as(:'partner_id', 'aal2');
update public.profiles set full_name = 'Piraté' where id = :'member_id';
select tests.clear_auth();
select is((select full_name from public.profiles where id = :'member_id'), 'Membre Modifié', 'associé : ne modifie pas le profil d''un autre');

select tests.authenticate_as(:'member_id', 'aal1');
update public.profiles set full_name = 'Mon Nom' where id = :'member_id';
select tests.clear_auth();
select is((select full_name from public.profiles where id = :'member_id'), 'Mon Nom', 'membre : modifie son propre nom');
select is((select count(*) from public.audit_log where table_name = 'profiles' and action = 'update' and record_id = :'member_id'), 2::bigint, 'les modifications sont dans la piste d''audit');

select * from finish();
rollback;
