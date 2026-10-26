#!/usr/bin/env bash
# Définit (ou réinitialise) le mot de passe d'un utilisateur de l'instance de RECETTE et confirme son adresse e-mail.
# Pourquoi : l'application n'a pas encore d'écran pour créer son mot de passe depuis le lien d'invitation (voir LISEZMOI.md, « Écarts »).
# Usage : recette/definir-mot-de-passe.sh prenom@exemple.test [mot de passe]    (défaut : Recette-2027-Equipe!)
# N'agit QUE sur la base de recette (port 55322).
set -euo pipefail
email="${1:?Usage : $0 adresse@exemple.test [mot de passe]}"
password="${2:-Recette-2027-Equipe!}"
if [ "${#password}" -lt 12 ] || ! [[ "$password" =~ [a-z] && "$password" =~ [A-Z] && "$password" =~ [0-9] ]]; then
  echo "Le mot de passe doit avoir 12 caractères minimum, avec minuscule, majuscule et chiffre." >&2; exit 2
fi
n=$(psql "postgresql://postgres:postgres@127.0.0.1:55322/postgres" -At -v ON_ERROR_STOP=1 -v email="$email" -v pw="$password" <<'SQL'
with u as (
  update auth.users
     set encrypted_password = extensions.crypt(:'pw', extensions.gen_salt('bf')),
         email_confirmed_at = coalesce(email_confirmed_at, now()), updated_at = now()
   where lower(email) = lower(:'email') returning 1)
select count(*) from u;
SQL
)
if [ "$n" != "1" ]; then echo "Aucun utilisateur $email dans la base de recette : l'inviter d'abord depuis l'application." >&2; exit 1; fi
echo "Mot de passe défini pour $email."
