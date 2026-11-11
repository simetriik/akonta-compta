-- =============================================================================
-- Recette interne du 11/11/2026, AN-01 : verrouillage d'un compte après 5 échecs de connexion consécutifs.
-- Supabase Auth appelle `hook_password_verification_attempt` à chaque vérification de mot de passe (config.toml,
-- [auth.hook.password_verification_attempt]). Après 5 échecs de suite, le compte est refusé pendant 15 minutes,
-- même avec le bon mot de passe ; un succès hors verrouillage remet le compteur à zéro.
-- Un associé (cabinet.settings) ou l'administrateur de la sécurité (users.manage) peut lever le verrou avant l'échéance.
-- =============================================================================
create table public.login_attempts (
  user_id       uuid primary key references auth.users (id) on delete cascade,
  failed_count  int not null default 0,
  locked_until  timestamptz,
  last_failed_at timestamptz
);
alter table public.login_attempts enable row level security;
revoke all on public.login_attempts from anon, authenticated;
-- Lecture seule pour ceux qui gèrent la sécurité ou le cabinet (liste des comptes verrouillés) ; écriture réservée aux fonctions ci-dessous.
grant select on public.login_attempts to authenticated;
create policy login_attempts_select on public.login_attempts for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = user_id and p.cabinet_id = public.current_cabinet_id())
         and (public.has_permission(null, 'users.manage') or public.has_permission(null, 'cabinet.settings')));

create or replace function public.hook_password_verification_attempt(event jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := (event ->> 'user_id')::uuid;
  v_valid boolean := coalesce((event ->> 'valid')::boolean, false);
  v_locked timestamptz;
  v_count int;
  c_max constant int := 5;
  c_minutes constant int := 15;
begin
  select locked_until into v_locked from public.login_attempts where user_id = v_user;
  if v_locked is not null and v_locked > now() then
    return jsonb_build_object('decision', 'reject',
      'message', format('Compte verrouillé après %s échecs de connexion. Réessayez à %s ou demandez à un associé de le déverrouiller.', c_max, to_char(v_locked at time zone 'UTC', 'HH24:MI "UTC"')));
  end if;
  if v_valid then
    delete from public.login_attempts where user_id = v_user;
    return jsonb_build_object('decision', 'continue');
  end if;
  insert into public.login_attempts (user_id, failed_count, last_failed_at) values (v_user, 1, now())
  on conflict (user_id) do update
    set failed_count = case when public.login_attempts.locked_until is not null and public.login_attempts.locked_until <= now() then 1 else public.login_attempts.failed_count + 1 end,
        locked_until = null, last_failed_at = now()
  returning failed_count into v_count;
  if v_count >= c_max then
    update public.login_attempts set locked_until = now() + make_interval(mins => c_minutes) where user_id = v_user;
    insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, payload)
    select p.cabinet_id, null, 'login_locked', 'login_attempts', v_user::text, jsonb_build_object('failed_count', v_count, 'minutes', c_minutes)
      from public.profiles p where p.id = v_user and p.cabinet_id is not null;
  end if;
  return jsonb_build_object('decision', 'continue');
end $$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.hook_password_verification_attempt(jsonb) to supabase_auth_admin;
revoke execute on function public.hook_password_verification_attempt(jsonb) from authenticated, anon, public;
grant select, insert, update, delete on public.login_attempts to supabase_auth_admin;

-- Levée du verrou par un utilisateur qui gère la sécurité, dans son cabinet ; tracée.
create or replace function public.unlock_login(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_cabinet uuid;
begin
  select cabinet_id into v_cabinet from public.profiles where id = p_user;
  if v_cabinet is null or v_cabinet is distinct from public.current_cabinet_id() or not (public.has_permission(null, 'users.manage') or public.has_permission(null, 'cabinet.settings')) then
    raise exception 'Permission refusée : déverrouiller un compte' using errcode = '42501';
  end if;
  delete from public.login_attempts where user_id = p_user;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, payload)
  values (v_cabinet, auth.uid(), 'login_unlocked', 'login_attempts', p_user::text, '{}'::jsonb);
end $$;
revoke all on function public.unlock_login(uuid) from public, anon;
grant execute on function public.unlock_login(uuid) to authenticated;

-- Retour arrière : drop function public.unlock_login(uuid); drop function public.hook_password_verification_attempt(jsonb); drop table public.login_attempts;
