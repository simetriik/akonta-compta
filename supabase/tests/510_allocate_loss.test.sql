-- Rejeu de la recette du 12/11/2026 : AN-38. L'affectation d'une perte se reporte à nouveau (129) ; le montant affecté
-- d'un bénéfice doit égaler le résultat en instance.
begin;
select plan(8);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('manager@a.test', :'a_id', 'Chef') as id \gset mgr_
select tests.create_entity(:'a_id', 'SARL Perte') as id \gset loss_
select tests.create_entity(:'a_id', 'SARL Bénéfice') as id \gset gain_
select tests.assign(:'mgr_id', :'a_id', 'manager', :'loss_id');
select tests.assign(:'mgr_id', :'a_id', 'manager', :'gain_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values
  (:'a_id', :'loss_id', '2027-01-01', '2027-12-31'), (:'a_id', :'gain_id', '2027-01-01', '2027-12-31');
select id as id from public.fiscal_years where entity_id = :'loss_id' \gset lfy_
select id as id from public.fiscal_years where entity_id = :'gain_id' \gset gfy_
select public.create_journals_from_template(:'loss_id', null);
select public.create_journals_from_template(:'gain_id', null);
-- À-nouveaux validés : perte de 100 000 (130 au débit) et bénéfice de 500 000 (130 au crédit)
select tests.make_entry(:'loss_id', 'AN', '2027-01-01', 'À-nouveaux', '[{"account":"1300000","debit":100000},{"account":"1011000","credit":100000}]', :'mgr_id') as id \gset lan_
select tests.make_entry(:'gain_id', 'AN', '2027-01-01', 'À-nouveaux', '[{"account":"1011000","debit":500000},{"account":"1300000","credit":500000}]', :'mgr_id') as id \gset gan_
select tests.authenticate_as(:'mgr_id');
select public.validate_entries(array[:'lan_id', :'gan_id']::uuid[]);

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

select * from finish();
rollback;
