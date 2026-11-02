-- Tableau de bord des dossiers pour les clients (D-044, tranche 3, étape 3).
-- Une seule fonction pour le personnel et pour les clients : la branche client ne renvoie QUE des compteurs sur les
-- brouillards visibles du client (la RLS limite déjà ce qu'il compte) et l'état de l'accès ; rien sur les écritures
-- validées, la revue ou le chef de mission. Fonction toujours en security invoker : la RLS de l'appelant s'applique.
drop function public.entity_dashboard();
create function public.entity_dashboard()
returns table (entity_id uuid, entity_name text, fiscal_year_id uuid, fiscal_year_label text, fiscal_year_status public.fiscal_year_status,
               manager_names text, last_entry_date date, draft_count bigint, unreviewed_count bigint, to_correct_count bigint,
               inbox_count bigint, client_access text)
language sql stable as $$
  select e.id, e.name, fy.id, fy.label, fy.status,
         (select string_agg(p.full_name, ', ' order by p.full_name)
            from public.assignments a join public.roles r on r.id = a.role_id join public.profiles p on p.id = a.user_id
           where a.entity_id = e.id and r.code = 'manager'),
         (select max(en.entry_date) from public.entries en where en.entity_id = e.id and en.status = 'validated'),
         (select count(*) from public.entries en where en.entity_id = e.id and en.status = 'draft'),
         (select count(*) from public.entries en where en.entity_id = e.id and en.status = 'validated' and en.review_status = 'not_reviewed'),
         (select count(*) from public.entries en where en.entity_id = e.id and en.review_status = 'to_correct'),
         (select count(*) from public.document_inbox d where d.entity_id = e.id),
         e.client_access
    from public.entities e
    left join lateral (select * from public.fiscal_years f where f.entity_id = e.id order by f.start_date desc limit 1) fy on true
   where e.is_active and public.can_access_entity(e.id)
  union all
  select e.id, e.name, fy.id, fy.label, fy.status,
         null::text, null::date,
         (select count(*) from public.entries en where en.entity_id = e.id and en.status = 'draft'),
         0::bigint,
         (select count(*) from public.entries en where en.entity_id = e.id and en.status = 'draft' and en.returned_comment is not null),
         0::bigint,
         e.client_access
    from public.entities e
    left join lateral (select * from public.fiscal_years f where f.entity_id = e.id order by f.start_date desc limit 1) fy on true
   where e.is_active and public.client_can_read_entity(e.id)
  order by 2;
$$;
revoke all on function public.entity_dashboard() from public, anon;
grant execute on function public.entity_dashboard() to authenticated;
