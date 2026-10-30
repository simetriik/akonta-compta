-- L'administrateur technique est invisible des membres du cabinet (D-017) : profils, affectations, libellés d'audit.
begin;
select plan(11);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id', 'Associé A') as id \gset partner_
select tests.create_user('admin@a.test',   :'a_id', 'Admin A')   as id \gset admin_
select tests.create_user('admin2@a.test',  :'a_id', 'Admin 2')   as id \gset admin2_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'admin_id',   :'a_id', 'tech_admin');
select tests.assign(:'admin2_id',  :'a_id', 'tech_admin');

select tests.authenticate_as(:'partner_id', 'aal2');
select is((select count(*) from public.profiles where id = :'admin_id'), 0::bigint, 'associé : ne voit pas le profil de l''administrateur');
select is((select count(*) from public.profiles where id = :'partner_id'), 1::bigint, 'associé : voit son propre profil');
select is((select count(*) from public.assignments where user_id in (:'admin_id', :'admin2_id')), 0::bigint, 'associé : ne voit pas les affectations de l''administrateur');
select ok(exists (select 1 from public.assignments where user_id = :'partner_id'), 'associé : voit sa propre affectation');
select is((select label from public.actor_labels(array[:'admin_id'::uuid])), 'Administration technique', 'associé : l''administrateur apparaît sous un libellé générique dans l''audit');
select is((select label from public.actor_labels(array[:'partner_id'::uuid])), 'Associé A', 'associé : son propre nom reste affiché');
select ok(public.has_permission(null, 'assignments.manage'), 'associé : détient bien assignments.manage (le masquage tient malgré ce droit)');
delete from public.assignments where user_id = :'admin_id';
select tests.clear_auth();
select is((select count(*) from public.assignments where user_id = :'admin_id'), 1::bigint, 'associé : ne peut pas supprimer l''affectation de l''administrateur');
select tests.authenticate_as(:'partner_id', 'aal2');
select tests.clear_auth();

select tests.authenticate_as(:'admin_id', 'aal2');
select is((select count(*) from public.profiles where id in (:'admin_id', :'admin2_id', :'partner_id')), 3::bigint, 'administrateur : voit les profils, dont les autres administrateurs');
select is((select label from public.actor_labels(array[:'admin2_id'::uuid])), 'Admin 2', 'administrateur : voit le nom réel d''un autre administrateur');
select tests.clear_auth();

select is((select count(*) from public.assignments where user_id = :'admin_id'), 1::bigint, 'hors RLS : l''affectation de l''administrateur existe bien');

select * from finish();
rollback;
