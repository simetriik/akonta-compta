-- Dotation aux amortissements des immobilisations incorporelles : compte 6812 (décision D-025).
-- Les fonctions d'amortissement et de cession visaient le compte 6811, absent du plan SYSCOHADA révisé comme du plan SYCEBNL :
-- toute immobilisation incorporelle (comptes 21x) était refusée (« Comptes d'amortissement introuvables »). Le compte 6812 existe dans les deux plans.

create or replace function public.generate_depreciation(p_entity uuid, p_fiscal_year uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare a record; c record; v_lines jsonb := '[]'::jsonb; v_fy public.fiscal_years%rowtype; v_entry uuid; v_len int; v_dep uuid; v_exp uuid;
begin
  perform public.require_inventory(p_entity);
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  if v_fy.id is null then raise exception 'Exercice inconnu' using errcode = 'P0002'; end if;
  if v_fy.status = 'closed' then raise exception 'Exercice clôturé' using errcode = '42501'; end if;
  select account_length into v_len from public.entities where id = p_entity;
  delete from public.depreciation_schedules where fiscal_year_id = p_fiscal_year and entity_id = p_entity;
  for a in select * from public.fixed_assets where entity_id = p_entity and is_depreciable and status = 'in_service' and service_date <= v_fy.end_date loop
    select * into c from public.depreciation_charge_for(a.id, p_fiscal_year);
    if c.charge is null or c.charge = 0 then continue; end if;
    -- Comptes : 28x déduit du 2x (2441 → 2844) si non renseigné ; charge 6813 (incorporelles 681 1) par défaut
    v_dep := coalesce(a.depreciation_account_id, public.account_id_by_code(p_entity, '28' || substr((select code from public.accounts where id = a.asset_account_id), 2, 2)));
    v_exp := coalesce(a.expense_account_id, public.account_id_by_code(p_entity, case when (select code from public.accounts where id = a.asset_account_id) like '21%' then '6812' else '6813' end));
    if v_dep is null or v_exp is null then
      raise exception 'Comptes d''amortissement introuvables pour % (renseigner la fiche)', a.code using errcode = '23514';
    end if;
    insert into public.depreciation_schedules (entity_id, asset_id, fiscal_year_id, period_start, period_end, base_amount, rate, charge, cumulated, net_book_value)
    values (p_entity, a.id, p_fiscal_year, greatest(c.period_start, v_fy.start_date), least(c.period_end, v_fy.end_date), c.base_amount, c.rate, c.charge, c.cumulated, c.net_book_value);
    v_lines := v_lines || jsonb_build_object('account_id', v_exp, 'debit', c.charge, 'label', 'Dotation ' || a.code || ' ' || a.designation)
                       || jsonb_build_object('account_id', v_dep, 'credit', c.charge, 'label', 'Amortissement ' || a.code || ' ' || a.designation);
  end loop;
  v_entry := public.generated_entry(p_entity, v_fy.end_date, 'Dotations aux amortissements ' || v_fy.label, 'depreciation:' || p_fiscal_year, v_lines);
  update public.depreciation_schedules set entry_id = v_entry where fiscal_year_id = p_fiscal_year and entity_id = p_entity;
  return v_entry;
end $$;

create or replace function public.dispose_asset(p_asset uuid, p_date date, p_price bigint default 0, p_counterpart_account uuid default null, p_third_party uuid default null, p_scrap boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare a public.fixed_assets%rowtype; v_fy public.fiscal_years%rowtype; v_cum bigint; v_add bigint; v_rate numeric; v_base bigint;
        v_dep uuid; v_exp uuid; v_vc uuid; v_prod uuid; v_cp uuid; v_lines jsonb := '[]'::jsonb; v_entry uuid; v_len int; v_code text;
begin
  select * into a from public.fixed_assets where id = p_asset for update;
  if a.id is null then raise exception 'Immobilisation inconnue' using errcode = 'P0002'; end if;
  perform public.require_inventory(a.entity_id);
  if a.status <> 'in_service' then raise exception 'Immobilisation déjà sortie' using errcode = '23514'; end if;
  select * into v_fy from public.fiscal_years where entity_id = a.entity_id and p_date between start_date and end_date;
  if v_fy.id is null or v_fy.status = 'closed' then raise exception 'Date hors exercice ouvert' using errcode = '23514'; end if;
  select code into v_code from public.accounts where id = a.asset_account_id;
  -- Amortissements cumulés : fin de l''exercice précédent + prorata de l''exercice de cession
  select coalesce(max(cumulated), a.prior_depreciation) into v_cum from public.depreciation_schedules s join public.fiscal_years f on f.id = s.fiscal_year_id
   where s.asset_id = p_asset and f.end_date < v_fy.start_date;
  v_base := a.gross_value - a.salvage_value;
  v_add := 0;
  if a.is_depreciable and v_cum < v_base then
    select coalesce(rate, 12.0 / a.duration_months) into v_rate from public.depreciation_charge_for(p_asset, v_fy.id);
    v_add := least(round(v_base * coalesce(v_rate, 12.0 / a.duration_months) * public.days360(greatest(a.service_date, v_fy.start_date), p_date) / 360.0), v_base - v_cum);
  end if;
  v_dep := coalesce(a.depreciation_account_id, public.account_id_by_code(a.entity_id, '28' || substr(v_code, 2, 2)));
  v_exp := coalesce(a.expense_account_id, public.account_id_by_code(a.entity_id, case when v_code like '21%' then '6812' else '6813' end));
  v_vc := public.account_id_by_code(a.entity_id, '812');     -- valeurs comptables des cessions d''immobilisations corporelles
  v_prod := public.account_id_by_code(a.entity_id, '822');   -- produits des cessions d''immobilisations corporelles
  v_cp := coalesce(p_counterpart_account, public.account_id_by_code(a.entity_id, '485'));
  if v_dep is null or v_vc is null or v_prod is null then raise exception 'Comptes 28x / 812 / 822 introuvables' using errcode = '23514'; end if;
  if v_add > 0 then
    v_lines := v_lines || jsonb_build_object('account_id', v_exp, 'debit', v_add, 'label', 'Dotation complémentaire ' || a.code)
                       || jsonb_build_object('account_id', v_dep, 'credit', v_add, 'label', 'Amortissement complémentaire ' || a.code);
  end if;
  -- Sortie : VCN au débit de 81, cumul au débit de 28, brut au crédit de 2x
  v_lines := v_lines || jsonb_build_object('account_id', v_vc, 'debit', a.gross_value - v_cum - v_add, 'label', 'Valeur comptable nette ' || a.code)
                     || jsonb_build_object('account_id', v_dep, 'debit', v_cum + v_add, 'label', 'Reprise amortissements ' || a.code)
                     || jsonb_build_object('account_id', a.asset_account_id, 'credit', a.gross_value, 'label', 'Sortie ' || a.code);
  if not p_scrap and p_price > 0 then
    v_lines := v_lines || jsonb_build_object('account_id', v_cp, 'third_party_id', p_third_party, 'debit', p_price, 'label', 'Prix de cession ' || a.code)
                       || jsonb_build_object('account_id', v_prod, 'credit', p_price, 'label', 'Produit de cession ' || a.code);
  end if;
  v_entry := public.generated_entry(a.entity_id, p_date, (case when p_scrap then 'Mise au rebut ' else 'Cession ' end) || a.code || ' ' || a.designation, 'disposal:' || p_asset, v_lines);
  update public.fixed_assets set status = case when p_scrap then 'scrapped' else 'disposed' end::public.asset_status, disposal_date = p_date, disposal_price = p_price, disposal_entry_id = v_entry where id = p_asset;
  return v_entry;
end $$;
