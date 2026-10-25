-- =============================================================================
-- Akonta — Migration 0016 : compatibilité safeupdate (API) pour les contrôles de clôture
-- L''API Supabase refuse tout DELETE sans clause WHERE : la table temporaire des contrôles
-- se vide avec « where true ».
-- =============================================================================
create or replace function public.run_closing_checks(p_entity uuid, p_fiscal_year uuid)
returns table (code text, label text, severity public.check_severity, status public.check_status, details jsonb)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare v_fy public.fiscal_years%rowtype; v_cabinet uuid; v_len int; r record;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  select cabinet_id, account_length into v_cabinet, v_len from public.entities where id = p_entity;
  create temp table if not exists _checks (code text, label text, severity public.check_severity, status public.check_status, details jsonb) on commit drop;
  delete from _checks where true;
  -- 1. Brouillards
  insert into _checks select 'drafts_pending', 'Aucun brouillard en attente', 'blocking'::public.check_severity, case when count(*) = 0 then 'passed' else 'failed' end::public.check_status, jsonb_build_object('count', count(*))
    from public.entries where entity_id = p_entity and fiscal_year_id = p_fiscal_year and status = 'draft';
  -- 2. Équilibre global (défense en profondeur : chaque écriture validée est équilibrée)
  insert into _checks select 'unbalanced', 'Grand livre équilibré', 'blocking'::public.check_severity, case when coalesce(sum(debit), 0) = coalesce(sum(credit), 0) then 'passed' else 'failed' end::public.check_status,
    jsonb_build_object('debit', coalesce(sum(debit), 0), 'credit', coalesce(sum(credit), 0)) from public.ledger_lines where entity_id = p_entity and fiscal_year_id = p_fiscal_year;
  -- 3. Comptes inexistants ou désactivés mouvementés
  insert into _checks select 'inactive_accounts', 'Aucun mouvement sur un compte désactivé', 'blocking'::public.check_severity, case when count(*) = 0 then 'passed' else 'failed' end::public.check_status,
    jsonb_build_object('accounts', coalesce(jsonb_agg(distinct a.code), '[]'::jsonb))
    from public.ledger_lines l join public.accounts a on a.id = l.account_id where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year and not a.is_active;
  -- 4. Compte d''attente 471 soldé
  insert into _checks select 'suspense_471', 'Compte d''attente 471 soldé', 'blocking'::public.check_severity, case when coalesce(sum(debit) - sum(credit), 0) = 0 then 'passed' else 'failed' end::public.check_status,
    jsonb_build_object('balance', coalesce(sum(debit) - sum(credit), 0)) from public.ledger_lines where entity_id = p_entity and fiscal_year_id = p_fiscal_year and account_code like public.pad_account_code('471', 0) || '%' and left(account_code, 3) = '471';
  -- 5. Alertes : écritures non revues, à corriger, rapprochements non figés, lettrage incomplet, périodes non verrouillées
  insert into _checks select 'unreviewed', 'Toutes les écritures sont revues', 'warning'::public.check_severity, case when count(*) = 0 then 'passed' else 'failed' end::public.check_status, jsonb_build_object('count', count(*))
    from public.entries where entity_id = p_entity and fiscal_year_id = p_fiscal_year and status = 'validated' and review_status = 'not_reviewed';
  insert into _checks select 'to_correct', 'Aucune écriture « à corriger »', 'warning'::public.check_severity, case when count(*) = 0 then 'passed' else 'failed' end::public.check_status, jsonb_build_object('count', count(*))
    from public.entries where entity_id = p_entity and fiscal_year_id = p_fiscal_year and review_status = 'to_correct';
  insert into _checks select 'reconciliations', 'États de rapprochement figés à la clôture pour chaque journal de banque', 'warning'::public.check_severity,
    case when count(*) = 0 then 'passed' else 'failed' end::public.check_status, jsonb_build_object('journals', coalesce(jsonb_agg(j.code), '[]'::jsonb))
    from public.journals j where j.entity_id = p_entity and j.type = 'bank' and j.is_active
     and not exists (select 1 from public.reconciliations r where r.journal_id = j.id and r.as_of = v_fy.end_date and r.status = 'final');
  insert into _checks select 'depreciation', 'Dotations aux amortissements générées et validées', 'warning'::public.check_severity,
    case when exists (select 1 from public.fixed_assets where entity_id = p_entity and status = 'in_service' and is_depreciable and service_date <= v_fy.end_date)
              and not exists (select 1 from public.entries where entity_id = p_entity and generated_source = 'depreciation:' || p_fiscal_year and status = 'validated')
         then 'failed' else 'passed' end::public.check_status, '{}'::jsonb;
  insert into _checks select 'unlocked_periods', 'Toutes les périodes sont verrouillées', 'warning'::public.check_severity, case when count(*) = 0 then 'passed' else 'failed' end::public.check_status, jsonb_build_object('count', count(*))
    from public.periods where fiscal_year_id = p_fiscal_year and not is_locked;
  -- Persistance (en conservant les levées déjà accordées sur les alertes encore en échec)
  for r in select * from _checks loop
    insert into public.closing_checks (cabinet_id, entity_id, fiscal_year_id, code, label, severity, status, details, checked_at)
    values (v_cabinet, p_entity, p_fiscal_year, r.code, r.label, r.severity, r.status, r.details, now())
    on conflict (fiscal_year_id, code) do update set status = case when excluded.status = 'failed' and public.closing_checks.status = 'waived' then 'waived' else excluded.status end,
      details = excluded.details, checked_at = now(), label = excluded.label, severity = excluded.severity;
  end loop;
  return query select c.code, c.label, c.severity, c.status, c.details from public.closing_checks c where c.fiscal_year_id = p_fiscal_year order by c.severity, c.code;
end $$;
