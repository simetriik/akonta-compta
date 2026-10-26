#!/usr/bin/env bash
# Contournement d'un écart de l'application : la grille de saisie n'a pas encore de champ « devise ».
# Ce script crée, en BROUILLARD, les deux écritures en devise du jeu de données (opérations « 3 000 EUR » et « 2 000 USD »)
# dans le dossier « Comptoir Aïdé Négoce SARL » ; l'équipe les relit, les modifie au besoin et les VALIDE ensuite dans l'application.
# Prérequis : dossier ouvert, journal AC, tiers FEU et FUS créés, comptes 6012000 et 6056000 présents.
# Usage : recette/injecter-ecritures-devise.sh adresse.de.l.assistant@exemple.test   (auteur des brouillards, doit avoir accès au dossier)
# N'agit QUE sur la base de recette (port 55322).
set -euo pipefail
author="${1:?Usage : $0 adresse-de-l-auteur@exemple.test}"
psql "postgresql://postgres:postgres@127.0.0.1:55322/postgres" -v ON_ERROR_STOP=1 -v author="$author" <<'SQL'
select set_config('recette.author', :'author', false) \gset
do $$
declare
  v_user uuid; v_cab uuid; v_ent uuid; v_fy uuid; v_j uuid; v_e uuid;
  spec record;
begin
  select id, cabinet_id into v_user, v_cab from public.profiles where lower(email) = lower(current_setting('recette.author'));
  if v_user is null then raise exception 'Utilisateur % inconnu', current_setting('recette.author'); end if;
  select id into v_ent from public.entities where cabinet_id = v_cab and name = 'Comptoir Aïdé Négoce SARL';
  if v_ent is null then raise exception 'Dossier « Comptoir Aïdé Négoce SARL » introuvable'; end if;
  select id into v_fy from public.fiscal_years where entity_id = v_ent and date '2027-02-12' between start_date and end_date;
  select id into v_j from public.journals where entity_id = v_ent and code = 'AC';
  if v_fy is null or v_j is null then raise exception 'Exercice 2027 ou journal AC manquant'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', v_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  for spec in
    select * from (values
      (date '2027-02-12', 'Achat de marchandises importées, 3 000 EUR (Euro Import SAS)', 'FACT-EU-3381', 'EUR', 3000.00::numeric, 655.957::numeric, '6012000', 'FEU', 1967871::bigint),
      (date '2027-02-18', 'Achat d''outillage, 2 000 USD (Global Tools Inc.)',            'INV-GT-5520',  'USD', 2000.00::numeric, 612.500::numeric, '6056000', 'FUS', 1225000::bigint)
    ) as t(dt, label, ref, cur, amount, rate, expense, tiers, fcfa)
  loop
    insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, reference, label, currency_code, created_by)
    values (v_cab, v_ent, v_fy, (select id from public.periods where entity_id = v_ent and spec.dt between start_date and end_date), v_j, spec.dt, spec.ref, spec.label, spec.cur, v_user)
    returning id into v_e;
    insert into public.entry_lines (cabinet_id, entity_id, entry_id, line_no, account_id, debit, credit, currency_code, amount_currency, exchange_rate)
    select v_cab, v_ent, v_e, 1, id, spec.fcfa, 0, spec.cur, spec.amount, spec.rate from public.accounts where entity_id = v_ent and code = spec.expense;
    insert into public.entry_lines (cabinet_id, entity_id, entry_id, line_no, account_id, third_party_id, debit, credit, currency_code, amount_currency, exchange_rate)
    select v_cab, v_ent, v_e, 2, a.id, tp.id, 0, spec.fcfa, spec.cur, spec.amount, spec.rate
      from public.accounts a, public.third_parties tp where a.entity_id = v_ent and a.code = '4011000' and tp.entity_id = v_ent and tp.code = spec.tiers;
    if (select count(*) from public.entry_lines where entry_id = v_e) <> 2 then raise exception 'Écriture % incomplète : tiers % ou compte % absent', spec.ref, spec.tiers, spec.expense; end if;
  end loop;
  perform set_config('request.jwt.claims', '', true);
end $$;
SQL
echo "Deux brouillards en devise créés (journal AC, février 2027). À relire et valider dans l'application."
