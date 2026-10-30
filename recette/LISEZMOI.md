# Recette interne d'Akonta : mode d'emploi

Ce dossier prépare le déroulé de `docs/recette-interne.md` (13 étapes, rôles réels) sur une instance de **test dédiée**, vierge, distincte de la pile de développement et de toute base destinée au cabinet ABC. Tout (cabinet, utilisateurs, dossier, écritures) est créé par l'équipe dans l'application.

## 1. Contenu du dossier

| Fichier | Rôle |
|---|---|
| `jeu-de-donnees.md` | La PME fictive (Comptoir Aïdé Négoce SARL, Cotonou), ses tiers, les à-nouveaux, **45 opérations** de janvier à mars 2027, le relevé, les pièces, les données d'inventaire et la balance attendue |
| `export-perfecto-simule.txt` | Faux journal Perfecto (Windows-1252, tabulations, CRLF) : à-nouveaux au 01/01/2027 (étape 4) |
| `releve-ecobank-janvier.csv` | Relevé bancaire de janvier avec lignes volontairement non rapprochables (étape 8) |
| `pieces/` | 12 pièces justificatives fictives (8 PDF, 4 JPEG) correspondant à des opérations |
| `generer-jeu.py` | Générateur unique de tous ces fichiers (rejouable) |
| `bootstrap-admin.sql` | Amorçage de la base de recette (cabinet-coquille + administrateur) |
| `definir-mot-de-passe.sh` | Fixe le mot de passe d'un utilisateur invité (voir « Écarts », n° 1) |
| `injecter-ecritures-devise.sh` | Crée en brouillard les deux écritures en devise (voir « Écarts », n° 3) |
| `lancer-service-documents.sh` | Lance le service d'exports PDF / Excel / liasse DGI (port 8101) |

## 2. Instance de test

| Élément | Valeur |
|---|---|
| Projet Supabase local | `akonta-recette` (la pile de développement `akonta` n'est pas touchée) |
| API | `http://127.0.0.1:55321` |
| Studio (base) | `http://127.0.0.1:55323` |
| Boîte mail de test (invitations, réinitialisations) | `http://127.0.0.1:55324` |
| PostgreSQL | `postgresql://postgres:postgres@127.0.0.1:55322/postgres` |
| Clé publiable | `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH` (publique par construction, valeur standard de la pile locale) |

**Administrateur technique** : `admin.recette@akonta.test` / `Recette-Admin-2027!` (à changer si l'instance sort de ce poste ; la double authentification TOTP est exigée à la première connexion).

La base ne contient au départ que le plan de référence SYSCOHADA (migration) et ce compte. Un **cabinet-coquille** nommé « Cabinet de recette Simetriik » existe aussi : un profil doit toujours référencer un cabinet et l'application n'a pas d'écran de création de cabinet. L'associé le renomme et le paramètre à l'étape 2.

## 3. Réinitialiser (à volonté)

```bash
scripts/reset-recette.sh          # remise à zéro complète : migrations rejouées, toutes données supprimées, administrateur recréé
scripts/reset-recette.sh --hard   # idem, après suppression des volumes (y compris les fichiers du Storage)
scripts/reset-recette.sh --stop   # arrête la pile de recette (données conservées)
```

Le script ne touche qu'au projet `akonta-recette` (il vérifie le nom du projet et le port 55322 avant d'agir). Prévoir environ une minute. Prérequis : Podman (socket utilisateur, géré par `scripts/common.sh`), Supabase CLI, `psql`.

## 4. Lancer l'application

Dans `app/`, pointer l'application sur l'instance de test (les valeurs par défaut visent la pile de développement) :

```bash
# Ordinateur (Linux ; la configuration du dépôt ne contient que les cibles Linux, Android, iOS et web)
flutter run -d linux --dart-define=SUPABASE_URL=http://127.0.0.1:55321 --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH

# Mobile Android (téléphone sur le même réseau : IP locale du poste ; émulateur : 10.0.2.2)
flutter run -d <appareil> --dart-define=SUPABASE_URL=http://<IP-du-poste>:55321 --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
```

- Le HTTP en clair est autorisé **uniquement** dans le manifeste de débogage Android : utiliser un build de débogage (`flutter run`, `flutter build apk --debug`), pas un build de production.
- Les exports PDF / Excel et la liasse DGI exigent le service de documents : dans un autre terminal, `recette/lancer-service-documents.sh` (port 8101, déjà déclaré aux fonctions Edge par `reset-recette.sh`).
- Les invitations envoyées par l'application arrivent dans la boîte mail de test (`http://127.0.0.1:55324`), pas dans de vraies boîtes.

### 4 bis. Recette en équipe sur le réseau local (navigateur)

Un seul poste héberge l'instance ; les collègues ouvrent Akonta dans leur navigateur, sans rien installer.

```bash
scripts/reset-recette.sh                  # sur le poste hôte : instance vierge
recette/lancer-service-documents.sh       # terminal 2 : exports PDF / Excel / DGI
recette/lancer-reseau.sh                  # terminal 3 : compile le build web (1re fois) et sert page + API sur le port 8080
```

Le script affiche l'adresse à donner aux collègues (ex. `http://192.168.1.232:8080`). Le build est compilé avec `SUPABASE_URL=auto` : la page et l'API partagent la même origine (relais de `recette/serveur-reseau.py`), donc ni CORS ni adresse à recompiler. `--rebuild` recompile après une modification du code ; `--port` change le port.

- **Pare-feu** : ouvrir le port 8080 du poste hôte aux machines du réseau si une page ne s'ouvre pas. Les ports 55322 (PostgreSQL, mot de passe `postgres`) et 55323 (Studio) sont publiés par la pile Supabase sur toutes les interfaces : ne pas les ouvrir au réseau (réseau de confiance, données fictives uniquement).
- **Invitations** : les e-mails arrivent dans la boîte de test du poste hôte (`http://127.0.0.1:55324`), pas chez les collègues ; l'hôte fixe leur mot de passe avec `recette/definir-mot-de-passe.sh` (écart n° 1).
- **Limites du navigateur** : sur `http://` (pas HTTPS), le navigateur refuse la caméra : pour l'étape 5.5, déposer une photo existante au lieu de photographier ; la capture directe se teste sur un build Android de débogage (§ 4).
- **Une session par navigateur et par personne** : un profil de navigateur distinct (ou une fenêtre privée) par rôle quand une même personne joue plusieurs rôles.

## 5. Ordre des étapes (rappel de `docs/recette-interne.md`)

1. **Socle** (administrateur) : connexion, TOTP, invitations, verrouillage et déconnexion, isolation des données.
2. **Cabinet et dossier** (associé) : paramétrage, ouverture du dossier en 5 étapes avec la fiche de `jeu-de-donnees.md` § 1, affectations.
3. **Référentiels** (chef de mission) : subdivisions, tiers (§ 2), modèles d'écritures, refus de suppression d'un compte mouvementé.
4. **Import Perfecto** (chef de mission) : `export-perfecto-simule.txt` en mode essai puis réel, dans le journal AN ; à-nouveaux en brouillard, équilibrés, validés.
5. **Saisie et pièces** (stagiaire, assistant) : opérations du § 4, garde-fous, validation, pièces de `pieces/`, capture mobile, devise.
6. **Revue** (chef de mission) : revue, « à corriger », contre-passation.
7. **Consultation** (tous) : grand livre, balances, comparaison avec la balance attendue du § 8 de `jeu-de-donnees.md`, exports.
8. **Lettrage et rapprochement** (assistant) : lettrages, puis relevé `releve-ecobank-janvier.csv`.
9. **Verrouillage** (associé / chef de mission) : janvier verrouillé puis déverrouillé avec motif.
10. **Inventaire** : immobilisations, stocks, provisions, régularisations, écart de conversion, avec les données du § 7.
11. **Clôture** : contrôles, IS, états financiers, Excel DGI et PDF, clôture provisoire, arrêté définitif.
12. **Exercice suivant** : ouverture 2028, à-nouveaux, extournes, affectation du résultat.
13. **Piste d'audit** : filtres et vérification de la chaîne.

Suggestion de comptes (domaine `@akonta.test`, un par rôle) : `associe@`, `chef@`, `assistant@`, `stagiaire@` : les inviter à l'étape 1, puis fixer leur mot de passe avec `recette/definir-mot-de-passe.sh` (écart n° 1).

## 6. Écarts : étapes de la fiche que l'application ne permet pas (encore) de réaliser

Constatés par lecture du code et par essais sur l'instance ; aucun n'a été corrigé (la préparation de la recette ne modifie pas la logique métier). Détails et hypothèses : `docs/questions.md` (Q-007 à Q-015).

| N° | Étape | Écart | Contournement ou conduite à tenir |
|---|---|---|---|
| 1 | 1.2 | **Pas d'écran pour créer son mot de passe** depuis le lien d'invitation (ni de réinitialisation) : le lien arrive dans la boîte de test mais l'application ne sait pas le traiter | `recette/definir-mot-de-passe.sh <e-mail>` après l'invitation (12 caractères minimum). À noter comme anomalie majeure |
| 2 | 1.3 | **Le verrouillage après 5 échecs de connexion n'existe pas** (seul un message d'erreur est prévu ; seule la limitation de débit de Supabase s'applique). La déconnexion après 30 min d'inactivité existe | Tester l'inactivité (réglable à 5 min dans les paramètres du cabinet pour aller plus vite) ; noter le verrouillage comme non réalisable |
| 3 | 5.6 | **La grille de saisie n'a pas de champ devise** : une écriture en euro (ou en dollar) ne peut pas être saisie par l'interface, alors que la base la gère (parité fixe 655,957 contrôlée) | `recette/injecter-ecritures-devise.sh <e-mail de l'assistant>` crée les deux brouillards du jeu de données ; les valider dans l'application. L'étape 10.5 (écart de conversion) en dépend |
| 4 | 6.2 | **« Reclassement » n'existe pas comme fonction distincte** : seule la contre-passation (motif obligatoire) est proposée | Corriger par contre-passation puis nouvelle saisie ; noter l'écart |
| 5 | 2.2 | **Les associés (nom, % du capital) ne peuvent pas être saisis** dans l'interface (le dépôt de données le prévoit, aucun écran ne l'appelle). Capital et effectif, eux, se saisissent à la création de l'exercice | Saisir capital et effectif ; ne pas chercher la liste des associés |
| 6 | 3.2 / 5 | Le modèle d'écritures **SALAIRES** utilise le compte 4221 (net à payer), qui **n'existe pas** dans le plan (le collectif est 422 → `4220000`) ; les modèles de règlement et de frais visent 5211000 « Banque X » alors que le journal de banque conseillé utilise 5210000 | Choisir `4220000` / `5210000` à la main quand la ligne reste vide ; noter l'écart dans les modèles |
| 7 | 4.1 | L'analyse de l'export Perfecto signale deux « Date illisible » **bénins** (ligne d'en-tête faite de tabulations, ligne « Total Journal » finale). **Même comportement sur le vrai `JOURNAL BANQUE.TXT`** (vérifié) ; aucune ligne de données n'est rejetée | Les ignorer ; à corriger plus tard (Q-007) |
| 8 | 4.1 | Le compte banque collé `5210ECO` est lu comme « collectif 5210 + tiers ECO » ; la banque n'étant pas un tiers, il faut retirer le tiers dans la table de correspondance (comme sur le vrai export) | Voir `jeu-de-donnees.md` § 3 |
| 9 | 5.5 | **Mobile** : le manifeste Android principal ne déclare pas la permission INTERNET (les builds de production n'atteindraient pas le réseau) et iOS n'a pas les descriptions d'usage de l'appareil photo | Recette mobile sur build de débogage Android ; iOS non testable en l'état |
| 10 | 7.3 / 8.3 / 11.3 | Les exports PDF / Excel / DGI **n'ont jamais été testés de bout en bout depuis l'interface** avec cette instance (service lancé et en bonne santé, liaison Edge → service non exercée) | Lancer le service (§ 4) ; toute erreur d'export est une anomalie à consigner |
| 11 | 1.2 / 2.3 | **Un utilisateur invité n'a aucun rôle** : l'invitation ne crée pas d'affectation, et l'écran Affectations est réservé à l'associé, qui n'en a pas non plus (impasse, voir Q-016). À noter comme anomalie majeure | Donner le rôle associé à la main, avec `recette/definir-role-associe.sh <e-mail>` ; l'associé affecte ensuite chef, assistant et stagiaire au dossier depuis Cabinet > Affectations |
| 12 | 1.4 | **L'administrateur technique était visible des membres** (liste des utilisateurs, affectations, audit). Corrigé le 30 oct. 2026 (D-017, migration `20261030100001`) : il est invisible, et apparaît sous « Administration technique » dans l'audit | Aucun. Si l'instance a été créée avant cette date, appliquer la migration (`scripts/reset-recette.sh` la prend en compte) |
| 13 | 2.2 | **Création d'un dossier refusée (violation RLS)** pour l'associé et le chef : l'`INSERT ... RETURNING` échouait. Corrigé le 30 oct. 2026 (D-018, migration `20261030100002`) | Aucun si la migration est appliquée. L'associé doit s'être connecté avec son code TOTP (session aal2), sinon il n'a aucun droit |
| 14 | 2.3 | **Écran Affectations en erreur (« type error »)** pour l'associé après le masquage de l'administrateur : sa ligne restait lisible via une politique `FOR ALL`. Corrigé le 30 oct. 2026 (D-019, migration `20261030100003`) | Aucun si la migration est appliquée ; recompiler le build web (`recette/lancer-reseau.sh --rebuild`) pour la tolérance côté application |

## 7. Contrôles automatiques du jeu de données

Exécutés par `scripts/test.sh` : `supabase/tests/150_recette_import.test.sql` (l'export Perfecto est lu sans erreur en mode essai ; comptes du plan présents), `151_recette_operations.test.sql` (les 44 opérations hors cession et les à-nouveaux sont acceptés et validés par la base, numérotation sans trou, balance égale à celle du § 8 du jeu de données) et `app/test/recette_jeu_test.dart` (format du fichier Perfecto, relevé lu avec le gabarit documenté, pièces valides, cohérence du test SQL avec le fichier). Après toute modification : `service-documents/.venv/bin/python recette/generer-jeu.py` puis `scripts/test.sh`.
