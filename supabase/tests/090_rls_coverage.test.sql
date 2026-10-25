-- Couverture RLS : toute table du schéma public a la RLS activée et au moins une politique de lecture ;
-- toute table portant entity_id ou cabinet_id est inaccessible à un utilisateur d'un autre cabinet.
begin;
select plan(4);

-- 1. RLS activée partout
select is((select string_agg(c.relname, ', ' order by c.relname)
             from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
          null, 'toutes les tables de public ont la RLS activée');

-- 2. Chaque table a au moins une politique de lecture
select is((select string_agg(c.relname, ', ' order by c.relname)
             from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind in ('r', 'p')
              and not exists (select 1 from pg_policy p where p.polrelid = c.oid and p.polcmd in ('r', '*'))),
          null, 'toutes les tables ont une politique de lecture');

-- 3. Les tables de données métier (entity_id) ne sont jamais ouvertes à tous (using (true))
select is((select string_agg(c.relname, ', ' order by c.relname)
             from pg_policy p join pg_class c on c.oid = p.polrelid join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and pg_get_expr(p.polqual, p.polrelid) = 'true'
              and exists (select 1 from information_schema.columns col where col.table_schema = 'public' and col.table_name = c.relname and col.column_name = 'entity_id')),
          null, 'aucune politique « using (true) » sur une table portant entity_id');

-- 4. Un utilisateur sans affectation ne voit aucune ligne d'aucune table de dossier (balayage générique)
select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('assist@a.test', :'a_id') as id \gset assist_
select tests.create_user('partner@b.test', :'b_id') as id \gset partnerb_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'partnerb_id', :'b_id', 'partner');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select public.create_journals_from_template(:'e1_id', null);
select tests.make_entry(:'e1_id', 'OD', '2026-01-10', 'Loyer', '[{"account":"6221000","debit":100000},{"account":"4710000","credit":100000}]', :'assist_id');

create temporary table leaks (tbl text, n bigint);
do $$
declare t record; n bigint;
begin
  perform tests.authenticate_as((select id from auth.users where email = 'partner@b.test'), 'aal2');
  for t in select c.relname from pg_class c join pg_namespace nsp on nsp.oid = c.relnamespace
            where nsp.nspname = 'public' and c.relkind = 'r'
              and exists (select 1 from information_schema.columns col where col.table_schema = 'public' and col.table_name = c.relname and col.column_name = 'entity_id') loop
    execute format('select count(*) from public.%I where entity_id = %L', t.relname, (select id from public.entities where name = 'SARL Démo')) into n;
    if n > 0 then insert into leaks values (t.relname, n); end if;
  end loop;
  perform tests.clear_auth();
end $$;
select is((select string_agg(tbl || ':' || n, ', ') from leaks), null, 'cabinet B : aucune ligne visible dans aucune table du dossier du cabinet A');

select * from finish();
rollback;
