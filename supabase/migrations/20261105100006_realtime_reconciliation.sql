-- Rafraîchissement automatique du rapprochement bancaire : les pointages et les lignes de relevé sont publiés vers Realtime
-- (même principe que 20261105100005 : simple signal, la RLS s'applique aux abonnés).
do $$
declare
  t text;
begin
  foreach t in array array['reconciliation_matches', 'bank_statement_lines']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
