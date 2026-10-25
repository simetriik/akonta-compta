# Audit du dépôt au regard de la conception

Date : 2026-10-25. Référence : `inputs/conception.md` (source de vérité, lecture seule, non versionnée).

## 1. État du dépôt

| Élément attendu (conception §11, §12) | État constaté | Écart |
|---|---|---|
| Dépôt Flutter / Supabase « existant » (§11.1, §12.1) | **Aucun code.** Un seul commit : `AGENTS.md`, `CLAUDE.md`, `.gitignore`, kit logo `outputs/logo-akonta/` | Tout est à construire. L'audit porte donc sur l'outillage et les intrants, pas sur du code. |
| Migrations SQL versionnées (§11.3) | Absentes | À créer (`supabase/migrations/`). |
| Tests pgTAP, Flutter, pytest (§12.2) | Absents | À créer. |
| Scripts reproductibles `scripts/` | Absents | À créer (installation, démarrage, tests). |
| Fichiers de pilotage `docs/plan.md`, `avancement.md`, `decisions-dev.md`, `questions.md` | Absents | Créés par cet audit. |
| Identité visuelle | Kit complet livré (`outputs/logo-akonta/`, palette encre `#1A1A18` / terracotta `#B5472A` / sable `#F7F3EC`) | Aucun ; à reprendre dans le thème Flutter. |

## 2. Intrants disponibles

| Intrant | Constat | Usage prévu |
|---|---|---|
| `inputs/conception.md` (258 lignes, 13 sections) | Complet et cohérent : données, règles, permissions, phasage. | Source unique. Référencée, jamais copiée (décision D-001). |
| `inputs/plan-comptable-syscohada-revise.csv` | 1 339 comptes, `Code;Libellé`, UTF-8 avec BOM. Classes 1 à 9. Pas de colonne nature / sens / collectif : à dériver par règle (classe, préfixe) dans le seed. | Seed du plan de référence (module 3). |
| `inputs/JOURNAL BANQUE.TXT` | Export Perfecto réel : 693 lignes, Windows-1252, CRLF, tabulations ; en-tête `JOURNAL <BANECO> …`, `Pièces du … au …`, colonnes Date / N° pièce / Compte / Intitulé / Débit / Crédit / Libellé, ligne `Sous-total` par pièce. Comptes à 6 chiffres (`401100`) **et** tiers collés (`4110CHU`, `5210ECO`). Numéros de pièce à 6 chiffres dans ce fichier (la conception §10.10 parle de 7 chiffres pour les comptes). | Jeu de test du parseur Perfecto (module 10) et d'un dossier de démonstration réaliste. |
| `inputs/Modèle DGI-Etats-Financiers-SN.xlsm` | Présent, macros à conserver. Non encore analysé. | Cartographie des cellules au lot 3. |
| `inputs/ohada/` | Acte uniforme (AUDCIF 2017), guide d'application SYSCOHADA révisé, kit du stagiaire comptable (PDF). | Référence pour les règles d'inventaire, de clôture et les états. |
| Exports Perfecto balance générale / auxiliaire / factures non soldées (§13) | **Absents.** | Hypothèse : même format tabulé que le journal ; consigné dans `docs/questions.md` (Q-001). |

## 3. Outillage machine

| Outil | État | Conséquence |
|---|---|---|
| Podman 5.4.2, socket utilisateur actif, `DOCKER_HOST` déjà exporté | OK | `supabase start` possible sans Docker. |
| Supabase CLI 2.121.0 | OK | Images `supabase/postgres 17.11`, `storage-api`, `realtime`, `studio` déjà présentes localement (téléchargement partiel fait). |
| PostgreSQL client `psql` 17.11 | OK | Requêtes et scripts hors conteneur. |
| `pg_prove` | Absent | pgTAP exécuté via `supabase test db` (inclus dans l'image Postgres de Supabase). Décision D-002. |
| Flutter SDK (`~/.local/opt/flutter`) + Dart | OK (mise à jour disponible, non faite) | Desktop Linux + Android à vérifier avec `flutter doctor` au montage de l'environnement. |
| Python 3.13.5 + `uv` | OK ; `openpyxl`, `pytest` absents | Environnement virtuel géré par `uv` dans `service-documents/`. |
| Deno, Node, Bun | OK | Edge Functions Supabase (Deno). |
| Ressources | 8 cœurs, 14 Go RAM, 347 Go libres | Suffisant pour la pile Supabase locale + Flutter desktop. |

## 4. Écarts de conception à trancher en autonomie (déjà consignés)

- Le CSV du plan de référence ne porte ni nature, ni sens normal, ni indicateur collectif : dérivés par règles SYSCOHADA (classe 1-5 bilan, 6-8 gestion, 9 analytique ; sens par classe et exceptions ; collectifs = 401, 411, 421, 422… et comptes marqués dans la table). D-003.
- Comptes Perfecto observés à 6 chiffres alors que §10.10 dit « 7 chiffres repris tels quels » : l'import prend la longueur réelle et complète à la longueur fixe de l'entité à droite par des zéros, conformément à §3.3. D-004.
- Aucun export de balance Perfecto : le parseur de balance est écrit sur un format supposé identique au journal (tabulations, Windows-1252), avec table de correspondance éditable. Q-001.

## 5. Conclusion

Le dépôt est vide : l'ordre de travail de `inputs/prompt-claude-code.md` s'applique intégralement, en commençant par l'environnement reproductible puis le schéma SQL complet des trois lots avant toute interface. Le plan détaillé est dans `docs/plan.md`.
