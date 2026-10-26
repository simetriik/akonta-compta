-- =============================================================================
-- Akonta — Migration 0019 : le poste CJ « Résultat net de l'exercice » est toujours le résultat
-- implicite de l'exercice (classes 6/7/8 hors écriture de détermination du résultat).
-- Les comptes 13x portés par les à-nouveaux (résultat de l'exercice précédent en instance
-- d'affectation, 130/131/139) sont présentés en report à nouveau (CH), comme le prévoit le bilan
-- SYSCOHADA (« Report à nouveau (+ ou -) »). Avant : CJ reprenait le solde 13x de l'an passé et
-- le résultat courant disparaissait du passif (contrôle d'équilibre en échec en cours d'exercice
-- et sur l'exercice N+1 tant que le résultat n'était pas affecté).
-- =============================================================================
update public.statement_mappings
   set account_from = '12', account_to = '13', post_label = 'Report à nouveau et résultat en instance'
 where cabinet_id is null and version = 'SYSCOHADA-2017' and statement = 'balance_sheet_liabilities' and post_code = 'CH';

delete from public.statement_mappings
 where cabinet_id is null and version = 'SYSCOHADA-2017' and statement = 'balance_sheet_liabilities' and post_code = 'CJ';

create or replace function public.statement_posts_full(p_entity uuid, p_fiscal_year uuid, p_statement public.statement_kind, p_version text default 'SYSCOHADA-2017')
returns table (post_code text, post_label text, column_role text, amount bigint, sort_order smallint)
language sql stable as $$
  select * from public.statement_posts(p_entity, p_fiscal_year, p_statement, p_version) where post_code <> 'CJ'
  union all
  select 'CJ', 'Résultat net de l''exercice', 'amount',
         (select -coalesce(sum(b.balance), 0) from public.statement_balances(p_entity, p_fiscal_year) b where left(b.account_code, 1) in ('6', '7', '8'))::bigint, 80::smallint
   where p_statement = 'balance_sheet_liabilities'
  order by 5, 3;
$$;
