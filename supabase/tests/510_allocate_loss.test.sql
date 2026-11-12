-- Rejeu de la recette du 12/11/2026 : AN-38. L'affectation d'une perte se reporte à nouveau (129) ; le montant affecté
-- d'un bénéfice doit égaler le résultat en instance.
begin;
select plan(14);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('manager@a.test', :'a_id', 'Chef') as id \gset mgr_
select tests.create_entity(:'a_id', 'SARL Perte') as id \gset loss_
select tests.create_entity(:'a_id', 'SARL Bénéfice') as id \gset gain_
select tests.create_entity(:'a_id', 'SARL Mixte') as id \gset mix_
select tests.assign(:'mgr_id', :'a_id', 'manager', :'mix_id');
select tests.assign(:'mgr_id', :'a_id', 'manager', :'loss_id');
select tests.assign(:'mgr_id', :'a_id', 'manager', :'gain_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values
  (:'a_id', :'loss_id', '2027-01-01', '2027-12-31'), (:'a_id', :'gain_id', '2027-01-01', '2027-12-31'), (:'a_id', :'mix_id', '2027-01-01', '2027-12-31');
select id as id from public.fiscal_years where entity_id = :'loss_id' \gset lfy_
select id as id from public.fiscal_years where entity_id = :'gain_id' \gset gfy_
select public.create_journals_from_template(:'loss_id', null);
select public.create_journals_from_template(:'gain_id', null);
select public.create_journals_from_template(:'mix_id', null);
select id as id from public.fiscal_years where entity_id = :'mix_id' \gset mfy_
-- À-nouveaux validés : perte de 100 000 (130 au débit) et bénéfice de 500 000 (130 au crédit)
select tests.make_entry(:'loss_id', 'AN', '2027-01-01', 'À-nouveaux', '[{"account":"1300000","debit":100000},{"account":"1011000","credit":100000}]', :'mgr_id') as id \gset lan_
select tests.make_entry(:'gain_id', 'AN', '2027-01-01', 'À-nouveaux', '[{"account":"1011000","debit":500000},{"account":"1300000","credit":500000}]', :'mgr_id') as id \gset gan_
-- Dossier mixte : bénéfice 2026 en instance sur 1301000 (650 000) et perte 2027 sur 1300000 (200 000)
select tests.make_entry(:'mix_id', 'AN', '2027-01-01', 'À-nouveaux', '[{"account":"1301000","credit":650000},{"account":"1300000","debit":200000},{"account":"1011000","debit":450000}]', :'mgr_id') as id \gset man_
select tests.authenticate_as(:'mgr_id');
select public.validate_entries(array[:'lan_id', :'gan_id', :'man_id']::uuid[]);

select is(public.pending_result(:'loss_id', :'lfy_id'), -100000::bigint, 'résultat en instance : perte de 100 000');
select is(public.pending_result(:'gain_id', :'gfy_id'), 500000::bigint, 'résultat en instance : bénéfice de 500 000');

-- Perte : aucune répartition, report à nouveau débiteur
select throws_ok(format('select public.allocate_result(%L, %L, ''2027-06-30'', 0, 0, 0, 100000)', :'loss_id', :'lfy_id'), '23514', null, 'perte : une répartition (réserve, dividende, report créditeur) est refusée');
select public.allocate_result(:'loss_id', :'lfy_id', '2027-06-30', 0, 0, 0, 0) as id \gset laff_
select is((select string_agg(a.code || '=' || l.debit || '/' || l.credit, ', ' order by a.code)
             from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'laff_id' and (l.debit > 0 or l.credit > 0)),
          '1290000=100000/0, 1300000=0/100000', 'perte : débit 129, crédit 130 du montant de la perte');
select ok(public.validate_entry(:'laff_id') is not null, 'l''écriture d''affectation de la perte se valide');
select is(public.pending_result(:'loss_id', :'lfy_id'), 0::bigint, 'après validation : plus de résultat en instance');

-- Bénéfice : le total doit égaler le résultat en instance
select throws_ok(format('select public.allocate_result(%L, %L, ''2027-06-30'', 50000, 100000, 0, 300000)', :'gain_id', :'gfy_id'), '23514', null, 'bénéfice : un total différent du résultat en instance est refusé');
select lives_ok(format('select public.allocate_result(%L, %L, ''2027-06-30'', 50000, 100000, 0, 350000)', :'gain_id', :'gfy_id'), 'bénéfice : le total égal au résultat est accepté');

-- Dossier mixte : bénéfice et perte en instance, traités séparément
select is((select profit || '/' || loss from public.pending_results(:'mix_id', :'mfy_id')), '650000/200000', 'mixte : bénéfice 650 000 et perte 200 000 distingués');
select throws_ok(format('select public.allocate_result(%L, %L, ''2027-06-30'', 65000, 85000, 0, 300000)', :'mix_id', :'mfy_id'), '23514', null, 'mixte : la répartition doit égaler le bénéfice (650 000), pas le net (450 000)');
select public.allocate_result(:'mix_id', :'mfy_id', '2027-06-30', 65000, 85000, 0, 500000) as id \gset maff_
select is((select string_agg(a.code || '=' || l.debit || '/' || l.credit, ', ' order by a.code)
             from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'maff_id' and (l.debit > 0 or l.credit > 0)),
          '1110000=0/65000, 1180000=0/85000, 1210000=0/500000, 1301000=650000/0', 'mixte : 1301000 soldé, réparti en réserve légale, réserves et report créditeur');
select public.carry_forward_loss(:'mix_id', :'mfy_id', '2027-06-30') as id \gset mloss_
select is((select string_agg(a.code || '=' || l.debit || '/' || l.credit, ', ' order by a.code)
             from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'mloss_id' and (l.debit > 0 or l.credit > 0)),
          '1290000=200000/0, 1300000=0/200000', 'mixte : perte reportée à nouveau, 1300000 soldé');
select public.validate_entries(array[:'maff_id', :'mloss_id']::uuid[]);
select is((select profit || '/' || loss from public.pending_results(:'mix_id', :'mfy_id')), '0/0', 'mixte : plus aucun résultat en instance après validation');
select throws_ok(format('select public.carry_forward_loss(%L, %L, ''2027-06-30'')', :'mix_id', :'mfy_id'), '23514', null, 'plus de perte à reporter');

select * from finish();
rollback;
