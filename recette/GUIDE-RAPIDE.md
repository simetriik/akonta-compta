# Recette Akonta : guide rapide

Durée : 10 minutes de préparation, puis la recette. Un seul poste (l'hôte) héberge tout ; les collègues n'installent rien.

## A. Préparer le poste hôte

Ouvrir **3 terminaux** dans le dossier du projet (`~/Documents/01_PROJETS/akonta`).

**Terminal 1 : remettre l'instance à zéro**
```bash
scripts/reset-recette.sh
```
Attendre « terminé » (environ 1 minute). La base est vide, seul l'administrateur existe.

**Terminal 2 : service des exports PDF / Excel**
```bash
recette/lancer-service-documents.sh
```
Laisser tourner.

**Terminal 3 : l'application pour le réseau**
```bash
recette/lancer-reseau.sh
```
La 1re fois, le script compile l'application (quelques minutes). Il affiche ensuite l'adresse à donner, par exemple `http://192.168.1.232:8080`. Laisser tourner.

Si un collègue n'arrive pas à ouvrir la page : autoriser le port **8080** dans le pare-feu du poste hôte. Ne pas ouvrir les ports 55322 et 55323.

## B. Donner l'accès aux collègues

1. Envoyer l'adresse `http://…:8080` aux collègues (même Wi-Fi ou même réseau).
2. Chacun l'ouvre dans son navigateur.
3. Une personne = un rôle : administrateur, associé, chef de mission, assistant, stagiaire.

Compte de départ (administrateur) : `admin.recette@akonta.test` / `Recette-Admin-2027!`
La double authentification (code à 6 chiffres, application type Google Authenticator) est demandée à la première connexion.

## C. Créer les utilisateurs

1. L'administrateur invite : `associe@akonta.test` en cochant « Premier associé du cabinet » (case proposée tant que le cabinet n'a pas d'associé), puis `chef@akonta.test`, `assistant@akonta.test`, `stagiaire@akonta.test` (l'associé leur donne ensuite leur rôle dans Cabinet > Affectations).
2. Les e-mails d'invitation ne partent pas vraiment : ils tombent dans la boîte de test de l'hôte, `http://127.0.0.1:55324`. Ne pas s'en servir.
3. L'hôte fixe le mot de passe de chacun (12 caractères minimum) :
```bash
recette/definir-mot-de-passe.sh associe@akonta.test
```
(même commande pour les trois autres). Donner ensuite le mot de passe à la personne.
4. L'invitation ne donne aucun rôle. L'hôte donne le rôle **Associé** à la personne concernée :
```bash
recette/definir-role-associe.sh associe@akonta.test
```
L'associé crée ensuite le dossier (étape 2), puis affecte le chef de mission, l'assistant et le stagiaire à ce dossier dans Cabinet > Affectations. Il doit s'être connecté avec son code à 6 chiffres, sinon il n'a aucun droit.

## D. Dérouler la recette

Suivre les 13 étapes dans l'ordre. Les fichiers à utiliser sont dans `recette/` :

| Étape | Qui | À faire | Fichier utile |
|---|---|---|---|
| 1 | Admin | Connexion, TOTP, invitations | |
| 2 | Associé | Renommer le cabinet, ouvrir le dossier | `jeu-de-donnees.md` §1 |
| 3 | Chef | Tiers, modèles d'écritures | `jeu-de-donnees.md` §2 |
| 4 | Chef | Import des à-nouveaux (essai puis réel) | `export-perfecto-simule.txt` |
| 5 | Stagiaire, assistant | Saisir les 45 opérations, ajouter les pièces | `jeu-de-donnees.md` §4, dossier `pieces/` |
| 6 | Chef | Revue, « à corriger », contre-passation | |
| 7 | Tous | Grand livre, balances, exports | `jeu-de-donnees.md` §8 |
| 8 | Assistant | Lettrage, rapprochement | `releve-ecobank-janvier.csv` |
| 9 | Associé | Verrouiller puis déverrouiller janvier | |
| 10 | Chef | Inventaire | `jeu-de-donnees.md` §7 |
| 11 | Associé | Clôture, états financiers, arrêté | |
| 12 | Associé | Exercice suivant, à-nouveaux | |
| 13 | Admin | Piste d'audit | |

Détail de chaque étape : `docs/recette-interne.md`.

**Deux écritures en devise** ne peuvent pas être saisies à la main (écran absent). Avant l'étape 5 :
```bash
recette/injecter-ecritures-devise.sh assistant@akonta.test
```
puis les valider dans l'application.

## E. Noter les anomalies

Pour chaque problème, noter : **étape, qui, ce qu'on a fait, ce qui s'est passé, ce qu'on attendait**, et une capture d'écran. Un tableau partagé suffit.

Écarts déjà connus (ne pas les re-signaler) : `recette/LISEZMOI.md` §6.

## F. Recommencer ou finir

- Recommencer à zéro : arrêter le terminal 3 (Ctrl+C), puis `scripts/reset-recette.sh`, et reprendre à l'étape C.
- Arrêter pour la nuit (données conservées) : `scripts/reset-recette.sh --stop`.

## Limites à connaître

- Caméra refusée par le navigateur en `http://` : pour une pièce, déposer une photo existante.
- Deux rôles sur la même personne : utiliser deux navigateurs ou une fenêtre privée.
- Vidéo de présentation : `outputs/recette-video/akonta-recette-v2.mp4`.
