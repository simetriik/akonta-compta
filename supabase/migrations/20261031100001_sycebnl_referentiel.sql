-- Référentiel comptable des entités (décision D-022) : le SYCEBNL (associations et autres entités à but non lucratif)
-- s'ajoute au système normal SYSCOHADA. Le référentiel se choisit à la création de l'entité et ne change plus.
--  1. entities.accounting_system accepte 'sycebnl' et devient immuable ;
--  2. reference_accounts est clé par (système, code) : codes jusqu'à 5 chiffres, niveaux jusqu'à 5 ;
--  3. accounts garde le référentiel d'origine de chaque compte (clé étrangère composite) ;
--  4. copy_reference_plan copie le plan du référentiel de l'entité ;
--  5. entry_templates porte le référentiel auquel s'applique un modèle.
-- Le plan SYCEBNL est chargé par la migration suivante (seed généré).

-- 1. Entités -------------------------------------------------------------------------------------------------------
alter table public.entities drop constraint entities_accounting_system_check;
alter table public.entities add constraint entities_accounting_system_check check (accounting_system in ('normal', 'sycebnl'));

-- Le référentiel détermine le plan, les modèles et les états : un changement passe par une nouvelle entité.
create or replace function public.entities_guard_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.accounting_system <> old.accounting_system then
    raise exception 'Le référentiel comptable d''une entité ne change pas : créer une nouvelle entité' using errcode = '23514';
  end if;
  if new.account_length <> old.account_length and exists (select 1 from public.fiscal_years where entity_id = old.id) then
    raise exception 'La longueur des comptes ne peut plus changer : un exercice existe' using errcode = '23514';
  end if;
  if (new.account_length <> old.account_length or new.monthly_lock_enabled <> old.monthly_lock_enabled
      or new.currency_code <> old.currency_code)
     and auth.uid() is not null and not public.has_permission(null, 'cabinet.settings') then
    raise exception 'Les paramètres comptables de l''entité sont réservés à l''associé' using errcode = '42501';
  end if;
  new.cabinet_id := old.cabinet_id;
  return new;
end $$;

-- 2. Plan de référence par système ---------------------------------------------------------------------------------
alter table public.accounts drop constraint accounts_reference_code_fkey;
alter table public.reference_accounts drop constraint reference_accounts_parent_code_fkey;
alter table public.reference_accounts drop constraint reference_accounts_pkey;
alter table public.reference_accounts drop constraint reference_accounts_code_check;
alter table public.reference_accounts drop constraint reference_accounts_level_check;

alter table public.reference_accounts add column system text not null default 'normal' check (system in ('normal', 'sycebnl'));
alter table public.reference_accounts add constraint reference_accounts_pkey primary key (system, code);
alter table public.reference_accounts add constraint reference_accounts_code_check check (code ~ '^[1-9][0-9]{0,4}$');
alter table public.reference_accounts add constraint reference_accounts_level_check check (level between 1 and 5);
alter table public.reference_accounts add constraint reference_accounts_parent_fkey
  foreign key (system, parent_code) references public.reference_accounts (system, code);
comment on table public.reference_accounts is 'Plans comptables de référence par système (SYSCOHADA révisé « normal », SYCEBNL), source des plans d''entité.';

-- 3. Origine des comptes d'entité ----------------------------------------------------------------------------------
alter table public.accounts add column reference_system text;
update public.accounts set reference_system = 'normal' where reference_code is not null;
alter table public.accounts add constraint accounts_reference_system_check check ((reference_code is null) = (reference_system is null));
alter table public.accounts add constraint accounts_reference_fkey
  foreign key (reference_system, reference_code) references public.reference_accounts (system, code);

-- Un compte issu de la copie du plan garde le sens, la nature et le rattachement du plan de référence : l'héritage
-- depuis le plus long préfixe existant (valable pour une subdivision créée à la main) fausserait par exemple les
-- amortissements (28) ou le déficit (139), et rattacherait les comptes à 2 chiffres du SYCEBNL au premier d'entre eux.
create or replace function public.accounts_validate()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_len int;
  v_sig text;
  v_parent public.accounts%rowtype;
begin
  select account_length into v_len from public.entities where id = new.entity_id;
  if v_len is null then raise exception 'Entité inconnue' using errcode = '23503'; end if;
  if new.cabinet_id <> (select cabinet_id from public.entities where id = new.entity_id) then
    raise exception 'Cabinet incohérent' using errcode = '23514';
  end if;
  if length(new.code) <> v_len then
    raise exception 'Le numéro de compte doit comporter % chiffres (reçu : %)', v_len, new.code using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' then
    if new.code <> old.code or new.entity_id <> old.entity_id or new.cabinet_id <> old.cabinet_id then
      raise exception 'Le numéro et le rattachement d''un compte ne se modifient pas' using errcode = '23514';
    end if;
    if new.normal_side <> old.normal_side or new.nature <> old.nature or new.class <> old.class then
      raise exception 'Le sens, la nature et la classe d''un compte ne changent pas' using errcode = '23514';
    end if;
    return new;
  end if;
  -- Insertion : classe déduite
  new.class := left(new.code, 1)::smallint;
  if current_setting('akonta.reference_copy', true) = 'on' then
    return new;   -- copie du plan de référence : attributs et rattachement fixés par la copie
  end if;
  -- Subdivision créée à la main : parent = plus long préfixe significatif existant
  v_sig := public.account_significant(new.code);
  if new.parent_id is null and length(v_sig) > 1 then
    select a.* into v_parent
      from public.accounts a
     where a.entity_id = new.entity_id
       and a.code <> new.code
       and v_sig like public.account_significant(a.code) || '%'
       and length(public.account_significant(a.code)) < length(v_sig)
     order by length(public.account_significant(a.code)) desc
     limit 1;
    new.parent_id := v_parent.id;
  elsif new.parent_id is not null then
    select a.* into v_parent from public.accounts a where a.id = new.parent_id and a.entity_id = new.entity_id;
    if v_parent.id is null then raise exception 'Parent inconnu dans ce plan' using errcode = '23503'; end if;
    if v_sig not like public.account_significant(v_parent.code) || '%' or length(v_sig) <= length(public.account_significant(v_parent.code)) then
      raise exception 'Le compte % n''est pas une subdivision de %', new.code, v_parent.code using errcode = '23514';
    end if;
  end if;
  if v_parent.id is not null then
    -- Subdivision : héritage, jamais de changement de sens
    new.nature := v_parent.nature;
    new.normal_side := v_parent.normal_side;
    new.is_collective := coalesce(new.is_collective, false) or v_parent.is_collective;
    new.is_letterable := coalesce(new.is_letterable, false) or v_parent.is_letterable;
    if new.reference_code is null then
      new.reference_code := v_parent.reference_code;
      new.reference_system := v_parent.reference_system;
    end if;
  elsif length(v_sig) > 2 then
    raise exception 'Aucun compte parent pour % : créer d''abord la subdivision de niveau supérieur', new.code using errcode = '23514';
  end if;
  return new;
end $$;

-- 4. Copie du plan de référence du référentiel de l'entité ----------------------------------------------------------
-- Compte imputable : SYSCOHADA = niveau 3 ou plus (inchangé) ; SYCEBNL = compte sans subdivision.
create or replace function public.copy_reference_plan(p_entity uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_len int; v_cabinet uuid; v_system text; v_count int;
begin
  select account_length, cabinet_id, accounting_system into v_len, v_cabinet, v_system from public.entities where id = p_entity;
  perform set_config('akonta.reference_copy', 'on', true);
  -- Deux codes de référence peuvent donner le même numéro complété (ex. 13 et 130 → 1300000) :
  -- on garde le plus détaillé.
  insert into public.accounts (cabinet_id, entity_id, code, label, class, nature, normal_side, is_collective, is_letterable,
                               allow_posting, reference_code, reference_system)
  select distinct on (public.pad_account_code(r.code, v_len))
         v_cabinet, p_entity, public.pad_account_code(r.code, v_len), r.label, r.class, r.nature, r.normal_side,
         r.is_collective, r.is_letterable,
         case when v_system = 'normal' then r.level >= 3
              else not exists (select 1 from public.reference_accounts c where c.system = r.system and c.parent_code = r.code) end,
         r.code, r.system
    from public.reference_accounts r
   where r.system = v_system
     and r.class between 1 and 8
     and not exists (select 1 from public.accounts a where a.entity_id = p_entity and a.code = public.pad_account_code(r.code, v_len))
   order by public.pad_account_code(r.code, v_len), r.level desc;
  get diagnostics v_count = row_count;
  -- Rattachement hiérarchique d'après le plan de référence (par numéro complété du parent)
  update public.accounts a
     set parent_id = p.id
    from public.reference_accounts r
    join public.accounts p on p.entity_id = p_entity and p.code = public.pad_account_code(r.parent_code, v_len)
   where a.entity_id = p_entity and a.reference_system = r.system and a.reference_code = r.code
     and r.parent_code is not null and a.parent_id is null and p.id <> a.id;
  perform set_config('akonta.reference_copy', 'off', true);
  return v_count;
end $$;

-- 5. Modèles d'écritures par référentiel ---------------------------------------------------------------------------
alter table public.entry_templates add column accounting_system text not null default 'normal'
  check (accounting_system in ('normal', 'sycebnl'));
comment on column public.entry_templates.accounting_system is 'Référentiel auquel s''applique le modèle : ses numéros de compte viennent du plan de ce référentiel.';
