-- =============================================================================
-- Akonta — Migration 0003 : référentiels (module 3, conception §3.3, §3.4, §10.3)
-- Plan de référence SYSCOHADA, plan de l''entité à longueur fixe, tiers,
-- journaux et modèles de journaux, modèles d''écritures, taux.
-- =============================================================================

create type public.account_nature as enum ('balance_sheet', 'income', 'analytic');
create type public.posting_side as enum ('debit', 'credit');
create type public.third_party_type as enum ('customer', 'supplier', 'employee', 'partner', 'other');
create type public.journal_type as enum ('purchases', 'sales', 'bank', 'cash', 'misc', 'opening', 'payroll');
create type public.amount_formula as enum ('input', 'percent_of', 'balance');

-- -----------------------------------------------------------------------------
-- Plan de référence SYSCOHADA révisé (seed versionné, migration 0004)
-- -----------------------------------------------------------------------------
create table public.reference_accounts (
  code           text primary key check (code ~ '^[1-9][0-9]{0,3}$'),
  label          text not null,
  class          smallint not null check (class between 1 and 9),
  level          smallint not null check (level between 1 and 4),
  parent_code    text references public.reference_accounts (code),
  nature         public.account_nature not null,
  normal_side    public.posting_side not null,
  is_collective  boolean not null default false,
  is_letterable  boolean not null default false
);
comment on table public.reference_accounts is 'Plan comptable SYSCOHADA révisé (classes 1 à 9), source des plans d''entité.';
alter table public.reference_accounts enable row level security;
create policy reference_accounts_select on public.reference_accounts for select to authenticated using (true);

-- -----------------------------------------------------------------------------
-- Plan de comptes de l''entité : numéros à longueur fixe (§3.3)
-- -----------------------------------------------------------------------------
create table public.accounts (
  id              uuid primary key default gen_random_uuid(),
  cabinet_id      uuid not null references public.cabinets (id) on delete cascade,
  entity_id       uuid not null references public.entities (id) on delete cascade,
  code            text not null check (code ~ '^[1-9][0-9]+$'),
  label           text not null check (length(trim(label)) >= 1),
  class           smallint not null check (class between 1 and 9),
  nature          public.account_nature not null,
  normal_side     public.posting_side not null,
  is_collective   boolean not null default false,
  is_letterable   boolean not null default false,
  allow_posting   boolean not null default true,
  is_active       boolean not null default true,
  parent_id       uuid references public.accounts (id),
  reference_code  text references public.reference_accounts (code),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (entity_id, code)
);
comment on table public.accounts is 'Plan de comptes d''une entité : copie du plan de référence, subdivisée ; longueur fixe par entité.';
create index accounts_entity_class_idx on public.accounts (entity_id, class, code);
create index accounts_parent_idx on public.accounts (parent_id);
create trigger accounts_updated_at before update on public.accounts for each row execute function public.set_updated_at();

-- Chiffres significatifs d''un numéro (sans les zéros de complément à droite).
create or replace function public.account_significant(p_code text)
returns text language sql immutable as $$ select rtrim(p_code, '0'); $$;

-- Complète un numéro à la longueur fixe de l''entité.
create or replace function public.pad_account_code(p_code text, p_length int)
returns text language sql immutable as $$ select rpad(p_code, p_length, '0'); $$;

-- Règles de création / modification d''un compte :
--   longueur fixe, parent = compte existant dont les chiffres significatifs préfixent le nouveau,
--   héritage de la classe, de la nature et du sens (jamais de changement de sens), désactivation réversible.
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
  -- Insertion : classe déduite, parent = plus long préfixe significatif existant
  new.class := left(new.code, 1)::smallint;
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
    if new.reference_code is null then new.reference_code := v_parent.reference_code; end if;
  elsif length(v_sig) > 2 then
    raise exception 'Aucun compte parent pour % : créer d''abord la subdivision de niveau supérieur', new.code using errcode = '23514';
  end if;
  return new;
end $$;

create trigger accounts_validate before insert or update on public.accounts
  for each row execute function public.accounts_validate();

-- Un compte ne se supprime pas s''il a des subdivisions (les mouvements sont contrôlés par la migration de saisie).
create or replace function public.accounts_guard_delete()
returns trigger language plpgsql as $$
begin
  if exists (select 1 from public.accounts where parent_id = old.id) then
    raise exception 'Ce compte a des subdivisions : désactivez-le plutôt' using errcode = '23503';
  end if;
  return old;
end $$;
create trigger accounts_guard_delete before delete on public.accounts
  for each row execute function public.accounts_guard_delete();

-- Copie du plan de référence (classes 1 à 8) dans une entité, à sa longueur fixe (D-007).
create or replace function public.copy_reference_plan(p_entity uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_len int; v_cabinet uuid; v_count int;
begin
  select account_length, cabinet_id into v_len, v_cabinet from public.entities where id = p_entity;
  -- Deux codes de référence peuvent donner le même numéro complété (ex. 13 et 130 → 1300000) :
  -- on garde le plus détaillé.
  insert into public.accounts (cabinet_id, entity_id, code, label, class, nature, normal_side, is_collective, is_letterable,
                               allow_posting, reference_code)
  select distinct on (public.pad_account_code(r.code, v_len))
         v_cabinet, p_entity, public.pad_account_code(r.code, v_len), r.label, r.class, r.nature, r.normal_side,
         r.is_collective, r.is_letterable, r.level >= 3, r.code
    from public.reference_accounts r
   where r.class between 1 and 8
     and not exists (select 1 from public.accounts a where a.entity_id = p_entity and a.code = public.pad_account_code(r.code, v_len))
   order by public.pad_account_code(r.code, v_len), r.level desc;
  get diagnostics v_count = row_count;
  -- Rattachement hiérarchique d''après le plan de référence (par numéro complété du parent)
  update public.accounts a
     set parent_id = p.id
    from public.reference_accounts r
    join public.accounts p on p.entity_id = p_entity and p.code = public.pad_account_code(r.parent_code, v_len)
   where a.entity_id = p_entity and a.reference_code = r.code and r.parent_code is not null and a.parent_id is null
     and p.id <> a.id;
  return v_count;
end $$;

-- -----------------------------------------------------------------------------
-- Tiers : collectif numérique + auxiliaire alphanumérique (§3.3, §10.3)
-- -----------------------------------------------------------------------------
create table public.third_parties (
  id          uuid primary key default gen_random_uuid(),
  cabinet_id  uuid not null references public.cabinets (id) on delete cascade,
  entity_id   uuid not null references public.entities (id) on delete cascade,
  code        text not null check (code ~ '^[A-Z0-9]{2,10}$'),
  name        text not null check (length(trim(name)) >= 2),
  type        public.third_party_type not null default 'other',
  tax_id      text,
  address     text,
  phone       text,
  email       text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (entity_id, code)
);
comment on table public.third_parties is 'Tiers d''une entité : code alphanumérique unique, rattaché à un ou plusieurs comptes collectifs.';
create index third_parties_entity_idx on public.third_parties (entity_id, name);
create trigger third_parties_updated_at before update on public.third_parties for each row execute function public.set_updated_at();

create table public.third_party_accounts (
  third_party_id  uuid not null references public.third_parties (id) on delete cascade,
  account_id      uuid not null references public.accounts (id),
  primary key (third_party_id, account_id)
);

-- Le compte rattaché est un collectif de la même entité.
create or replace function public.third_party_accounts_validate()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_ok boolean;
begin
  select a.is_collective and a.entity_id = t.entity_id into v_ok
    from public.accounts a, public.third_parties t
   where a.id = new.account_id and t.id = new.third_party_id;
  if not coalesce(v_ok, false) then
    raise exception 'Un tiers se rattache à un compte collectif de sa propre entité' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger third_party_accounts_validate before insert or update on public.third_party_accounts
  for each row execute function public.third_party_accounts_validate();

-- Cohérence cabinet / entité (tiers, journaux, modèles)
create or replace function public.check_entity_cabinet()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.entity_id is not null and new.cabinet_id <> (select cabinet_id from public.entities where id = new.entity_id) then
    raise exception 'Cabinet incohérent' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger third_parties_cabinet before insert or update on public.third_parties
  for each row execute function public.check_entity_cabinet();

-- -----------------------------------------------------------------------------
-- Journaux (§3.4, §10.3)
-- -----------------------------------------------------------------------------
create table public.journal_templates (
  id                  uuid primary key default gen_random_uuid(),
  cabinet_id          uuid not null references public.cabinets (id) on delete cascade,
  code                text not null check (code ~ '^[A-Z0-9]{2,6}$'),
  label               text not null,
  type                public.journal_type not null,
  is_default_checked  boolean not null default true,
  sort_order          smallint not null default 0,
  unique (cabinet_id, code)
);
comment on table public.journal_templates is 'Modèle de journaux du cabinet, proposé coché à l''ouverture d''un dossier ; réglable par l''associé.';

create table public.journals (
  id                   uuid primary key default gen_random_uuid(),
  cabinet_id           uuid not null references public.cabinets (id) on delete cascade,
  entity_id            uuid not null references public.entities (id) on delete cascade,
  code                 text not null check (code ~ '^[A-Z0-9]{2,6}$'),
  label                text not null,
  type                 public.journal_type not null,
  treasury_account_id  uuid references public.accounts (id),
  currency_code        char(3) not null default 'XOF',
  is_active            boolean not null default true,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (entity_id, code)
);
comment on table public.journals is 'Journaux d''une entité ; le journal des à-nouveaux (type opening) est imposé et unique.';
create unique index journals_one_opening on public.journals (entity_id) where type = 'opening';
create index journals_entity_idx on public.journals (entity_id);
create trigger journals_updated_at before update on public.journals for each row execute function public.set_updated_at();
create trigger journals_cabinet before insert or update on public.journals for each row execute function public.check_entity_cabinet();

create or replace function public.journals_validate()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_class smallint; v_entity uuid;
begin
  if new.type in ('bank', 'cash') then
    if new.treasury_account_id is null then
      raise exception 'Un journal de trésorerie est relié à son compte de trésorerie' using errcode = '23514';
    end if;
    select class, entity_id into v_class, v_entity from public.accounts where id = new.treasury_account_id;
    if v_class <> 5 or v_entity <> new.entity_id then
      raise exception 'Le compte de trésorerie doit être un compte de classe 5 de la même entité' using errcode = '23514';
    end if;
  end if;
  if tg_op = 'UPDATE' and (new.type <> old.type or new.entity_id <> old.entity_id) then
    raise exception 'Le type et l''entité d''un journal ne changent pas' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' and old.type = 'opening' and not new.is_active then
    raise exception 'Le journal des à-nouveaux est imposé : il ne se désactive pas' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger journals_validate before insert or update on public.journals
  for each row execute function public.journals_validate();

create or replace function public.journals_guard_delete()
returns trigger language plpgsql as $$
begin
  raise exception 'Le journal des à-nouveaux est imposé : il ne se supprime pas' using errcode = '42501';
end $$;
-- (la clause WHEN laisse passer les suppressions en cascade, ex. suppression de l''entité)
create trigger journals_guard_delete before delete on public.journals
  for each row when (old.type = 'opening' and pg_trigger_depth() = 0) execute function public.journals_guard_delete();

-- Création des journaux d''une entité depuis le modèle du cabinet (codes choisis ; AN toujours créé).
create or replace function public.create_journals_from_template(p_entity uuid, p_codes text[] default null)
returns integer language plpgsql security definer set search_path = public as $$
declare v_cabinet uuid; v_count int;
begin
  select cabinet_id into v_cabinet from public.entities where id = p_entity;
  insert into public.journals (cabinet_id, entity_id, code, label, type)
  select v_cabinet, p_entity, t.code, t.label, t.type
    from public.journal_templates t
   where t.cabinet_id = v_cabinet
     and t.type not in ('bank', 'cash')          -- les journaux de trésorerie exigent un compte : créés par l''assistant d''ouverture
     and (t.type = 'opening' or (p_codes is null and t.is_default_checked) or t.code = any (coalesce(p_codes, '{}')))
     and not exists (select 1 from public.journals j where j.entity_id = p_entity and j.code = t.code)
   order by t.sort_order;
  get diagnostics v_count = row_count;
  return v_count;
end $$;

-- -----------------------------------------------------------------------------
-- Taux paramétrables avec dates de validité (§10.3)
-- -----------------------------------------------------------------------------
create table public.tax_rates (
  id          uuid primary key default gen_random_uuid(),
  cabinet_id  uuid not null references public.cabinets (id) on delete cascade,
  code        text not null check (code ~ '^[A-Z0-9_]{2,20}$'),
  label       text not null,
  rate        numeric(9,6) not null check (rate >= 0 and rate <= 1),   -- 0.18 = 18 %
  valid_from  date not null,
  valid_to    date,
  check (valid_to is null or valid_to >= valid_from),
  exclude using gist (cabinet_id with =, code with =, daterange(valid_from, valid_to, '[]') with &&)
);
comment on table public.tax_rates is 'Taux de TVA, AIB, retenues, TAF, IS… avec périodes de validité sans chevauchement.';

create or replace function public.tax_rate_at(p_cabinet uuid, p_code text, p_date date)
returns numeric language sql stable security definer set search_path = public as $$
  select rate from public.tax_rates
   where cabinet_id = p_cabinet and code = p_code and p_date >= valid_from and (valid_to is null or p_date <= valid_to)
   limit 1;
$$;

-- -----------------------------------------------------------------------------
-- Modèles d''écritures (niveau cabinet ou entité) (§10.3)
-- -----------------------------------------------------------------------------
create table public.entry_templates (
  id            uuid primary key default gen_random_uuid(),
  cabinet_id    uuid not null references public.cabinets (id) on delete cascade,
  entity_id     uuid references public.entities (id) on delete cascade,  -- null = modèle du cabinet
  code          text not null check (code ~ '^[A-Z0-9_]{2,20}$'),
  label         text not null,
  journal_type  public.journal_type,
  description   text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create unique index entry_templates_unique on public.entry_templates (cabinet_id, coalesce(entity_id, '00000000-0000-0000-0000-000000000000'::uuid), code);
create trigger entry_templates_updated_at before update on public.entry_templates for each row execute function public.set_updated_at();
create trigger entry_templates_cabinet before insert or update on public.entry_templates for each row execute function public.check_entity_cabinet();

create table public.entry_template_lines (
  id              uuid primary key default gen_random_uuid(),
  template_id     uuid not null references public.entry_templates (id) on delete cascade,
  line_no         smallint not null check (line_no between 1 and 50),
  account_code    text not null,        -- numéro de référence (ex. 4452) ou collectif (ex. 4011) : complété à la longueur de l''entité
  uses_third_party boolean not null default false,
  side            public.posting_side not null,
  formula         public.amount_formula not null default 'input',
  ref_line_no     smallint,             -- ligne de référence pour percent_of
  percent         numeric(9,6),         -- taux fixe (0.18) …
  tax_rate_code   text,                 -- … ou code de taux paramétré (prioritaire)
  label           text,
  unique (template_id, line_no),
  check (formula <> 'percent_of' or (ref_line_no is not null and (percent is not null or tax_rate_code is not null)))
);
comment on table public.entry_template_lines is 'Lignes d''un modèle : compte (ou collectif + tiers), sens, formule (saisie, pourcentage d''une autre ligne, solde).';

-- Modèles de journaux, taux et modèles d''écritures par défaut d''un nouveau cabinet (§10.3, Q-002)
create or replace function public.seed_default_referentials(p_cabinet uuid)
returns void language plpgsql security definer set search_path = public as $$
declare t uuid;
begin
  insert into public.journal_templates (cabinet_id, code, label, type, is_default_checked, sort_order) values
    (p_cabinet, 'AC', 'Achats',               'purchases', true, 10),
    (p_cabinet, 'VT', 'Ventes',               'sales',     true, 20),
    (p_cabinet, 'BQ', 'Banque',               'bank',      true, 30),
    (p_cabinet, 'CA', 'Caisse',               'cash',      true, 40),
    (p_cabinet, 'OD', 'Opérations diverses',  'misc',      true, 50),
    (p_cabinet, 'PA', 'Paie',                 'payroll',   false, 60),
    (p_cabinet, 'AN', 'À-nouveaux',           'opening',   true, 70);

  insert into public.tax_rates (cabinet_id, code, label, rate, valid_from) values
    (p_cabinet, 'TVA',      'TVA',                                   0.18,   '2000-01-01'),
    (p_cabinet, 'AIB1',     'AIB 1 % (fournisseur immatriculé)',     0.01,   '2000-01-01'),
    (p_cabinet, 'AIB5',     'AIB 5 % (fournisseur non immatriculé)', 0.05,   '2000-01-01'),
    (p_cabinet, 'TVA_RET',  'TVA retenue à la source',               0.18,   '2000-01-01'),
    (p_cabinet, 'TAF',      'Taxe sur les activités financières',    0.10,   '2000-01-01'),
    (p_cabinet, 'IS',       'Impôt sur les sociétés',                0.30,   '2000-01-01'),
    (p_cabinet, 'IS_MIN',   'Minimum d''impôt (taux sur CA)',        0.005,  '2000-01-01'),
    (p_cabinet, 'CNSS_SAL', 'CNSS part salariale',                   0.036,  '2000-01-01'),
    (p_cabinet, 'CNSS_PAT', 'CNSS part patronale',                   0.154,  '2000-01-01');

  -- Achat avec TVA
  insert into public.entry_templates (cabinet_id, code, label, journal_type, description)
  values (p_cabinet, 'ACHAT_TVA', 'Achat avec TVA', 'purchases', 'Charge HT, TVA récupérable, fournisseur TTC') returning id into t;
  insert into public.entry_template_lines (template_id, line_no, account_code, uses_third_party, side, formula, ref_line_no, tax_rate_code, label) values
    (t, 1, '6011', false, 'debit',  'input',      null, null,  'Achat HT'),
    (t, 2, '4452', false, 'debit',  'percent_of', 1,    'TVA', 'TVA récupérable'),
    (t, 3, '4011', true,  'credit', 'balance',    null, null,  'Fournisseur TTC');
  -- Vente avec TVA
  insert into public.entry_templates (cabinet_id, code, label, journal_type, description)
  values (p_cabinet, 'VENTE_TVA', 'Vente avec TVA', 'sales', 'Client TTC, vente HT, TVA facturée') returning id into t;
  insert into public.entry_template_lines (template_id, line_no, account_code, uses_third_party, side, formula, ref_line_no, tax_rate_code, label) values
    (t, 1, '7011', false, 'credit', 'input',      null, null,  'Vente HT'),
    (t, 2, '4431', false, 'credit', 'percent_of', 1,    'TVA', 'TVA facturée'),
    (t, 3, '4111', true,  'debit',  'balance',    null, null,  'Client TTC');
  -- Règlement client avec AIB et TVA retenue
  insert into public.entry_templates (cabinet_id, code, label, journal_type, description)
  values (p_cabinet, 'REGL_CLIENT_RET', 'Règlement client avec AIB et TVA retenue', 'bank', 'Banque net, AIB et TVA retenues, client soldé') returning id into t;
  insert into public.entry_template_lines (template_id, line_no, account_code, uses_third_party, side, formula, ref_line_no, tax_rate_code, label) values
    (t, 1, '4111', true,  'credit', 'input',      null, null,     'Client (montant TTC réglé)'),
    (t, 2, '4478', false, 'debit',  'percent_of', 1,    'AIB1',   'AIB retenu par le client'),
    (t, 3, '4452', false, 'debit',  'percent_of', 1,    'TVA_RET','TVA retenue à la source'),
    (t, 4, '5211', false, 'debit',  'balance',    null, null,     'Banque (net encaissé)');
  -- Frais bancaires avec TAF
  insert into public.entry_templates (cabinet_id, code, label, journal_type, description)
  values (p_cabinet, 'FRAIS_BQ_TAF', 'Frais bancaires avec TAF', 'bank', 'Frais HT, TAF, banque') returning id into t;
  insert into public.entry_template_lines (template_id, line_no, account_code, uses_third_party, side, formula, ref_line_no, tax_rate_code, label) values
    (t, 1, '6311', false, 'debit',  'input',      null, null,  'Frais bancaires HT'),
    (t, 2, '6312', false, 'debit',  'percent_of', 1,    'TAF', 'TAF'),
    (t, 3, '5211', false, 'credit', 'balance',    null, null,  'Banque');
  -- Salaires avec IRPP et CNSS
  insert into public.entry_templates (cabinet_id, code, label, journal_type, description)
  values (p_cabinet, 'SALAIRES', 'Salaires avec IRPP et CNSS', 'payroll', 'Salaires bruts, retenues salariales, charges patronales, net à payer') returning id into t;
  insert into public.entry_template_lines (template_id, line_no, account_code, uses_third_party, side, formula, ref_line_no, tax_rate_code, percent, label) values
    (t, 1, '6611', false, 'debit',  'input',      null, null,       null, 'Salaires bruts'),
    (t, 2, '4472', false, 'credit', 'input',      null, null,       null, 'IRPP retenu (barème)'),
    (t, 3, '4311', false, 'credit', 'percent_of', 1,    'CNSS_SAL', null, 'CNSS part salariale'),
    (t, 4, '6641', false, 'debit',  'percent_of', 1,    'CNSS_PAT', null, 'Charges sociales patronales'),
    (t, 5, '4311', false, 'credit', 'percent_of', 1,    'CNSS_PAT', null, 'CNSS part patronale'),
    (t, 6, '4221', true,  'credit', 'balance',    null, null,       null, 'Net à payer');
end $$;

create or replace function public.handle_new_cabinet()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.seed_default_roles(new.id);
  perform public.seed_default_referentials(new.id);
  return new;
end $$;

-- À la création d''une entité : plan de référence copié et journal des à-nouveaux créé.
create or replace function public.entities_init_referentials()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.copy_reference_plan(new.id);
  perform public.create_journals_from_template(new.id, '{}');   -- uniquement les journaux imposés (AN)
  return new;
end $$;
create trigger entities_init_referentials after insert on public.entities
  for each row execute function public.entities_init_referentials();

-- -----------------------------------------------------------------------------
-- Journalisation et RLS
-- -----------------------------------------------------------------------------
create trigger audit_accounts after insert or update or delete on public.accounts
  for each row when (pg_trigger_depth() = 0) execute function public.audit_row_change();
create trigger audit_third_parties after insert or update or delete on public.third_parties
  for each row execute function public.audit_row_change();
create trigger audit_journals after insert or update or delete on public.journals
  for each row when (pg_trigger_depth() = 0) execute function public.audit_row_change();
create trigger audit_tax_rates after insert or update or delete on public.tax_rates
  for each row when (pg_trigger_depth() = 0) execute function public.audit_row_change();
create trigger audit_entry_templates after insert or update or delete on public.entry_templates
  for each row when (pg_trigger_depth() = 0) execute function public.audit_row_change();

alter table public.accounts              enable row level security;
alter table public.third_parties         enable row level security;
alter table public.third_party_accounts  enable row level security;
alter table public.journal_templates     enable row level security;
alter table public.journals              enable row level security;
alter table public.tax_rates             enable row level security;
alter table public.entry_templates       enable row level security;
alter table public.entry_template_lines  enable row level security;

create policy accounts_select on public.accounts for select to authenticated using (public.can_access_entity(entity_id));
create policy accounts_write  on public.accounts for all to authenticated
  using (public.has_permission(entity_id, 'references.manage'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'references.manage'));

create policy third_parties_select on public.third_parties for select to authenticated using (public.can_access_entity(entity_id));
create policy third_parties_write  on public.third_parties for all to authenticated
  using (public.has_permission(entity_id, 'references.manage'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'references.manage'));

create policy third_party_accounts_select on public.third_party_accounts for select to authenticated
  using (exists (select 1 from public.third_parties t where t.id = third_party_id and public.can_access_entity(t.entity_id)));
create policy third_party_accounts_write on public.third_party_accounts for all to authenticated
  using (exists (select 1 from public.third_parties t where t.id = third_party_id and public.has_permission(t.entity_id, 'references.manage')))
  with check (exists (select 1 from public.third_parties t where t.id = third_party_id and public.has_permission(t.entity_id, 'references.manage')));

create policy journal_templates_select on public.journal_templates for select to authenticated using (cabinet_id = public.current_cabinet_id());
create policy journal_templates_write  on public.journal_templates for all to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'cabinet.settings'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'cabinet.settings'));

create policy journals_select on public.journals for select to authenticated using (public.can_access_entity(entity_id));
create policy journals_write  on public.journals for all to authenticated
  using (public.has_permission(entity_id, 'references.manage'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'references.manage'));

create policy tax_rates_select on public.tax_rates for select to authenticated using (cabinet_id = public.current_cabinet_id());
create policy tax_rates_write  on public.tax_rates for all to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'cabinet.settings'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'cabinet.settings'));

-- Modèles : ceux du cabinet (lecture par tous les membres comptables) et ceux des dossiers accessibles.
create policy entry_templates_select on public.entry_templates for select to authenticated
  using (cabinet_id = public.current_cabinet_id() and (entity_id is null or public.can_access_entity(entity_id)));
create policy entry_templates_write on public.entry_templates for all to authenticated
  using (cabinet_id = public.current_cabinet_id()
         and ((entity_id is null and public.has_permission(null, 'cabinet.settings'))
              or (entity_id is not null and public.has_permission(entity_id, 'references.manage'))))
  with check (cabinet_id = public.current_cabinet_id()
         and ((entity_id is null and public.has_permission(null, 'cabinet.settings'))
              or (entity_id is not null and public.has_permission(entity_id, 'references.manage'))));
create policy entry_template_lines_select on public.entry_template_lines for select to authenticated
  using (exists (select 1 from public.entry_templates t where t.id = template_id
                   and t.cabinet_id = public.current_cabinet_id() and (t.entity_id is null or public.can_access_entity(t.entity_id))));
create policy entry_template_lines_write on public.entry_template_lines for all to authenticated
  using (exists (select 1 from public.entry_templates t where t.id = template_id and t.cabinet_id = public.current_cabinet_id()
                   and ((t.entity_id is null and public.has_permission(null, 'cabinet.settings'))
                        or (t.entity_id is not null and public.has_permission(t.entity_id, 'references.manage')))))
  with check (exists (select 1 from public.entry_templates t where t.id = template_id and t.cabinet_id = public.current_cabinet_id()
                   and ((t.entity_id is null and public.has_permission(null, 'cabinet.settings'))
                        or (t.entity_id is not null and public.has_permission(t.entity_id, 'references.manage')))));

revoke execute on function public.copy_reference_plan(uuid) from public, anon;
revoke execute on function public.seed_default_referentials(uuid) from public, anon, authenticated;
