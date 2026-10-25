-- Helpers de test (schéma `tests`, base locale uniquement). Ce fichier n'est pas une transaction annulée :
-- il installe les fonctions utilisées par les autres fichiers de test.
create schema if not exists tests;

-- Crée un utilisateur Auth + profil dans un cabinet, renvoie son identifiant.
create or replace function tests.create_user(p_email text, p_cabinet uuid, p_full_name text default 'Test')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', p_email,
          extensions.crypt('Motdepasse-Test-123', extensions.gen_salt('bf')), now(),
          '{"provider":"email","providers":["email"]}'::jsonb,
          jsonb_build_object('cabinet_id', p_cabinet, 'full_name', p_full_name), now(), now());
  return v_id;
end $$;

-- Se fait passer pour un utilisateur connecté (aal1 ou aal2).
create or replace function tests.authenticate_as(p_user uuid, p_aal text default 'aal1')
returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- Revient au rôle postgres (fin de l'emprunt d'identité).
create or replace function tests.clear_auth()
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'postgres', true);
end $$;

-- Crée un cabinet (avec ses rôles par défaut) et renvoie son identifiant.
create or replace function tests.create_cabinet(p_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  insert into public.cabinets (name) values (p_name) returning id into v_id;
  return v_id;
end $$;

-- Crée une entité dans un cabinet (hors RLS) et renvoie son identifiant.
create or replace function tests.create_entity(p_cabinet uuid, p_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  insert into public.entities (cabinet_id, name) values (p_cabinet, p_name) returning id into v_id;
  return v_id;
end $$;

-- Affecte un rôle (par code) à un utilisateur, sur un dossier ou à l'échelle du cabinet.
create or replace function tests.assign(p_user uuid, p_cabinet uuid, p_role_code text, p_entity uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  insert into public.assignments (cabinet_id, user_id, entity_id, role_id)
  select p_cabinet, p_user, p_entity, r.id from public.roles r where r.cabinet_id = p_cabinet and r.code = p_role_code
  returning id into v_id;
  return v_id;
end $$;

-- Exécute une requête en attendant une erreur SQLSTATE précise ; renvoie true si elle survient.
create or replace function tests.fails_with(p_sql text, p_sqlstate text)
returns boolean language plpgsql as $$
begin
  execute p_sql;
  return false;
exception when others then
  return sqlstate = p_sqlstate;
end $$;

-- Les tests changent de rôle (authenticated) : ils doivent garder accès aux helpers.
grant usage on schema tests to authenticated, anon;
grant execute on all functions in schema tests to authenticated, anon;

select plan(1);
select pass('helpers de test installés');
select * from finish();
