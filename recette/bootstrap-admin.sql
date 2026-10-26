-- Amorçage minimal de l'instance de RECETTE : un cabinet-coquille (obligatoire : un profil référence toujours un cabinet)
-- et le compte administrateur technique. Rien d'autre : ni dossier, ni autre utilisateur, ni donnée comptable.
-- Appelé uniquement par scripts/reset-recette.sh, sur la base de recette.
do $$
declare v_cabinet uuid; v_admin uuid := md5('akonta-recette:admin')::uuid; v_email text := 'admin.recette@akonta.test';
begin
  insert into public.cabinets (name) values ('Cabinet de recette Simetriik') returning id into v_cabinet;
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
  values (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', v_email,
          extensions.crypt('Recette-Admin-2027!', extensions.gen_salt('bf')), now(),
          '{"provider":"email","providers":["email"]}'::jsonb,
          jsonb_build_object('cabinet_id', v_cabinet, 'full_name', 'Administrateur technique', 'job_title', 'Administrateur technique'), now(), now(), '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), v_admin, v_email, jsonb_build_object('sub', v_admin::text, 'email', v_email, 'email_verified', true), 'email', now(), now(), now());
  insert into public.assignments (cabinet_id, user_id, entity_id, role_id)
  select v_cabinet, v_admin, null, id from public.roles where cabinet_id = v_cabinet and code = 'tech_admin';
end $$;
