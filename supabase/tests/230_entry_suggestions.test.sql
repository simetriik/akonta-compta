-- Suggestions de saisie sans modèle (D-026) : écritures proches, comptes habituels, modèles proches, doublons ; isolation par dossier.
begin;
select plan(18);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('chef@a.test', :'a_id') as id \gset chef_
select tests.create_user('autre@a.test', :'a_id') as id \gset autre_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.create_entity(:'a_id', 'SARL Voisine') as id \gset e2_
select tests.assign(:'chef_id', :'a_id', 'manager', :'e1_id');
select tests.assign(:'autre_id', :'a_id', 'manager', :'e2_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31'), (:'a_id', :'e2_id', '2026-01-01', '2026-12-31');
select public.create_journals_from_template(:'e1_id', null);
select public.create_journals_from_template(:'e2_id', null);
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'e1_id', 'SOB', 'SOBEBRA', 'supplier'), (:'a_id', :'e2_id', 'SOB', 'SOBEBRA', 'supplier');

-- Historique de SARL Démo : deux loyers validés, une fourniture, un loyer contre-passé, un brouillard
select tests.make_entry(:'e1_id', 'AC', '2026-01-31', 'Loyer janvier 2026', '[{"account":"6222000","debit":300000},{"account":"4011000","tp":"SOB","credit":300000}]') as id \gset l1_
select tests.make_entry(:'e1_id', 'AC', '2026-02-28', 'Loyer février 2026', '[{"account":"6222000","debit":300000},{"account":"4011000","tp":"SOB","credit":300000}]') as id \gset l2_
select tests.make_entry(:'e1_id', 'AC', '2026-03-05', 'Fournitures de bureau', '[{"account":"6055000","debit":50000},{"account":"4011000","tp":"SOB","credit":50000}]') as id \gset f1_
select tests.make_entry(:'e1_id', 'AC', '2026-03-10', 'Loyer erroné mars', '[{"account":"6222000","debit":999},{"account":"4011000","tp":"SOB","credit":999}]') as id \gset bad_
select tests.make_entry(:'e1_id', 'AC', '2026-04-10', 'Loyer brouillon avril', '[{"account":"6222000","debit":300000},{"account":"4011000","tp":"SOB","credit":300000}]') as id \gset dr_
update public.entries set reference = 'F-2026-001' where id = :'f1_id';
select public.validate_entries(array[:'l1_id', :'l2_id', :'f1_id', :'bad_id']::uuid[]);
select public.reverse_entry(:'bad_id', 'Erreur de saisie', '2026-03-11');
select tests.make_entry(:'e2_id', 'AC', '2026-02-10', 'Loyer du voisin', '[{"account":"6222000","debit":111},{"account":"4011000","tp":"SOB","credit":111}]') as id \gset v_
select public.validate_entry(:'v_id');

-- A. Écritures proches
select tests.authenticate_as(:'chef_id');
select is((select string_agg(label, ' | ' order by entry_date desc) from public.suggest_entries(:'e1_id', 'loyer')), 'Loyer février 2026 | Loyer janvier 2026',
          'écritures proches : loyers validés, du plus récent au plus ancien (ni brouillard, ni contre-passée, ni contre-passation)');
select is((select count(*) from public.suggest_entries(:'e1_id', 'LOYER FEVRIER')), 1::bigint, 'recherche insensible à la casse et aux accents');
select is((select count(*) from public.suggest_entries(:'e1_id', 'lo')), 0::bigint, 'moins de 3 caractères : aucune suggestion');
select is((select lines->0->>'account_code' || '/' || (lines->0->>'side') || '/' || (lines->1->>'third_party_code') from public.suggest_entries(:'e1_id', 'loyer janvier')),
          '6222000/debit/SOB', 'les lignes reprennent comptes, sens et tiers');
select is((select count(*) from public.suggest_entries(:'e1_id', 'loyer janvier'), jsonb_array_elements(lines) l where l ? 'debit' or l ? 'credit' or l ? 'amount'), 0::bigint,
          'aucun montant n''est repris');

-- Isolation : le dossier voisin n'est pas visible
select is((select count(*) from public.suggest_entries(:'e2_id', 'loyer')), 0::bigint, 'dossier non affecté : aucune suggestion');
select is((select count(*) from public.suggest_accounts(:'e2_id', 'loyer')), 0::bigint, 'dossier non affecté : aucun compte suggéré');
select tests.authenticate_as(:'autre_id');
select is((select count(*) from public.suggest_entries(:'e1_id', 'loyer')), 0::bigint, 'un autre collaborateur ne voit pas l''historique du dossier');
select is((select count(*) from public.suggest_entries(:'e2_id', 'loyer')), 1::bigint, 'mais voit celui de son propre dossier');
select tests.authenticate_as(:'chef_id');

-- B. Comptes habituels d'après le libellé
select is((select account_code || '/' || source || '/' || uses from public.suggest_accounts(:'e1_id', 'loyer') order by 1 limit 1), '6222000/label/2', 'compte habituel d''un libellé : 6222000, 2 emplois');
select is((select count(*) from public.suggest_accounts(:'e1_id', 'loyer') where account_code like '4011%'), 0::bigint, 'les comptes collectifs ne sont pas suggérés');

-- C. Habitudes d'un tiers
select is((select account_code || '/' || source || '/' || uses from public.suggest_accounts(:'e1_id', 'divers', (select id from public.third_parties where entity_id = :'e1_id' and code = 'SOB'), 1)),
          '6222000/third_party/2', 'tiers : compte le plus employé avec ce fournisseur (6222000 deux fois)');
update public.accounts set is_active = false where entity_id = :'e1_id' and code = '6222000';
select is((select count(*) from public.suggest_accounts(:'e1_id', 'loyer') where account_code = '6222000'), 0::bigint, 'un compte désactivé n''est plus suggéré');

-- Modèles proches
select is((select string_agg(code, ',' order by code) from public.suggest_templates(:'e1_id', 'loyer')), 'LOYER,LOYER_TVA', 'modèles proches du libellé « loyer »');
select tests.clear_auth();
insert into public.entities (cabinet_id, name, accounting_system) values (:'a_id', 'Association Espoir', 'sycebnl') returning id as sy_id \gset
select tests.assign(:'chef_id', :'a_id', 'manager', :'sy_id');
select tests.authenticate_as(:'chef_id');
select is((select string_agg(code, ',' order by code) from public.suggest_templates(:'sy_id', 'loyer')), 'AS_LOYER', 'modèles du référentiel de l''entité seulement');

-- D. Doublons
select is((select number || '/' || journal_code from public.find_duplicate_entries(:'e1_id', ' f-2026-001 ', 50000, (select id from public.third_parties where entity_id = :'e1_id' and code = 'SOB'))), '3/AC', 'doublon : même référence, même montant et même tiers');
select is((select count(*) from public.find_duplicate_entries(:'e1_id', 'F-2026-001', 50001)), 0::bigint, 'montant différent : pas de doublon');
select is((select count(*) from public.find_duplicate_entries(:'e1_id', 'F-2026-001', 50000, null, :'f1_id')), 0::bigint, 'l''écriture elle-même est exclue');

select * from finish();
rollback;
