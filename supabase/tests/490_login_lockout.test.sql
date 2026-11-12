-- Recette 11/11/2026, AN-01 : verrouillage d'un compte après 5 échecs de connexion consécutifs.
begin;
select plan(10);

select tests.create_cabinet('Cabinet A') as id \gset a_
select tests.create_user('assist@a.test', :'a_id') as id \gset assist_
select tests.create_user('partner@a.test', :'a_id', 'Associé') as id \gset partner_
select tests.assign(:'partner_id', :'a_id', 'partner');


-- 4 échecs : aucun verrou
select is((select public.hook_password_verification_attempt(jsonb_build_object('user_id', :'assist_id', 'valid', false)) ->> 'decision'), 'continue', 'échec 1 : la connexion suit son cours (refusée par le mot de passe)');
select public.hook_password_verification_attempt(jsonb_build_object('user_id', :'assist_id', 'valid', false));
select public.hook_password_verification_attempt(jsonb_build_object('user_id', :'assist_id', 'valid', false));
select public.hook_password_verification_attempt(jsonb_build_object('user_id', :'assist_id', 'valid', false));
select is((select failed_count from public.login_attempts where user_id = :'assist_id'), 4, '4 échecs comptés');
select is((select locked_until is null from public.login_attempts where user_id = :'assist_id'), true, 'pas encore verrouillé à 4 échecs');

-- 5e échec : verrouillage, puis refus même avec le bon mot de passe
select public.hook_password_verification_attempt(jsonb_build_object('user_id', :'assist_id', 'valid', false));
select is((select locked_until > now() from public.login_attempts where user_id = :'assist_id'), true, '5e échec : compte verrouillé');
select is((select public.hook_password_verification_attempt(jsonb_build_object('user_id', :'assist_id', 'valid', true)) ->> 'decision'), 'reject', 'verrouillé : refus même avec le bon mot de passe');
select is((select count(*) from public.audit_log where action = 'login_locked' and record_id = :'assist_id'), 1::bigint, 'le verrouillage est tracé dans la piste d''audit');

-- Après l'échéance : la connexion est de nouveau possible, un succès remet le compteur à zéro
update public.login_attempts set locked_until = now() - interval '1 minute' where user_id = :'assist_id';
select is((select public.hook_password_verification_attempt(jsonb_build_object('user_id', :'assist_id', 'valid', true)) ->> 'decision'), 'continue', 'verrou échu : connexion possible');
select is((select count(*) from public.login_attempts where user_id = :'assist_id'), 0::bigint, 'un succès remet le compteur à zéro');

-- Levée du verrou par l'associé, pas par un assistant
select public.hook_password_verification_attempt(jsonb_build_object('user_id', :'assist_id', 'valid', false));
select tests.authenticate_as(:'assist_id');
select throws_ok(format('select public.unlock_login(%L)', :'assist_id'), '42501', null, 'un assistant ne déverrouille pas');
select tests.authenticate_as(:'partner_id', 'aal2');
select lives_ok(format('select public.unlock_login(%L)', :'assist_id'), 'l''associé déverrouille');

select * from finish();
rollback;
