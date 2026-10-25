-- Module 10 — Import Perfecto : analyse du texte tabulé, scission des tiers collés, négatifs inversés, correspondances, essai, application (§10.10, D-004).
begin;
select plan(25);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('manager@a.test', :'a_id') as id \gset manager_
select tests.create_user('assist@a.test',  :'a_id') as id \gset assist_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'manager_id', :'a_id', 'manager',   :'e1_id');
select tests.assign(:'assist_id',  :'a_id', 'assistant', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'e1_id', 'BQ', 'Ecobank', 'bank', id from public.accounts where entity_id = :'e1_id' and code = '5210000';
select id as id from public.journals where entity_id = :'e1_id' and code = 'BQ' \gset bq_

-- 1. Scission des comptes
select is((select collective || '|' || coalesce(third_party, '-') from public.perfecto_split_account('4110CHU')), '4110|CHU', '4110CHU → collectif 4110 + tiers CHU');
select is((select collective || '|' || coalesce(third_party, '-') from public.perfecto_split_account('401100')), '401100|-', '401100 → compte sans tiers');
select is((select collective from public.perfecto_split_account('CHU4110')), null::text, 'compte illisible → null');
select is(public.perfecto_parse_amount('4 720 000'), 4720000::numeric, 'montant avec espaces');
select is(public.perfecto_parse_amount('-1 500,50'), -1500.50::numeric, 'montant négatif à virgule');

-- 2. Analyse d'un extrait réel de JOURNAL BANQUE.TXT (décodé), avec une pièce à montants négatifs ajoutée
select tests.authenticate_as(:'manager_id');
insert into public.import_batches (cabinet_id, entity_id, kind, source_file_name, target_journal_id)
values (:'a_id', :'e1_id', 'journal', 'JOURNAL BANQUE.TXT', :'bq_id');
select id as id from public.import_batches where entity_id = :'e1_id' \gset batch_
select public.import_parse_perfecto_journal(:'batch_id', E'JOURNAL <BANECO> Ecobank Bénin\r\nPièces du 01/01/2026  au 22/10/2026\t\t\r\n\t\t\t\t\t\t\r\nDate\tN° pièce\tCompte\tIntitulé\tDébit\tCrédit\tLibellé\r\n04/01/2026\t000001\t4110CHU\tCHU - Parakou\t0\t4720000\tS/Règlement partiel chu 2022\r\n04/01/2026\t000001\t4452002\tTva retenue a la source\t288000\t0\tS/Règlement partiel chu 2022\r\n04/01/2026\t000001\t4478004\tAib  clients / Avec quittance\t40000\t0\tS/Règlement partiel chu 2022\r\n04/01/2026\t000001\t5210ECO\tEcobank Bénin\t4392000\t0\tS/Règlement partiel chu 2022\r\nSous-total\t000001\t\t\t4720000\t4720000\t\r\n05/01/2026\t000002\t4011NSI\tNsia assurances\t121000\t0\tS/Règlement nsia\r\n05/01/2026\t000002\t5210ECO\tEcobank Bénin\t0\t121000\tS/Règlement nsia\r\nSous-total\t000002\t\t\t121000\t121000\t\r\n06/01/2026\t000003\t401100\tFournisseurs\t58475\t0\tS/Règlement formation\r\n06/01/2026\t000003\t5210ECO\tEcobank Bénin\t0\t58475\tS/Règlement formation\r\nSous-total\t000003\t\t\t58475\t58475\t\r\n07/01/2026\t000004\t6311000\tFrais bancaires\t-2500\t0\tAnnulation frais\r\n07/01/2026\t000004\t5210ECO\tEcobank Bénin\t0\t-2500\tAnnulation frais\r\nSous-total\t000004\t\t\t-2500\t-2500\t\r\nTotal Journal\t\t\t\t4896975\t4896975\t\r\n') as report \gset parse_
select is((select source_journal from public.import_batches where id = :'batch_id'), 'BANECO', 'code du journal source lu dans l''en-tête');
select is((select period_from::text || '→' || period_to::text from public.import_batches where id = :'batch_id'), '2026-01-01→2026-10-22', 'période lue');
select is((select count(*) from public.import_lines where batch_id = :'batch_id'), 10::bigint, '10 lignes de données (sous-totaux et totaux exclus)');
select is((select (:'parse_report'::jsonb ->> 'pieces')::int), 4, '4 pièces');
select is((select debit || '/' || credit from public.import_lines where batch_id = :'batch_id' and raw_account = '6311000'), '0/2500', 'débit négatif converti en crédit');
select is((select debit || '/' || credit from public.import_lines where batch_id = :'batch_id' and raw_account = '5210ECO' and piece_ref = '000004'), '2500/0', 'crédit négatif converti en débit');
select is((select (:'parse_report'::jsonb ->> 'subtotal_errors')::int), 0, 'sous-totaux cohérents après normalisation');

-- 3. Correspondances proposées (D-004 : complétées à 7 chiffres, tiers scindés)
select public.import_propose_mappings(:'batch_id') as report \gset map_
select is((select account_code || '|' || third_party_code || '|' || create_third_party from public.import_account_mappings where entity_id = :'e1_id' and raw_account = '4110CHU'),
          '4110000|CHU|true', '4110CHU → 4110000 + tiers CHU à créer');
select is((select account_code from public.import_account_mappings where entity_id = :'e1_id' and raw_account = '401100'), '4011000', '401100 → 4011000 (complété à droite)');
select is((select account_code || '|' || third_party_code from public.import_account_mappings where entity_id = :'e1_id' and raw_account = '5210ECO'), '5210000|ECO', '5210ECO → 5210000 + ECO (compte de banque suffixé)');
select is((select third_party_name from public.import_account_mappings where entity_id = :'e1_id' and raw_account = '4011NSI'), 'Nsia assurances', 'nom du tiers repris de l''intitulé');

select is((select (:'map_report'::jsonb ->> 'unknown_accounts')::int), 2, 'deux subdivisions Perfecto absentes du plan (4452002, 4478004) signalées, non créées (D-008)');
-- L'utilisateur les fait correspondre aux comptes existants dans la table éditable
update public.import_account_mappings set account_code = '4452000' where entity_id = :'e1_id' and raw_account = '4452002';
update public.import_account_mappings set account_code = '4478000' where entity_id = :'e1_id' and raw_account = '4478004';
-- Le compte 5210 n'est pas collectif : la correspondance éditable retire le suffixe (la banque n'est pas un tiers)
update public.import_account_mappings set third_party_code = null, third_party_name = null, create_third_party = false where entity_id = :'e1_id' and raw_account = '5210ECO';
-- 401100 est un collectif : un tiers est requis → on le renseigne dans la table de correspondance
update public.import_account_mappings set third_party_code = 'DIVERS', third_party_name = 'Fournisseurs divers', create_third_party = true where entity_id = :'e1_id' and raw_account = '401100';

-- 4. Mode essai : rapport, aucune écriture, aucun tiers créé
select public.import_apply(:'batch_id', true) as report \gset dry_
select is((select (:'dry_report'::jsonb ->> 'entries')::int), 4, 'essai : 4 écritures seraient créées');
select is((select count(*) from public.entries where entity_id = :'e1_id'), 0::bigint, 'essai : aucune écriture créée');
select is((select count(*) from public.third_parties where entity_id = :'e1_id'), 0::bigint, 'essai : aucun tiers créé');

-- 5. Application réelle : brouillards « générés », tiers créés et rattachés
select public.import_apply(:'batch_id', false) as report \gset real_
select is((select count(*) from public.entries where entity_id = :'e1_id' and status = 'draft' and is_generated), 4::bigint, 'application : 4 brouillards marqués « générée »');
select is((select count(*) from public.third_parties where entity_id = :'e1_id' and code in ('CHU', 'NSI', 'DIVERS')), 3::bigint, 'tiers CHU, NSI et DIVERS créés');
select is((select sum(debit) from public.entry_lines where entity_id = :'e1_id'), 4901975::numeric, 'total débit importé = total Perfecto avec les négatifs remis dans le bon sens (4 896 975 + 2 × 2 500)');
-- Les brouillards importés se valident ensuite par le chef de mission
select lives_ok(format('select public.validate_entries(array(select id from public.entries where entity_id = %L order by entry_date))', :'e1_id'), 'validation des brouillards importés');
select tests.authenticate_as(:'assist_id');
select throws_ok(format('select public.import_apply(%L, true)', :'batch_id'), '23514', null, 'lot déjà appliqué : refusé');
select tests.clear_auth();

select * from finish();
rollback;
