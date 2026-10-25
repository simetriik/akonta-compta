# Livraison du lot 1 — Akonta

Date : 25 octobre 2026. Branche `lot1` fusionnée dans `main`. Périmètre : modules 1 Socle, 2 Cabinet et dossiers, 3 Référentiels, 4 Saisie, 5 Pièces justificatives, 6 Consultation, 10 Import Perfecto, plus le **schéma SQL complet des lots 1 à 3** (conception §12.1).

## 1. Ce qui est livré

| Module | Base de données (PostgreSQL / Supabase) | Application Flutter (desktop + mobile) | Autres |
|---|---|---|---|
| 1 Socle | cabinets, profils, 21 permissions unitaires, 5 rôles par défaut ajustables, affectations (utilisateur, dossier, rôle), `has_permission` / `can_access_entity` avec TOTP exigé pour associé et administrateur, piste d'audit en ajout seul chaînée SHA-256, RLS | connexion (mot de passe ≥ 12 car.), TOTP (défi / enrôlement forcé), déconnexion pour inactivité, navigation par permissions, dossier courant permanent, utilisateurs (invitation, import CSV eABC, désactivation), rôles × permissions, affectations et réaffectation en masse, piste d'audit avec vérification de chaîne | Edge Function `invite-user` |
| 2 Cabinet et dossiers | entités (R1-R3, paramètres), dirigeants, historisation, exercices (continuité, statuts), associés, 12 périodes, verrouillage / déverrouillage avec motif | tableau de bord des dossiers, liste, fiche, dirigeants, exercices et périodes, historique, assistant d'ouverture en 5 étapes | — |
| 3 Référentiels | plan SYSCOHADA révisé seedé (1 339 comptes), plan d'entité à longueur fixe avec subdivision et sens figé, tiers + collectifs, journaux (AN imposé, trésorerie reliée), modèles d'écritures (5 fournis), taux datés | plan de comptes, tiers, journaux, modèles, taux | générateur de seed |
| 4 Saisie | écritures / lignes (débit xor crédit > 0), `validate_entry` transactionnelle (contrôles + numéro sans trou), immutabilité, `reverse_entry`, `review_entry` + notifications, devises (parité euro) | liste filtrée et recherche, validation par lot, revue, contre-passation, grille clavier (autocomplétion, contrepartie, modèles, équilibre) | — |
| 5 Pièces | documents (formats, 20 Mo, SHA-256), rattachement n-n, non-suppression après validation, Storage privé | dépôt, photo mobile, boîte de réception, rattachement, visionneuse (URL signée) | — |
| 6 Consultation | vue `ledger_lines`, grand livre, balances générale / auxiliaire / âgée, journal, centralisateur, tableau de bord (fonctions SQL, écritures validées uniquement) | onglets consultation, comparaison N-1, exports PDF / Excel | service Python (PDF / Excel) + Edge Function `export-document` |
| 10 Import Perfecto | lots, lignes, correspondances éditables, analyse du texte tabulé Windows-1252, scission des tiers collés, négatifs inversés, essai sans écriture, application en brouillard « générée » | écran d'import en 4 temps | — |
| Lots 2 et 3 (schéma) | lettrage, relevés et rapprochement, immobilisations, stocks, provisions, régularisations, écarts de conversion, contrôles de clôture, règles fiscales et correspondances d'états versionnées, archives | — | — |

Jeu de démonstration : `scripts/demo.sh` (cabinet, 5 comptes, 2 dossiers, exercice 2026 complet).

## 2. Installation

Prérequis : Podman (rootless), Supabase CLI, Flutter SDK (Linux desktop et/ou Android), Python 3.13 + `uv`, Deno. Détails et dépannage : `docs/environnement.md`.

```bash
scripts/setup.sh          # vérifie l'outillage, télécharge les images, récupère les dépendances
scripts/demo.sh           # base locale + jeu de démonstration
```

Service de documents (exports PDF / Excel) :
```bash
cd service-documents && cp .env.example .env   # renseigner AKONTA_SERVICE_KEY
uv run uvicorn app.main:app --port 8100
```
Edge Functions en local : `supabase functions serve --env-file supabase/.env.local` avec `DOCUMENTS_SERVICE_URL=http://host.containers.internal:8100` et `DOCUMENTS_SERVICE_KEY=<la même clé>`.

## 3. Lancement

```bash
cd app && flutter run -d linux        # desktop (valeurs par défaut : pile locale)
cd app && flutter run -d <android>    # mobile
```
Pour une autre pile : `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…`. La clé de service n'est jamais embarquée.

Comptes de démonstration (mot de passe `Akonta-Demo-2026!`) : `associe@akonta.demo` (TOTP à enrôler à la première connexion), `chef@akonta.demo`, `assistant@akonta.demo`, `stagiaire@akonta.demo`, `admin@akonta.demo`.

## 4. Tests

`scripts/test.sh` : pgTAP (219 assertions : règles comptables et RLS de toutes les tables), Flutter (29 tests : formats, permissions, inactivité, formulaires, grille de saisie), pytest (8 tests : service de documents), Deno (6 tests : Edge Functions). Chaque règle de la conception citée dans `docs/plan.md` est couverte par au moins un test pgTAP ; `090_rls_coverage` vérifie qu'aucune table de dossier n'est lisible depuis un autre cabinet.

## 5. Décisions prises seul

Voir `docs/decisions-dev.md` (D-001 à D-008) : référencement de `inputs/` sans copie, pgTAP via la CLI, dérivation des attributs du plan de référence, longueur des comptes importés, organisation du dépôt, permissions dérivées pour le verrouillage et la création de dossier, copie du plan (classes 1-8, collisions de numéros, journaux de trésorerie créés par l'assistant), comptes inconnus jamais créés à l'import.

## 6. Questions restantes

Voir `docs/questions.md` : format des exports de balance Perfecto (Q-001), taux fiscaux en vigueur (Q-002), longueur des comptes chez ABC (Q-003). Hypothèses appliquées et modifiables sans code (tables de taux, correspondances d'import).

Limites connues du lot 1 :
- Les exports (PDF / Excel) exigent le service Python et la configuration de l'Edge Function ; sans eux, les écrans de consultation fonctionnent mais l'export renvoie une erreur explicite.
- Le verrouillage de connexion après 5 échecs repose sur la limitation de débit de Supabase Auth (paramétrable dans `config.toml`), non sur un compteur applicatif.
- L'interface mobile partage le code desktop : fonctionnelle, à retravailler avec les maquettes issues de `docs/prompt-claude-design.md`.
- La capture mobile ne compresse pas les HEIC ; les JPEG sont réduits à 2 400 px.

## 7. Scénario de recette pas à pas (pour ABC)

Pré-requis : `scripts/demo.sh` exécuté, application lancée, service de documents démarré.

1. **Connexion et sécurité** — Se connecter avec `admin@akonta.demo` : l'activation TOTP est exigée ; scanner le QR, saisir le code. Vérifier que le menu ne montre que « Utilisateurs ». Inviter un collaborateur fictif, importer un CSV `Nom;E-mail;Fonction`. Désactiver un compte puis le réactiver. Se déconnecter.
2. **Associé** — Se connecter avec `associe@akonta.demo`, enrôler le TOTP. Cabinet → Rôles : retirer « Valider ses écritures » à l'assistant, constater l'effet à l'étape 5, puis la rétablir. Cabinet → Affectations : affecter le stagiaire à SA Alpha, puis réaffecter en masse les dossiers du chef de mission vers l'assistant et revenir en arrière. Piste d'audit : filtrer sur « Connexions », vérifier la chaîne.
3. **Dossiers** — Tableau de bord : lire les compteurs de SARL Démo Distribution. Dossiers → Nouveau dossier : dérouler l'assistant en 5 étapes (fiche avec IFU à 13 chiffres, exercice 2026, plan copié, journaux AC/VT/BQ avec compte 5210000, « plus tard »). Ouvrir la fiche : modifier l'adresse, vérifier l'historique ; tenter de changer la longueur des comptes (refusé car un exercice existe). Exercices : verrouiller avril, déverrouiller janvier avec motif.
4. **Référentiels** — Sur SARL Démo : subdiviser 4011 en 4011100 « Fournisseurs étrangers » (numéro complété automatiquement) ; tenter de supprimer 4011000 (refusé : subdivisions) ; créer le tiers `TOTAL` rattaché à 4011000 ; créer un journal `CA2` de caisse avec 5710000 ; consulter le modèle « Achat avec TVA » et les taux.
5. **Saisie (assistant)** — Se connecter avec `assistant@akonta.demo`. Saisie → Nouvelle écriture : journal AC, date du mois courant, « Modèle » Achat avec TVA, montant 1 000 000 : les trois lignes s'affichent équilibrées ; saisir le tiers SOBEB, Valider → numéro attribué. Nouvelle écriture déséquilibrée : Valider → erreur listée, Ctrl+B pose la contrepartie, Valider. Tenter de modifier une écriture validée : lecture seule. Liste → filtre Brouillards, cocher trois brouillards de caisse du stagiaire : « Valider » refusé (pas ses écritures) ; se reconnecter en chef de mission et valider le lot.
6. **Revue et correction (chef de mission)** — `chef@akonta.demo` : segment « À revoir », revue d'une écriture en « À corriger » avec commentaire ; se reconnecter en assistant : la notification et le statut rouge apparaissent. Contre-passer une facture (motif, date) : l'écriture inverse validée apparaît, l'originale est marquée.
7. **Pièces** — Déposer un PDF depuis le desktop ; sur mobile, photographier une pièce : elle arrive dans la boîte de réception du dossier. Rattacher à l'écriture contre-passée ; tenter de supprimer la pièce (refusé). Ouvrir la visionneuse.
8. **Consultation** — Grand livre 4111000 sur l'exercice : solde progressif et lien vers les écritures. Balance générale : totaux débit = crédit ; cocher « Comparer N-1 » (vide : première année). Balance auxiliaire : CHU. Balance âgée au 30/06 puis au 31/12. Centralisateur. Exporter la balance en PDF et en Excel ; vérifier l'événement « export » dans la piste d'audit (associé).
9. **Import Perfecto** — Chef de mission → Import : fichier `inputs/JOURNAL BANQUE.TXT`, journal cible BQ. Lire le rapport (lignes, pièces, comptes inconnus). Corriger les correspondances (ex. `4452002` → `4452000`, retirer le suffixe de `5210ECO`). Essai : lire le nombre d'écritures ; Importer en brouillard ; retrouver les brouillards « générée » dans Saisie et en valider un.
10. **Cloisonnement** — Avec l'associé, créer un second cabinet de test via SQL n'est pas possible depuis l'interface : la preuve de cloisonnement est le test `090_rls_coverage` (`scripts/test.sh sql`).

Résultat attendu : toutes les étapes se déroulent sans erreur technique ; chaque refus affiché correspond à une règle de la conception (§4, §8, §10).
