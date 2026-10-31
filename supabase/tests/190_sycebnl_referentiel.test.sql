-- Référentiel SYCEBNL (D-022) : plan de référence, copie à la création de l'entité, sens des comptes, immutabilité
-- du référentiel, modèles d'écritures par référentiel.
begin;
select plan(24);

select tests.create_cabinet('Cabinet A') as id \gset a_

-- Plan de référence ------------------------------------------------------------------------------------------------
select is((select count(*) from public.reference_accounts where system = 'sycebnl'), 1130::bigint, 'le plan SYCEBNL compte 1 130 comptes');
select is((select count(*) from public.reference_accounts r where system = 'sycebnl' and parent_code is not null
            and not exists (select 1 from public.reference_accounts p where p.system = 'sycebnl' and p.code = r.parent_code)),
          0::bigint, 'tout parent du plan SYCEBNL existe');
select ok(not exists (select 1 from public.reference_accounts where system = 'normal' and code = '7010'
                       and label ilike '%cotisation%'), 'les plans des deux systèmes sont distincts');

-- Entité SYCEBNL : copie du plan -------------------------------------------------------------------------------------
insert into public.entities (cabinet_id, name, accounting_system) values (:'a_id', 'Association Espoir', 'sycebnl') returning id as sy_id \gset
insert into public.entities (cabinet_id, name) values (:'a_id', 'Société Normale') returning id as no_id \gset

select is((select count(*) from public.accounts where entity_id = :'sy_id'),
          (select count(distinct rpad(code, 7, '0')) from public.reference_accounts where system = 'sycebnl' and class between 1 and 8),
          'une entité SYCEBNL reçoit le plan SYCEBNL (classes 1 à 8), un compte par numéro complété');
select is((select count(*) from public.accounts where entity_id = :'sy_id' and reference_system is distinct from 'sycebnl'),
          0::bigint, 'tous ses comptes viennent du référentiel SYCEBNL');
select is((select count(*) from public.accounts where entity_id = :'no_id' and reference_system is distinct from 'normal'),
          0::bigint, 'une entité normale ne reçoit que des comptes SYSCOHADA');

select is((select label from public.accounts where entity_id = :'sy_id' and code = '7010000'), 'Cotisations des adhérents', 'compte 701 : cotisations des adhérents');
select ok((select allow_posting from public.accounts where entity_id = :'sy_id' and code = '7010000'), 'un compte sans subdivision est imputable');
select ok(not (select allow_posting from public.accounts where entity_id = :'sy_id' and code = '1010000'), 'un compte subdivisé n''est pas imputable');

-- Sens normal conservé (régression : l'héritage depuis le premier compte de la classe le faussait) ------------------
select is((select normal_side::text from public.accounts where entity_id = :'sy_id' and code = '2800000'), 'credit', 'SYCEBNL : amortissements (28) au crédit');
select is((select normal_side::text from public.accounts where entity_id = :'sy_id' and code = '1390000'), 'debit', 'SYCEBNL : déficit (139) au débit');
select is((select normal_side::text from public.accounts where entity_id = :'sy_id' and code = '6190000'), 'credit', 'SYCEBNL : rabais obtenus (619) au crédit');
select is((select normal_side::text from public.accounts where entity_id = :'no_id' and code = '2800000'), 'credit', 'SYSCOHADA : amortissements (28) au crédit');

-- Hiérarchie ---------------------------------------------------------------------------------------------------------
select is((select p.code from public.accounts a join public.accounts p on p.id = a.parent_id where a.entity_id = :'sy_id' and a.code = '1010000'),
          '1000000', 'le compte 101 est rattaché à 10');
select is((select parent_id from public.accounts where entity_id = :'sy_id' and code = '1100000'), null,
          'le compte 11 est une racine (et non un enfant de 10)');

-- Subdivision créée à la main : hérite du sens et de l'origine -------------------------------------------------------
insert into public.accounts (cabinet_id, entity_id, code, label) values (:'a_id', :'sy_id', '7010100', 'Cotisations annuelles');
select is((select normal_side::text || '/' || reference_system from public.accounts where entity_id = :'sy_id' and code = '7010100'),
          'credit/sycebnl', 'une subdivision hérite du sens et du référentiel de son parent');

-- Référentiel immuable ------------------------------------------------------------------------------------------------
select ok(tests.fails_with(format('update public.entities set accounting_system = ''normal'' where id = %L', :'sy_id'), '23514'),
          'le référentiel d''une entité ne change pas');
select ok(tests.fails_with(format('insert into public.entities (cabinet_id, name, accounting_system) values (%L, ''X'', ''minimal'')', :'a_id'), '23514'),
          'un référentiel inconnu est refusé');

-- Modèles d'écritures par référentiel --------------------------------------------------------------------------------
select is((select count(*) from public.entry_templates where cabinet_id = :'a_id' and entity_id is null and accounting_system = 'sycebnl'), 19::bigint,
          'un cabinet reçoit 19 modèles SYCEBNL');
select is((select count(*) from public.entry_templates where cabinet_id = :'a_id' and entity_id is null and accounting_system = 'normal'), 30::bigint,
          'et conserve ses 30 modèles SYSCOHADA');
select is((select count(*) from public.entry_template_lines l join public.entry_templates t on t.id = l.template_id
            where t.cabinet_id = :'a_id' and t.accounting_system = 'sycebnl'
              and not exists (select 1 from public.reference_accounts a where a.system = 'sycebnl' and a.code = l.account_code
                                 and not exists (select 1 from public.reference_accounts c where c.system = 'sycebnl' and c.parent_code = a.code))),
          0::bigint, 'chaque compte des modèles SYCEBNL existe au plan SYCEBNL et est imputable');
select is((select count(*) from public.entry_template_lines l join public.entry_templates t on t.id = l.template_id
            join public.reference_accounts a on a.system = 'sycebnl' and a.code = l.account_code
            where t.cabinet_id = :'a_id' and t.accounting_system = 'sycebnl' and l.uses_third_party is distinct from a.is_collective),
          0::bigint, 'le tiers est demandé exactement sur les comptes collectifs');
select is((select count(*) from public.entry_templates t
            where t.cabinet_id = :'a_id' and t.accounting_system = 'sycebnl'
              and ((select count(*) from public.entry_template_lines l where l.template_id = t.id and l.formula = 'balance') <> 1
                   or not exists (select 1 from public.entry_template_lines l where l.template_id = t.id and l.side = 'debit')
                   or not exists (select 1 from public.entry_template_lines l where l.template_id = t.id and l.side = 'credit'))),
          0::bigint, 'chaque modèle SYCEBNL a une seule ligne solde, un débit et un crédit');
select is((select count(*) from public.seed_sycebnl_template_library(:'a_id') ), 1::bigint, 'le chargement des modèles est rejouable');

select * from finish();
rollback;
