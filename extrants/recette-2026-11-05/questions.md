# Questions en attente – recette du 05/11/2026

## Q-R01 – Identifiant unique d'un client sans IFU (point 8)
**Contexte.** Le cadrage propose l'IFU comme identifiant unique du client, sans dire quoi faire pour un client sans IFU. L'index sur l'IFU existait déjà ; il ne protège rien quand l'IFU est vide, ce qui explique le doublon « Maître ASSANI ».
**Appliqué provisoirement.** Un dossier est refusé s'il porte le même nom (sans casse ni accents) qu'un dossier du cabinet quand l'un des deux n'a pas d'IFU. Deux homonymes avec chacun un IFU différent sont acceptés. Réglage cabinet `block_homonym_entities` pour désactiver.
**À trancher par le cabinet.** Faut-il exiger l'IFU à la création, ou garder cette règle sur le nom ? Que faire de deux clients réellement homonymes sans IFU (suffixe imposé, autre identifiant) ?
