-- Affectation du résultat : bénéfice et perte en instance traités séparément, compte par compte (AN-39, préparation de l'étape 12).
-- À l'ouverture d'un exercice, plusieurs comptes 130x peuvent porter un résultat en instance de signe opposé : bénéfice N-1 repris
-- à l'import (1301000) et perte N de l'exercice arrêté (1300000). L'affectation solde chaque compte de bénéfice ; la perte se reporte à nouveau
-- séparément ; les deux ne se compensent jamais d'office (c'est une décision de l'assemblée).

-- Résultats en instance à l'ouverture de l'exercice suivant : bénéfices (comptes créditeurs) et pertes (comptes débiteurs), en valeur positive.
create or replace function public.pending_results(p_entity uuid, p_fiscal_year_next uuid)
returns table (profit bigint, loss bigint) language sql stable security definer set search_path = public as $$
  with b as (
    select l.account_id, sum(l.credit - l.debit) as bal
      from public.ledger_lines l join public.entities e on e.id = l.entity_id
     where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year_next and public.has_permission(p_entity, 'closing.provisional')
       and left(l.account_code, 3) = case e.accounting_system when 'sycebnl' then '128' else '130' end
     group by l.account_id)
  select coalesce(sum(bal) filter (where bal > 0), 0)::bigint, coalesce(-sum(bal) filter (where bal < 0), 0)::bigint from b;
$$;
revoke all on function public.pending_results(uuid, uuid) from public, anon;
grant execute on function public.pending_results(uuid, uuid) to authenticated;

-- Solde net (bénéfice - perte), conservé pour la compatibilité avec la version précédente.
create or replace function public.pending_result(p_entity uuid, p_fiscal_year_next uuid)
returns bigint language sql stable security definer set search_path = public as $$
  select profit - loss from public.pending_results(p_entity, p_fiscal_year_next);
$$;

-- Lignes qui soldent les comptes de résultat en instance : bénéfices (comptes créditeurs → débit) ou pertes (comptes débiteurs → crédit).
create or replace function public.instance_clearing_lines(p_entity uuid, p_fiscal_year_next uuid, p_profit boolean)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('account_id', x.account_id,
           'debit', case when p_profit then x.bal else 0 end, 'credit', case when p_profit then 0 else -x.bal end,
           'label', case when p_profit then 'Résultat en instance affecté' else 'Perte en instance reportée' end) order by x.code), '[]'::jsonb)
    from (select l.account_id, l.account_code as code, sum(l.credit - l.debit) as bal
            from public.ledger_lines l join public.entities e on e.id = l.entity_id
           where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year_next
             and left(l.account_code, 3) = case e.accounting_system when 'sycebnl' then '128' else '130' end
           group by l.account_id, l.account_code
          having case when p_profit then sum(l.credit - l.debit) > 0 else sum(l.credit - l.debit) < 0 end) x;
$$;

-- Report à nouveau de la perte en instance : débit du compte 129, crédit des comptes de perte en instance.
create or replace function public.carry_forward_loss(p_entity uuid, p_fiscal_year_next uuid, p_date date)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_loss bigint;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture' using errcode = '42501';
  end if;
  select loss into v_loss from public.pending_results(p_entity, p_fiscal_year_next);
  if coalesce(v_loss, 0) <= 0 then raise exception 'Aucune perte en instance à reporter (valider les à-nouveaux d''abord)' using errcode = '23514'; end if;
  return public.generated_entry(p_entity, p_date, 'Report à nouveau de la perte', 'loss_carry:' || p_fiscal_year_next,
    public.instance_clearing_lines(p_entity, p_fiscal_year_next, false)
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '129'), 'debit', v_loss, 'label', 'Report à nouveau débiteur (perte)'));
end $$;
revoke all on function public.carry_forward_loss(uuid, uuid, date) from public, anon;
grant execute on function public.carry_forward_loss(uuid, uuid, date) to authenticated;

-- Affectation du bénéfice en instance. Une perte seule (aucun bénéfice) se reporte via carry_forward_loss (montants à zéro : compatibilité).
create or replace function public.allocate_result(p_entity uuid, p_fiscal_year_next uuid, p_date date, p_legal_reserve bigint, p_free_reserve bigint, p_dividends bigint, p_carry_forward bigint)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_total bigint := p_legal_reserve + p_free_reserve + p_dividends + p_carry_forward; v_lines jsonb; v_system text; v_profit bigint; v_loss bigint; v_pending_acc text;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture' using errcode = '42501';
  end if;
  select accounting_system into v_system from public.entities where id = p_entity;
  v_pending_acc := case v_system when 'sycebnl' then '128' else '130' end;
  select profit, loss into v_profit, v_loss from public.pending_results(p_entity, p_fiscal_year_next);
  if least(p_legal_reserve, p_free_reserve, p_dividends, p_carry_forward) < 0 then
    raise exception 'Montant d''affectation négatif' using errcode = '23514';
  end if;

  if v_profit = 0 and v_loss > 0 then
    if v_total <> 0 then
      raise exception 'Le résultat en instance est une perte de % : elle se reporte à nouveau, sans réserve ni dividende (laisser les montants à zéro)', v_loss using errcode = '23514';
    end if;
    return public.carry_forward_loss(p_entity, p_fiscal_year_next, p_date);
  end if;

  if v_total <= 0 then raise exception 'Montant à affecter nul' using errcode = '23514'; end if;
  if v_profit > 0 and v_total <> v_profit then
    raise exception 'Le montant affecté (%) doit égaler le bénéfice en instance (%)', v_total, v_profit using errcode = '23514';
  end if;
  -- Bénéfice en instance validé : chaque compte de bénéfice est soldé ; sinon (à-nouveaux non validés) ancien comportement, au compte 130 / 128.
  if v_profit > 0 then
    v_lines := public.instance_clearing_lines(p_entity, p_fiscal_year_next, true);
  else
    v_lines := jsonb_build_array(jsonb_build_object('account_id', public.account_id_by_code(p_entity, v_pending_acc), 'debit', v_total, 'label', 'Affectation du résultat'));
  end if;
  if v_system = 'sycebnl' then
    if p_dividends <> 0 then raise exception 'Une entité à but non lucratif ne distribue pas son excédent' using errcode = '23514'; end if;
    v_lines := v_lines
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '112'), 'credit', p_legal_reserve, 'label', 'Réserves statutaires ou contractuelles')
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '118'), 'credit', p_free_reserve, 'label', 'Autres réserves')
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '121'), 'credit', p_carry_forward, 'label', 'Report à nouveau des excédents');
  else
    v_lines := v_lines
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '111'), 'credit', p_legal_reserve, 'label', 'Réserve légale')
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '118'), 'credit', p_free_reserve, 'label', 'Réserves libres')
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '465'), 'credit', p_dividends, 'label', 'Dividendes à payer')
      || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '121'), 'credit', p_carry_forward, 'label', 'Report à nouveau');
  end if;
  return public.generated_entry(p_entity, p_date, 'Affectation du résultat', 'allocation:' || p_fiscal_year_next, v_lines);
end $$;

-- Retour arrière : recréer allocate_result et pending_result depuis 20261112200001 ; supprimer pending_results, instance_clearing_lines, carry_forward_loss.
