# Questions en attente – recette du 05/11/2026

## Q-R01 – Identifiant unique d'un client sans IFU (point 8) — TRANCHÉE le 07/11/2026
**Réponse.** On garde la règle sur le nom, sans exiger l'IFU à la création (beaucoup de petits clients n'en ont pas). Deux vrais homonymes sans IFU : le nom doit être distingué par un suffixe (ville, activité, par exemple « Maître ASSANI – Cotonou »). Aucun changement de code : c'est le comportement déjà appliqué. À reconfirmer par ABC à la prochaine recette.

**Contexte.** Le cadrage propose l'IFU comme identifiant unique du client, sans dire quoi faire pour un client sans IFU. L'index sur l'IFU existait déjà ; il ne protège rien quand l'IFU est vide, ce qui explique le doublon « Maître ASSANI ».
**Appliqué provisoirement.** Un dossier est refusé s'il porte le même nom (sans casse ni accents) qu'un dossier du cabinet quand l'un des deux n'a pas d'IFU. Deux homonymes avec chacun un IFU différent sont acceptés. Réglage cabinet `block_homonym_entities` pour désactiver.
**À trancher par le cabinet.** Faut-il exiger l'IFU à la création, ou garder cette règle sur le nom ? Que faire de deux clients réellement homonymes sans IFU (suffixe imposé, autre identifiant) ?

## Q-R02 – Pourcentage dans un modèle enregistré depuis une écriture (point 1) — TRANCHÉE le 07/11/2026
**Réponse.** Pas de détection automatique : une ligne qui vaut 18 % d'une autre peut être une coïncidence, et un modèle faux produirait des écritures fausses. Le pourcentage reste réglé explicitement dans Référentiels → Modèles. Aucun changement de code.

**Contexte.** Dans un modèle, toutes les lignes « saisie » reprennent le même montant de base (comportement existant). « Enregistrer comme modèle » garde donc comptes, sens et libellés, avec des montants libres ; les pourcentages (TVA 18 %) se règlent ensuite dans Référentiels → Modèles.
**À trancher.** Faut-il détecter automatiquement une ligne qui vaut 18 % d'une autre pour en faire une ligne « pourcentage » ? Je n'ai pas deviné.

## Q-R03 – Fichier `.env` à la racine — RÉSOLUE le 07/11/2026
**Réponse.** Ligne 1 préfixée par `# ` sur accord de Dansi ; la pile Supabase démarre depuis le dépôt.

**Contexte.** La première ligne de `.env` est une phrase non commentée ; la CLI Supabase refuse de démarrer (« failed to parse environment file »). Je n'ai pas modifié ce fichier.
**À trancher.** Préfixer cette ligne par `#` ? (changement d'une ligne, aucun effet sur les valeurs.)
