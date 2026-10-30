-- Bibliothèque de modèles d'écritures (D-021) : cohérence avec le plan de référence, les taux et l'équilibre ; correction Q-013.
begin;
select plan(11);

select tests.create_cabinet('Cabinet A') as id \gset a_

select is((select count(*) from public.entry_templates where cabinet_id = :'a_id' and entity_id is null), 30::bigint, 'un nouveau cabinet reçoit 30 modèles');

select is((select count(*) from public.entry_template_lines l join public.entry_templates t on t.id = l.template_id
            where t.cabinet_id = :'a_id' and not exists (select 1 from public.reference_accounts a where a.code = l.account_code)),
          0::bigint, 'tous les comptes des modèles existent dans le plan de référence');

select is((select count(*) from public.entry_template_lines l join public.entry_templates t on t.id = l.template_id
            join public.reference_accounts a on a.code = l.account_code
            where t.cabinet_id = :'a_id' and l.uses_third_party is distinct from a.is_collective),
          0::bigint, 'le tiers est demandé exactement sur les comptes collectifs');

select is((select count(*) from public.entry_template_lines l join public.entry_templates t on t.id = l.template_id
            where t.cabinet_id = :'a_id' and l.tax_rate_code is not null
              and not exists (select 1 from public.tax_rates r where r.cabinet_id = t.cabinet_id and r.code = l.tax_rate_code)),
          0::bigint, 'tous les taux cités existent');

select is((select count(*) from public.entry_template_lines l join public.entry_templates t on t.id = l.template_id
            where t.cabinet_id = :'a_id' and l.formula = 'percent_of'
              and not exists (select 1 from public.entry_template_lines p where p.template_id = l.template_id and p.line_no = l.ref_line_no and p.line_no < l.line_no)),
          0::bigint, 'un pourcentage se réfère toujours à une ligne qui précède');

-- Équilibre : sauf SALAIRES (retenues saisies à la main), chaque modèle de la bibliothèque a une seule ligne « solde »
-- et au moins une ligne au débit et une au crédit.
select is((select count(*) from public.entry_templates t
            where t.cabinet_id = :'a_id' and t.code not in ('SALAIRES')
              and ((select count(*) from public.entry_template_lines l where l.template_id = t.id and l.formula = 'balance') <> 1
                   or not exists (select 1 from public.entry_template_lines l where l.template_id = t.id and l.side = 'debit')
                   or not exists (select 1 from public.entry_template_lines l where l.template_id = t.id and l.side = 'credit'))),
          0::bigint, 'chaque modèle a une ligne solde, un débit et un crédit');

-- Simulation : base 100 000 et TVA 18 %, la ligne solde équilibre l'écriture et reste positive.
with t as (select t.id, t.code from public.entry_templates t where t.cabinet_id = :'a_id' and t.code not in ('SALAIRES')),
     l as (select t.code, l.*, case l.formula when 'input' then 100000::numeric end as amt from t join public.entry_template_lines l on l.template_id = t.id),
     pct as (select a.code, a.line_no, round(coalesce(b.amt, 0) * 0.18) as amt from l a join l b on b.code = a.code and b.line_no = a.ref_line_no where a.formula = 'percent_of'),
     amounts as (select code, line_no, side, amt from l where formula = 'input' union all select l.code, l.line_no, l.side, pct.amt from l join pct using (code, line_no)),
     sums as (select code, sum(amt) filter (where side = 'debit') as d, sum(amt) filter (where side = 'credit') as c from amounts group by code)
select is((select count(*) from sums where coalesce(d, 0) = coalesce(c, 0)), 0::bigint, 'jamais une écriture déjà équilibrée avant la ligne solde (le solde a toujours un montant)');

select is((select count(*) from public.entry_template_lines l join public.entry_templates t on t.id = l.template_id
            where t.cabinet_id = :'a_id' and l.account_code in ('4221', '5211')),
          0::bigint, 'Q-013 : plus de compte 4221 ni 5211 dans les modèles');
select is((select account_code from public.entry_template_lines l join public.entry_templates t on t.id = l.template_id
            where t.cabinet_id = :'a_id' and t.code = 'SALAIRES' and l.line_no = 6), '422', 'Q-013 : le net à payer vise 422');

-- Rejouable, sans doublon ni écrasement d'un modèle modifié par le cabinet
update public.entry_templates set label = 'Libellé du cabinet' where cabinet_id = :'a_id' and code = 'LOYER';
select public.seed_entry_template_library(:'a_id');
select is((select count(*) from public.entry_templates where cabinet_id = :'a_id' and entity_id is null), 30::bigint, 'rejouer ne crée aucun doublon');
select is((select label from public.entry_templates where cabinet_id = :'a_id' and code = 'LOYER'), 'Libellé du cabinet', 'rejouer n''écrase pas un modèle modifié');

select * from finish();
rollback;
