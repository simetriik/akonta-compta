-- =============================================================================
-- Akonta — Jeu de démonstration (rejouable : supabase db reset / scripts/demo.sh)
-- Cabinet « ABC Expertise Comptable (démo) », 5 collaborateurs (un par rôle), 2 dossiers,
-- exercice 2026 complet sur SARL Démo (achats, ventes, banque, caisse, OD, paie), tiers,
-- écritures validées, brouillards, revues, une contre-passation, un import Perfecto.
-- Mot de passe de tous les comptes de démonstration : Akonta-Demo-2026!
-- Ne jamais rejouer sur un environnement de recette ou de production.
-- =============================================================================

create or replace function pg_temp.demo_user(p_email text, p_cabinet uuid, p_full_name text, p_job text)
returns uuid language plpgsql as $$
declare v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
  values (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', p_email,
          extensions.crypt('Akonta-Demo-2026!', extensions.gen_salt('bf')), now(),
          '{"provider":"email","providers":["email"]}'::jsonb,
          jsonb_build_object('cabinet_id', p_cabinet, 'full_name', p_full_name, 'job_title', p_job), now(), now(), '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), v_id, p_email, jsonb_build_object('sub', v_id::text, 'email', p_email, 'email_verified', true), 'email', now(), now(), now());
  return v_id;
end $$;

create or replace function pg_temp.demo_entry(p_entity uuid, p_journal text, p_date date, p_label text, p_ref text, p_lines jsonb, p_author uuid, p_validate boolean default true)
returns uuid language plpgsql as $$
declare v_id uuid; v_cabinet uuid; v_journal uuid; l jsonb;
begin
  select cabinet_id into v_cabinet from public.entities where id = p_entity;
  select id into v_journal from public.journals where entity_id = p_entity and code = p_journal;
  perform set_config('request.jwt.claims', json_build_object('sub', p_author, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, reference, label, created_by)
  values (v_cabinet, p_entity,
          (select id from public.fiscal_years fy where fy.entity_id = p_entity and p_date between fy.start_date and fy.end_date),
          (select p.id from public.periods p where p.entity_id = p_entity and p_date between p.start_date and p.end_date),
          v_journal, p_date, p_ref, p_label, p_author)
  returning id into v_id;
  for l in select * from jsonb_array_elements(p_lines) loop
    if not exists (select 1 from public.accounts a where a.entity_id = p_entity and a.code = l->>'a') then
      raise exception 'Seed : compte % inconnu dans le dossier', l->>'a';
    end if;
    if l->>'tp' is not null and not exists (select 1 from public.third_parties t where t.entity_id = p_entity and t.code = l->>'tp') then
      raise exception 'Seed : tiers % inconnu dans le dossier', l->>'tp';
    end if;
    insert into public.entry_lines (cabinet_id, entity_id, entry_id, account_id, third_party_id, label, debit, credit)
    select v_cabinet, p_entity, v_id, a.id, t.id, coalesce(l->>'label', p_label), coalesce((l->>'d')::bigint, 0), coalesce((l->>'c')::bigint, 0)
      from public.accounts a
      left join public.third_parties t on t.entity_id = p_entity and t.code = l->>'tp'
     where a.entity_id = p_entity and a.code = l->>'a';
  end loop;
  if p_validate then perform public.validate_entry(v_id); end if;
  perform set_config('request.jwt.claims', '', true);
  return v_id;
end $$;

do $$
declare
  v_cabinet uuid; v_partner uuid; v_admin uuid; v_manager uuid; v_assistant uuid; v_trainee uuid;
  v_demo uuid; v_alpha uuid; v_fy uuid; v_e uuid; v_rev uuid; v_batch uuid; m int; d date; v_sl bigint; v_bq uuid; v_prop record;
  v_tp text; v_amt bigint; v_ht bigint; v_tva bigint;
begin
  -- Cabinet et collaborateurs
  insert into public.cabinets (name, address, phone, email) values ('ABC Expertise Comptable (démo)', 'Cotonou, Bénin', '+229 97 00 00 00', 'contact@abc-demo.bj') returning id into v_cabinet;
  v_partner   := pg_temp.demo_user('associe@akonta.demo',   v_cabinet, 'Hodonou AGBESSI', 'Associé, expert-comptable');
  v_admin     := pg_temp.demo_user('admin@akonta.demo',     v_cabinet, 'Sèna HOUNKPATIN', 'Administrateur technique');
  v_manager   := pg_temp.demo_user('chef@akonta.demo',      v_cabinet, 'Kofi MENSAH', 'Chef de mission');
  v_assistant := pg_temp.demo_user('assistant@akonta.demo', v_cabinet, 'Awa DOSSOU', 'Assistante comptable');
  v_trainee   := pg_temp.demo_user('stagiaire@akonta.demo', v_cabinet, 'Yao ADJOVI', 'Stagiaire');

  insert into public.assignments (cabinet_id, user_id, entity_id, role_id)
  select v_cabinet, v_partner, null, id from public.roles where cabinet_id = v_cabinet and code = 'partner';
  insert into public.assignments (cabinet_id, user_id, entity_id, role_id)
  select v_cabinet, v_admin, null, id from public.roles where cabinet_id = v_cabinet and code = 'tech_admin';

  -- Dossiers
  insert into public.entities (cabinet_id, name, acronym, legal_form, address, tax_id, trade_register, tax_regime, incorporation_date, establishments_count, control_type, control_origin, main_activity, activity_code, monthly_lock_enabled, created_by)
  values (v_cabinet, 'SARL Démo Distribution', 'SDD', 'SARL', 'Akpakpa, Cotonou', '3202600000011', 'RB/COT/20 B 1234', 'Réel normal', '2020-03-15', 1, 'private', 'national', 'Commerce général de marchandises', 'G4690', true, v_partner)
  returning id into v_demo;
  insert into public.entities (cabinet_id, name, acronym, legal_form, address, tax_id, trade_register, tax_regime, incorporation_date, establishments_count, control_type, control_origin, main_activity, created_by)
  values (v_cabinet, 'SA Alpha Services', 'ALPHA', 'SA', 'Ganhi, Cotonou', '3202600000022', 'RB/COT/18 B 5678', 'Réel normal', '2018-06-01', 2, 'private', 'national', 'Prestations de services informatiques', v_partner)
  returning id into v_alpha;
  insert into public.entity_directors (cabinet_id, entity_id, full_name, position, nationality, address) values
    (v_cabinet, v_demo, 'Rachelle GBAGUIDI', 'Gérante', 'Béninoise', 'Cotonou'),
    (v_cabinet, v_alpha, 'Marc TOSSOU', 'Directeur général', 'Béninoise', 'Cotonou'),
    (v_cabinet, v_alpha, 'Inès KOUDJO', 'Présidente du conseil d''administration', 'Béninoise', 'Porto-Novo');

  insert into public.assignments (cabinet_id, user_id, entity_id, role_id)
  select v_cabinet, v_manager, v_demo, id from public.roles where cabinet_id = v_cabinet and code = 'manager';
  insert into public.assignments (cabinet_id, user_id, entity_id, role_id)
  select v_cabinet, v_manager, v_alpha, id from public.roles where cabinet_id = v_cabinet and code = 'manager';
  insert into public.assignments (cabinet_id, user_id, entity_id, role_id)
  select v_cabinet, v_assistant, v_demo, id from public.roles where cabinet_id = v_cabinet and code = 'assistant';
  insert into public.assignments (cabinet_id, user_id, entity_id, role_id)
  select v_cabinet, v_trainee, v_demo, id from public.roles where cabinet_id = v_cabinet and code = 'trainee';
  insert into public.assignments (cabinet_id, user_id, entity_id, role_id)
  select v_cabinet, v_assistant, v_alpha, id from public.roles where cabinet_id = v_cabinet and code = 'assistant';

  -- Exercices 2026
  insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date, capital, headcount) values (v_cabinet, v_demo, '2026-01-01', '2026-12-31', 10000000, 12) returning id into v_fy;
  insert into public.fiscal_year_partners (cabinet_id, fiscal_year_id, name, share_percent) values (v_cabinet, v_fy, 'Rachelle GBAGUIDI', 60), (v_cabinet, v_fy, 'Paul GBAGUIDI', 40);
  insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date, capital, headcount) values (v_cabinet, v_alpha, '2026-01-01', '2026-12-31', 50000000, 25);

  -- Journaux et tiers de SARL Démo
  perform public.create_journals_from_template(v_demo, array['AC', 'VT', 'OD', 'PA']);
  insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
    select v_cabinet, v_demo, 'BQ', 'Ecobank Bénin', 'bank', id from public.accounts where entity_id = v_demo and code = '5210000';
  insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
    select v_cabinet, v_demo, 'CA', 'Caisse principale', 'cash', id from public.accounts where entity_id = v_demo and code = '5710000';
  perform public.create_journals_from_template(v_alpha, array['AC', 'VT', 'OD']);
  insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
    select v_cabinet, v_alpha, 'BQ', 'BOA Bénin', 'bank', id from public.accounts where entity_id = v_alpha and code = '5210000';

  insert into public.third_parties (cabinet_id, entity_id, code, name, type, tax_id, address) values
    (v_cabinet, v_demo, 'CHU',   'CHU - Parakou',             'customer', '3200100000031', 'Parakou'),
    (v_cabinet, v_demo, 'BIL',   'Etude Me BILIKIS ASSANI',   'customer', null, 'Cotonou'),
    (v_cabinet, v_demo, 'ACL',   'ACL Bénin',                 'customer', '3200100000044', 'Cotonou'),
    (v_cabinet, v_demo, 'SOBEB', 'SOBEBRA',                   'supplier', '3200100000055', 'Cotonou'),
    (v_cabinet, v_demo, 'NSIA',  'NSIA Assurances',           'supplier', null, 'Cotonou'),
    (v_cabinet, v_demo, 'SBEE',  'SBEE',                      'supplier', null, 'Cotonou'),
    (v_cabinet, v_demo, 'MTN',   'MTN Bénin',                 'supplier', null, 'Cotonou'),
    (v_cabinet, v_demo, 'PERS',  'Personnel (collectif paie)','employee', null, null),
    (v_cabinet, v_demo, 'GERANT','Rachelle GBAGUIDI (gérante)','partner', null, null);
  insert into public.third_party_accounts (third_party_id, account_id)
  select t.id, a.id from public.third_parties t join public.accounts a on a.entity_id = t.entity_id
   where t.entity_id = v_demo and ((t.type = 'customer' and a.code = '4111000') or (t.type = 'supplier' and a.code = '4011000')
          or (t.type = 'employee' and a.code = '4220000') or (t.type = 'partner' and a.code = '4621000'));

  -- À-nouveaux (soldes au 01/01/2026) : capital, banque, caisse, stock, immobilisation, clients, fournisseurs
  perform pg_temp.demo_entry(v_demo, 'AN', '2026-01-01', 'À-nouveaux 2026', 'AN-2026', '[
     {"a":"5210000","d":8450000},{"a":"5710000","d":350000},{"a":"3110000","d":4200000},{"a":"2441000","d":6000000},{"a":"2844000","c":1800000},
     {"a":"4111000","tp":"CHU","d":4720000},{"a":"4111000","tp":"ACL","d":540000},
     {"a":"4011000","tp":"SOBEB","c":2310000},{"a":"4011000","tp":"NSIA","c":121000},
     {"a":"1011000","c":10000000},{"a":"1181000","c":4600000},{"a":"1300000","c":5429000}]', v_manager);

  -- Tenue courante : 12 mois d'opérations
  for m in 1..12 loop
    d := make_date(2026, m, 5);
    v_ht := 1500000 + (m * 137000) % 900000; v_tva := round(v_ht * 0.18);
    -- Achat de marchandises SOBEBRA avec TVA
    perform pg_temp.demo_entry(v_demo, 'AC', d, format('Facture SOBEBRA %s/2026', lpad(m::text, 2, '0')), format('F-SB-%s', 1000 + m), jsonb_build_array(
      jsonb_build_object('a','6011000','d',v_ht), jsonb_build_object('a','4452000','d',v_tva), jsonb_build_object('a','4011000','tp','SOBEB','c',v_ht + v_tva)), v_assistant, m <= 10);
    -- Vente CHU avec TVA
    v_ht := 4800000 + (m * 251000) % 1500000; v_tva := round(v_ht * 0.18);
    perform pg_temp.demo_entry(v_demo, 'VT', d + 3, format('Facture CHU %s/2026', lpad(m::text, 2, '0')), format('FV-%s', 2000 + m), jsonb_build_array(
      jsonb_build_object('a','4111000','tp','CHU','d',v_ht + v_tva), jsonb_build_object('a','7011000','c',v_ht), jsonb_build_object('a','4431000','c',v_tva)), v_assistant, m <= 10);
    -- Vente ACL (petite)
    perform pg_temp.demo_entry(v_demo, 'VT', d + 9, format('Facture ACL %s/2026', lpad(m::text, 2, '0')), format('FV-%s', 2100 + m), jsonb_build_array(
      jsonb_build_object('a','4111000','tp','ACL','d',590000), jsonb_build_object('a','7011000','c',500000), jsonb_build_object('a','4431000','c',90000)), v_assistant, m <= 10);
    -- Règlement client CHU avec AIB 1 % et TVA retenue (marché public), le mois suivant
    if m >= 2 then
      v_ht := 4800000 + ((m - 1) * 251000) % 1500000; v_tva := round(v_ht * 0.18); v_amt := v_ht + v_tva;
      perform pg_temp.demo_entry(v_demo, 'BQ', d + 12, format('Règlement CHU facture %s/2026', lpad((m - 1)::text, 2, '0')), format('VIR-%s', 3000 + m), jsonb_build_array(
        jsonb_build_object('a','4111000','tp','CHU','c',v_amt), jsonb_build_object('a','4478000','d',round(v_ht * 0.01)), jsonb_build_object('a','4452000','d',v_tva),
        jsonb_build_object('a','5210000','d',v_amt - round(v_ht * 0.01) - v_tva)), v_assistant, m <= 10);
      -- Règlement fournisseur SOBEBRA
      v_ht := 1500000 + ((m - 1) * 137000) % 900000; v_tva := round(v_ht * 0.18);
      perform pg_temp.demo_entry(v_demo, 'BQ', d + 15, format('Virement SOBEBRA facture %s/2026', lpad((m - 1)::text, 2, '0')), format('VIR-%s', 3100 + m), jsonb_build_array(
        jsonb_build_object('a','4011000','tp','SOBEB','d',v_ht + v_tva), jsonb_build_object('a','5210000','c',v_ht + v_tva)), v_assistant, m <= 10);
    end if;
    -- Frais bancaires avec TAF
    perform pg_temp.demo_entry(v_demo, 'BQ', (date_trunc('month', d) + interval '1 month - 1 day')::date, format('Frais de tenue de compte %s/2026', lpad(m::text, 2, '0')), null, jsonb_build_array(
      jsonb_build_object('a','6311000','d',15000), jsonb_build_object('a','6312000','d',1500), jsonb_build_object('a','5210000','c',16500)), v_assistant, m <= 10);
    -- Caisse : petites dépenses
    perform pg_temp.demo_entry(v_demo, 'CA', d + 7, format('Carburant et fournitures %s/2026', lpad(m::text, 2, '0')), format('CA-%s', 100 + m), jsonb_build_array(
      jsonb_build_object('a','6051000','d',45000), jsonb_build_object('a','6047000','d',22000), jsonb_build_object('a','5710000','c',67000)), v_trainee, false);
    -- Électricité et téléphone (OD fournisseurs)
    perform pg_temp.demo_entry(v_demo, 'AC', d + 10, format('Facture SBEE %s/2026', lpad(m::text, 2, '0')), null, jsonb_build_array(
      jsonb_build_object('a','6051000','d',180000), jsonb_build_object('a','4452000','d',32400), jsonb_build_object('a','4011000','tp','SBEE','c',212400)), v_assistant, m <= 10);
    -- Paie mensuelle : salaires bruts 2 400 000, CNSS salariale 3,6 %, IRPP forfaitaire, charges patronales 15,4 %
    perform pg_temp.demo_entry(v_demo, 'PA', (date_trunc('month', d) + interval '1 month - 1 day')::date, format('Paie %s/2026', lpad(m::text, 2, '0')), null, jsonb_build_array(
      jsonb_build_object('a','6611000','d',2400000), jsonb_build_object('a','6641000','d',369600),
      jsonb_build_object('a','4311000','c',369600 + 86400), jsonb_build_object('a','4472000','c',180000), jsonb_build_object('a','4220000','tp','PERS','c',2400000 - 86400 - 180000)), v_assistant, m <= 10);
    if m <= 10 then
      perform pg_temp.demo_entry(v_demo, 'BQ', make_date(2026, m, 28), format('Virement salaires %s/2026', lpad(m::text, 2, '0')), null, jsonb_build_array(
        jsonb_build_object('a','4220000','tp','PERS','d',2400000 - 86400 - 180000), jsonb_build_object('a','5210000','c',2400000 - 86400 - 180000)), v_assistant, true);
    end if;
  end loop;

  -- Revue par le chef de mission : les écritures de janvier à mars sont revues, deux « à corriger »
  perform set_config('request.jwt.claims', json_build_object('sub', v_manager, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  for v_e in select id from public.entries where entity_id = v_demo and status = 'validated' and entry_date < '2026-04-01' loop
    perform public.review_entry(v_e, 'reviewed');
  end loop;
  select id into v_e from public.entries where entity_id = v_demo and status = 'validated' and label like 'Facture SBEE 04%' limit 1;
  perform public.review_entry(v_e, 'to_correct', 'Imputer en 6052 (eau) une partie de la facture SBEE : voir pièce.');
  select id into v_e from public.entries where entity_id = v_demo and status = 'validated' and label like 'Facture ACL 05%' limit 1;
  perform public.review_entry(v_e, 'to_correct', 'Numéro de facture client manquant en référence.');
  -- Contre-passation d''une facture en double (ACL juin)
  select id into v_e from public.entries where entity_id = v_demo and status = 'validated' and label like 'Facture ACL 06%' limit 1;
  v_rev := public.reverse_entry(v_e, 'Facture saisie en double', '2026-06-20');
  perform set_config('request.jwt.claims', '', true);

  -- Verrouillage des périodes de janvier à mars par l''associé
  perform set_config('request.jwt.claims', json_build_object('sub', v_partner, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  update public.periods set is_locked = true where fiscal_year_id = v_fy and period_no <= 3;
  perform set_config('request.jwt.claims', '', true);

  -- Lot 2 : relevé bancaire de janvier (Ecobank) et pointage partiel, lettrage des factures CHU réglées
  perform set_config('request.jwt.claims', json_build_object('sub', v_assistant, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  insert into public.bank_statement_templates (cabinet_id, bank_name, label, delimiter, has_header, date_column, label_column, debit_column, credit_column, reference_column)
  values (v_cabinet, 'Ecobank Bénin', 'Export CSV Ecobank', ';', true, 1, 2, 3, 4, 5);
  select id into v_bq from public.journals where entity_id = v_demo and code = 'BQ';
  perform public.import_bank_statement(v_bq, '2026-01-01', '2026-01-31', jsonb_build_array(
      jsonb_build_object('date', '2026-01-28', 'label', 'VIR SALAIRES JANVIER', 'debit', 2400000 - 86400 - 180000),
      jsonb_build_object('date', '2026-01-31', 'label', 'FRAIS TENUE DE COMPTE', 'debit', 16500),
      jsonb_build_object('date', '2026-02-02', 'label', 'AGIOS DECOUVERT', 'debit', 4200)),
    8450000, null, (select id from public.bank_statement_templates where cabinet_id = v_cabinet limit 1), 'ecobank-2026-01.csv');
  -- Pointage des deux lignes de janvier d''après les propositions
  for v_sl in select statement_line_id from public.reconciliation_proposals(v_bq, '2026-01-31') loop
    perform public.match_bank_lines(v_bq, array[v_sl],
      array[(select entry_line_id from public.reconciliation_proposals(v_bq, '2026-01-31') where statement_line_id = v_sl)], 'proposition');
  end loop;
  -- Lettrage : factures CHU de janvier à septembre réglées le mois suivant (propositions règle 1)
  -- (instantané des propositions ; une ligne déjà consommée par un lettrage précédent est ignorée)
  for v_prop in select debit_line_id, credit_line_ids from public.lettering_proposals(v_demo, (select id from public.accounts where entity_id = v_demo and code = '4111000')) loop
    continue when exists (select 1 from public.entry_lines where id = any (array[v_prop.debit_line_id] || v_prop.credit_line_ids) and lettering_id is not null);
    perform public.letter_lines(array[v_prop.debit_line_id] || v_prop.credit_line_ids);
  end loop;
  perform set_config('request.jwt.claims', '', true);

  -- SA Alpha : quelques écritures de démarrage
  insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (v_cabinet, v_alpha, 'MINFI', 'Ministère des Finances', 'customer'), (v_cabinet, v_alpha, 'ORANGE', 'Orange Bénin', 'supplier');
  insert into public.third_party_accounts (third_party_id, account_id)
  select t.id, a.id from public.third_parties t join public.accounts a on a.entity_id = t.entity_id
   where t.entity_id = v_alpha and ((t.type = 'customer' and a.code = '4111000') or (t.type = 'supplier' and a.code = '4011000'));
  perform pg_temp.demo_entry(v_alpha, 'AN', '2026-01-01', 'À-nouveaux 2026', null, '[{"a":"5210000","d":50000000},{"a":"1011000","c":50000000}]', v_manager);
  perform pg_temp.demo_entry(v_alpha, 'VT', '2026-01-20', 'Prestation MINFI janvier', 'ALPHA-2026-001', '[{"a":"4111000","tp":"MINFI","d":11800000},{"a":"7061000","c":10000000},{"a":"4431000","c":1800000}]', v_assistant);
  perform pg_temp.demo_entry(v_alpha, 'AC', '2026-01-25', 'Connexion Orange', 'OR-7788', '[{"a":"6281000","d":250000},{"a":"4452000","d":45000},{"a":"4011000","tp":"ORANGE","c":295000}]', v_assistant, false);

  raise notice 'Jeu de démonstration chargé : cabinet %, dossiers % et %', v_cabinet, v_demo, v_alpha;
end $$;
