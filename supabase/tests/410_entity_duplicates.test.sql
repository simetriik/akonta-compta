-- Recette 05/11/2026, point 8 : doublons de dossiers (idempotence, homonymes, suppression d'un doublon vide).
begin;
select plan(10);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.create_user('assist@a.test',  :'a_id', 'Assistant') as id \gset assist_
select tests.assign(:'partner_id', :'a_id', 'partner');

-- Idempotence : même demande rejouée = un seul dossier
insert into public.entities (cabinet_id, name, request_id) values (:'a_id', 'Maître ASSANI', '11111111-1111-1111-1111-111111111111');
select throws_ok(
  format($$insert into public.entities (cabinet_id, name, request_id) values (%L, 'Autre nom', '11111111-1111-1111-1111-111111111111')$$, :'a_id'),
  '23505', null, 'la même demande de création rejouée est refusée par la base');
select is((select count(*) from public.entities where cabinet_id = :'a_id'), 1::bigint, 'un seul dossier après la double soumission');

-- Homonyme sans IFU : refusé, sans casse ni accents
select throws_ok(
  format($$insert into public.entities (cabinet_id, name) values (%L, 'MAITRE assani')$$, :'a_id'),
  '23505', null, 'un homonyme sans IFU est refusé');
-- Deux homonymes avec IFU distincts : acceptés
insert into public.entities (cabinet_id, name, tax_id) values (:'a_id', 'Société Alpha', '1000000000001');
select lives_ok(
  format($$insert into public.entities (cabinet_id, name, tax_id) values (%L, 'Société Alpha', '1000000000002')$$, :'a_id'),
  'deux homonymes qui ont chacun un IFU distinct sont acceptés');
-- Un autre cabinet peut porter le même nom
select lives_ok(
  format($$insert into public.entities (cabinet_id, name) values (%L, 'Maître ASSANI')$$, :'b_id'),
  'le même nom dans un autre cabinet est accepté');
-- Réglage désactivé : l'homonyme passe
update public.cabinets set block_homonym_entities = false where id = :'b_id';
select lives_ok(
  format($$insert into public.entities (cabinet_id, name) values (%L, 'Maître ASSANI')$$, :'b_id'),
  'le réglage cabinet permet de désactiver le contrôle des homonymes');

-- Suppression d'un doublon vide
select id as dup from public.entities where cabinet_id = :'a_id' and name = 'Maître ASSANI' \gset
select tests.authenticate_as(:'assist_id', 'aal2');
select throws_ok(format($$select public.delete_empty_duplicate_entity(%L)$$, :'dup'), '42501', null, 'un assistant ne peut pas supprimer un dossier');
select tests.clear_auth();

select tests.authenticate_as(:'partner_id', 'aal2');
select lives_ok(format($$select public.delete_empty_duplicate_entity(%L)$$, :'dup'), 'l''associé supprime un doublon vide');
select tests.clear_auth();
select is((select count(*) from public.entities where id = :'dup'), 0::bigint, 'le doublon vide a disparu');

-- Refus dès qu'il y a une donnée de travail
select tests.create_entity(:'a_id', 'Client avec tiers') as id \gset used_
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'used_id', 'CHU', 'CHU', 'customer');
select tests.authenticate_as(:'partner_id', 'aal2');
select throws_ok(format($$select public.delete_empty_duplicate_entity(%L)$$, :'used_id'), '23503', null, 'un dossier qui contient un tiers ne se supprime pas');
select tests.clear_auth();

select * from finish();
rollback;
