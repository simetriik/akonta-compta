-- Recalculer l'IS alors que le calcul précédent référence encore son brouillard échouait (clé étrangère tax_computations.entry_id
-- à la suppression du brouillard remplacé). Constaté au rejeu de la recette du 12/11/2026 (AN-36).

CREATE OR REPLACE FUNCTION public.compute_income_tax(p_entity uuid, p_fiscal_year uuid, p_adjustments jsonb, p_rules_version text DEFAULT '2026'::text, p_minimum_floor bigint DEFAULT 250000)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_fy public.fiscal_years%rowtype; v_cabinet uuid; v_result bigint; v_add bigint; v_ded bigint; v_taxable bigint; v_rev bigint;
        v_rate numeric; v_min_rate numeric; v_tax bigint; v_min bigint; v_due bigint; v_prepaid bigint; v_balance bigint; v_entry uuid; v_id uuid; v_len int;
        v_891 uuid; v_441 uuid; v_4492 uuid;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  if v_fy.status = 'closed' then raise exception 'Exercice clôturé' using errcode = '42501'; end if;
  select cabinet_id, account_length into v_cabinet, v_len from public.entities where id = p_entity;
  v_result := public.accounting_result(p_entity, p_fiscal_year);
  select coalesce(sum((a->>'amount')::bigint) filter (where a->>'kind' = 'add_back'), 0), coalesce(sum((a->>'amount')::bigint) filter (where a->>'kind' = 'deduction'), 0)
    into v_add, v_ded from jsonb_array_elements(p_adjustments) a;
  v_taxable := v_result + v_add - v_ded;
  -- Chiffre d''affaires (70x) pour le minimum d''impôt
  select coalesce(sum(credit - debit), 0) into v_rev from public.ledger_lines where entity_id = p_entity and fiscal_year_id = p_fiscal_year and left(account_code, 2) = '70';
  v_rate := coalesce(public.tax_rate_at(v_cabinet, 'IS', v_fy.end_date), 0.30);
  v_min_rate := coalesce(public.tax_rate_at(v_cabinet, 'IS_MIN', v_fy.end_date), 0.005);
  v_tax := greatest(round(greatest(v_taxable, 0) * v_rate), 0);
  v_min := greatest(round(v_rev * v_min_rate), p_minimum_floor);
  v_due := greatest(v_tax, v_min);
  -- Acomptes versés (4492, solde débiteur)
  select coalesce(sum(debit - credit), 0) into v_prepaid from public.ledger_lines where entity_id = p_entity and fiscal_year_id = p_fiscal_year and left(account_code, 4) = '4492';
  v_balance := v_due - v_prepaid;
  v_891 := public.account_id_by_code(p_entity, '891'); v_441 := public.account_id_by_code(p_entity, '441'); v_4492 := public.account_id_by_code(p_entity, '4492');
  -- Un recalcul remplace le brouillard d'IS : le calcul précédent ne doit plus le référencer (AN-36).
  update public.tax_computations set entry_id = null where fiscal_year_id = p_fiscal_year and entry_id in (select id from public.entries where status = 'draft');
  v_entry := public.generated_entry(p_entity, v_fy.end_date, 'Impôt sur les bénéfices ' || v_fy.label, 'income_tax:' || p_fiscal_year,
    jsonb_build_array(jsonb_build_object('account_id', v_891, 'debit', v_due, 'label', 'IS de l''exercice'),
                      jsonb_build_object('account_id', v_4492, 'credit', least(v_prepaid, v_due), 'label', 'Imputation des acomptes'),
                      jsonb_build_object('account_id', v_441, 'credit', greatest(v_due - least(v_prepaid, v_due), 0), 'label', 'IS à payer')));
  insert into public.tax_computations (cabinet_id, entity_id, fiscal_year_id, rules_version, accounting_result, adjustments, taxable_result, revenue, is_rate, minimum_tax_rate, minimum_tax_floor,
                                       computed_tax, minimum_tax, tax_due, prepayments, balance_due, entry_id, computed_by)
  values (v_cabinet, p_entity, p_fiscal_year, p_rules_version, v_result, p_adjustments, v_taxable, v_rev, v_rate, v_min_rate, p_minimum_floor, v_tax, v_min, v_due, v_prepaid, v_balance, v_entry, auth.uid())
  on conflict (fiscal_year_id) do update set adjustments = excluded.adjustments, accounting_result = excluded.accounting_result, taxable_result = excluded.taxable_result, revenue = excluded.revenue,
    is_rate = excluded.is_rate, minimum_tax_rate = excluded.minimum_tax_rate, computed_tax = excluded.computed_tax, minimum_tax = excluded.minimum_tax, tax_due = excluded.tax_due,
    prepayments = excluded.prepayments, balance_due = excluded.balance_due, entry_id = excluded.entry_id, computed_at = now(), computed_by = excluded.computed_by
  returning id into v_id;
  return v_id;
end $function$;

-- Retour arrière : recréer compute_income_tax sans la ligne « update public.tax_computations ... » (voir 20261025200013).
