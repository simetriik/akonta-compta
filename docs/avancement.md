# Journal d'avancement

Une entrée par itération : date, tâche, résultat, tests, commit.

## 2026-10-25
- **Préalable** : kit logo finalisé et commité sur `main` (identité : tête d'éléphant, terracotta `#B5472A`).
- **L1-00 Audit** : `docs/audit.md` rédigé (dépôt vide, intrants et outillage inventoriés) ; `docs/plan.md`, `docs/decisions-dev.md` (D-001 à D-005), `docs/questions.md` (Q-001 à Q-003) créés. Branche `lot1` ouverte. Tests : sans objet. Commit : voir ci-dessous.
- **L1-01 Environnement** : `supabase init`, config durcie (mot de passe 12 car., TOTP, inscription fermée, analytics/realtime/vector désactivés), `scripts/{setup,start,stop,reset-db,test}.sh`, `docs/environnement.md`. `supabase start` OK sous Podman (volumes de l'ancien projet réinitialisés par `db reset`). Flutter 3.47 : Linux desktop et Android OK, Chrome absent (web hors périmètre).
- **L1-02 Schéma socle** : migration `20261025200001_socle.sql` (cabinets, profils, 21 permissions unitaires, 5 rôles par défaut seedés par cabinet, affectations avec contrôle de cohérence, `has_permission` / `can_access_entity` avec exigence aal2 pour associé et administrateur, piste d'audit en ajout seul chaînée SHA-256 + `audit_chain_verify`, RLS). Tests : `010_socle.test.sql`, 34 assertions vertes (`scripts/test.sh sql`).
- **L1-03 Schéma cabinet et dossiers** : migration `20261025200002_dossiers.sql` (entités fiche R1-R3 + paramètres, unicité IFU/RCCM par cabinet, dirigeants, historisation en ajout seul, exercices avec continuité et transitions de statut, associés d'exercice, 12 périodes générées, verrouillage associé / chef de mission selon option, déverrouillage associé avec motif, `period_open_for`). Correction de sécurité : les rôles de portée cabinet sont désormais bornés au cabinet du dossier (`can_access_entity`, `has_permission`). Tests : `020_dossiers.test.sql`, 29 assertions ; suite totale 67 vertes.
