# Environnement de développement

## Prérequis
| Outil | Version testée | Rôle |
|---|---|---|
| Podman (rootless) | 5.4 | Conteneurs de la pile Supabase. Pas de Docker. |
| Supabase CLI | 2.121 | Pile locale, migrations, seed, tests pgTAP, Edge Functions. |
| Flutter SDK | 3.47 (Dart 3.13) | Application desktop (Linux, Windows, macOS) et mobile (Android, iOS). |
| Android SDK 36 + OpenJDK 21 | — | Build Android. |
| `libsecret-1-dev` (Linux) | — | Compilation de l'application de bureau Linux : trousseau où est conservée la clé de la base locale chiffrée (`sudo apt install libsecret-1-dev`). |
| Python 3.13 + `uv` | — | Service de documents (PDF, Excel DGI). |
| Deno 2 | — | Tests des Edge Functions. |
| `psql` 17 | — | Requêtes manuelles (`psql "$(supabase status -o env | grep DB_URL | cut -d= -f2-)"`). |

## Podman à la place de Docker
La Supabase CLI parle au démon Docker via un socket. Sous Podman rootless :
```bash
systemctl --user enable --now podman.socket
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
```
`scripts/common.sh` exporte `DOCKER_HOST` et active le socket si besoin : tous les scripts du dépôt fonctionnent sans configuration manuelle. Pour utiliser la CLI à la main dans un autre terminal, exporter `DOCKER_HOST` (ou l'ajouter au profil du shell).

## Commandes
| Action | Commande |
|---|---|
| Vérifier/installer l'environnement, télécharger les images | `scripts/setup.sh` |
| Démarrer la pile locale | `scripts/start.sh` |
| Arrêter (données conservées) | `scripts/stop.sh` |
| Recréer la base depuis les migrations + seed de démonstration | `scripts/reset-db.sh` |
| Toute la suite de tests | `scripts/test.sh` (ou `scripts/test.sh sql|flutter|python|edge`) |

Services locaux : API `http://127.0.0.1:54321`, Studio `http://127.0.0.1:54323`, PostgreSQL `127.0.0.1:54322`, boîte mail de test (Mailpit) `http://127.0.0.1:54324`. Les clés locales (`anon`, `service_role`) s'affichent avec `supabase status` ; elles ne valent que pour la pile locale.

## Configuration Supabase (`supabase/config.toml`)
- Auth : mot de passe de 12 caractères minimum avec minuscules, majuscules et chiffres ; inscription publique désactivée (création par invitation uniquement) ; MFA TOTP activée (exigée pour associé et administrateur côté application et RLS).
- Services désactivés en local pour alléger : analytics, realtime, storage vector. Storage, Auth, Edge Runtime et Studio actifs.
- Migrations : `supabase/migrations/` (horodatées, jamais modifiées après fusion). Seed : `supabase/seed.sql` (jeu de démonstration). Tests : `supabase/tests/*.test.sql` (pgTAP, un fichier par domaine, transaction annulée à la fin).

## Organisation du dépôt
```
supabase/        config, migrations, seed, tests pgTAP, functions (Edge, Deno)
app/             application Flutter (desktop + mobile)
service-documents/  service Python (FastAPI) : PDF et modèle Excel DGI
scripts/         installation, démarrage, tests
docs/            pilotage (plan, avancement, décisions, questions), livraisons
inputs/          intrants (lecture seule, non versionnés) : conception, CSV du plan, exports Perfecto, modèle DGI
outputs/         artefacts produits (kit logo…)
```

## Dépannage
- `supabase start` échoue à joindre le démon : vérifier `systemctl --user status podman.socket` et `echo $DOCKER_HOST`.
- Port déjà utilisé : un autre projet Supabase local tourne ; `supabase stop --project-id <autre>`.
- Volumes d'un ancien projet du même nom (`supabase_db_akonta`) : `supabase db reset` recrée la base depuis les migrations.
- Repli sans Supabase CLI : `podman run -e POSTGRES_PASSWORD=postgres -p 54322:5432 public.ecr.aws/supabase/postgres:17.11.0.004` donne un PostgreSQL avec pgTAP ; appliquer les migrations avec `psql -f`, lancer les tests avec `pg_prove` depuis le conteneur. Non utilisé tant que la CLI fonctionne.
