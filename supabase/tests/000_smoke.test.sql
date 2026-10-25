-- Test de fumée : l'environnement pgTAP fonctionne et les extensions attendues sont là.
begin;
select plan(3);

select has_extension('pgtap', 'pgTAP est installé');
select has_extension('pgcrypto', 'pgcrypto est installé (empreintes SHA-256 de la piste d''audit)');
select ok(current_setting('server_version_num')::int >= 170000, 'PostgreSQL 17 ou plus');

select * from finish();
rollback;
