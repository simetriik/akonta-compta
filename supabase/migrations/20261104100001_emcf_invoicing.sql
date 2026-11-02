-- =============================================================================
-- Akonta — Facturation normalisée e-MECeF (D-043, tranche 1)
-- e-MCF par dossier (NIM, jeton côté serveur seulement), factures FV/FA, lignes, paiements,
-- taux de taxe versionnés, calcul de contrôle des totaux, immutabilité, avoir.
-- Périmètre déclaré à la DGI : factures de vente (FV) et d'avoir (FA), groupes A (exonéré) et B (taxable),
-- AIB 1 % (A) et 5 % (B). Exportation, TPS, régime d'exception, taxe spécifique : non utilisés.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Permissions
-- -----------------------------------------------------------------------------
insert into public.permissions (code, label, category, sort_order) values
  ('invoices.issue', 'Émettre et annuler des factures normalisées', 'facturation', 190),
  ('emcf.manage',    'Gérer les e-MCF et leurs jetons',             'facturation', 191)
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_code)
select id, 'invoices.issue' from public.roles where code in ('manager', 'partner')
on conflict do nothing;
insert into public.role_permissions (role_id, permission_code)
select id, 'emcf.manage' from public.roles where code = 'partner'
on conflict do nothing;

-- Nouveaux cabinets : le chef de mission reçoit le droit d'émettre à la création de son rôle.
-- L'associé n'a rien à recevoir ici : seed_default_roles lui donne déjà tout le catalogue (sauf users.manage) ;
-- l'ajouter ici ferait échouer cette insertion en bloc (clé en double).
create or replace function public.roles_default_invoicing()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.code = 'manager' then
    insert into public.role_permissions (role_id, permission_code) values (new.id, 'invoices.issue') on conflict do nothing;
  end if;
  return null;
end $$;
create trigger roles_default_invoicing after insert on public.roles
  for each row execute function public.roles_default_invoicing();

-- -----------------------------------------------------------------------------
-- 2. Taux de taxe versionnés (A et B, AIB 1 % et 5 %)
-- -----------------------------------------------------------------------------
create table public.invoice_tax_rates (
  code        text not null check (code in ('A', 'B', 'AIB_A', 'AIB_B')),
  valid_from  date not null,
  rate        numeric(6,3) not null check (rate >= 0 and rate < 100),
  label       text not null,
  primary key (code, valid_from)
);
comment on table public.invoice_tax_rates is 'Taux versionnés des groupes de taxe e-MECeF utilisés pour le contrôle des totaux (la DGI reste la référence).';
insert into public.invoice_tax_rates (code, valid_from, rate, label) values
  ('A',     '2021-01-01', 0,  'Exonéré'),
  ('B',     '2021-01-01', 18, 'Taxable (TVA)'),
  ('AIB_A', '2021-01-01', 1,  'AIB 1 %'),
  ('AIB_B', '2021-01-01', 5,  'AIB 5 %');

-- -----------------------------------------------------------------------------
-- 3. e-MCF d'un dossier (un NIM et un jeton par point de vente)
-- -----------------------------------------------------------------------------
create table public.emcf_devices (
  id          uuid primary key default gen_random_uuid(),
  cabinet_id  uuid not null references public.cabinets (id) on delete cascade,
  entity_id   uuid not null references public.entities (id) on delete cascade,
  nim         text not null check (length(nim) = 10),
  label       text not null check (length(trim(label)) >= 1),
  mode        text not null default 'test' check (mode in ('test', 'production')),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (cabinet_id, nim)
);
comment on table public.emcf_devices is 'e-MCF d''un dossier : NIM (10 caractères) et environnement DGI. Le jeton est dans emcf_device_tokens.';
create trigger emcf_devices_updated_at before update on public.emcf_devices
  for each row execute function public.set_updated_at();
create trigger emcf_devices_audit after insert or update or delete on public.emcf_devices
  for each row execute function public.audit_row_change();

-- Jetons : jamais lisibles par l'application (aucune politique d'accès), seule la clé de service les lit.
create table public.emcf_device_tokens (
  device_id   uuid primary key references public.emcf_devices (id) on delete cascade,
  token       text not null,
  updated_at  timestamptz not null default now()
);
comment on table public.emcf_device_tokens is 'Jetons JWT des e-MCF : secret, accessible à la clé de service uniquement (Edge Function).';

create or replace function public.emcf_devices_guard()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' and (new.entity_id <> old.entity_id or new.cabinet_id <> old.cabinet_id or new.nim <> old.nim) then
    raise exception 'Le NIM et le dossier d''un e-MCF ne changent pas' using errcode = '23514';
  end if;
  if not exists (select 1 from public.entities e where e.id = new.entity_id and e.cabinet_id = new.cabinet_id) then
    raise exception 'Cabinet incohérent' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger emcf_devices_guard before insert or update on public.emcf_devices
  for each row execute function public.emcf_devices_guard();

-- -----------------------------------------------------------------------------
-- 4. Factures, lignes, paiements
-- -----------------------------------------------------------------------------
create type public.invoice_status as enum ('draft', 'pending', 'confirmed', 'cancelled');

create table public.invoices (
  id                    uuid primary key default gen_random_uuid(),
  cabinet_id            uuid not null references public.cabinets (id) on delete cascade,
  entity_id             uuid not null references public.entities (id) on delete cascade,
  device_id             uuid not null references public.emcf_devices (id),
  type                  text not null check (type in ('FV', 'FA')),
  status                public.invoice_status not null default 'draft',
  is_test               boolean not null default true,       -- copie du mode de l'e-MCF : une facture de test n'a aucune valeur comptable
  seller_ifu            text not null check (length(seller_ifu) = 13),
  aib                   text check (aib in ('A', 'B')),       -- A = 1 %, B = 5 %
  client_ifu            text check (client_ifu is null or length(client_ifu) = 13),
  client_name           text,
  client_contact        text,
  client_address        text,
  operator_name         text not null check (length(trim(operator_name)) >= 1),
  original_invoice_id   uuid references public.invoices (id),
  reference             text check (reference is null or length(reference) = 24),  -- code MECeF/DGI de la facture d'origine (avoir)
  commercial_message    text,
  -- Retour de la DGI
  dgi_uid               text,
  dgi_response          jsonb,                                -- totaux calculés par l'e-MCF
  total                 bigint,
  code_mecef            text check (code_mecef is null or length(code_mecef) = 29),
  qr_code               text,
  counters              text,
  dgi_nim               text,
  dgi_datetime          text,                                 -- horodatage tel que rendu par la DGI
  issued_at             timestamptz,
  last_error            text,
  created_by            uuid references public.profiles (id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  check ((type = 'FA') = (original_invoice_id is not null)),
  check (type = 'FV' or reference is not null or status = 'draft'),
  check (status <> 'confirmed' or (code_mecef is not null and qr_code is not null and issued_at is not null))
);
comment on table public.invoices is 'Factures normalisées e-MECeF (FV, FA). Confirmée ou annulée : intangible ; correction par facture d''avoir.';
create unique index invoices_code_mecef_key on public.invoices (cabinet_id, code_mecef) where code_mecef is not null;
create index invoices_entity_idx on public.invoices (entity_id, created_at desc);
create trigger invoices_updated_at before update on public.invoices
  for each row execute function public.set_updated_at();
create trigger invoices_audit after insert or update or delete on public.invoices
  for each row execute function public.audit_row_change();

create table public.invoice_lines (
  id                  uuid primary key default gen_random_uuid(),
  invoice_id          uuid not null references public.invoices (id) on delete cascade,
  position            smallint not null check (position > 0),
  code                text,
  name                text not null check (length(trim(name)) >= 1),
  price               bigint not null check (price > 0),              -- prix unitaire TTC en FCFA
  quantity            numeric(18,3) not null check (quantity > 0),
  tax_group           text not null check (tax_group in ('A', 'B')),
  original_price      bigint check (original_price is null or original_price > 0),
  price_modification  text,
  unique (invoice_id, position)
);
create table public.invoice_payments (
  id          uuid primary key default gen_random_uuid(),
  invoice_id  uuid not null references public.invoices (id) on delete cascade,
  name        text not null check (name in ('ESPECES', 'VIREMENT', 'CARTEBANCAIRE', 'MOBILEMONEY', 'CHEQUES', 'CREDIT', 'AUTRE')),
  amount      bigint not null check (amount >= 0)
);
create index invoice_lines_invoice_idx on public.invoice_lines (invoice_id);
create index invoice_payments_invoice_idx on public.invoice_payments (invoice_id);

-- Contrôles à la création : dossier, e-MCF actif du même dossier, IFU du vendeur, mode copié.
create or replace function public.invoices_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_device public.emcf_devices%rowtype; v_entity public.entities%rowtype;
begin
  if tg_op = 'DELETE' then
    if old.status <> 'draft' then
      raise exception 'Facture émise : suppression interdite (correction par facture d''avoir)' using errcode = '42501';
    end if;
    return old;
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'draft' and not public.internal_mode() then
      raise exception 'Une facture naît en brouillon' using errcode = '42501';
    end if;
    select * into v_device from public.emcf_devices where id = new.device_id;
    if v_device.id is null or v_device.entity_id <> new.entity_id or v_device.cabinet_id <> new.cabinet_id then
      raise exception 'e-MCF inconnu dans ce dossier' using errcode = '23503';
    end if;
    if not v_device.is_active then
      raise exception 'e-MCF désactivé' using errcode = '23514';
    end if;
    select * into v_entity from public.entities where id = new.entity_id;
    if v_entity.tax_id is null or length(v_entity.tax_id) <> 13 then
      raise exception 'L''IFU du dossier (13 caractères) est requis pour facturer' using errcode = '23514';
    end if;
    new.seller_ifu := v_entity.tax_id;
    new.is_test := (v_device.mode = 'test');
    if new.created_by is null then new.created_by := auth.uid(); end if;
    if new.original_invoice_id is not null then
      if not exists (select 1 from public.invoices o where o.id = new.original_invoice_id and o.entity_id = new.entity_id
                      and o.type = 'FV' and o.status = 'confirmed' and o.is_test = new.is_test) then
        raise exception 'L''avoir doit se rapporter à une facture de vente confirmée du même dossier et du même environnement' using errcode = '23514';
      end if;
    end if;
    return new;
  end if;

  -- UPDATE
  if old.status in ('confirmed', 'cancelled') then
    raise exception 'Facture émise : intangible (correction par facture d''avoir)' using errcode = '42501';
  end if;
  if new.entity_id <> old.entity_id or new.cabinet_id <> old.cabinet_id or new.device_id <> old.device_id
     or new.type <> old.type or new.seller_ifu <> old.seller_ifu or new.is_test <> old.is_test
     or new.original_invoice_id is distinct from old.original_invoice_id then
    raise exception 'Dossier, e-MCF, type et facture d''origine ne changent pas' using errcode = '23514';
  end if;
  if old.status = 'pending' and not public.internal_mode() then
    raise exception 'Facture en cours d''émission : modification interdite' using errcode = '42501';
  end if;
  if (new.status <> old.status or new.dgi_uid is distinct from old.dgi_uid or new.code_mecef is distinct from old.code_mecef
      or new.qr_code is distinct from old.qr_code or new.dgi_response is distinct from old.dgi_response)
     and not public.internal_mode() then
    raise exception 'L''émission passe par la fonction e-MECeF' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger invoices_guard before insert or update or delete on public.invoices
  for each row execute function public.invoices_guard();

-- Lignes et paiements : modifiables seulement tant que la facture est en brouillon.
create or replace function public.invoice_children_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_invoice uuid := coalesce(new.invoice_id, old.invoice_id); v_status public.invoice_status;
begin
  select status into v_status from public.invoices where id = v_invoice;
  if v_status is null then return coalesce(new, old); end if;   -- suppression en cascade de la facture
  if v_status <> 'draft' then
    raise exception 'Facture émise ou en cours d''émission : lignes et paiements intangibles' using errcode = '42501';
  end if;
  return coalesce(new, old);
end $$;
create trigger invoice_lines_guard before insert or update or delete on public.invoice_lines
  for each row execute function public.invoice_children_guard();
create trigger invoice_payments_guard before insert or update or delete on public.invoice_payments
  for each row execute function public.invoice_children_guard();

-- -----------------------------------------------------------------------------
-- 5. Calcul de contrôle des totaux (le SFE doit recalculer avant de confirmer)
-- Prix TTC ; HT = TTC / (1 + taux) arrondi ; TVA = TTC − HT. Le total ne comprend pas l'AIB.
-- -----------------------------------------------------------------------------
create or replace function public.invoice_rate(p_code text, p_on date)
returns numeric language sql stable as $$
  select rate from public.invoice_tax_rates where code = p_code and valid_from <= p_on order by valid_from desc limit 1;
$$;

create or replace function public.invoice_expected_totals(p_invoice uuid)
returns table (taa bigint, tab bigint, hab bigint, vab bigint, total bigint, aib_rate numeric)
language plpgsql stable security definer set search_path = public as $$
declare v_inv public.invoices%rowtype; v_rate_b numeric; v_a bigint; v_b bigint; v_hab bigint;
begin
  select * into v_inv from public.invoices where id = p_invoice;
  if v_inv.id is null or not public.can_access_entity(v_inv.entity_id) then
    raise exception 'Facture inaccessible' using errcode = '42501';
  end if;
  v_rate_b := public.invoice_rate('B', coalesce(v_inv.issued_at::date, current_date));
  select coalesce(sum(round(l.price * l.quantity)) filter (where l.tax_group = 'A'), 0)::bigint,
         coalesce(sum(round(l.price * l.quantity)) filter (where l.tax_group = 'B'), 0)::bigint
    into v_a, v_b from public.invoice_lines l where l.invoice_id = p_invoice;
  v_hab := round(v_b * 100 / (100 + v_rate_b))::bigint;
  return query select v_a, v_b, v_hab, v_b - v_hab, v_a + v_b,
    case v_inv.aib when 'A' then public.invoice_rate('AIB_A', current_date)
                   when 'B' then public.invoice_rate('AIB_B', current_date) else 0 end;
end $$;
revoke all on function public.invoice_expected_totals(uuid) from public, anon;
grant execute on function public.invoice_expected_totals(uuid) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 6. Transitions réservées à la clé de service (Edge Function emcf-invoice)
-- -----------------------------------------------------------------------------
create or replace function public.invoice_mark_pending(p_invoice uuid, p_uid text, p_response jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('akonta.internal', 'on', true);
  update public.invoices set status = 'pending', dgi_uid = p_uid, dgi_response = p_response,
         total = (p_response ->> 'total')::bigint, last_error = null
   where id = p_invoice and status = 'draft';
  if not found then raise exception 'Facture absente ou déjà en cours d''émission' using errcode = '23514'; end if;
  perform set_config('akonta.internal', '', true);
end $$;

create or replace function public.invoice_mark_confirmed(p_invoice uuid, p_security jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('akonta.internal', 'on', true);
  update public.invoices set status = 'confirmed',
         code_mecef = p_security ->> 'codeMECeFDGI', qr_code = p_security ->> 'qrCode',
         counters = p_security ->> 'counters', dgi_nim = p_security ->> 'nim',
         dgi_datetime = p_security ->> 'dateTime',
         issued_at = (p_security ->> 'issuedAt')::timestamptz, last_error = null
   where id = p_invoice and status = 'pending';
  if not found then raise exception 'Facture absente ou non en cours d''émission' using errcode = '23514'; end if;
  perform set_config('akonta.internal', '', true);
end $$;

create or replace function public.invoice_mark_cancelled(p_invoice uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('akonta.internal', 'on', true);
  update public.invoices set status = 'cancelled', last_error = p_reason where id = p_invoice and status = 'pending';
  if not found then raise exception 'Facture absente ou non en cours d''émission' using errcode = '23514'; end if;
  perform set_config('akonta.internal', '', true);
end $$;

-- Retour en brouillon (échec avant confirmation, demande expirée, totaux divergents) : le motif est conservé.
create or replace function public.invoice_revert_to_draft(p_invoice uuid, p_error text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('akonta.internal', 'on', true);
  update public.invoices set status = 'draft', dgi_uid = null, dgi_response = null, total = null, last_error = p_error
   where id = p_invoice and status in ('draft', 'pending');
  if not found then raise exception 'Facture absente ou déjà émise' using errcode = '23514'; end if;
  perform set_config('akonta.internal', '', true);
end $$;

revoke all on function public.invoice_mark_pending(uuid, text, jsonb), public.invoice_mark_confirmed(uuid, jsonb),
  public.invoice_mark_cancelled(uuid, text), public.invoice_revert_to_draft(uuid, text) from public, anon, authenticated;
grant execute on function public.invoice_mark_pending(uuid, text, jsonb), public.invoice_mark_confirmed(uuid, jsonb),
  public.invoice_mark_cancelled(uuid, text), public.invoice_revert_to_draft(uuid, text) to service_role;

-- -----------------------------------------------------------------------------
-- 7. Facture d'avoir à partir d'une facture de vente confirmée
-- La référence est le code MECeF/DGI sans tirets (24 caractères). Les lignes sont reprises ; l'utilisateur
-- ajuste les quantités avant l'émission (la DGI refuse un avoir supérieur à l'original : erreur 12).
-- -----------------------------------------------------------------------------
create or replace function public.create_credit_note(p_original uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_orig public.invoices%rowtype; v_new uuid;
begin
  select * into v_orig from public.invoices where id = p_original;
  if v_orig.id is null or not public.can_access_entity(v_orig.entity_id) then
    raise exception 'Facture inaccessible' using errcode = '42501';
  end if;
  if not public.has_permission(v_orig.entity_id, 'invoices.issue') then
    raise exception 'Permission refusée : invoices.issue' using errcode = '42501';
  end if;
  if v_orig.type <> 'FV' or v_orig.status <> 'confirmed' then
    raise exception 'Seule une facture de vente confirmée peut être corrigée par un avoir' using errcode = '23514';
  end if;
  insert into public.invoices (cabinet_id, entity_id, device_id, type, seller_ifu, aib, client_ifu, client_name, client_contact,
                               client_address, operator_name, original_invoice_id, reference)
  values (v_orig.cabinet_id, v_orig.entity_id, v_orig.device_id, 'FA', v_orig.seller_ifu, v_orig.aib, v_orig.client_ifu,
          v_orig.client_name, v_orig.client_contact, v_orig.client_address, v_orig.operator_name, v_orig.id,
          replace(v_orig.code_mecef, '-', ''))
  returning id into v_new;
  insert into public.invoice_lines (invoice_id, position, code, name, price, quantity, tax_group, original_price, price_modification)
  select v_new, position, code, name, price, quantity, tax_group, original_price, price_modification
    from public.invoice_lines where invoice_id = p_original;
  insert into public.invoice_payments (invoice_id, name, amount)
  select v_new, name, amount from public.invoice_payments where invoice_id = p_original;
  return v_new;
end $$;
revoke all on function public.create_credit_note(uuid) from public, anon;
grant execute on function public.create_credit_note(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 8. RLS
-- -----------------------------------------------------------------------------
alter table public.invoice_tax_rates    enable row level security;
alter table public.emcf_devices         enable row level security;
alter table public.emcf_device_tokens   enable row level security;
alter table public.invoices             enable row level security;
alter table public.invoice_lines        enable row level security;
alter table public.invoice_payments     enable row level security;

create policy invoice_tax_rates_select on public.invoice_tax_rates for select to authenticated using (true);

create policy emcf_devices_select on public.emcf_devices for select to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.can_access_entity(entity_id));
create policy emcf_devices_insert on public.emcf_devices for insert to authenticated
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'emcf.manage'));
create policy emcf_devices_update on public.emcf_devices for update to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'emcf.manage'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'emcf.manage'));
create policy emcf_devices_delete on public.emcf_devices for delete to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'emcf.manage')
         and not exists (select 1 from public.invoices i where i.device_id = emcf_devices.id));

-- Aucun accès pour l'application ; la clé de service contourne la RLS.
create policy emcf_device_tokens_none on public.emcf_device_tokens for select to authenticated using (false);

create policy invoices_select on public.invoices for select to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.can_access_entity(entity_id));
create policy invoices_insert on public.invoices for insert to authenticated
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'invoices.issue'));
create policy invoices_update on public.invoices for update to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'invoices.issue'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'invoices.issue'));
create policy invoices_delete on public.invoices for delete to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'invoices.issue') and status = 'draft');

create policy invoice_lines_select on public.invoice_lines for select to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_id and public.can_access_entity(i.entity_id)));
create policy invoice_lines_write on public.invoice_lines for all to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_id and public.has_permission(i.entity_id, 'invoices.issue')))
  with check (exists (select 1 from public.invoices i where i.id = invoice_id and public.has_permission(i.entity_id, 'invoices.issue')));
create policy invoice_payments_select on public.invoice_payments for select to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_id and public.can_access_entity(i.entity_id)));
create policy invoice_payments_write on public.invoice_payments for all to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_id and public.has_permission(i.entity_id, 'invoices.issue')))
  with check (exists (select 1 from public.invoices i where i.id = invoice_id and public.has_permission(i.entity_id, 'invoices.issue')));

grant select, insert, update, delete on public.emcf_devices, public.invoices, public.invoice_lines, public.invoice_payments to authenticated;
grant select on public.invoice_tax_rates to authenticated;

-- Les jetons ne sont lisibles par aucun rôle de l'application (même sans la RLS).
revoke all on public.emcf_device_tokens from anon, authenticated;
grant all on public.emcf_device_tokens to service_role;
