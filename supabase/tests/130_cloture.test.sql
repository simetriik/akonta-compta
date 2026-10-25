-- Module 9 — Clôture : contrôles bloquants / alertes levables, résultat et IS avec minimum, états financiers (postes, équilibre), clôture provisoire,
-- réouverture, arrêté définitif avec archive, à-nouveaux N+1, affectation du résultat (§7, §10.9).
begin;
select plan(37);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('partner@a.test', :'a_id') as id \gset partner_
select tests.create_user('manager@a.test', :'a_id') as id \gset manager_
select tests.create_user('assist@a.test',  :'a_id') as id \gset assist_
select tests.create_entity(:'a_id', 'SARL Démo') as id \gset e1_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'e1_id' \gset fy_
select public.create_journals_from_template(:'e1_id', null);
insert into public.journals (cabinet_id, entity_id, code, label, type, treasury_account_id)
  select :'a_id', :'e1_id', 'BQ', 'Ecobank', 'bank', id from public.accounts where entity_id = :'e1_id' and code = '5210000';
insert into public.third_parties (cabinet_id, entity_id, code, name, type) values (:'a_id', :'e1_id', 'CHU', 'CHU', 'customer'), (:'a_id', :'e1_id', 'SOB', 'SOBEBRA', 'supplier');

-- Exercice simple : capital 10 M en banque ; vente 10 M HT (TVA 1,8 M) encaissée ; achat 6 M HT ; amende 200 000 ; acompte IS 300 000
select tests.make_entry(:'e1_id', 'AN', '2026-01-01', 'AN', '[{"account":"5210000","debit":10000000},{"account":"1011000","credit":10000000}]', :'assist_id') as id \gset an_
select tests.make_entry(:'e1_id', 'VT', '2026-03-10', 'Vente', '[{"account":"4111000","tp":"CHU","debit":11800000},{"account":"7011000","credit":10000000},{"account":"4431000","credit":1800000}]', :'assist_id') as id \gset v1_
select tests.make_entry(:'e1_id', 'BQ', '2026-04-10', 'Encaissement', '[{"account":"5210000","debit":11800000},{"account":"4111000","tp":"CHU","credit":11800000}]', :'assist_id') as id \gset b1_
select tests.make_entry(:'e1_id', 'AC', '2026-05-10', 'Achat', '[{"account":"6011000","debit":6000000},{"account":"4452000","debit":1080000},{"account":"4011000","tp":"SOB","credit":7080000}]', :'assist_id') as id \gset a1_
select tests.make_entry(:'e1_id', 'OD', '2026-06-10', 'Amende fiscale', '[{"account":"6471000","debit":200000},{"account":"5210000","credit":200000}]', :'assist_id') as id \gset od1_
select tests.make_entry(:'e1_id', 'BQ', '2026-07-10', 'Acompte IS', '[{"account":"4492000","debit":300000},{"account":"5210000","credit":300000}]', :'assist_id') as id \gset ac1_
select tests.make_entry(:'e1_id', 'OD', '2026-08-10', 'Brouillard oublié', '[{"account":"6221000","debit":1000},{"account":"4710000","credit":1000}]', :'assist_id') as id \gset draft_
select public.validate_entries(array[:'an_id', :'v1_id', :'b1_id', :'a1_id', :'od1_id', :'ac1_id']::uuid[]);

-- 1. Contrôles : un brouillard bloque ; alertes non revues
select tests.authenticate_as(:'manager_id');
select is((select status::text from public.run_closing_checks(:'e1_id', :'fy_id') where code = 'drafts_pending'), 'failed', 'contrôle bloquant : brouillard en attente');
select is((select status::text from public.run_closing_checks(:'e1_id', :'fy_id') where code = 'unbalanced'), 'passed', 'grand livre équilibré');
select is((select status::text from public.run_closing_checks(:'e1_id', :'fy_id') where code = 'unreviewed'), 'failed', 'alerte : écritures non revues');
select throws_ok(format('select public.close_provisional(%L, %L)', :'e1_id', :'fy_id'), '23514', null, 'clôture provisoire refusée tant qu''un bloquant échoue');
select throws_ok(format('select public.waive_closing_check(%L, ''drafts_pending'', ''on verra'')', :'fy_id'), '23514', null, 'un contrôle bloquant ne se lève pas');
delete from public.entries where id = :'draft_id';
select lives_ok(format('select public.waive_closing_check(%L, ''unreviewed'', ''Revue globale faite sur la balance'')', :'fy_id'), 'alerte levée avec commentaire');
select throws_ok(format('select public.waive_closing_check(%L, ''unlocked_periods'', '''')', :'fy_id'), '23514', null, 'commentaire obligatoire');

-- 2. Résultat comptable et IS : produits 10 M - charges 6,2 M = 3,8 M ; réintégration amende 200 000 → RF 4 M ; IS 30 % = 1,2 M > minimum 0,5 % CA (50 000, plancher 250 000) ; acompte 300 000 → solde 900 000
select is(public.accounting_result(:'e1_id', :'fy_id'), 3800000::bigint, 'résultat comptable avant impôt 3 800 000');
select ok((select (public.propose_tax_adjustments(:'e1_id', :'fy_id') -> 1 ->> 'amount')::bigint = 200000), 'tableau de passage : amende 200 000 proposée en réintégration');
select public.compute_income_tax(:'e1_id', :'fy_id', '[{"code":"AMENDES","kind":"add_back","amount":200000}]'::jsonb) as id \gset tax_
select is((select taxable_result || '/' || tax_due || '/' || balance_due from public.tax_computations where id = :'tax_id'), '4000000/1200000/900000', 'résultat fiscal 4 M, IS 1,2 M, solde 900 000 après acompte');
select is((select status::text from public.entries where generated_source = 'income_tax:' || :'fy_id'), 'draft', 'écriture d''IS en brouillard');
select is((select credit from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = (select id from public.entries where generated_source = 'income_tax:' || :'fy_id') and a.code = '4492000'), 300000::bigint, 'acompte imputé');
-- Minimum d''impôt : petite activité
select tests.clear_auth();
select tests.create_entity(:'a_id', 'Petite SARL') as id \gset e2_
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e2_id', '2026-01-01', '2026-12-31');
select id as id from public.fiscal_years where entity_id = :'e2_id' \gset fy2_
select public.create_journals_from_template(:'e2_id', null);
select tests.make_entry(:'e2_id', 'OD', '2026-03-10', 'Vente', '[{"account":"4710000","debit":1000000},{"account":"7011000","credit":1000000}]', :'partner_id') as id \gset pv_
select tests.make_entry(:'e2_id', 'OD', '2026-03-11', 'Charges', '[{"account":"6221000","debit":950000},{"account":"4710000","credit":950000}]', :'partner_id') as id \gset pc_
select public.validate_entries(array[:'pv_id', :'pc_id']::uuid[]);
select tests.authenticate_as(:'partner_id', 'aal2');
select public.compute_income_tax(:'e2_id', :'fy2_id', '[]'::jsonb) as id \gset tax2_
select is((select computed_tax || '/' || minimum_tax || '/' || tax_due from public.tax_computations where id = :'tax2_id'), '15000/250000/250000', 'minimum d''impôt : max(15 000 ; 0,5 % × 1 M = 5 000 ; plancher 250 000) = 250 000');

-- 3. États financiers : postes et équilibre (avant écriture de résultat : résultat implicite)
select public.validate_entry((select id from public.entries where generated_source = 'income_tax:' || :'fy_id'));
select public.generate_financial_statements(:'e1_id', :'fy_id') as id \gset fs_
select is((select amount from public.statement_posts(:'e1_id', :'fy_id', 'income_statement') where post_code = 'TA'), 10000000::bigint, 'poste TA ventes de marchandises = 10 M');
select is((select amount from public.statement_posts(:'e1_id', :'fy_id', 'income_statement') where post_code = 'RA'), -6000000::bigint, 'poste RA achats = -6 M');
select is((select amount from public.statement_posts(:'e1_id', :'fy_id', 'income_statement') where post_code = 'RS'), -1200000::bigint, 'poste RS impôt = -1,2 M');
select is((select amount from public.statement_posts(:'e1_id', :'fy_id', 'balance_sheet_assets') where post_code = 'BS'), 21300000::bigint, 'poste BS trésorerie = 10 M + 11,8 M - 0,2 M - 0,3 M = 21,3 M');
select is((select amount from public.statement_posts(:'e1_id', :'fy_id', 'balance_sheet_liabilities') where post_code = 'DJ'), 7080000::bigint, 'poste DJ fournisseurs = 7 080 000');
select ok((select bool_and((c->>'passed')::boolean) from public.financial_statements f, jsonb_array_elements(f.checks) c where f.id = :'fs_id'), 'contrôles de cohérence des états passés (actif = passif + résultat ; résultat = grand livre)');

-- 4. Détermination du résultat, clôture provisoire, réouverture, arrêté définitif
select public.generate_result_entry(:'e1_id', :'fy_id') as id \gset res_
select is((select credit from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'res_id' and a.code = '1310000'), 2600000::bigint, 'bénéfice net 2 600 000 au crédit de 131');
select public.validate_entry(:'res_id');
select is((select amount from public.statement_posts(:'e1_id', :'fy_id', 'income_statement') where post_code = 'TA'), 10000000::bigint, 'compte de résultat inchangé après l''écriture de détermination du résultat');
select is((select sum(amount)::bigint from public.statement_posts_full(:'e1_id', :'fy_id', 'balance_sheet_liabilities') where post_code = 'CJ'), 2600000::bigint, 'résultat net au passif après l''écriture de détermination du résultat');
select public.review_entry(:'v1_id', 'reviewed');
update public.closing_checks set status = 'waived', waive_comment = 'test' where fiscal_year_id = :'fy_id' and severity = 'warning' and status = 'failed';
select public.run_closing_checks(:'e1_id', :'fy_id');
update public.closing_checks set status = 'waived', waive_comment = 'test' where fiscal_year_id = :'fy_id' and severity = 'warning' and status = 'failed';
select lives_ok(format('select public.close_provisional(%L, %L)', :'e1_id', :'fy_id'), 'clôture provisoire');
select is((select status::text from public.fiscal_years where id = :'fy_id'), 'closing', 'exercice en clôture ; périodes verrouillées');
select tests.clear_auth();
select tests.make_entry(:'e1_id', 'OD', '2026-09-01', 'Tardive', '[{"account":"6221000","debit":10},{"account":"4710000","credit":10}]', :'assist_id') as id \gset late_
select throws_ok(format('select public.validate_entry(%L)', :'late_id'), '23514', null, 'plus de validation : toutes les périodes sont verrouillées');
delete from public.entries where id = :'late_id';
select tests.authenticate_as(:'manager_id');
select throws_ok(format('select public.close_final(%L, %L, ''ARRETER 2026'')', :'e1_id', :'fy_id'), '42501', null, 'chef de mission : pas d''arrêté définitif');
select lives_ok(format('select public.reopen_fiscal_year(%L, %L, ''Facture oubliée'')', :'e1_id', :'fy_id'), 'réouverture avec motif');
select lives_ok(format('select public.close_provisional(%L, %L)', :'e1_id', :'fy_id'), 'nouvelle clôture provisoire');
select tests.authenticate_as(:'partner_id', 'aal2');
select throws_ok(format('select public.close_final(%L, %L, ''oui'')', :'e1_id', :'fy_id'), '23514', null, 'double confirmation : texte exact exigé');
select public.close_final(:'e1_id', :'fy_id', 'ARRETER 2026') as id \gset arc_
select is((select status::text from public.fiscal_years where id = :'fy_id'), 'closed', 'exercice clôturé définitivement');
select ok((select length(hash) = 64 and manifest ? 'ledger_hash' from public.closing_archives where id = :'arc_id'), 'archive de clôture avec empreintes');
select tests.clear_auth();
select throws_ok(format('update public.fiscal_years set capital = 1 where id = %L', :'fy_id'), '42501', null, 'exercice clôturé : intangible');
select throws_ok(format('delete from public.closing_archives where id = %L', :'arc_id'), '42501', null, 'archive intangible');

-- 5. À-nouveaux N+1 et affectation
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2027-01-01', '2027-12-31');
select tests.authenticate_as(:'manager_id');
select public.generate_opening_balances(:'e1_id', :'fy_id') as id \gset an27_
select is((select sum(debit) - sum(credit) from public.entry_lines where entry_id = :'an27_id'), 0::numeric, 'à-nouveaux équilibrés');
select is((select credit from public.entry_lines l join public.accounts a on a.id = l.account_id where l.entry_id = :'an27_id' and a.code = '1300000'), 2600000::bigint, 'résultat 2026 repris en 1300 (en instance d''affectation)');
select is((select credit from public.entry_lines l join public.accounts a on a.id = l.account_id left join public.third_parties t on t.id = l.third_party_id where l.entry_id = :'an27_id' and a.code = '4011000' and t.code = 'SOB'), 7080000::bigint, 'fournisseur SOBEBRA repris au crédit (détail par tiers)');
select public.validate_entry(:'an27_id');
select public.allocate_result(:'e1_id', (select id from public.fiscal_years where entity_id = :'e1_id' and label = '2027'), '2027-06-30', 260000, 1340000, 1000000, 0) as id \gset aff_
select is((select sum(credit) from public.entry_lines where entry_id = :'aff_id'), 2600000::numeric, 'affectation : réserve légale + réserves + dividendes = résultat');
select tests.clear_auth();

select * from finish();
rollback;
