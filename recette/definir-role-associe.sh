#!/usr/bin/env bash
# Donne le rôle « Associé » (portée cabinet) à un utilisateur invité de l'instance de RECETTE.
# Pourquoi : l'invitation ne crée aucune affectation et seul l'associé peut en créer (écart n° 11, Q-016).
# Usage : recette/definir-role-associe.sh associe@exemple.test        N'agit QUE sur la base de recette (port 55322).
set -euo pipefail
email="${1:?Usage : $0 adresse@exemple.test}"
n=$(psql "postgresql://postgres:postgres@127.0.0.1:55322/postgres" -At -v ON_ERROR_STOP=1 -v email="$email" <<'SQL'
with a as (
  insert into public.assignments (cabinet_id, user_id, role_id, created_by)
  select p.cabinet_id, p.id, r.id, p.id
    from public.profiles p
    join public.roles r on r.cabinet_id = p.cabinet_id and r.code = 'partner'
   where lower(p.email) = lower(:'email')
  on conflict do nothing
  returning 1)
select count(*) from a;
SQL
)
if [ "$n" != "1" ]; then echo "Rien fait : utilisateur $email introuvable ou déjà associé." >&2; exit 1; fi
echo "Rôle Associé donné à $email."
