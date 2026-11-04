-- Rafraîchissement automatique : les tables lues par les listes sont publiées vers Realtime.
begin;
select plan(10);

select ok(exists (select 1 from pg_publication where pubname = 'supabase_realtime'), 'publication supabase_realtime présente');

select ok(exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'entries'),
          'écritures publiées');
select ok(exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'documents'),
          'pièces publiées');
select ok(exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'entry_documents'),
          'rattachements de pièces publiés');
select ok(exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'),
          'notifications publiées');
select ok(exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'letterings'),
          'lettrages publiés');
select ok(exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'reconciliations'),
          'rapprochements publiés');

select ok(exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'reconciliation_matches'),
          'pointages publiés');
select ok(exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'bank_statement_lines'),
          'lignes de relevé publiées');

-- Garde-fou : une table publiée sans RLS exposerait ses événements à tout abonné.
select is((select count(*) from pg_publication_tables p join pg_class c on c.relname = p.tablename
           join pg_namespace n on n.oid = c.relnamespace and n.nspname = p.schemaname
           where p.pubname = 'supabase_realtime' and p.schemaname = 'public' and not c.relrowsecurity), 0::bigint,
          'toute table publiée a la RLS activée');

select * from finish();
rollback;
