-- Suggestions de saisie sans modèle (décision D-026, palier 0) : écritures proches, comptes habituels, habitudes d'un tiers,
-- modèles proches et alerte de doublon, calculés à partir de l'historique de l'entité (ressemblance de texte sans accents).
-- Les fonctions s'exécutent avec les droits de l'appelant : la RLS limite l'historique aux dossiers auxquels il est affecté.
-- Seules les écritures validées, non générées et non contre-passées servent d'exemple. Rien n'est appliqué automatiquement.

create extension if not exists unaccent with schema extensions;

-- Libellé normalisé : minuscules, sans accents (immuable pour l'indexation).
create or replace function public.norm_label(p_text text)
returns text language sql immutable parallel safe as $$
  select lower(extensions.unaccent('extensions.unaccent'::regdictionary, coalesce(p_text, '')));
$$;

create index entries_label_norm_trgm on public.entries using gin (public.norm_label(label) extensions.gin_trgm_ops);
create index entry_lines_label_norm_trgm on public.entry_lines using gin (public.norm_label(label) extensions.gin_trgm_ops);

-- A. Écritures proches : mêmes comptes, tiers et sens, sans montants.
create or replace function public.suggest_entries(p_entity uuid, p_label text, p_limit integer default 5)
returns table (entry_id uuid, entry_date date, journal_code text, label text, reference text, similarity real, lines jsonb)
language sql stable set search_path = public, extensions set pg_trgm.word_similarity_threshold = '0.5' as $$
  with q as (select public.norm_label(trim(coalesce(p_label, ''))) as t)
  select e.id, e.entry_date, j.code, e.label, e.reference,
         word_similarity(q.t, public.norm_label(e.label))::real,
         (select jsonb_agg(jsonb_build_object('account_id', a.id, 'account_code', a.code, 'account_label', a.label,
                                              'third_party_id', l.third_party_id, 'third_party_code', t.code,
                                              'side', case when l.debit > 0 then 'debit' else 'credit' end, 'label', l.label) order by l.line_no)
            from public.entry_lines l
            join public.accounts a on a.id = l.account_id
            left join public.third_parties t on t.id = l.third_party_id
           where l.entry_id = e.id)
    from public.entries e
    join public.journals j on j.id = e.journal_id, q
   where e.entity_id = p_entity and length(q.t) >= 3
     and e.status = 'validated' and not e.is_generated and e.reversal_of is null and e.reversed_by is null
     and q.t <% public.norm_label(e.label)
   order by 6 desc, e.entry_date desc, e.id
   limit least(greatest(p_limit, 1), 20);
$$;

-- B et C. Comptes habituels : ceux des écritures du même tiers (source « third_party »), puis ceux des libellés proches
-- (source « label »). Comptes imputables, actifs et non collectifs.
create or replace function public.suggest_accounts(p_entity uuid, p_label text, p_third_party uuid default null, p_limit integer default 3)
returns table (account_id uuid, account_code text, account_label text, source text, uses integer, last_used date, similarity real)
language sql stable set search_path = public, extensions set pg_trgm.word_similarity_threshold = '0.5' as $$
  with q as (select public.norm_label(trim(coalesce(p_label, ''))) as t),
  history as (
    select e.id, e.entry_date from public.entries e
     where e.entity_id = p_entity and e.status = 'validated' and not e.is_generated and e.reversal_of is null and e.reversed_by is null
  ),
  by_third_party as (
    select a.id as account_id, a.code, a.label, 'third_party'::text as source, count(distinct h.id)::integer as uses,
           max(h.entry_date) as last_used, null::real as similarity, 1 as ord, count(distinct h.id)::numeric as score
      from history h
      join public.entry_lines tl on tl.entry_id = h.id and tl.third_party_id = p_third_party
      join public.entry_lines l on l.entry_id = h.id and l.third_party_id is null
      join public.accounts a on a.id = l.account_id and a.allow_posting and a.is_active and not a.is_collective
     where p_third_party is not null
     group by a.id, a.code, a.label
  ),
  by_label as (
    select a.id as account_id, a.code, a.label, 'label'::text as source, count(distinct h.id)::integer as uses,
           max(h.entry_date) as last_used, max(word_similarity(q.t, public.norm_label(coalesce(l.label, ''))))::real as similarity, 2 as ord,
           max(word_similarity(q.t, public.norm_label(coalesce(l.label, '')))) * (1 + ln(count(distinct h.id)))::numeric as score
      from q, history h
      join public.entry_lines l on l.entry_id = h.id
      join public.accounts a on a.id = l.account_id and a.allow_posting and a.is_active and not a.is_collective
     where length(q.t) >= 3 and q.t <% public.norm_label(l.label)
     group by a.id, a.code, a.label
  )
  select x.account_id, x.code, x.label, x.source, x.uses, x.last_used, x.similarity
    from (select * from by_third_party
          union all
          select * from by_label where account_id not in (select account_id from by_third_party)) x
   order by x.ord, x.score desc, x.last_used desc, x.code
   limit least(greatest(p_limit, 1), 10);
$$;

-- A. Modèles d'écritures proches du libellé (même référentiel que l'entité).
create or replace function public.suggest_templates(p_entity uuid, p_label text, p_limit integer default 3)
returns table (template_id uuid, code text, label text, similarity real)
language sql stable set search_path = public, extensions set pg_trgm.word_similarity_threshold = '0.5' as $$
  with q as (select public.norm_label(trim(coalesce(p_label, ''))) as t)
  select t.id, t.code, t.label,
         greatest(word_similarity(q.t, public.norm_label(t.label)), word_similarity(q.t, public.norm_label(coalesce(t.description, ''))))::real
    from public.entry_templates t
    join public.entities en on en.id = p_entity, q
   where length(q.t) >= 3 and t.is_active and t.cabinet_id = en.cabinet_id and (t.entity_id is null or t.entity_id = p_entity)
     and t.accounting_system = en.accounting_system
     and (q.t <% public.norm_label(t.label) or q.t <% public.norm_label(coalesce(t.description, '')))
   order by 4 desc, t.code
   limit least(greatest(p_limit, 1), 10);
$$;

-- D. Doublon possible : même référence de pièce, même montant (total débit) et, si connu, même tiers.
create or replace function public.find_duplicate_entries(p_entity uuid, p_reference text, p_amount bigint, p_third_party uuid default null, p_exclude uuid default null)
returns table (entry_id uuid, number bigint, journal_code text, entry_date date, status public.entry_status, label text)
language sql stable set search_path = public as $$
  select e.id, e.number, j.code, e.entry_date, e.status, e.label
    from public.entries e
    join public.journals j on j.id = e.journal_id
   where e.entity_id = p_entity and nullif(trim(p_reference), '') is not null and p_amount > 0
     and lower(trim(e.reference)) = lower(trim(p_reference))
     and e.id is distinct from p_exclude and e.reversal_of is null and e.reversed_by is null
     and (select coalesce(sum(l.debit), 0) from public.entry_lines l where l.entry_id = e.id) = p_amount
     and (p_third_party is null or exists (select 1 from public.entry_lines l where l.entry_id = e.id and l.third_party_id = p_third_party))
   order by e.entry_date desc, e.id
   limit 5;
$$;

revoke execute on function public.suggest_entries(uuid, text, integer), public.suggest_accounts(uuid, text, uuid, integer),
  public.suggest_templates(uuid, text, integer), public.find_duplicate_entries(uuid, text, bigint, uuid, uuid) from public, anon;
grant execute on function public.norm_label(text), public.suggest_entries(uuid, text, integer), public.suggest_accounts(uuid, text, uuid, integer),
  public.suggest_templates(uuid, text, integer), public.find_duplicate_entries(uuid, text, bigint, uuid, uuid) to authenticated;
