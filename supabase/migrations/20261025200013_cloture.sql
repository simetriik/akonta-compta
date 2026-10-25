-- =============================================================================
-- Akonta — Migration 0013 : clôture (module 9, conception §7, §10.9)
-- Contrôles de clôture (bloquants / alertes levables), tableau de passage et IS
-- (règles paramétrables, minimum d''impôt, acomptes), moteur comptes → postes des
-- états financiers (correspondance versionnée), clôture provisoire / réouverture,
-- arrêté définitif (archive avec empreintes), à-nouveaux N+1 et affectation du résultat.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Règles fiscales livrées (tableau de passage) et correspondance SYSCOHADA des états
-- -----------------------------------------------------------------------------
insert into public.tax_rules (cabinet_id, version, code, label, kind, account_pattern, sort_order) values
  (null, '2026', 'IS_COMPTABILISE',   'Impôt sur le résultat comptabilisé (89)',                 'add_back',  '^89', 10),
  (null, '2026', 'AMENDES',           'Amendes et pénalités non déductibles (6471-6478)',        'add_back',  '^647', 20),
  (null, '2026', 'DONS_EXCEDENTAIRES','Dons et libéralités au-delà du plafond',                  'add_back',  null, 30),
  (null, '2026', 'PROVISIONS_NON_DED','Provisions non déductibles',                              'add_back',  null, 40),
  (null, '2026', 'CHARGES_SOMPTUAIRES','Charges somptuaires et dépenses non justifiées',         'add_back',  null, 50),
  (null, '2026', 'AMORT_EXCEDENTAIRES','Amortissements excédentaires (véhicules de tourisme)',   'add_back',  null, 60),
  (null, '2026', 'PV_EXONEREES',      'Plus-values exonérées ou en sursis d''imposition',        'deduction', null, 70),
  (null, '2026', 'DIVIDENDES_RECUS',  'Produits de participations déjà imposés',                 'deduction', '^772', 80),
  (null, '2026', 'REPRISES_NON_IMP',  'Reprises de provisions antérieurement réintégrées',       'deduction', null, 90),
  (null, '2026', 'DEFICITS_ANT',      'Déficits antérieurs reportables',                         'deduction', null, 100);

-- Correspondance SYSCOHADA révisé (version SYSCOHADA-2017) : postes du bilan et du compte de résultat (systéme normal).
insert into public.statement_mappings (cabinet_id, version, statement, post_code, post_label, account_from, account_to, balance_side, sign, column_role, sort_order) values
  -- ACTIF
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AE', 'Frais de développement et de prospection', '211', '212', 'any', 1, 'gross', 10),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AE', 'Frais de développement et de prospection', '2811', '2812', 'any', -1, 'depreciation', 10),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AF', 'Brevets, licences, logiciels et droits similaires', '213', '214', 'any', 1, 'gross', 20),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AF', 'Brevets, licences, logiciels et droits similaires', '2813', '2814', 'any', -1, 'depreciation', 20),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AG', 'Fonds commercial et droit au bail', '215', '216', 'any', 1, 'gross', 30),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AG', 'Fonds commercial et droit au bail', '2815', '2816', 'any', -1, 'depreciation', 30),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AH', 'Autres immobilisations incorporelles', '217', '219', 'any', 1, 'gross', 40),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AH', 'Autres immobilisations incorporelles', '2817', '2819', 'any', -1, 'depreciation', 40),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AJ', 'Terrains', '22', '22', 'any', 1, 'gross', 50),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AJ', 'Terrains', '282', '282', 'any', -1, 'depreciation', 50),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AK', 'Bâtiments', '231', '233', 'any', 1, 'gross', 60),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AK', 'Bâtiments', '2831', '2833', 'any', -1, 'depreciation', 60),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AL', 'Aménagements, agencements et installations', '234', '239', 'any', 1, 'gross', 70),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AL', 'Aménagements, agencements et installations', '2834', '2839', 'any', -1, 'depreciation', 70),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AM', 'Matériel, mobilier et actifs biologiques', '24', '24', 'any', 1, 'gross', 80),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AM', 'Matériel, mobilier et actifs biologiques', '284', '284', 'any', -1, 'depreciation', 80),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AN', 'Matériel de transport', '245', '245', 'any', 1, 'gross', 90),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AN', 'Matériel de transport', '2845', '2845', 'any', -1, 'depreciation', 90),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AP', 'Avances et acomptes versés sur immobilisations', '25', '25', 'any', 1, 'gross', 100),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AR', 'Titres de participation', '26', '26', 'any', 1, 'gross', 110),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AR', 'Titres de participation', '296', '296', 'any', -1, 'depreciation', 110),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AS', 'Autres immobilisations financières', '27', '27', 'any', 1, 'gross', 120),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'AS', 'Autres immobilisations financières', '297', '297', 'any', -1, 'depreciation', 120),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BA', 'Actif circulant HAO', '485', '488', 'debit', 1, 'gross', 130),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BB', 'Stocks et encours', '31', '38', 'any', 1, 'gross', 140),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BB', 'Stocks et encours', '39', '39', 'any', -1, 'depreciation', 140),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BH', 'Fournisseurs avances versées', '409', '409', 'debit', 1, 'gross', 150),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BI', 'Clients', '411', '418', 'debit', 1, 'gross', 160),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BI', 'Clients', '491', '491', 'any', -1, 'depreciation', 160),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BJ', 'Autres créances', '42', '47', 'debit', 1, 'gross', 170),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BJ', 'Autres créances', '492', '498', 'any', -1, 'depreciation', 170),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BQ', 'Titres de placement', '50', '50', 'any', 1, 'gross', 180),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BQ', 'Titres de placement', '590', '590', 'any', -1, 'depreciation', 180),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BR', 'Valeurs à encaisser', '51', '51', 'any', 1, 'gross', 190),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BS', 'Banques, chèques postaux, caisse et assimilés', '52', '58', 'debit', 1, 'gross', 200),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BS', 'Banques, chèques postaux, caisse et assimilés', '591', '594', 'any', -1, 'depreciation', 200),
  (null, 'SYSCOHADA-2017', 'balance_sheet_assets', 'BU', 'Écart de conversion-Actif', '478', '478', 'any', 1, 'gross', 210),
  -- PASSIF
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'CA', 'Capital', '101', '104', 'any', 1, 'amount', 10),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'CB', 'Apporteurs capital non appelé', '109', '109', 'any', 1, 'amount', 20),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'CD', 'Primes liées au capital social', '105', '105', 'any', 1, 'amount', 30),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'CE', 'Écarts de réévaluation', '106', '106', 'any', 1, 'amount', 40),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'CF', 'Réserves indisponibles', '111', '113', 'any', 1, 'amount', 50),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'CG', 'Réserves libres', '118', '118', 'any', 1, 'amount', 60),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'CH', 'Report à nouveau', '12', '12', 'any', 1, 'amount', 70),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'CJ', 'Résultat net de l''exercice', '13', '13', 'any', 1, 'amount', 80),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'CL', 'Subventions d''investissement', '14', '14', 'any', 1, 'amount', 90),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'CM', 'Provisions réglementées', '15', '15', 'any', 1, 'amount', 100),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DA', 'Emprunts et dettes financières diverses', '16', '18', 'any', 1, 'amount', 110),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DC', 'Provisions pour risques et charges', '19', '19', 'any', 1, 'amount', 120),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DH', 'Dettes circulantes HAO', '481', '484', 'credit', 1, 'amount', 130),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DI', 'Clients, avances reçues', '419', '419', 'credit', 1, 'amount', 140),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DJ', 'Fournisseurs d''exploitation', '401', '408', 'credit', 1, 'amount', 150),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DK', 'Dettes fiscales et sociales', '42', '44', 'credit', 1, 'amount', 160),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DM', 'Autres dettes', '45', '47', 'credit', 1, 'amount', 170),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DN', 'Provisions pour risques à court terme', '499', '499', 'any', 1, 'amount', 180),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DR', 'Banques, crédits de trésorerie et d''escompte', '56', '56', 'credit', 1, 'amount', 190),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DQ', 'Banques, découverts', '52', '55', 'credit', 1, 'amount', 195),
  (null, 'SYSCOHADA-2017', 'balance_sheet_liabilities', 'DV', 'Écart de conversion-Passif', '479', '479', 'any', 1, 'amount', 200),
  -- COMPTE DE RÉSULTAT (signe : produits +, charges -)
  (null, 'SYSCOHADA-2017', 'income_statement', 'TA', 'Ventes de marchandises', '701', '701', 'any', 1, 'amount', 10),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RA', 'Achats de marchandises', '601', '601', 'any', -1, 'amount', 20),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RB', 'Variation de stocks de marchandises', '6031', '6031', 'any', -1, 'amount', 30),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TB', 'Ventes de produits fabriqués', '702', '704', 'any', 1, 'amount', 40),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TC', 'Travaux, services vendus', '705', '706', 'any', 1, 'amount', 50),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TD', 'Produits accessoires', '707', '707', 'any', 1, 'amount', 60),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TE', 'Production stockée (ou déstockage)', '73', '73', 'any', 1, 'amount', 70),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TF', 'Production immobilisée', '72', '72', 'any', 1, 'amount', 80),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TG', 'Subventions d''exploitation', '71', '71', 'any', 1, 'amount', 90),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TH', 'Autres produits', '75', '75', 'any', 1, 'amount', 100),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TI', 'Transferts de charges d''exploitation', '781', '781', 'any', 1, 'amount', 110),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RC', 'Achats de matières premières et fournitures liées', '602', '602', 'any', -1, 'amount', 120),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RD', 'Variation de stocks de matières premières', '6032', '6032', 'any', -1, 'amount', 130),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RE', 'Autres achats', '604', '608', 'any', -1, 'amount', 140),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RF', 'Variation de stocks d''autres approvisionnements', '6033', '6039', 'any', -1, 'amount', 150),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RG', 'Transports', '61', '61', 'any', -1, 'amount', 160),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RH', 'Services extérieurs', '62', '63', 'any', -1, 'amount', 170),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RI', 'Impôts et taxes', '64', '64', 'any', -1, 'amount', 180),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RJ', 'Autres charges', '65', '65', 'any', -1, 'amount', 190),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RK', 'Charges de personnel', '66', '66', 'any', -1, 'amount', 200),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TJ', 'Reprises d''amortissements, provisions et dépréciations', '791', '799', 'any', 1, 'amount', 210),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RL', 'Dotations aux amortissements, provisions et dépréciations', '68', '69', 'any', -1, 'amount', 220),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TK', 'Revenus financiers et assimilés', '77', '77', 'any', 1, 'amount', 230),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TL', 'Reprises de provisions et dépréciations financières', '797', '797', 'any', 1, 'amount', 240),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TM', 'Transferts de charges financières', '787', '787', 'any', 1, 'amount', 250),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RM', 'Frais financiers et charges assimilées', '67', '67', 'any', -1, 'amount', 260),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RN', 'Dotations aux provisions et dépréciations financières', '697', '697', 'any', -1, 'amount', 270),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TN', 'Produits des cessions d''immobilisations', '82', '82', 'any', 1, 'amount', 280),
  (null, 'SYSCOHADA-2017', 'income_statement', 'TO', 'Autres produits HAO', '84', '88', 'any', 1, 'amount', 290),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RO', 'Valeurs comptables des cessions d''immobilisations', '81', '81', 'any', -1, 'amount', 300),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RP', 'Autres charges HAO', '83', '83', 'any', -1, 'amount', 310),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RP', 'Autres charges HAO', '85', '85', 'any', -1, 'amount', 310),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RQ', 'Participation des travailleurs', '87', '87', 'any', -1, 'amount', 320),
  (null, 'SYSCOHADA-2017', 'income_statement', 'RS', 'Impôts sur le résultat', '89', '89', 'any', -1, 'amount', 330);

-- -----------------------------------------------------------------------------
-- Contrôles de clôture (§7) : bloquants et alertes levables
-- -----------------------------------------------------------------------------
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
  delete from _checks;
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

-- Lever une alerte (chef de mission / associé) avec commentaire obligatoire ; un contrôle bloquant ne se lève pas.
create or replace function public.waive_closing_check(p_fiscal_year uuid, p_code text, p_comment text)
returns void language plpgsql security definer set search_path = public as $$
declare c public.closing_checks%rowtype;
begin
  select * into c from public.closing_checks where fiscal_year_id = p_fiscal_year and code = p_code for update;
  if c.id is null then raise exception 'Contrôle inconnu' using errcode = 'P0002'; end if;
  if auth.uid() is not null and not public.has_permission(c.entity_id, 'closing.override_alerts') then
    raise exception 'Permission refusée : lever les alertes de clôture' using errcode = '42501';
  end if;
  if c.severity = 'blocking' then raise exception 'Un contrôle bloquant ne se lève pas' using errcode = '23514'; end if;
  if coalesce(trim(p_comment), '') = '' then raise exception 'Commentaire obligatoire' using errcode = '23514'; end if;
  update public.closing_checks set status = 'waived', waived_by = auth.uid(), waived_at = now(), waive_comment = p_comment where id = c.id;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (c.cabinet_id, auth.uid(), 'waive_check', 'closing_checks', c.id::text, c.entity_id, jsonb_build_object('code', p_code, 'comment', p_comment));
end $$;

-- -----------------------------------------------------------------------------
-- Résultat comptable, tableau de passage et IS
-- -----------------------------------------------------------------------------
create or replace function public.accounting_result(p_entity uuid, p_fiscal_year uuid, p_as_of date default null)
returns bigint language sql stable as $$
  -- produits (classe 7 + 82/84/86/88) - charges (classe 6 + 81/83/85/87) ; 89 exclu (impôt)
  select coalesce(sum(case when l.account_class = 7 or left(l.account_code, 2) in ('82', '84', '86', '88') then l.credit - l.debit
                           when l.account_class = 6 or left(l.account_code, 2) in ('81', '83', '85', '87') then -(l.debit - l.credit) else 0 end), 0)::bigint
    from public.ledger_lines l join public.fiscal_years fy on fy.id = p_fiscal_year
   where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year and l.entry_date <= coalesce(p_as_of, fy.end_date);
$$;

-- Propose le tableau de passage : montants des règles à motif de compte, les autres à zéro (à saisir).
create or replace function public.propose_tax_adjustments(p_entity uuid, p_fiscal_year uuid, p_version text default '2026')
returns jsonb language sql stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('code', r.code, 'label', r.label, 'kind', r.kind,
           'amount', coalesce((select abs(sum(l.debit - l.credit)) from public.ledger_lines l where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year and l.account_code ~ r.account_pattern), 0))
         order by r.sort_order), '[]'::jsonb)
    from public.tax_rules r
   where r.version = p_version and (r.cabinet_id is null or r.cabinet_id = (select cabinet_id from public.entities where id = p_entity))
     and current_date >= r.valid_from and (r.valid_to is null or current_date <= r.valid_to);
$$;

-- Calcule l''IS : résultat fiscal = résultat comptable + réintégrations - déductions ; IS = max(taux × RF, minimum sur CA, plancher) ;
-- solde = IS - acomptes (4492). Écriture d''IS (891 / 441) en brouillard.
create or replace function public.compute_income_tax(p_entity uuid, p_fiscal_year uuid, p_adjustments jsonb, p_rules_version text default '2026', p_minimum_floor bigint default 250000)
returns uuid language plpgsql security definer set search_path = public as $$
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
end $$;

-- -----------------------------------------------------------------------------
-- États financiers : moteur comptes → postes
-- -----------------------------------------------------------------------------

-- Solde de chaque compte à la clôture (débit - crédit), exercice donné.
create or replace function public.closing_balances(p_entity uuid, p_fiscal_year uuid)
returns table (account_code text, balance bigint)
language sql stable as $$
  select l.account_code, (sum(l.debit) - sum(l.credit))::bigint from public.ledger_lines l
   where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year group by l.account_code having sum(l.debit) - sum(l.credit) <> 0;
$$;

-- Postes d''un état : somme des soldes des comptes dont le préfixe est dans [account_from, account_to] (préfixes), filtrés par sens.
create or replace function public.statement_posts(p_entity uuid, p_fiscal_year uuid, p_statement public.statement_kind, p_version text default 'SYSCOHADA-2017')
returns table (post_code text, post_label text, column_role text, amount bigint, sort_order smallint)
language sql stable as $$
  with bal as (select * from public.closing_balances(p_entity, p_fiscal_year)),
  maps as (
    select m.* from public.statement_mappings m
     where m.version = p_version and m.statement = p_statement
       and (m.cabinet_id is null or m.cabinet_id = (select cabinet_id from public.entities where id = p_entity))
  ),
  matched as (
    select m.post_code, m.post_label, m.column_role, m.sort_order,
           -- somme des soldes (débit - crédit) des comptes dont le préfixe est dans la plage, filtrés par sens
           sum(case when (m.balance_side = 'debit' and b.balance < 0) or (m.balance_side = 'credit' and b.balance > 0) then 0 else b.balance end) as amt
      from maps m
      join bal b on left(b.account_code, length(m.account_from)) >= m.account_from and left(b.account_code, length(m.account_to)) <= m.account_to
     group by m.post_code, m.post_label, m.column_role, m.sort_order
  )
  select post_code, post_label, column_role,
         -- Actif : brut positif, amortissements en positif ; passif : solde créditeur positif ; résultat : produits positifs, charges négatives
         case p_statement
           when 'balance_sheet_assets' then case when column_role = 'depreciation' then abs(amt) else amt end
           else -amt end::bigint,
         sort_order
    from matched
   order by sort_order, column_role;
$$;

-- Génère et enregistre les états (bilan actif/passif, compte de résultat) avec contrôles de cohérence ; N-1 inclus si l''exercice précédent existe.
create or replace function public.generate_financial_statements(p_entity uuid, p_fiscal_year uuid, p_version text default 'SYSCOHADA-2017')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_prev uuid; v_cabinet uuid; v_data jsonb; v_checks jsonb := '[]'::jsonb; v_id uuid;
        v_assets_net bigint; v_liab bigint; v_result_cr bigint; v_result_bs bigint; v_acc bigint;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'statements.generate') then
    raise exception 'Permission refusée : générer les états financiers' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  select cabinet_id into v_cabinet from public.entities where id = p_entity;
  select id into v_prev from public.fiscal_years where entity_id = p_entity and end_date = v_fy.start_date - 1;
  v_data := jsonb_build_object(
    'assets', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order, p.column_role), '[]'::jsonb) from public.statement_posts(p_entity, p_fiscal_year, 'balance_sheet_assets', p_version) p),
    'liabilities', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order), '[]'::jsonb) from public.statement_posts(p_entity, p_fiscal_year, 'balance_sheet_liabilities', p_version) p),
    'income', (select coalesce(jsonb_agg(to_jsonb(p) order by p.sort_order), '[]'::jsonb) from public.statement_posts(p_entity, p_fiscal_year, 'income_statement', p_version) p),
    'previous', case when v_prev is null then null else jsonb_build_object(
        'assets', (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.statement_posts(p_entity, v_prev, 'balance_sheet_assets', p_version) p),
        'liabilities', (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.statement_posts(p_entity, v_prev, 'balance_sheet_liabilities', p_version) p),
        'income', (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.statement_posts(p_entity, v_prev, 'income_statement', p_version) p)) end);
  -- Contrôles : total actif net = total passif (+ résultat non encore affecté) ; résultat du compte de résultat = résultat comptable - IS
  select coalesce(sum(case when column_role = 'depreciation' then -amount else amount end), 0) into v_assets_net from public.statement_posts(p_entity, p_fiscal_year, 'balance_sheet_assets', p_version);
  select coalesce(sum(amount), 0) into v_liab from public.statement_posts(p_entity, p_fiscal_year, 'balance_sheet_liabilities', p_version);
  select coalesce(sum(amount), 0) into v_result_cr from public.statement_posts(p_entity, p_fiscal_year, 'income_statement', p_version);
  -- Le résultat de l''exercice n''est au bilan (13) qu''après l''écriture de détermination ; sinon il équilibre le passif
  v_result_bs := v_assets_net - v_liab;
  v_checks := v_checks || jsonb_build_object('code', 'balance_sheet_equilibrium', 'label', 'Actif net = passif + résultat du compte de résultat',
                 'passed', v_result_bs = v_result_cr, 'assets', v_assets_net, 'liabilities', v_liab, 'result_balance_sheet', v_result_bs, 'result_income', v_result_cr);
  v_checks := v_checks || jsonb_build_object('code', 'income_vs_ledger', 'label', 'Résultat du compte de résultat = résultat comptable après impôt du grand livre',
                 'passed', v_result_cr = public.accounting_result(p_entity, p_fiscal_year) - coalesce((select sum(debit - credit) from public.ledger_lines where entity_id = p_entity and fiscal_year_id = p_fiscal_year and left(account_code, 2) = '89'), 0));
  insert into public.financial_statements (cabinet_id, entity_id, fiscal_year_id, mapping_version, generated_by, data, checks)
  values (v_cabinet, p_entity, p_fiscal_year, p_version, auth.uid(), v_data, v_checks) returning id into v_id;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_cabinet, auth.uid(), 'statements', 'financial_statements', v_id::text, p_entity, jsonb_build_object('fiscal_year', v_fy.label, 'checks', v_checks));
  return v_id;
end $$;

-- -----------------------------------------------------------------------------
-- Clôture provisoire, réouverture, arrêté définitif, à-nouveaux, affectation du résultat
-- -----------------------------------------------------------------------------

-- Écriture de détermination du résultat : solde des comptes 6/7/8 vers 131 (bénéfice) ou 139 (perte), en brouillard.
create or replace function public.generate_result_entry(p_entity uuid, p_fiscal_year uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_lines jsonb; v_result bigint; v_acc uuid;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity;
  select coalesce(jsonb_agg(jsonb_build_object('account_id', a.id, 'debit', greatest(-b.balance, 0), 'credit', greatest(b.balance, 0), 'label', 'Solde pour détermination du résultat')), '[]'::jsonb)
    into v_lines
    from public.closing_balances(p_entity, p_fiscal_year) b join public.accounts a on a.entity_id = p_entity and a.code = b.account_code
   where left(b.account_code, 1) in ('6', '7', '8');
  select coalesce(sum(-b.balance), 0) into v_result from public.closing_balances(p_entity, p_fiscal_year) b where left(b.account_code, 1) in ('6', '7', '8');
  v_acc := public.account_id_by_code(p_entity, case when v_result >= 0 then '131' else '139' end);
  v_lines := v_lines || jsonb_build_object('account_id', v_acc, 'debit', greatest(-v_result, 0), 'credit', greatest(v_result, 0), 'label', case when v_result >= 0 then 'Bénéfice de l''exercice' else 'Perte de l''exercice' end);
  return public.generated_entry(p_entity, v_fy.end_date, 'Détermination du résultat ' || v_fy.label, 'result:' || p_fiscal_year, v_lines);
end $$;

create or replace function public.close_provisional(p_entity uuid, p_fiscal_year uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_blocking int;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture provisoire' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity for update;
  if v_fy.status <> 'open' then raise exception 'L''exercice n''est pas ouvert' using errcode = '23514'; end if;
  perform public.run_closing_checks(p_entity, p_fiscal_year);
  select count(*) into v_blocking from public.closing_checks where fiscal_year_id = p_fiscal_year and status = 'failed' and severity = 'blocking';
  if v_blocking > 0 then raise exception '% contrôle(s) bloquant(s) en échec', v_blocking using errcode = '23514'; end if;
  if exists (select 1 from public.closing_checks where fiscal_year_id = p_fiscal_year and status = 'failed' and severity = 'warning') then
    raise exception 'Des alertes ne sont pas levées : commenter chaque levée' using errcode = '23514';
  end if;
  update public.fiscal_years set status = 'closing' where id = p_fiscal_year;
  update public.periods set is_locked = true, locked_at = now(), locked_by = auth.uid() where fiscal_year_id = p_fiscal_year and not is_locked;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_fy.cabinet_id, auth.uid(), 'close_provisional', 'fiscal_years', p_fiscal_year::text, p_entity, jsonb_build_object('label', v_fy.label));
end $$;

create or replace function public.reopen_fiscal_year(p_entity uuid, p_fiscal_year uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : réouverture' using errcode = '42501';
  end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'Motif de réouverture obligatoire' using errcode = '23514'; end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity for update;
  if v_fy.status <> 'closing' then raise exception 'Seul un exercice en clôture provisoire se rouvre' using errcode = '23514'; end if;
  update public.fiscal_years set status = 'open' where id = p_fiscal_year;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_fy.cabinet_id, auth.uid(), 'reopen', 'fiscal_years', p_fiscal_year::text, p_entity, jsonb_build_object('label', v_fy.label, 'reason', p_reason));
end $$;

-- Arrêté définitif (associé, aal2) : archive avec empreintes (grand livre, balance, états), exercice clôturé et intangible.
create or replace function public.close_final(p_entity uuid, p_fiscal_year uuid, p_confirmation text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_manifest jsonb; v_hash text; v_id uuid; v_statements uuid;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.final') then
    raise exception 'Permission refusée : arrêté définitif (associé avec TOTP)' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity for update;
  if v_fy.status <> 'closing' then raise exception 'L''exercice doit être en clôture provisoire' using errcode = '23514'; end if;
  if p_confirmation is distinct from 'ARRETER ' || v_fy.label then
    raise exception 'Confirmation attendue : « ARRETER % »', v_fy.label using errcode = '23514';
  end if;
  if not exists (select 1 from public.entries where entity_id = p_entity and generated_source = 'result:' || p_fiscal_year and status = 'validated') then
    raise exception 'L''écriture de détermination du résultat doit être validée' using errcode = '23514';
  end if;
  select id into v_statements from public.financial_statements where fiscal_year_id = p_fiscal_year order by generated_at desc limit 1;
  if v_statements is null then raise exception 'Générer les états financiers avant l''arrêté' using errcode = '23514'; end if;
  v_manifest := jsonb_build_object(
    'fiscal_year', v_fy.label, 'archived_at', now(),
    'ledger_hash', encode(extensions.digest(coalesce((select string_agg(concat_ws('|', l.entry_date, l.journal_code, l.number, l.account_code, l.third_party_code, l.debit, l.credit), E'\n' order by l.entry_date, l.journal_code, l.number, l.line_id)
                                                     from public.ledger_lines l where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year), ''), 'sha256'), 'hex'),
    'balance_hash', encode(extensions.digest(coalesce((select string_agg(concat_ws('|', account_code, balance), E'\n' order by account_code) from public.closing_balances(p_entity, p_fiscal_year)), ''), 'sha256'), 'hex'),
    'statements_id', v_statements,
    'statements_hash', encode(extensions.digest((select data::text from public.financial_statements where id = v_statements), 'sha256'), 'hex'),
    'entries_count', (select count(*) from public.entries where entity_id = p_entity and fiscal_year_id = p_fiscal_year and status = 'validated'),
    'documents_count', (select count(distinct ed.document_id) from public.entry_documents ed join public.entries e on e.id = ed.entry_id where e.entity_id = p_entity and e.fiscal_year_id = p_fiscal_year));
  v_hash := encode(extensions.digest(v_manifest::text, 'sha256'), 'hex');
  insert into public.closing_archives (cabinet_id, entity_id, fiscal_year_id, archived_by, manifest, hash)
  values (v_fy.cabinet_id, p_entity, p_fiscal_year, auth.uid(), v_manifest, v_hash) returning id into v_id;
  update public.financial_statements set is_final = true where id = v_statements;
  update public.fiscal_years set status = 'closed', final_closed_at = now(), final_closed_by = auth.uid() where id = p_fiscal_year;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_fy.cabinet_id, auth.uid(), 'close_final', 'fiscal_years', p_fiscal_year::text, p_entity, jsonb_build_object('label', v_fy.label, 'archive', v_id, 'hash', v_hash));
  return v_id;
end $$;

-- À-nouveaux N+1 : soldes des comptes de bilan (classes 1 à 5) à la clôture de N, détail par tiers pour les collectifs ;
-- le résultat de N est repris en 1300 (en instance d''affectation) ; recalculés tant que N n''est pas arrêté.
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
  v_1300 := public.account_id_by_code(p_entity, '130');
  if v_result <> 0 then
    v_lines := v_lines || jsonb_build_object('account_id', v_1300, 'debit', greatest(-v_result, 0), 'credit', greatest(v_result, 0), 'label', 'Résultat ' || v_fy.label || ' en instance d''affectation');
  end if;
  perform set_config('akonta.internal', 'on', true);
  v_entry := public.generated_entry(p_entity, v_next.start_date, 'À-nouveaux ' || v_next.label || (case when v_fy.status = 'closed' then '' else ' (provisoires)' end), 'opening:' || v_next.id, v_lines, 'opening');
  perform set_config('akonta.internal', 'off', true);
  return v_entry;
end $$;

-- Affectation du résultat en N+1 : 1300 → réserves (111/118), report à nouveau (12), dividendes (465).
create or replace function public.allocate_result(p_entity uuid, p_fiscal_year_next uuid, p_date date, p_legal_reserve bigint, p_free_reserve bigint, p_dividends bigint, p_carry_forward bigint)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_total bigint := p_legal_reserve + p_free_reserve + p_dividends + p_carry_forward; v_lines jsonb;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture' using errcode = '42501';
  end if;
  if v_total <= 0 then raise exception 'Montant à affecter nul' using errcode = '23514'; end if;
  v_lines := jsonb_build_array(jsonb_build_object('account_id', public.account_id_by_code(p_entity, '130'), 'debit', v_total, 'label', 'Affectation du résultat'))
    || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '111'), 'credit', p_legal_reserve, 'label', 'Réserve légale')
    || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '118'), 'credit', p_free_reserve, 'label', 'Réserves libres')
    || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '465'), 'credit', p_dividends, 'label', 'Dividendes à payer')
    || jsonb_build_object('account_id', public.account_id_by_code(p_entity, '121'), 'credit', p_carry_forward, 'label', 'Report à nouveau');
  return public.generated_entry(p_entity, p_date, 'Affectation du résultat', 'allocation:' || p_fiscal_year_next, v_lines);
end $$;

grant execute on function public.run_closing_checks(uuid, uuid), public.waive_closing_check(uuid, text, text), public.accounting_result(uuid, uuid, date),
  public.propose_tax_adjustments(uuid, uuid, text), public.compute_income_tax(uuid, uuid, jsonb, text, bigint), public.closing_balances(uuid, uuid),
  public.statement_posts(uuid, uuid, public.statement_kind, text), public.generate_financial_statements(uuid, uuid, text), public.generate_result_entry(uuid, uuid),
  public.close_provisional(uuid, uuid), public.reopen_fiscal_year(uuid, uuid, text), public.close_final(uuid, uuid, text), public.generate_opening_balances(uuid, uuid),
  public.allocate_result(uuid, uuid, date, bigint, bigint, bigint, bigint) to authenticated;
