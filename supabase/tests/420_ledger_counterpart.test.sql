-- Recette 05/11/2026, point 2 : contrepartie et nom du tiers au grand livre.
begin;
select plan(9);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('assist@a.test', :'a_id') as id \gset assist_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select public.create_journals_from_template(:'e1_id', null);
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'e1_id', 'NSIA', 'NSIA Assurances', 'supplier');

-- OD 1 du cadrage : 6011 débit 1 000, 4452 débit 180, 4011 crédit 1 180 (fournisseur NSIA)
select tests.make_entry(:'e1_id', 'OD', '2026-03-10', 'OD 1', '[{"account":"6011000","debit":1000},{"account":"4452000","debit":180},{"account":"4011000","tp":"NSIA","credit":1180}]', :'assist_id') as id \gset od1_
-- Écriture à deux lignes
select tests.make_entry(:'e1_id', 'OD', '2026-03-11', 'OD 2', '[{"account":"6251000","debit":500},{"account":"4710000","credit":500}]', :'assist_id') as id \gset od2_
-- Deux lignes sur le même compte opposé : un seul compte, montants additionnés
select tests.make_entry(:'e1_id', 'OD', '2026-03-12', 'OD 3', '[{"account":"6011000","debit":300},{"account":"6011000","debit":200},{"account":"4710000","credit":500}]', :'assist_id') as id \gset od3_
select public.validate_entries(array[:'od1_id', :'od2_id', :'od3_id']::uuid[]);

select tests.authenticate_as(:'assist_id');
select is((select counterpart_code || ' + ' || counterpart_more from public.general_ledger(:'e1_id', '2026-03-10', '2026-03-10', '4011000', '4011000')),
          '6011000 + 1', 'la ligne fournisseur a pour contrepartie principale 6011 et un autre compte');
select is((select counterpart_code || ' + ' || counterpart_more from public.general_ledger(:'e1_id', '2026-03-10', '2026-03-10', '6011000', '6011000')),
          '4011000 + 0', 'la charge a pour contrepartie le fournisseur seul');
select is((select counterpart_code from public.general_ledger(:'e1_id', '2026-03-10', '2026-03-10', '4452000', '4452000')),
          '4011000', 'la TVA a pour contrepartie le fournisseur');
select is((select jsonb_array_length(counterparts) from public.general_ledger(:'e1_id', '2026-03-10', '2026-03-10', '4011000', '4011000')),
          2, 'la liste complète contient les deux comptes opposés');
select is((select (counterparts -> 0 ->> 'amount')::bigint from public.general_ledger(:'e1_id', '2026-03-10', '2026-03-10', '4011000', '4011000')),
          1000::bigint, 'le montant de la contrepartie principale est celui du compte opposé');
select is((select counterpart_code || ' + ' || counterpart_more from public.general_ledger(:'e1_id', '2026-03-11', '2026-03-11', '6251000', '6251000')),
          '4710000 + 0', 'écriture à deux lignes : une seule contrepartie');
select is((select counterpart_more from public.general_ledger(:'e1_id', '2026-03-12', '2026-03-12', '4710000', '4710000')),
          0, 'deux lignes sur le même compte opposé comptent pour un seul compte');
select is((select (counterparts -> 0 ->> 'amount')::bigint from public.general_ledger(:'e1_id', '2026-03-12', '2026-03-12', '4710000', '4710000')),
          500::bigint, 'leurs montants s''additionnent');
select is((select third_party_name from public.general_ledger(:'e1_id', '2026-03-10', '2026-03-10', '4011000', '4011000')),
          'NSIA Assurances', 'le nom du tiers est fourni avec son code');

select * from finish();
rollback;
