-- =============================================================================
-- Akonta — Migration 0012 : travaux d''inventaire (module 8, conception §6, §10.8)
-- Amortissements (linéaire, dégressif en option, prorata temporis, reprise de l''existant,
-- cessions et rebuts), stocks (inventaire intermittent), provisions (créances, risques),
-- régularisations (CAP, PAR, CCA, PCA) avec extourne, écarts de conversion.
-- Toutes les écritures générées arrivent en brouillard, marquées « générée ».
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Utilitaires
-- -----------------------------------------------------------------------------

-- Jours entre deux dates incluses, base 360 (mois de 30 jours) — convention retenue (D-011).
create or replace function public.days360(p_from date, p_to date)
returns integer language sql immutable as $$
  select case when p_to < p_from then 0 else
    (extract(year from p_to) - extract(year from p_from))::int * 360
    + (extract(month from p_to) - extract(month from p_from))::int * 30
    + (least(extract(day from p_to)::int, 30) - least(extract(day from p_from)::int, 30)) + 1 end;
$$;

-- Écriture générée en brouillard (journal OD de l''entité) ; remplace un brouillard existant de même source.
create or replace function public.generated_entry(p_entity uuid, p_date date, p_label text, p_source text, p_lines jsonb, p_journal_type public.journal_type default 'misc')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_cabinet uuid; v_journal uuid; v_old uuid; v_id uuid; l jsonb; v_n int := 0;
begin
  select cabinet_id into v_cabinet from public.entities where id = p_entity;
  select id into v_journal from public.journals where entity_id = p_entity and type = p_journal_type and is_active order by code limit 1;
  if v_journal is null then raise exception 'Aucun journal % actif dans ce dossier', p_journal_type using errcode = '23514'; end if;
  select id into v_old from public.entries where entity_id = p_entity and generated_source = p_source;
  if v_old is not null then
    if (select status from public.entries where id = v_old) = 'validated' then
      raise exception 'L''écriture générée « % » est déjà validée : contre-passez-la avant de régénérer', p_label using errcode = '23514';
    end if;
    delete from public.entries where id = v_old;
  end if;
  if jsonb_array_length(p_lines) = 0 then return null; end if;
  insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, label, is_generated, generated_source, created_by)
  select v_cabinet, p_entity, fy.id, p.id, v_journal, p_date, p_label, true, p_source, auth.uid()
    from public.fiscal_years fy join public.periods p on p.fiscal_year_id = fy.id
   where fy.entity_id = p_entity and p_date between p.start_date and p.end_date
  returning id into v_id;
  if v_id is null then raise exception 'Aucun exercice ne couvre la date %', p_date using errcode = '23514'; end if;
  for l in select * from jsonb_array_elements(p_lines) loop
    if coalesce((l->>'debit')::bigint, 0) = 0 and coalesce((l->>'credit')::bigint, 0) = 0 then continue; end if;
    v_n := v_n + 1;
    insert into public.entry_lines (cabinet_id, entity_id, entry_id, line_no, account_id, third_party_id, label, debit, credit)
    values (v_cabinet, p_entity, v_id, v_n, (l->>'account_id')::uuid, nullif(l->>'third_party_id', '')::uuid, l->>'label', coalesce((l->>'debit')::bigint, 0), coalesce((l->>'credit')::bigint, 0));
  end loop;
  if v_n = 0 then delete from public.entries where id = v_id; return null; end if;
  return v_id;
end $$;

create or replace function public.account_id_by_code(p_entity uuid, p_code text)
returns uuid language sql stable as $$
  select a.id from public.accounts a join public.entities e on e.id = a.entity_id
   where a.entity_id = p_entity and a.code = public.pad_account_code(p_code, e.account_length);
$$;

create or replace function public.require_inventory(p_entity uuid)
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'inventory.prepare') then
    raise exception 'Permission refusée : préparer les travaux d''inventaire' using errcode = '42501';
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- Amortissements
-- -----------------------------------------------------------------------------

-- Plan d''amortissement prévisionnel d''une immobilisation, exercice par exercice (exercices civils).
create or replace function public.depreciation_plan(p_asset uuid)
returns table (year_no int, period_start date, period_end date, base_amount bigint, rate numeric, charge bigint, cumulated bigint, net_book_value bigint)
language plpgsql stable as $$
declare
  a public.fixed_assets%rowtype;
  v_base bigint; v_rate numeric; v_cum bigint; v_year int; v_start date; v_end date; v_charge bigint; v_nbv bigint;
  v_months_left numeric; v_remaining bigint; v_lin_rate numeric; v_first boolean := true; v_fraction numeric; v_declining_rate numeric;
  v_end_date date;
begin
  select * into a from public.fixed_assets where id = p_asset;
  if a.id is null or not a.is_depreciable then return; end if;
  v_base := a.gross_value - a.salvage_value;
  v_lin_rate := 12.0 / a.duration_months;
  v_declining_rate := case when a.method = 'declining' then v_lin_rate * coalesce(a.declining_coefficient, 1.5) else v_lin_rate end;
  v_cum := a.prior_depreciation;
  v_year := 0;
  v_start := a.service_date;
  v_end_date := (a.service_date + (a.duration_months || ' months')::interval - interval '1 day')::date;
  while v_cum < v_base and v_year < 60 loop
    v_year := v_year + 1;
    v_end := least(make_date(extract(year from v_start)::int, 12, 31), v_end_date);
    v_fraction := public.days360(v_start, v_end) / 360.0;
    v_remaining := v_base - v_cum;
    if a.method = 'linear' then
      v_rate := v_lin_rate;
      v_charge := least(round(v_base * v_rate * v_fraction), v_remaining);
    else
      -- Dégressif : taux sur la valeur nette, bascule en linéaire sur la durée restante quand il devient plus favorable
      v_months_left := greatest(public.days360(v_start, v_end_date) / 30.0, 1);
      if v_declining_rate < 12.0 / v_months_left then
        v_rate := 12.0 / v_months_left;
        v_charge := least(round(v_remaining * v_rate * v_fraction), v_remaining);
      else
        v_rate := v_declining_rate;
        v_charge := least(round(v_remaining * v_rate * v_fraction), v_remaining);
      end if;
    end if;
    if v_end >= v_end_date then v_charge := v_remaining; end if;  -- dernier exercice : solde
    v_cum := v_cum + v_charge;
    v_nbv := a.gross_value - v_cum;
    year_no := v_year; period_start := v_start; period_end := v_end; base_amount := v_base; rate := round(v_rate, 6);
    charge := v_charge; cumulated := v_cum; net_book_value := v_nbv;
    return next;
    exit when v_end >= v_end_date;
    v_start := v_end + 1;
  end loop;
end $$;

-- Dotation d''une immobilisation pour un exercice donné (ligne du plan dont la période chevauche l''exercice).
create or replace function public.depreciation_charge_for(p_asset uuid, p_fiscal_year uuid)
returns table (charge bigint, cumulated bigint, net_book_value bigint, rate numeric, base_amount bigint, period_start date, period_end date)
language sql stable as $$
  select p.charge, p.cumulated, p.net_book_value, p.rate, p.base_amount, p.period_start, p.period_end
    from public.depreciation_plan(p_asset) p join public.fiscal_years fy on fy.id = p_fiscal_year
   where p.period_start between fy.start_date and fy.end_date or p.period_end between fy.start_date and fy.end_date
   order by p.period_start limit 1;
$$;

-- Génère le tableau des dotations de l''exercice et l''écriture en brouillard (68x / 28x), une ligne par immobilisation.
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
    v_exp := coalesce(a.expense_account_id, public.account_id_by_code(p_entity, case when (select code from public.accounts where id = a.asset_account_id) like '21%' then '6811' else '6813' end));
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

-- Cession ou mise au rebut : dotation complémentaire jusqu''à la date, sortie de l''actif (81 / 28 / 2x), produit de cession (485 ou trésorerie / 82).
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
  v_exp := coalesce(a.expense_account_id, public.account_id_by_code(a.entity_id, case when v_code like '21%' then '6811' else '6813' end));
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

-- -----------------------------------------------------------------------------
-- Stocks (inventaire intermittent) : variation = stock final - stock initial
-- -----------------------------------------------------------------------------
create or replace function public.generate_stock_variations(p_entity uuid, p_fiscal_year uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare s record; v_fy public.fiscal_years%rowtype; v_lines jsonb := '[]'::jsonb; v_var uuid; v_delta bigint; v_code text; v_entry uuid;
begin
  perform public.require_inventory(p_entity);
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  if v_fy.status = 'closed' then raise exception 'Exercice clôturé' using errcode = '42501'; end if;
  for s in select * from public.inventory_stocks where fiscal_year_id = p_fiscal_year loop
    -- Stock initial = solde du compte de stock à l''ouverture (à-nouveaux)
    update public.inventory_stocks set opening_value = greatest(public.account_balance(s.stock_account_id, v_fy.start_date), 0) where id = s.id returning opening_value into s.opening_value;
    v_delta := s.closing_value - s.opening_value;
    if v_delta = 0 then continue; end if;
    select code into v_code from public.accounts where id = s.stock_account_id;
    -- Augmentation de stock : débit 3x / crédit 603x (ou 73x) ; diminution : inverse
    v_lines := v_lines || jsonb_build_object('account_id', s.stock_account_id, 'debit', greatest(v_delta, 0), 'credit', greatest(-v_delta, 0), 'label', 'Stock final ' || v_code)
                       || jsonb_build_object('account_id', s.variation_account_id, 'debit', greatest(-v_delta, 0), 'credit', greatest(v_delta, 0), 'label', 'Variation de stock ' || v_code);
  end loop;
  v_entry := public.generated_entry(p_entity, v_fy.end_date, 'Variations de stocks ' || v_fy.label, 'stocks:' || p_fiscal_year, v_lines);
  update public.inventory_stocks set entry_id = v_entry where fiscal_year_id = p_fiscal_year;
  return v_entry;
end $$;

-- -----------------------------------------------------------------------------
-- Provisions pour dépréciation des créances (balance âgée) et pour risques
-- -----------------------------------------------------------------------------

-- Propose les provisions clients depuis la balance âgée : taux par tranche (jsonb {"d91_180":0.25,"over_180":0.5}) ou taux par tiers.
create or replace function public.propose_receivable_provisions(p_entity uuid, p_fiscal_year uuid, p_bucket_rates jsonb default '{"d91_180": 0.25, "over_180": 0.5}'::jsonb, p_third_party_rates jsonb default '{}'::jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; r record; v_rate numeric; v_base bigint; v_amount bigint; v_prev bigint; v_n int := 0; v_cabinet uuid; v_491 uuid;
begin
  perform public.require_inventory(p_entity);
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  select cabinet_id into v_cabinet from public.entities where id = p_entity;
  v_491 := public.account_id_by_code(p_entity, '4911');
  delete from public.provisions where fiscal_year_id = p_fiscal_year and kind = 'receivable' and entry_id is null;
  for r in select * from public.aged_balance(p_entity, v_fy.end_date, 'debit') where total > 0 loop
    if p_third_party_rates ? r.third_party_code then
      v_rate := (p_third_party_rates ->> r.third_party_code)::numeric; v_base := r.total;
      v_amount := round(v_base * v_rate);
    else
      v_amount := round(coalesce(r.d91_180, 0) * coalesce((p_bucket_rates ->> 'd91_180')::numeric, 0))
                + round(coalesce(r.over_180, 0) * coalesce((p_bucket_rates ->> 'over_180')::numeric, 0));
      v_base := coalesce(r.d91_180, 0) + coalesce(r.over_180, 0); v_rate := null;
    end if;
    if v_amount <= 0 then continue; end if;
    -- Provision N-1 du même tiers
    select coalesce(sum(p.amount), 0) into v_prev from public.provisions p join public.fiscal_years f on f.id = p.fiscal_year_id
     where p.entity_id = p_entity and p.kind = 'receivable' and p.third_party_id = r.third_party_id and f.end_date < v_fy.start_date and f.end_date = (select max(end_date) from public.fiscal_years where entity_id = p_entity and end_date < v_fy.start_date);
    insert into public.provisions (cabinet_id, entity_id, fiscal_year_id, kind, third_party_id, provision_account_id, expense_account_id, reversal_account_id, base_amount, rate, amount, previous_amount, note)
    values (v_cabinet, p_entity, p_fiscal_year, 'receivable', r.third_party_id, v_491, public.account_id_by_code(p_entity, '6594'), public.account_id_by_code(p_entity, '7594'),
            v_base, v_rate, v_amount, v_prev, 'Proposée depuis la balance âgée au ' || v_fy.end_date);
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- Écriture des dotations / reprises : différence entre la provision de l''exercice et celle de N-1.
create or replace function public.generate_provision_entries(p_entity uuid, p_fiscal_year uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare p record; v_fy public.fiscal_years%rowtype; v_lines jsonb := '[]'::jsonb; v_delta bigint; v_entry uuid;
begin
  perform public.require_inventory(p_entity);
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  if v_fy.status = 'closed' then raise exception 'Exercice clôturé' using errcode = '42501'; end if;
  for p in select * from public.provisions where fiscal_year_id = p_fiscal_year loop
    v_delta := p.amount - p.previous_amount;
    if v_delta > 0 then
      v_lines := v_lines || jsonb_build_object('account_id', p.expense_account_id, 'debit', v_delta, 'label', 'Dotation provision ' || p.kind)
                         || jsonb_build_object('account_id', p.provision_account_id, 'third_party_id', p.third_party_id, 'credit', v_delta, 'label', 'Provision ' || p.kind);
    elsif v_delta < 0 then
      v_lines := v_lines || jsonb_build_object('account_id', p.provision_account_id, 'third_party_id', p.third_party_id, 'debit', -v_delta, 'label', 'Reprise provision ' || p.kind)
                         || jsonb_build_object('account_id', p.reversal_account_id, 'credit', -v_delta, 'label', 'Reprise provision ' || p.kind);
    end if;
  end loop;
  v_entry := public.generated_entry(p_entity, v_fy.end_date, 'Provisions ' || v_fy.label, 'provisions:' || p_fiscal_year, v_lines);
  update public.provisions set entry_id = v_entry where fiscal_year_id = p_fiscal_year;
  return v_entry;
end $$;

-- -----------------------------------------------------------------------------
-- Régularisations : CAP, PAR, CCA, PCA — prorata au jour (base 360), écriture au 31/12, extourne au 1er janvier
-- -----------------------------------------------------------------------------

-- Part d''une charge ou d''un produit couvrant [period_from, period_to] qui concerne l''exercice (CCA/PCA : part hors exercice).
create or replace function public.accrual_amount(p_kind public.accrual_kind, p_total bigint, p_from date, p_to date, p_fy_start date, p_fy_end date)
returns bigint language plpgsql immutable as $$
declare v_total_days int := public.days360(p_from, p_to); v_in int;
begin
  if v_total_days <= 0 then return 0; end if;
  v_in := public.days360(greatest(p_from, p_fy_start), least(p_to, p_fy_end));
  if v_in < 0 then v_in := 0; end if;
  return case p_kind
    when 'cap' then round(p_total * v_in / v_total_days::numeric)      -- charge de l''exercice non encore facturée
    when 'par' then round(p_total * v_in / v_total_days::numeric)      -- produit de l''exercice non encore facturé
    when 'cca' then round(p_total * (v_total_days - v_in) / v_total_days::numeric)   -- charge facturée, part hors exercice
    when 'pca' then round(p_total * (v_total_days - v_in) / v_total_days::numeric)   -- produit facturé, part hors exercice
  end;
end $$;

create or replace function public.generate_accruals(p_entity uuid, p_fiscal_year uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare a record; v_fy public.fiscal_years%rowtype; v_lines jsonb := '[]'::jsonb; v_amt bigint; v_entry uuid;
begin
  perform public.require_inventory(p_entity);
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  if v_fy.status = 'closed' then raise exception 'Exercice clôturé' using errcode = '42501'; end if;
  for a in select * from public.accruals where fiscal_year_id = p_fiscal_year loop
    v_amt := public.accrual_amount(a.kind, a.total_amount, a.period_from, a.period_to, v_fy.start_date, v_fy.end_date);
    update public.accruals set amount = v_amt where id = a.id;
    if v_amt = 0 then continue; end if;
    -- (jsonb_build_array : deux objets concaténés par || fusionneraient en un seul)
    v_lines := v_lines || case a.kind
      when 'cap' then jsonb_build_array(jsonb_build_object('account_id', a.account_id, 'debit', v_amt, 'label', a.description), jsonb_build_object('account_id', a.counterpart_account_id, 'third_party_id', a.third_party_id, 'credit', v_amt, 'label', 'Charge à payer : ' || a.description))
      when 'par' then jsonb_build_array(jsonb_build_object('account_id', a.counterpart_account_id, 'third_party_id', a.third_party_id, 'debit', v_amt, 'label', 'Produit à recevoir : ' || a.description), jsonb_build_object('account_id', a.account_id, 'credit', v_amt, 'label', a.description))
      when 'cca' then jsonb_build_array(jsonb_build_object('account_id', a.counterpart_account_id, 'debit', v_amt, 'label', 'Charge constatée d''avance : ' || a.description), jsonb_build_object('account_id', a.account_id, 'credit', v_amt, 'label', a.description))
      when 'pca' then jsonb_build_array(jsonb_build_object('account_id', a.account_id, 'debit', v_amt, 'label', a.description), jsonb_build_object('account_id', a.counterpart_account_id, 'credit', v_amt, 'label', 'Produit constaté d''avance : ' || a.description))
    end;
  end loop;
  v_entry := public.generated_entry(p_entity, v_fy.end_date, 'Régularisations ' || v_fy.label, 'accruals:' || p_fiscal_year, v_lines);
  update public.accruals set entry_id = v_entry where fiscal_year_id = p_fiscal_year;
  return v_entry;
end $$;

-- Extournes au 1er janvier N+1 des régularisations et des écarts de conversion de N (exercice N+1 requis).
create or replace function public.generate_reversals(p_entity uuid, p_fiscal_year uuid)
returns uuid[] language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_next public.fiscal_years%rowtype; v_src uuid; v_lines jsonb; v_entry uuid; v_out uuid[] := '{}'; v_label text; v_tag text;
begin
  perform public.require_inventory(p_entity);
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  select * into v_next from public.fiscal_years where entity_id = p_entity and start_date = v_fy.end_date + 1;
  if v_next.id is null then raise exception 'L''exercice suivant doit exister pour extourner' using errcode = '23514'; end if;
  foreach v_tag in array array['accruals', 'fx'] loop
    select id into v_src from public.entries where entity_id = p_entity and generated_source = v_tag || ':' || p_fiscal_year and status = 'validated';
    if v_src is null then continue; end if;
    select coalesce(jsonb_agg(jsonb_build_object('account_id', l.account_id, 'third_party_id', l.third_party_id, 'debit', l.credit, 'credit', l.debit, 'label', 'Extourne : ' || coalesce(l.label, '')) order by l.line_no), '[]'::jsonb)
      into v_lines from public.entry_lines l where l.entry_id = v_src;
    v_label := case v_tag when 'accruals' then 'Extourne des régularisations ' else 'Extourne des écarts de conversion ' end || v_fy.label;
    v_entry := public.generated_entry(p_entity, v_next.start_date, v_label, v_tag || '_reversal:' || p_fiscal_year, v_lines);
    if v_tag = 'accruals' then update public.accruals set reversal_entry_id = v_entry where fiscal_year_id = p_fiscal_year;
    else update public.fx_revaluations set reversal_entry_id = v_entry where fiscal_year_id = p_fiscal_year; end if;
    v_out := v_out || v_entry;
  end loop;
  return v_out;
end $$;

-- -----------------------------------------------------------------------------
-- Écarts de conversion : lignes en devises non lettrées, cours de clôture, 478 / 479 et provision pour perte de change
-- -----------------------------------------------------------------------------
create or replace function public.generate_fx_revaluation(p_entity uuid, p_fiscal_year uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; l record; v_rate numeric; v_booked bigint; v_new bigint; v_diff bigint; v_cabinet uuid;
        v_lines jsonb := '[]'::jsonb; v_loss bigint := 0; v_478 uuid; v_479 uuid; v_6591 uuid; v_194 uuid; v_entry uuid;
begin
  perform public.require_inventory(p_entity);
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  if v_fy.status = 'closed' then raise exception 'Exercice clôturé' using errcode = '42501'; end if;
  select cabinet_id into v_cabinet from public.entities where id = p_entity;
  v_478 := public.account_id_by_code(p_entity, '478'); v_479 := public.account_id_by_code(p_entity, '479');
  v_6591 := public.account_id_by_code(p_entity, '6591'); v_194 := public.account_id_by_code(p_entity, '194');
  delete from public.fx_revaluations where fiscal_year_id = p_fiscal_year;
  for l in select ll.*, el.amount_currency, el.exchange_rate, el.currency_code as cur
             from public.ledger_lines ll join public.entry_lines el on el.id = ll.line_id
            where ll.entity_id = p_entity and ll.entry_date <= v_fy.end_date and el.currency_code <> 'XOF' and ll.letter_code is null and ll.account_class = 4 loop
    select rate into v_rate from public.closing_rates where cabinet_id = v_cabinet and currency_code = l.cur and as_of <= v_fy.end_date order by as_of desc limit 1;
    if v_rate is null then
      if l.cur = 'EUR' then v_rate := 655.957; else raise exception 'Cours de clôture manquant pour %', l.cur using errcode = '23514'; end if;
    end if;
    v_booked := l.debit - l.credit;
    v_new := round(l.amount_currency * v_rate) * sign(v_booked);
    v_diff := v_new - v_booked;     -- > 0 : gain latent (créance qui vaut plus / dette qui vaut moins), < 0 : perte latente
    if v_diff = 0 then continue; end if;
    insert into public.fx_revaluations (cabinet_id, entity_id, fiscal_year_id, entry_line_id, currency_code, amount_currency, booked_rate, closing_rate, difference)
    values (v_cabinet, p_entity, p_fiscal_year, l.line_id, l.cur, l.amount_currency, l.exchange_rate, v_rate, v_diff);
    if v_diff > 0 then
      v_lines := v_lines || jsonb_build_object('account_id', l.account_id, 'third_party_id', l.third_party_id, 'debit', v_diff, 'label', 'Réévaluation ' || l.cur)
                         || jsonb_build_object('account_id', v_479, 'credit', v_diff, 'label', 'Écart de conversion passif ' || l.cur);
    else
      v_lines := v_lines || jsonb_build_object('account_id', v_478, 'debit', -v_diff, 'label', 'Écart de conversion actif ' || l.cur)
                         || jsonb_build_object('account_id', l.account_id, 'third_party_id', l.third_party_id, 'credit', -v_diff, 'label', 'Réévaluation ' || l.cur);
      v_loss := v_loss - v_diff;
    end if;
  end loop;
  if v_loss > 0 and v_6591 is not null and v_194 is not null then
    v_lines := v_lines || jsonb_build_object('account_id', v_6591, 'debit', v_loss, 'label', 'Dotation provision pour pertes de change')
                       || jsonb_build_object('account_id', v_194, 'credit', v_loss, 'label', 'Provision pour pertes de change');
  end if;
  v_entry := public.generated_entry(p_entity, v_fy.end_date, 'Écarts de conversion ' || v_fy.label, 'fx:' || p_fiscal_year, v_lines);
  update public.fx_revaluations set entry_id = v_entry where fiscal_year_id = p_fiscal_year;
  return v_entry;
end $$;

grant execute on function public.days360(date, date), public.depreciation_plan(uuid), public.depreciation_charge_for(uuid, uuid), public.generate_depreciation(uuid, uuid),
  public.dispose_asset(uuid, date, bigint, uuid, uuid, boolean), public.generate_stock_variations(uuid, uuid), public.propose_receivable_provisions(uuid, uuid, jsonb, jsonb),
  public.generate_provision_entries(uuid, uuid), public.accrual_amount(public.accrual_kind, bigint, date, date, date, date), public.generate_accruals(uuid, uuid),
  public.generate_reversals(uuid, uuid), public.generate_fx_revaluation(uuid, uuid), public.account_id_by_code(uuid, text) to authenticated;
revoke execute on function public.generated_entry(uuid, date, text, text, jsonb, public.journal_type) from public, anon, authenticated;
