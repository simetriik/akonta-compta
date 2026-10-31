# Architecture de l'application Flutter

Décision D-031 (31 oct. 2026) : architecture clean, pour deux raisons exprimées par Dansi : pouvoir **changer de moteur de données** selon le client, et **travailler sans connexion** sur l'appareil. Les règles comptables restent dans PostgreSQL pour l'adaptateur actuel (voir `AGENTS.md`).

## Couches (`app/lib/src/`)
```
presentation/   écrans, widgets, routeur           ─► application, domain, core
application/    services (cas d'usage), providers, connectivité, synchronisation  ─► domain, core
domain/         entités, ports (interfaces de dépôt), règles pures          (ne dépend de rien)
infrastructure/ adaptateurs : supabase/ (données), local/ (base chiffrée)   ─► domain, application, core
composition/    seul endroit qui relie ports et adaptateurs  ─► tout sauf presentation
core/           noyau partagé : erreurs, formats, configuration (ne dépend de rien)
```
`test/architecture_test.dart` vérifie ces règles sur les imports de chaque fichier (sens des dépendances, paquets interdits par couche, absence de l'ancien dossier `data/`). Un test de garde-fou (`error_display_guard_test.dart`) interdit d'afficher une exception telle quelle.

### Rôle de chaque dossier
| Dossier | Contenu |
|---|---|
| `domain/*_models.dart` | Entités (sans conversion JSON : `fromJson`/`toJson` vivent dans `infrastructure/supabase/mappers/`). |
| `domain/repositories/` | Un port par module (`EntriesRepository`…), plus `AuthRepository`, `SessionRepository`, `OutboxRepository`. |
| `application/services/` | Un service par module : mêmes méthodes que le port, avec la règle « connexion obligatoire » (`OnlinePolicy`). |
| `application/providers/` | Providers Riverpod : `repositories.dart` (points d'injection des ports), `services.dart`, états par module. |
| `application/offline/` | File d'envoi (codec, version mémoire), cache de lectures (port), `SyncService`. |
| `infrastructure/supabase/` | `Supabase*Repository`, mappers, classeur d'erreurs, client HTTP à cache (`OfflineHttpClient`), moniteur de connexion. |
| `infrastructure/local/` | Base chiffrée drift/SQLite3 Multiple Ciphers : cache des lectures, file d'envoi. |
| `composition/` | `composeApp()` (choix des adaptateurs, initialisation) et `supabaseOverrides()`. |

## Où va la logique d'un écran
- Règles pures (contrôle d'un formulaire, comptes proposés, calculs) : `application/rules/` ou `application/<module>/`, testées sans interface.
- État qui se charge, se sélectionne et appelle des services : un contrôleur Riverpod (`application/providers/reconciliation_controller.dart` en est le modèle) ou un `FutureProvider` (`closing_providers.dart`).
- Le widget garde la mise en page, les dialogues, la navigation et l'affichage des erreurs (`errorText`). Un écran ne dépasse pas 600 lignes (test d'architecture).

## Ajouter une fonction
1. Entité et règle pure dans `domain/` ; méthode sur le port du module (`domain/repositories/`).
2. Implémentation dans `infrastructure/supabase/supabase_<module>_repository.dart` et conversion dans `mappers/`.
3. Méthode du service dans `application/services/<module>_service.dart` : appeler `_online.require('Libellé')` si la fonction ne peut pas fonctionner hors connexion.
4. L'écran appelle le service via `ref.read(<module>ServiceProvider)` ; les erreurs passent par `showError` ou `errorText`.
5. Tests : service avec un faux port, adaptateur si logique propre, écran avec les providers remplacés.

## Changer de moteur de données
Écrire un nouvel adaptateur par port (`infrastructure/<moteur>/`) et un `<moteur>Overrides()` dans `composition/`, qui remplace les providers de `application/providers/repositories.dart`. Le classement des erreurs du fournisseur s'enregistre avec `ErrorClassifiers.register`. Les tests de conformité (`test/storage_contract_test.dart` pour le stockage local) donnent le modèle pour valider un adaptateur. Rien dans `presentation`, `application` ni `domain` ne change. Un serveur d'API pour un moteur sans PostgREST (Oracle…) reste à construire : voir `docs/reste-a-faire.md`.

## Mode hors connexion
- **Détection** : `ReachabilityMonitor` interroge le service d'authentification (point de santé) toutes les 30 s en ligne, 5 s hors ligne ; le client HTTP bascule hors ligne à la première erreur réseau.
- **Lectures** : `OfflineHttpClient` conserve chaque lecture (API de données, et la liste des dossiers) et la rejoue hors connexion, **par utilisateur** (identifiant extrait du jeton) ; le cache est vidé à la déconnexion.
- **Saisie** : les brouillons d'écritures (`local:<n>`) et les pièces déposées hors connexion vont dans la **file d'envoi** ; `SyncService` la rejoue à chaque retour en ligne (et sur demande). Le serveur fait foi : la numérotation et les contrôles s'appliquent à l'enregistrement. Un refus consigne le motif sur l'élément ; il n'est plus rejoué seul après trois échecs.
- **Autorisé hors ligne** : consulter les dossiers, référentiels et écritures déjà chargés, saisir et modifier des brouillons, déposer des pièces.
- **Refusé hors ligne** (message « … nécessite une connexion internet » et écran remplacé par un message) : grand livre, balance, balance âgée, états financiers, exports, validation, contre-passation, revue, lettrage, rapprochement, import, inventaire, clôture, suggestions, administration, création de dossier.
- **Stockage** : ordinateur et mobile : base SQLite3 Multiple Ciphers dans le dossier de l'application, clé de 256 bits dans le trousseau du système (`flutter_secure_storage`). Si la clé ne peut pas être conservée, aucune donnée n'est écrite sur disque (cache et file en mémoire). Web : mémoire seulement.
- **Prérequis Linux (bureau)** : `libsecret-1-dev` pour compiler (et un trousseau actif, par exemple GNOME Keyring, à l'exécution).
