-- =============================================================================
-- Akonta — Saisie par scan de pièce : écriture proposée en brouillard depuis une pièce lue (OCR local).
-- La proposition (date, libellé, lignes) est calculée par l'Edge Function `extract-document` ; cette fonction la
-- vérifie, crée le brouillard marqué « générée » (source `document:<id>`) et lie la pièce. Jamais de validation automatique.
-- Un second appel pour la même pièce renvoie le brouillard existant sans l'écraser (le comptable a pu le retoucher).
-- =============================================================================
create or replace function public.generate_scan_entry(p_document uuid, p_proposal jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_doc public.documents%rowtype;
  v_source text := 'document:' || p_document::text;
  v_entry uuid; v_date date; v_label text; v_reference text; v_journal_type public.journal_type;
  v_lines jsonb; l jsonb; v_debit bigint := 0; v_credit bigint := 0; v_d bigint; v_c bigint;
begin
  select * into v_doc from public.documents where id = p_document and cabinet_id = public.current_cabinet_id();
  if v_doc.id is null then
    raise exception 'Pièce inaccessible' using errcode = '42501';
  end if;
  if not (public.has_permission(v_doc.entity_id, 'entries.draft') and public.has_permission(v_doc.entity_id, 'documents.attach')) then
    raise exception 'Permission refusée : entries.draft et documents.attach' using errcode = '42501';
  end if;
  -- Un client (sans accès général au dossier) ne traite que ses propres dépôts.
  if not public.can_access_entity(v_doc.entity_id) and v_doc.captured_by is distinct from auth.uid() then
    raise exception 'Pièce inaccessible' using errcode = '42501';
  end if;

  -- Déjà proposée : on renvoie l'écriture existante, sans rien écraser.
  select id into v_entry from public.entries where entity_id = v_doc.entity_id and generated_source = v_source;
  if v_entry is not null then return v_entry; end if;

  v_date := (p_proposal ->> 'date')::date;
  v_label := nullif(trim(p_proposal ->> 'label'), '');
  v_reference := nullif(trim(p_proposal ->> 'reference'), '');
  v_journal_type := coalesce(nullif(p_proposal ->> 'journal_type', ''), 'purchases')::public.journal_type;
  v_lines := coalesce(p_proposal -> 'lines', '[]'::jsonb);
  if v_date is null or v_label is null then
    raise exception 'La proposition doit comporter une date et un libellé' using errcode = '23514';
  end if;
  if jsonb_typeof(v_lines) <> 'array' or jsonb_array_length(v_lines) < 2 then
    raise exception 'La proposition doit comporter au moins deux lignes' using errcode = '23514';
  end if;

  for l in select * from jsonb_array_elements(v_lines) loop
    v_d := coalesce((l ->> 'debit')::bigint, 0);
    v_c := coalesce((l ->> 'credit')::bigint, 0);
    if v_d < 0 or v_c < 0 or (v_d > 0 and v_c > 0) then
      raise exception 'Chaque ligne porte un débit ou un crédit positif, pas les deux' using errcode = '23514';
    end if;
    if not exists (select 1 from public.accounts a where a.id = (l ->> 'account_id')::uuid and a.entity_id = v_doc.entity_id and a.is_active and a.allow_posting) then
      raise exception 'Chaque compte doit appartenir au dossier, être actif et accepter des écritures' using errcode = '23514';
    end if;
    if nullif(l ->> 'third_party_id', '') is not null and not exists (
         select 1 from public.third_parties t where t.id = (l ->> 'third_party_id')::uuid and t.entity_id = v_doc.entity_id) then
      raise exception 'Le tiers n''appartient pas au dossier' using errcode = '23514';
    end if;
    v_debit := v_debit + v_d;
    v_credit := v_credit + v_c;
  end loop;
  if v_debit = 0 or v_debit <> v_credit then
    raise exception 'La proposition ne s''équilibre pas (débit %, crédit %)', v_debit, v_credit using errcode = '23514';
  end if;

  v_entry := public.generated_entry(v_doc.entity_id, v_date, v_label, v_source, v_lines, v_journal_type);
  update public.entries set reference = v_reference where id = v_entry;
  insert into public.entry_documents (entry_id, document_id) values (v_entry, p_document) on conflict do nothing;
  return v_entry;
end $$;
revoke all on function public.generate_scan_entry(uuid, jsonb) from public, anon;
grant execute on function public.generate_scan_entry(uuid, jsonb) to authenticated;

comment on function public.generate_scan_entry(uuid, jsonb) is 'Crée en brouillard (source document:<id>) l''écriture proposée après lecture d''une pièce, et lie la pièce. Idempotent : ne réécrit jamais un brouillard existant.';

-- Retour arrière : drop function public.generate_scan_entry(uuid, jsonb);
