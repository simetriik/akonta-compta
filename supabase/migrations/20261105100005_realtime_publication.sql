-- Rafraîchissement automatique : les tables dont un autre utilisateur peut modifier le contenu sont publiées vers Supabase Realtime.
-- L'application s'en sert comme simple signal (« quelque chose a changé ») pour relire ses listes ; aucune donnée n'est lue
-- depuis l'événement. La RLS s'applique aux abonnés : on ne reçoit que les événements des dossiers auxquels on a accès.

do $$
begin
  -- La publication existe déjà sur Supabase ; on la crée seulement sur une base nue (tests, conteneur simple).
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array['entries', 'documents', 'entry_documents', 'notifications', 'letterings', 'reconciliations', 'invoices']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
