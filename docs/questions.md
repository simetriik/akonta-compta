# Questions pour Dansi / ABC (hypothèses appliquées, travail poursuivi)

## Q-001 — Format des exports de balance Perfecto
- **Question** : quel est le format exact des exports « balance générale », « balance auxiliaire » et « factures non soldées » de Perfecto ?
- **Hypothèse appliquée** : même format que le journal (texte tabulé, Windows-1252, CRLF) avec colonnes Compte / Intitulé / Débit / Crédit (ou soldes débiteur / créditeur). Table de correspondance éditable avant import ; le parseur est isolé pour être adapté en une fonction.

## Q-002 — Taux fiscaux en vigueur
- **Question** : taux d'AIB (1 % / 3 % / 5 % selon le statut ?), minimum d'impôt IS, TAF, IRPP barème à confirmer.
- **Hypothèse appliquée** : TVA 18 %, AIB 1 % (immatriculé) et 5 % (non immatriculé), TVA retenue 18 % du HT sur marchés publics, TAF 10 %, IS 30 % avec minimum 0,5 % du CA (plancher 250 000 FCFA). Tous dans la table des taux avec dates de validité : modifiables sans code.

## Q-003 — Numérotation Perfecto
- **Question** : les numéros de pièce Perfecto sont à 6 chiffres dans l'export fourni (`000001`), les comptes à 6 chiffres aussi ; la conception parle de 7 chiffres. Quelle longueur de compte pour les dossiers d'ABC ?
- **Hypothèse appliquée** : longueur par défaut 7 au niveau cabinet, modifiable par entité (§3.3) ; l'import complète à droite (D-004).
