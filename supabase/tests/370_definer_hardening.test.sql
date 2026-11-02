-- Durcissement des fonctions security definer appelables en RPC (D-044, tranche 3) :
-- un utilisateur connecté ne doit pas agir sur un dossier d'un autre cabinet, ni sur un dossier qu'il ne voit pas.
begin;
select plan(7);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('partner@a.test', :'a_id', 'Associé A') as id \gset pa_
select tests.create_user('partner@b.test', :'b_id', 'Associé B') as id \gset pb_
select tests.create_user('assist@a.test', :'a_id', 'Assistant A') as id \gset as_
select tests.create_entity(:'a_id', 'SARL A1') as id \gset e1_
select tests.create_entity(:'a_id', 'SARL A2') as id \gset e2_
select tests.assign(:'pa_id', :'a_id', 'partner');
select tests.assign(:'pb_id', :'b_id', 'partner');
select tests.assign(:'as_id', :'a_id', 'assistant', :'e1_id');

-- Associé d'un autre cabinet
select tests.authenticate_as(:'pb_id', 'aal2');
select throws_ok(format($q$select public.create_journals_from_template(%L, '{}')$q$, :'e1_id'), '42501', null,
  'un autre cabinet ne crée pas de journaux dans mon dossier');
select throws_ok(format($q$select public.copy_reference_plan(%L)$q$, :'e1_id'), '42501', null,
  'un autre cabinet ne copie pas de plan de comptes dans mon dossier');
select throws_ok(format($q$select public.audit_chain_verify(%L)$q$, :'a_id'), '42501', null,
  'un autre cabinet ne vérifie pas ma piste d''audit');
select tests.clear_auth();

-- Assistant du dossier A1 : pas de droit sur le dossier A2 (hors de son affectation)
select tests.authenticate_as(:'as_id', 'aal1');
select throws_ok(format($q$select public.create_journals_from_template(%L, '{}')$q$, :'e2_id'), '42501', null,
  'un assistant n''agit pas sur un dossier hors de son affectation');
select tests.clear_auth();

-- L'associé du cabinet garde la main sur ses propres dossiers
select tests.authenticate_as(:'pa_id', 'aal2');
select lives_ok(format($q$select public.create_journals_from_template(%L, '{}')$q$, :'e1_id'), 'l''associé crée des journaux dans son dossier');
select lives_ok(format($q$select public.copy_reference_plan(%L)$q$, :'e1_id'), 'l''associé copie le plan de comptes dans son dossier');
select lives_ok(format($q$select public.audit_chain_verify(%L)$q$, :'a_id'), 'l''associé vérifie la piste d''audit de son cabinet');
select tests.clear_auth();

select * from finish();
rollback;
