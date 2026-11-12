-- Affectation du résultat : une perte se reporte à nouveau (débiteur) et le montant affecté est contrôlé (AN-38, rejeu du 12/11/2026).
-- Avant : « Montant à affecter nul » pour une perte, et rien ne rapprochait le total saisi du résultat réellement en instance.

-- Résultat en instance d'affectation à l'ouverture de l'exercice suivant : bénéfice > 0, perte < 0, 0 si rien (ou à-nouveaux non validés).
create or replace function public.pending_result(p_entity uuid, p_fiscal_year_next uuid)
returns bigint language sql stable security definer set search_path = public as $$
  select coalesce(sum(l.credit - l.debit), 0)::bigint
    from public.ledger_lines l
    join public.entities e on e.id = l.entity_id
   where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year_next
     and public.has_permission(p_entity, 'closing.provisional')
     and l.account_code = public.pad_account_code(case e.accounting_system when 'sycebnl' then '128' else '130' end, e.account_length);
$$;
revoke all on function public.pending_result(uuid, uuid) from public, anon;
grant execute on function public.pending_result(uuid, uuid) to authenticated;

create or replace function public.allocate_result(p_entity uuid, p_fiscal_year_next uuid, p_date date, p_legal_reserve bigint, p_free_reserve bigint, p_dividends bigint, p_carry_forward bigint)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_total bigint := p_legal_reserve + p_free_reserve + p_dividends + p_carry_forward; v_lines jsonb; v_system text; v_pending bigint; v_pending_code text;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture' using errcode = '42501';
  end if;
  select accounting_system into v_system from public.entities where id = p_entity;
  v_pending_code := case v_system when 'sycebnl' then '128' else '130' end;
  v_pending := public.pending_result(p_entity, p_fiscal_year_next);
  if least(p_legal_reserve, p_free_reserve, p_dividends, p_carry_forward) < 0 then
    raise exception 'Montant d''affectation négatif' using errcode = '23514';
  end if;

  -- Perte : aucune répartition, elle est reportée à nouveau au débit du compte 129 en soldant le résultat en instance.
  if v_pending < 0 then
    if v_total <> 0 then
      raise exception 'Le résultat en instance est une perte de % : elle se reporte à nouveau, sans réserve ni dividende (laisser les montants à zéro)', -v_pending using errcode = '23514';
    end if;
    v_lines := jsonb_build_array(
      jsonb_build_object('account_id', public.account_id_by_code(p_entity, '129'), 'debit', -v_pending, 'label', 'Report à nouveau débiteur (perte)'),
      jsonb_build_object('account_id', public.account_id_by_code(p_entity, v_pending_code), 'credit', -v_pending, 'label', 'Affectation de la perte'));
    return public.generated_entry(p_entity, p_date, 'Affectation du résultat', 'allocation:' || p_fiscal_year_next, v_lines);
  end if;

  if v_total <= 0 then raise exception 'Montant à affecter nul' using errcode = '23514'; end if;
  -- Bénéfice : le total affecté doit égaler le résultat en instance (quand les à-nouveaux sont validés).
  if v_pending > 0 and v_total <> v_pending then
    raise exception 'Le montant affecté (%) doit égaler le résultat en instance (%)', v_total, v_pending using errcode = '23514';
  end if;
  if v_system = 'sycebnl' then
    if p_dividends <> 0 then raise exception 'Une entité à but non lucratif ne distribue pas son excédent' using errcode = '23514'; end if;
    v_lines := jsonb_build_array(jsonb_build_object('account_id', public.account_id_by_code(p_entity, '128'), 'debit', v_total, 'label', 'Affectation du résultat'))
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '112'), 'credit', p_legal_reserve, 'label', 'Réserves statutaires ou contractuelles')
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '118'), 'credit', p_free_reserve, 'label', 'Autres réserves')
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '121'), 'credit', p_carry_forward, 'label', 'Report à nouveau des excédents');
  else
    v_lines := jsonb_build_array(jsonb_build_object('account_id', public.account_id_by_code(p_entity, '130'), 'debit', v_total, 'label', 'Affectation du résultat'))
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '111'), 'credit', p_legal_reserve, 'label', 'Réserve légale')
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '118'), 'credit', p_free_reserve, 'label', 'Réserves libres')
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '465'), 'credit', p_dividends, 'label', 'Dividendes à payer')
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '121'), 'credit', p_carry_forward, 'label', 'Report à nouveau');
  end if;
  return public.generated_entry(p_entity, p_date, 'Affectation du résultat', 'allocation:' || p_fiscal_year_next, v_lines);
end $$;

-- Retour arrière : recréer allocate_result depuis 20261031100007 et supprimer pending_result.
