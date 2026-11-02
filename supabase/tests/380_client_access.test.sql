-- Accès des clients du cabinet (D-044) : un client voit uniquement son brouillard et ses factures, écrit seulement
-- quand l'accès de son dossier est actif, ne valide jamais ; isolation entre clients et entre cabinets.
begin;
select plan(41);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_cabinet('Cabinet B') as id \gset b_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.create_user('assist@a.test',  :'a_id', 'Assistant') as id \gset assist_
select tests.create_user('gerant@c1.test', :'a_id', 'Gérant client 1') as id \gset gerant_
select tests.create_user('saisie@c1.test', :'a_id', 'Saisie client 1') as id \gset saisie_
select tests.create_user('gerant@c2.test', :'a_id', 'Gérant client 2') as id \gset gerant2_
select tests.create_user('partner@b.test', :'b_id', 'Associé B') as id \gset partnerb_
select tests.create_entity(:'a_id', 'Client 1 SARL') as id \gset e1_
select tests.create_entity(:'a_id', 'Client 2 SARL') as id \gset e2_
select tests.assign(:'partner_id', :'a_id', 'partner');
select tests.assign(:'partnerb_id', :'b_id', 'partner');
select tests.assign(:'assist_id', :'a_id', 'assistant', :'e1_id');
select tests.assign(:'gerant_id', :'a_id', 'client_gerant', :'e1_id');
select tests.assign(:'saisie_id', :'a_id', 'client_saisie', :'e1_id');
select tests.assign(:'gerant2_id', :'a_id', 'client_gerant', :'e2_id');

insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values
  (:'a_id', :'e1_id', '2026-01-01', '2026-12-31'), (:'a_id', :'e2_id', '2026-01-01', '2026-12-31');
select public.create_journals_from_template(:'e1_id', null);
select public.create_journals_from_template(:'e2_id', null);

-- Brouillards : saisie (client 1), gérant (client 1), assistant (personnel), gérant 2 (client 2), plus une écriture validée
select tests.make_entry(:'e1_id', 'VT', '2026-02-01', 'Brouillard saisie', '[{"account":"5210000","debit":1000},{"account":"7011000","credit":1000}]', :'saisie_id') as id \gset d1_
select tests.make_entry(:'e1_id', 'VT', '2026-02-02', 'Brouillard gérant', '[{"account":"5210000","debit":2000},{"account":"7011000","credit":2000}]', :'gerant_id') as id \gset d2_
select tests.make_entry(:'e1_id', 'VT', '2026-02-03', 'Brouillard cabinet', '[{"account":"5210000","debit":3000},{"account":"7011000","credit":3000}]', :'assist_id') as id \gset d3_
select tests.make_entry(:'e2_id', 'VT', '2026-02-04', 'Brouillard autre client', '[{"account":"5210000","debit":4000},{"account":"7011000","credit":4000}]', :'gerant2_id') as id \gset d4_
select tests.make_entry(:'e1_id', 'VT', '2026-02-05', 'Validée', '[{"account":"5210000","debit":5000},{"account":"7011000","credit":5000}]', :'assist_id') as id \gset v1_
select public.validate_entry(:'v1_id');

-- 1. Rôles et droits
select is((select count(*) from public.roles where cabinet_id = :'a_id' and is_client), 2::bigint, 'deux rôles client livrés à la création du cabinet');
select is((select count(*) from public.roles where cabinet_id = :'b_id' and is_client), 2::bigint, 'les autres cabinets aussi');
select is((select requires_mfa from public.roles where cabinet_id = :'a_id' and code = 'client_gerant'), true, 'le gérant client passe par TOTP');
select throws_ok(format($q$insert into public.role_permissions (role_id, permission_code) select id, 'ledger.read' from public.roles where cabinet_id = %L and code = 'client_saisie'$q$, :'a_id'),
  '42501', null, 'on ne donne pas la lecture du grand livre à un rôle client');
select throws_ok(format($q$insert into public.role_permissions (role_id, permission_code) select id, 'entries.validate' from public.roles where cabinet_id = %L and code = 'client_saisie'$q$, :'a_id'),
  '42501', null, 'on ne donne pas la validation à un rôle client');
select lives_ok(format($q$insert into public.role_permissions (role_id, permission_code) select id, 'invoices.issue' from public.roles where cabinet_id = %L and code = 'client_saisie'$q$, :'a_id'),
  'l''émission de factures peut être accordée au saisisseur');
delete from public.role_permissions where permission_code = 'invoices.issue'
  and role_id = (select id from public.roles where cabinet_id = :'a_id' and code = 'client_saisie');

-- 2. Affectations
select throws_ok(format($q$select tests.assign(%L, %L, 'client_saisie')$q$, :'saisie_id', :'a_id'), '23514', null, 'un rôle client vise un dossier précis');
select throws_ok(format($q$select tests.assign(%L, %L, 'assistant', %L)$q$, :'saisie_id', :'a_id', :'e1_id'), '23514', null, 'un compte client ne porte pas de rôle du cabinet');
select throws_ok(format($q$select tests.assign(%L, %L, 'client_saisie', %L)$q$, :'assist_id', :'a_id', :'e1_id'), '23514', null, 'un compte du cabinet ne porte pas de rôle client');

select tests.authenticate_as(:'partner_id', 'aal2');
select ok(public.can_assign_role('client_gerant', :'e1_id'), 'l''associé attribue les rôles client');
select tests.clear_auth();
select tests.authenticate_as(:'assist_id', 'aal1');
select ok(not public.can_assign_role('client_gerant', :'e1_id'), 'un assistant n''attribue pas de rôle client');
select tests.clear_auth();

-- 3. Interrupteur : fermé par défaut
select tests.authenticate_as(:'gerant_id', 'aal2');
select is((select count(*) from public.entities) + (select count(*) from public.entries) + (select count(*) from public.accounts), 0::bigint,
  'accès fermé par défaut : le client ne voit rien');
select tests.clear_auth();

select tests.authenticate_as(:'assist_id', 'aal1');
select throws_ok(format($q$select public.set_client_access(%L, 'active')$q$, :'e1_id'), '42501', null, 'un assistant n''ouvre pas l''accès des clients');
select tests.clear_auth();
select tests.authenticate_as(:'partner_id', 'aal2');
select throws_ok(format($q$update public.entities set client_access = 'active' where id = %L$q$, :'e1_id'), '42501', null, 'l''interrupteur ne se change pas par un UPDATE direct');
select lives_ok(format($q$select public.set_client_access(%L, 'active', 'Ouverture du portail')$q$, :'e1_id'), 'l''associé ouvre l''accès du client 1');
select tests.clear_auth();
select ok((select count(*) from public.audit_log where action = 'client_access' and entity_id = :'e1_id') = 1, 'l''ouverture est inscrite dans la piste d''audit');

-- 4. Lecture : gérant client 1
select tests.authenticate_as(:'gerant_id', 'aal2');
select is((select string_agg(name, ',') from public.entities), 'Client 1 SARL', 'le gérant ne voit que son dossier');
select is((select count(*) from public.entries), 2::bigint, 'le gérant voit les brouillards de son dossier (saisie et gérant, pas ceux du cabinet)');
select is((select count(*) from public.entries where status <> 'draft'), 0::bigint, 'aucune écriture validée visible');
select is((select count(*) from public.entry_lines), 4::bigint, 'seules les lignes des brouillards visibles sont lisibles');
select is((select count(*) from public.profiles), 1::bigint, 'le gérant ne voit que son propre profil');
select is((select count(*) from public.audit_log), 0::bigint, 'pas de piste d''audit pour un client');
select ok(not public.has_permission(:'e1_id', 'ledger.read'), 'pas de droit de lecture du grand livre');
select throws_ok(format($q$select public.validate_entry(%L)$q$, :'d2_id'), '42501', null, 'un client ne valide pas, même son propre brouillard');
select tests.clear_auth();

-- Sans TOTP, le gérant (rôle qui l'exige) ne voit rien
select tests.authenticate_as(:'gerant_id', 'aal1');
select is((select count(*) from public.entries), 0::bigint, 'gérant sans TOTP : rien');
select tests.clear_auth();

-- 5. Lecture : saisisseur
select tests.authenticate_as(:'saisie_id', 'aal1');
select is((select string_agg(label, ',') from public.entries), 'Brouillard saisie', 'le saisisseur ne voit que ses propres brouillards');
select tests.clear_auth();

-- 6. Isolation entre clients : le client 2 est encore fermé, puis ouvert
select tests.authenticate_as(:'gerant2_id', 'aal2');
select is((select count(*) from public.entries), 0::bigint, 'client 2 fermé : rien');
select tests.clear_auth();
select public.set_client_access(:'e2_id', 'active');
select tests.authenticate_as(:'gerant2_id', 'aal2');
select is((select string_agg(label, ',') from public.entries), 'Brouillard autre client', 'le client 2 ne voit que son brouillard');
select tests.clear_auth();

-- 7. Le personnel garde tout
select tests.authenticate_as(:'assist_id', 'aal1');
select is((select count(*) from public.entries where entity_id = :'e1_id'), 4::bigint, 'le personnel voit toujours tout le dossier');
select ok((select count(*) from public.profiles) > 1, 'le personnel voit l''annuaire');
select tests.clear_auth();

-- 8. Écriture : brouillard seulement, accès actif
select tests.authenticate_as(:'saisie_id', 'aal1');
select lives_ok(format($q$insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, label, created_by, currency_code)
  select %L, %L, fy.id, p.id, j.id, '2026-03-01', 'Nouveau brouillard client', %L, 'XOF'
    from public.fiscal_years fy join public.periods p on p.fiscal_year_id = fy.id and '2026-03-01' between p.start_date and p.end_date
    join public.journals j on j.entity_id = fy.entity_id and j.code = 'VT' where fy.entity_id = %L$q$, :'a_id', :'e1_id', :'saisie_id', :'e1_id'),
  'le client saisit un brouillard quand l''accès est actif');
select is((select count(*) from public.entries where label = 'Nouveau brouillard client'), 1::bigint, 'le brouillard a bien été créé');
select tests.clear_auth();

select public.set_client_access(:'e1_id', 'suspended', 'Abonnement non réglé');
select tests.authenticate_as(:'saisie_id', 'aal1');
select throws_ok(format($q$insert into public.entries (cabinet_id, entity_id, fiscal_year_id, period_id, journal_id, entry_date, label, created_by, currency_code)
  select %L, %L, fy.id, p.id, j.id, '2026-03-02', 'Refusé', %L, 'XOF'
    from public.fiscal_years fy join public.periods p on p.fiscal_year_id = fy.id and '2026-03-02' between p.start_date and p.end_date
    join public.journals j on j.entity_id = fy.entity_id and j.code = 'VT' where fy.entity_id = %L$q$, :'a_id', :'e1_id', :'saisie_id', :'e1_id'),
  '42501', null, 'accès suspendu : plus de nouvelle saisie');
select ok((select count(*) from public.entries) >= 1, 'accès suspendu : la lecture reste possible');
select tests.clear_auth();

select public.set_client_access(:'e1_id', 'disabled');
select tests.authenticate_as(:'saisie_id', 'aal1');
select is((select count(*) from public.entries), 0::bigint, 'accès désactivé : plus rien');
select tests.clear_auth();
select public.set_client_access(:'e1_id', 'active');

-- 9. Retour au client avec un motif
select tests.authenticate_as(:'gerant_id', 'aal2');
select throws_ok(format($q$select public.return_draft_to_client(%L, 'test')$q$, :'d1_id'), '42501', null, 'un client ne renvoie pas un brouillard');
select tests.clear_auth();
select tests.authenticate_as(:'assist_id', 'aal1');
select throws_ok(format($q$select public.return_draft_to_client(%L, '  ')$q$, :'d1_id'), '23514', null, 'le motif est obligatoire');
select throws_ok(format($q$select public.return_draft_to_client(%L, 'x')$q$, :'v1_id'), '23514', null, 'on ne renvoie qu''un brouillard');
select lives_ok(format($q$select public.return_draft_to_client(%L, 'Pièce illisible : joindre la facture')$q$, :'d1_id'), 'le comptable renvoie le brouillard avec un motif');
select tests.clear_auth();
select tests.authenticate_as(:'saisie_id', 'aal1');
select is((select returned_comment from public.entries where id = :'d1_id'), 'Pièce illisible : joindre la facture', 'le client lit le motif');
select is((select count(*) from public.notifications where kind = 'entry_returned'), 1::bigint, 'le client est notifié');
select tests.clear_auth();

select * from finish();
rollback;
