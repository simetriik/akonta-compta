-- Validation d'écriture : la permission est contrôlée avant le statut (AN-41, rejeu de la recette du 14/11/2026).
-- Avant, un utilisateur sans droit sur le dossier (un client par exemple) qui connaissait l'identifiant d'une écriture
-- recevait « Écriture déjà validée (n° N) » au lieu de « Permission refusée » : le statut et le numéro étaient divulgués.
-- Seul l'ordre des contrôles change ; les règles de validation sont inchangées.
CREATE OR REPLACE FUNCTION public.validate_entry(p_entry uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_entry public.entries%rowtype;
  v_debit bigint; v_credit bigint; v_lines int;
  v_bad text;
  v_number bigint;
begin
  select * into v_entry from public.entries where id = p_entry for update;
  if v_entry.id is null then raise exception 'Écriture inconnue' using errcode = 'P0002'; end if;
  if auth.uid() is not null then
    if not public.has_permission(v_entry.entity_id, 'entries.validate') then
      raise exception 'Permission refusée : valider des écritures' using errcode = '42501';
    end if;
  if v_entry.status <> 'draft' then
    raise exception 'Écriture déjà validée (n° %)', v_entry.number using errcode = '23514';
  end if;
    if v_entry.created_by <> auth.uid() and not public.has_permission(v_entry.entity_id, 'entries.review') then
      raise exception 'Vous ne validez que vos propres écritures' using errcode = '42501';
    end if;
  end if;
  -- Période ouverte
  if not public.period_open_for(v_entry.entity_id, v_entry.entry_date) then
    raise exception 'La date % n''est pas dans une période ouverte', v_entry.entry_date using errcode = '23514';
  end if;
  -- Lignes : au moins deux, équilibre, comptes actifs et imputables, tiers sur collectif
  select count(*), coalesce(sum(debit), 0), coalesce(sum(credit), 0) into v_lines, v_debit, v_credit
    from public.entry_lines where entry_id = p_entry;
  if v_lines < 2 then
    raise exception 'Une écriture comporte au moins deux lignes' using errcode = '23514';
  end if;
  if v_debit <> v_credit then
    raise exception 'Écriture déséquilibrée : débit % ≠ crédit %', v_debit, v_credit using errcode = '23514';
  end if;
  select string_agg(a.code, ', ') into v_bad
    from public.entry_lines l join public.accounts a on a.id = l.account_id
   where l.entry_id = p_entry and (not a.is_active or not a.allow_posting);
  if v_bad is not null then
    raise exception 'Comptes inactifs ou non imputables : %', v_bad using errcode = '23514';
  end if;
  select string_agg(a.code, ', ') into v_bad
    from public.entry_lines l join public.accounts a on a.id = l.account_id
   where l.entry_id = p_entry and a.is_collective and l.third_party_id is null;
  if v_bad is not null then
    raise exception 'Tiers obligatoire sur les comptes collectifs : %', v_bad using errcode = '23514';
  end if;
  -- Numéro séquentiel : verrou sur la séquence du journal pour l''exercice
  insert into public.journal_sequences (journal_id, fiscal_year_id, last_number)
  values (v_entry.journal_id, v_entry.fiscal_year_id, 0)
  on conflict (journal_id, fiscal_year_id) do nothing;
  select last_number + 1 into v_number from public.journal_sequences
   where journal_id = v_entry.journal_id and fiscal_year_id = v_entry.fiscal_year_id for update;
  update public.journal_sequences set last_number = v_number
   where journal_id = v_entry.journal_id and fiscal_year_id = v_entry.fiscal_year_id;

  perform set_config('akonta.internal', 'on', true);
  update public.entries
     set status = 'validated', number = v_number, validated_by = auth.uid(), validated_at = now()
   where id = p_entry;
  perform set_config('akonta.internal', 'off', true);

  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_entry.cabinet_id, auth.uid(), 'validate', 'entries', p_entry::text, v_entry.entity_id,
          jsonb_build_object('number', v_number, 'journal_id', v_entry.journal_id, 'entry_date', v_entry.entry_date,
                             'debit', v_debit, 'credit', v_credit,
                             'lines', (select jsonb_agg(jsonb_build_object('account', a.code, 'third_party', t.code, 'debit', l.debit, 'credit', l.credit) order by l.line_no)
                                         from public.entry_lines l join public.accounts a on a.id = l.account_id
                                         left join public.third_parties t on t.id = l.third_party_id where l.entry_id = p_entry)));
  return v_number;
end $function$;
