-- Correction de Q-018 / D-023 : les plans d'entités créés avant la migration 20261031100001 ont hérité le sens normal du
-- compte de classe au lieu de celui du plan de référence (ex. 2800000 amortissements au débit, 1390000 perte au crédit).
-- Les comptes subdivisés à la main portent le code de référence de leur parent : ils reprennent le sens de ce parent,
-- comme le fait déjà l'héritage à la création.
-- Rejouable : ne touche que les comptes dont le sens diffère de la référence. Renvoie le nombre de comptes corrigés.

create or replace function public.fix_reference_account_sides()
returns integer language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  -- Le déclencheur interdit de modifier le sens d'un compte : suspendu le temps de la correction.
  alter table public.accounts disable trigger accounts_validate;
  update public.accounts a
     set normal_side = r.normal_side
    from public.reference_accounts r
   where r.system = a.reference_system and r.code = a.reference_code
     and a.normal_side <> r.normal_side;
  get diagnostics v_count = row_count;
  alter table public.accounts enable trigger accounts_validate;
  return v_count;
end $$;
revoke execute on function public.fix_reference_account_sides() from public, anon, authenticated;

select public.fix_reference_account_sides();
