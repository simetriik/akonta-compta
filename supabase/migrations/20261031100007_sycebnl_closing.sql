-- Clôture des entités à but non lucratif (décision D-024).
--  1. Résultat en instance d'affectation : compte 130 (SYSCOHADA) ou 128 (SYCEBNL), repris par les à-nouveaux ;
--  2. Affectation du résultat : SYSCOHADA inchangée (réserve légale 111, réserves libres 118, dividendes 465, report 121) ;
--     SYCEBNL : réserves statutaires ou contractuelles 112, autres réserves 118, report à nouveau des excédents 121, aucune distribution ;
--  3. Pas d'impôt sur les sociétés calculé pour une entité à but non lucratif (le calcul de l'IS reste celui du système normal).

create or replace function public.result_pending_account_code(p_entity uuid)
returns text language sql stable as $$
  select case e.accounting_system when 'sycebnl' then '128' else '130' end from public.entities e where e.id = p_entity;
$$;

-- À-nouveaux : le résultat de l'exercice précédent est repris au compte « en instance d'affectation » du référentiel.
create or replace function public.generate_opening_balances(p_entity uuid, p_fiscal_year uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_next public.fiscal_years%rowtype; v_lines jsonb; v_result bigint; v_entry uuid; v_1300 uuid;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  select * into v_next from public.fiscal_years where entity_id = p_entity and start_date = v_fy.end_date + 1;
  if v_next.id is null then raise exception 'Créer l''exercice suivant avant de générer les à-nouveaux' using errcode = '23514'; end if;
  if v_next.status <> 'open' then raise exception 'L''exercice suivant n''est plus ouvert' using errcode = '23514'; end if;
  -- Soldes de bilan par compte et tiers (hors comptes de résultat 13x soldés par détermination : on reprend 131/139 en 1300)
  select coalesce(jsonb_agg(jsonb_build_object('account_id', x.account_id, 'third_party_id', x.third_party_id, 'debit', greatest(x.bal, 0), 'credit', greatest(-x.bal, 0), 'label', 'À-nouveaux ' || v_next.label)), '[]'::jsonb)
    into v_lines
    from (select l.account_id, l.third_party_id, sum(l.debit) - sum(l.credit) as bal
            from public.ledger_lines l where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year and l.account_class between 1 and 5 and left(l.account_code, 3) not in ('131', '139')
           group by l.account_id, l.third_party_id having sum(l.debit) - sum(l.credit) <> 0) x;
  -- Résultat de N : solde des comptes 131/139 si l''écriture de détermination est validée, sinon résultat calculé
  select coalesce(sum(l.credit - l.debit), 0) into v_result from public.ledger_lines l where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year and left(l.account_code, 3) in ('131', '139');
  if v_result = 0 then v_result := public.accounting_result(p_entity, p_fiscal_year) - coalesce((select sum(debit - credit) from public.ledger_lines where entity_id = p_entity and fiscal_year_id = p_fiscal_year and left(account_code, 2) = '89'), 0); end if;
  v_1300 := public.account_id_by_code(p_entity, public.result_pending_account_code(p_entity));
  if v_result <> 0 then
    v_lines := v_lines || jsonb_build_object('account_id', v_1300, 'debit', greatest(-v_result, 0), 'credit', greatest(v_result, 0), 'label', 'Résultat ' || v_fy.label || ' en instance d''affectation');
  end if;
  perform set_config('akonta.internal', 'on', true);
  v_entry := public.generated_entry(p_entity, v_next.start_date, 'À-nouveaux ' || v_next.label || (case when v_fy.status = 'closed' then '' else ' (provisoires)' end), 'opening:' || v_next.id, v_lines, 'opening');
  perform set_config('akonta.internal', 'off', true);
  return v_entry;
end $$;

-- Affectation du résultat en N+1 : compte en instance → réserves, report à nouveau (et dividendes pour le système normal).
create or replace function public.allocate_result(p_entity uuid, p_fiscal_year_next uuid, p_date date, p_legal_reserve bigint, p_free_reserve bigint, p_dividends bigint, p_carry_forward bigint)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_total bigint := p_legal_reserve + p_free_reserve + p_dividends + p_carry_forward; v_lines jsonb; v_system text;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture' using errcode = '42501';
  end if;
  if v_total <= 0 then raise exception 'Montant à affecter nul' using errcode = '23514'; end if;
  select accounting_system into v_system from public.entities where id = p_entity;
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

-- L'impôt sur les sociétés ne se calcule pas pour une entité à but non lucratif.
create or replace function public.tax_computations_guard_system()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.entities e where e.id = new.entity_id and e.accounting_system = 'sycebnl') then
    raise exception 'Le calcul de l''impôt sur les sociétés ne s''applique pas à une entité à but non lucratif (SYCEBNL)' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger tax_computations_guard_system before insert on public.tax_computations
  for each row execute function public.tax_computations_guard_system();

grant execute on function public.result_pending_account_code(uuid) to authenticated;
