-- =============================================================================
-- Akonta — Migration 0009 : schéma des lots 2 et 3 (conception §5, §6, §7, §10.7 à §10.9)
-- Tables, contraintes et RLS du lettrage, du rapprochement bancaire, des travaux
-- d''inventaire et de la clôture. Les fonctions métier arrivent avec les lots 2 et 3,
-- conformément à « schéma SQL complet des lots 1 à 3 avant toute interface » (§12.1).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Lot 2 — Lettrage (§10.7)
-- -----------------------------------------------------------------------------
alter table public.entities add column lettering_tolerance bigint not null default 0 check (lettering_tolerance >= 0);
comment on column public.entities.lettering_tolerance is 'Écart toléré (FCFA) pour considérer un lettrage comme soldé (0 par défaut).';

create table public.letterings (
  id               uuid primary key default gen_random_uuid(),
  cabinet_id       uuid not null references public.cabinets (id) on delete cascade,
  entity_id        uuid not null references public.entities (id) on delete cascade,
  account_id       uuid not null references public.accounts (id),
  third_party_id   uuid references public.third_parties (id),
  code             text not null,                          -- A, B, …, AA : par compte (et tiers)
  is_partial       boolean not null default false,
  total_debit      bigint not null default 0,
  total_credit     bigint not null default 0,
  created_by       uuid references public.profiles (id),
  created_at       timestamptz not null default now(),
  unlettered_at    timestamptz,
  unlettered_by    uuid references public.profiles (id),
  unlettered_reason text,
  unique (account_id, third_party_id, code)
);
comment on table public.letterings is 'Groupe de lettrage : lignes d''un compte (et tiers) rapprochées entre elles ; partiel si non soldé ; délettrage tracé.';
create index letterings_entity_idx on public.letterings (entity_id, account_id, third_party_id);
create trigger letterings_cabinet before insert or update on public.letterings for each row execute function public.check_entity_cabinet();

alter table public.entry_lines add column lettering_id uuid references public.letterings (id);
create index entry_lines_lettering_idx on public.entry_lines (lettering_id) where lettering_id is not null;

-- -----------------------------------------------------------------------------
-- Lot 2 — Rapprochement bancaire (§10.7)
-- -----------------------------------------------------------------------------
create type public.statement_status as enum ('imported', 'in_progress', 'reconciled', 'archived');
create type public.reconciliation_status as enum ('draft', 'final');

create table public.bank_statement_templates (
  id                 uuid primary key default gen_random_uuid(),
  cabinet_id         uuid not null references public.cabinets (id) on delete cascade,
  entity_id          uuid references public.entities (id) on delete cascade,   -- null = partagé par le cabinet
  bank_name          text not null,
  label              text not null,
  file_format        text not null default 'csv' check (file_format in ('csv', 'excel')),
  encoding           text not null default 'utf-8',
  delimiter          text not null default ';',
  has_header         boolean not null default true,
  skip_rows          smallint not null default 0,
  date_column        smallint not null,
  label_column       smallint not null,
  debit_column       smallint,
  credit_column      smallint,
  amount_column      smallint,                                -- colonne signée, alternative à débit/crédit
  reference_column   smallint,
  value_date_column  smallint,
  date_format        text not null default 'DD/MM/YYYY',
  decimal_separator  char(1) not null default ',',
  amount_sign_inverted boolean not null default false,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check (amount_column is not null or (debit_column is not null and credit_column is not null))
);
comment on table public.bank_statement_templates is 'Gabarit de colonnes d''un relevé bancaire, mémorisé par banque (§10.7).';
create trigger bank_statement_templates_updated_at before update on public.bank_statement_templates for each row execute function public.set_updated_at();
create trigger bank_statement_templates_cabinet before insert or update on public.bank_statement_templates for each row execute function public.check_entity_cabinet();

create table public.bank_statements (
  id                uuid primary key default gen_random_uuid(),
  cabinet_id        uuid not null references public.cabinets (id) on delete cascade,
  entity_id         uuid not null references public.entities (id) on delete cascade,
  journal_id        uuid not null references public.journals (id),
  template_id       uuid references public.bank_statement_templates (id),
  period_from       date not null,
  period_to         date not null check (period_to >= period_from),
  opening_balance   bigint,                                   -- solde banque début (positif = créditeur chez la banque)
  closing_balance   bigint,
  source_file_name  text,
  status            public.statement_status not null default 'imported',
  imported_by       uuid references public.profiles (id),
  imported_at       timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index bank_statements_journal_idx on public.bank_statements (journal_id, period_from);
create trigger bank_statements_updated_at before update on public.bank_statements for each row execute function public.set_updated_at();
create trigger bank_statements_cabinet before insert or update on public.bank_statements for each row execute function public.check_entity_cabinet();

create table public.bank_statement_lines (
  id              bigint generated always as identity primary key,
  statement_id    uuid not null references public.bank_statements (id) on delete cascade,
  entity_id       uuid not null references public.entities (id) on delete cascade,
  line_no         integer not null,
  operation_date  date not null,
  value_date      date,
  label           text not null,
  reference       text,
  debit           bigint not null default 0 check (debit >= 0),    -- sortie de fonds (point de vue entreprise)
  credit          bigint not null default 0 check (credit >= 0),   -- entrée de fonds
  check ((debit > 0 and credit = 0) or (credit > 0 and debit = 0)),
  unique (statement_id, line_no)
);
create index bank_statement_lines_match_idx on public.bank_statement_lines (entity_id, operation_date, debit, credit);

create table public.reconciliation_matches (
  id          uuid primary key default gen_random_uuid(),
  cabinet_id  uuid not null references public.cabinets (id) on delete cascade,
  entity_id   uuid not null references public.entities (id) on delete cascade,
  journal_id  uuid not null references public.journals (id),
  matched_by  uuid references public.profiles (id),
  matched_at  timestamptz not null default now(),
  is_proposal boolean not null default false,
  note        text
);
comment on table public.reconciliation_matches is 'Pointage 1-1 ou plusieurs-à-plusieurs entre lignes de relevé et lignes d''écritures du journal de banque.';
create trigger reconciliation_matches_cabinet before insert or update on public.reconciliation_matches for each row execute function public.check_entity_cabinet();

create table public.reconciliation_match_statement_lines (
  match_id            uuid not null references public.reconciliation_matches (id) on delete cascade,
  statement_line_id   bigint not null references public.bank_statement_lines (id) on delete cascade,
  primary key (match_id, statement_line_id),
  unique (statement_line_id)
);
create table public.reconciliation_match_entry_lines (
  match_id       uuid not null references public.reconciliation_matches (id) on delete cascade,
  entry_line_id  uuid not null references public.entry_lines (id),
  primary key (match_id, entry_line_id),
  unique (entry_line_id)
);

create table public.reconciliations (
  id                   uuid primary key default gen_random_uuid(),
  cabinet_id           uuid not null references public.cabinets (id) on delete cascade,
  entity_id            uuid not null references public.entities (id) on delete cascade,
  journal_id           uuid not null references public.journals (id),
  statement_id         uuid references public.bank_statements (id),
  as_of                date not null,
  book_balance         bigint not null,       -- solde du compte 52x au grand livre
  bank_balance         bigint not null,       -- solde du relevé
  outstanding_debits   bigint not null default 0,
  outstanding_credits  bigint not null default 0,
  difference           bigint not null default 0,
  status               public.reconciliation_status not null default 'draft',
  finalized_by         uuid references public.profiles (id),
  finalized_at         timestamptz,
  pdf_document_id      uuid references public.documents (id),
  details              jsonb not null default '{}'::jsonb,
  created_at           timestamptz not null default now(),
  unique (journal_id, as_of)
);
comment on table public.reconciliations is 'État de rapprochement mensuel : figé (final) quand l''écart est nul, archivé en PDF.';
create trigger reconciliations_cabinet before insert or update on public.reconciliations for each row execute function public.check_entity_cabinet();

-- -----------------------------------------------------------------------------
-- Lot 3 — Travaux d''inventaire (§6, §10.8)
-- -----------------------------------------------------------------------------
create type public.depreciation_method as enum ('linear', 'declining');
create type public.asset_status as enum ('in_service', 'disposed', 'scrapped');
create type public.provision_kind as enum ('receivable', 'risk', 'other');
create type public.accrual_kind as enum ('cap', 'par', 'cca', 'pca');   -- charges à payer, produits à recevoir, charges / produits constatés d''avance

create table public.fixed_assets (
  id                       uuid primary key default gen_random_uuid(),
  cabinet_id               uuid not null references public.cabinets (id) on delete cascade,
  entity_id                uuid not null references public.entities (id) on delete cascade,
  code                     text not null,
  designation              text not null,
  asset_account_id         uuid not null references public.accounts (id),       -- 2x
  depreciation_account_id  uuid references public.accounts (id),                -- 28x
  expense_account_id       uuid references public.accounts (id),                -- 68x
  supplier_third_party_id  uuid references public.third_parties (id),
  document_id              uuid references public.documents (id),
  parent_asset_id          uuid references public.fixed_assets (id),            -- composant
  acquisition_date         date not null,
  service_date             date not null,
  gross_value              bigint not null check (gross_value > 0),
  salvage_value            bigint not null default 0 check (salvage_value >= 0),
  method                   public.depreciation_method not null default 'linear',
  duration_months          integer not null check (duration_months > 0),
  declining_coefficient    numeric(5,2),
  prior_depreciation       bigint not null default 0 check (prior_depreciation >= 0),   -- reprise de l''existant
  is_depreciable           boolean not null default true,
  status                   public.asset_status not null default 'in_service',
  disposal_date            date,
  disposal_price           bigint,
  disposal_entry_id        uuid references public.entries (id),
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  unique (entity_id, code),
  check (service_date >= acquisition_date),
  check (status = 'in_service' or disposal_date is not null)
);
create index fixed_assets_entity_idx on public.fixed_assets (entity_id, status);
create trigger fixed_assets_updated_at before update on public.fixed_assets for each row execute function public.set_updated_at();
create trigger fixed_assets_cabinet before insert or update on public.fixed_assets for each row execute function public.check_entity_cabinet();

create table public.depreciation_schedules (
  id               uuid primary key default gen_random_uuid(),
  entity_id        uuid not null references public.entities (id) on delete cascade,
  asset_id         uuid not null references public.fixed_assets (id) on delete cascade,
  fiscal_year_id   uuid not null references public.fiscal_years (id),
  period_start     date not null,
  period_end       date not null,
  base_amount      bigint not null,
  rate             numeric(9,6) not null,
  charge           bigint not null check (charge >= 0),        -- dotation de l''exercice
  cumulated        bigint not null check (cumulated >= 0),
  net_book_value   bigint not null check (net_book_value >= 0),
  entry_id         uuid references public.entries (id),         -- écriture de dotation générée (brouillard)
  unique (asset_id, fiscal_year_id)
);

create table public.inventory_stocks (
  id                     uuid primary key default gen_random_uuid(),
  cabinet_id             uuid not null references public.cabinets (id) on delete cascade,
  entity_id              uuid not null references public.entities (id) on delete cascade,
  fiscal_year_id         uuid not null references public.fiscal_years (id),
  stock_account_id       uuid not null references public.accounts (id),       -- 3x
  variation_account_id   uuid not null references public.accounts (id),       -- 603x / 73x
  opening_value          bigint not null default 0 check (opening_value >= 0),
  closing_value          bigint not null check (closing_value >= 0),
  entry_id               uuid references public.entries (id),
  created_at             timestamptz not null default now(),
  unique (fiscal_year_id, stock_account_id)
);
create trigger inventory_stocks_cabinet before insert or update on public.inventory_stocks for each row execute function public.check_entity_cabinet();

create table public.provisions (
  id                     uuid primary key default gen_random_uuid(),
  cabinet_id             uuid not null references public.cabinets (id) on delete cascade,
  entity_id              uuid not null references public.entities (id) on delete cascade,
  fiscal_year_id         uuid not null references public.fiscal_years (id),
  kind                   public.provision_kind not null,
  third_party_id         uuid references public.third_parties (id),
  provision_account_id   uuid not null references public.accounts (id),     -- 49x, 19x, 29x…
  expense_account_id     uuid references public.accounts (id),              -- 659x / 69x
  reversal_account_id    uuid references public.accounts (id),              -- 759x / 79x
  base_amount            bigint not null default 0,
  rate                   numeric(9,6),
  amount                 bigint not null check (amount >= 0),               -- provision à la clôture
  previous_amount        bigint not null default 0 check (previous_amount >= 0),   -- provision N-1
  note                   text,
  entry_id               uuid references public.entries (id),
  created_at             timestamptz not null default now()
);
create index provisions_fy_idx on public.provisions (fiscal_year_id, kind);
create trigger provisions_cabinet before insert or update on public.provisions for each row execute function public.check_entity_cabinet();

create table public.accruals (
  id                      uuid primary key default gen_random_uuid(),
  cabinet_id              uuid not null references public.cabinets (id) on delete cascade,
  entity_id               uuid not null references public.entities (id) on delete cascade,
  fiscal_year_id          uuid not null references public.fiscal_years (id),
  kind                    public.accrual_kind not null,
  description             text not null,
  account_id              uuid not null references public.accounts (id),      -- charge ou produit
  counterpart_account_id  uuid not null references public.accounts (id),      -- 408/418/476/477…
  third_party_id          uuid references public.third_parties (id),
  total_amount            bigint not null check (total_amount > 0),
  period_from             date not null,
  period_to               date not null check (period_to >= period_from),
  amount                  bigint not null check (amount >= 0),                -- part régularisée (prorata au jour)
  entry_id                uuid references public.entries (id),
  reversal_entry_id       uuid references public.entries (id),                -- extourne au 1er janvier N+1
  created_at              timestamptz not null default now()
);
create trigger accruals_cabinet before insert or update on public.accruals for each row execute function public.check_entity_cabinet();

create table public.fx_revaluations (
  id                 uuid primary key default gen_random_uuid(),
  cabinet_id         uuid not null references public.cabinets (id) on delete cascade,
  entity_id          uuid not null references public.entities (id) on delete cascade,
  fiscal_year_id     uuid not null references public.fiscal_years (id),
  entry_line_id      uuid not null references public.entry_lines (id),
  currency_code      char(3) not null,
  amount_currency    numeric(18,2) not null,
  booked_rate        numeric(18,6) not null,
  closing_rate       numeric(18,6) not null,
  difference         bigint not null,                                         -- > 0 gain latent, < 0 perte latente
  entry_id           uuid references public.entries (id),                     -- 478/479 (+ provision 194/659)
  reversal_entry_id  uuid references public.entries (id),
  created_at         timestamptz not null default now(),
  unique (fiscal_year_id, entry_line_id)
);
create trigger fx_revaluations_cabinet before insert or update on public.fx_revaluations for each row execute function public.check_entity_cabinet();

create table public.closing_rates (
  cabinet_id     uuid not null references public.cabinets (id) on delete cascade,
  currency_code  char(3) not null,
  as_of          date not null,
  rate           numeric(18,6) not null check (rate > 0),
  primary key (cabinet_id, currency_code, as_of)
);

-- -----------------------------------------------------------------------------
-- Lot 3 — Clôture (§7, §10.9)
-- -----------------------------------------------------------------------------
create type public.check_severity as enum ('blocking', 'warning');
create type public.check_status as enum ('failed', 'passed', 'waived');
create type public.tax_adjustment_kind as enum ('add_back', 'deduction');
create type public.statement_kind as enum ('balance_sheet_assets', 'balance_sheet_liabilities', 'income_statement', 'cash_flow', 'notes');

create table public.closing_checks (
  id              uuid primary key default gen_random_uuid(),
  cabinet_id      uuid not null references public.cabinets (id) on delete cascade,
  entity_id       uuid not null references public.entities (id) on delete cascade,
  fiscal_year_id  uuid not null references public.fiscal_years (id) on delete cascade,
  code            text not null,                 -- drafts_pending, unbalanced, missing_accounts, suspense_471, …
  label           text not null,
  severity        public.check_severity not null,
  status          public.check_status not null,
  details         jsonb not null default '{}'::jsonb,
  checked_at      timestamptz not null default now(),
  waived_by       uuid references public.profiles (id),
  waived_at       timestamptz,
  waive_comment   text,
  unique (fiscal_year_id, code),
  check (status <> 'waived' or (severity = 'warning' and waive_comment is not null))
);
create trigger closing_checks_cabinet before insert or update on public.closing_checks for each row execute function public.check_entity_cabinet();

create table public.tax_rules (
  id              uuid primary key default gen_random_uuid(),
  cabinet_id      uuid references public.cabinets (id) on delete cascade,     -- null = règle livrée
  version         text not null default '2026',
  code            text not null,
  label           text not null,
  kind            public.tax_adjustment_kind not null,
  account_pattern text,                            -- ex. '^6[0-9]{2}1' : montant proposé depuis la balance
  default_rate    numeric(9,6),
  sort_order      smallint not null default 0,
  valid_from      date not null default '2000-01-01',
  valid_to        date,
  unique (cabinet_id, version, code)
);
comment on table public.tax_rules is 'Tableau de passage du résultat comptable au résultat fiscal : réintégrations et déductions paramétrables, versionnées.';

create table public.tax_computations (
  id                  uuid primary key default gen_random_uuid(),
  cabinet_id          uuid not null references public.cabinets (id) on delete cascade,
  entity_id           uuid not null references public.entities (id) on delete cascade,
  fiscal_year_id      uuid not null references public.fiscal_years (id) on delete cascade,
  rules_version       text not null,
  accounting_result   bigint not null,
  adjustments         jsonb not null default '[]'::jsonb,   -- [{code, label, kind, amount}]
  taxable_result      bigint not null,
  revenue             bigint not null default 0,
  is_rate             numeric(9,6) not null,
  minimum_tax_rate    numeric(9,6) not null,
  minimum_tax_floor   bigint not null default 0,
  computed_tax        bigint not null,
  minimum_tax         bigint not null,
  tax_due             bigint not null,
  prepayments         bigint not null default 0,            -- acomptes 4492
  balance_due         bigint not null,
  entry_id            uuid references public.entries (id),
  computed_at         timestamptz not null default now(),
  computed_by         uuid references public.profiles (id),
  unique (fiscal_year_id)
);
create trigger tax_computations_cabinet before insert or update on public.tax_computations for each row execute function public.check_entity_cabinet();

create table public.statement_mappings (
  id             uuid primary key default gen_random_uuid(),
  cabinet_id     uuid references public.cabinets (id) on delete cascade,      -- null = correspondance livrée
  version        text not null default 'SYSCOHADA-2017',
  statement      public.statement_kind not null,
  post_code      text not null,                        -- ex. AD, BJ, TA, RA (postes des états SYSCOHADA)
  post_label     text not null,
  account_from   text not null,                        -- préfixe de début (ex. 21)
  account_to     text not null,                        -- préfixe de fin inclus (ex. 24)
  balance_side   text not null default 'any' check (balance_side in ('debit', 'credit', 'any')),
  sign           smallint not null default 1 check (sign in (-1, 1)),
  column_role    text not null default 'gross' check (column_role in ('gross', 'depreciation', 'net', 'amount')),
  sort_order     smallint not null default 0,
  valid_from     date not null default '2018-01-01',
  valid_to       date
);
comment on table public.statement_mappings is 'Moteur comptes → postes des états financiers : règles par plage de comptes et sens du solde, versionnées.';
create index statement_mappings_version_idx on public.statement_mappings (version, statement, sort_order);

create table public.financial_statements (
  id                  uuid primary key default gen_random_uuid(),
  cabinet_id          uuid not null references public.cabinets (id) on delete cascade,
  entity_id           uuid not null references public.entities (id) on delete cascade,
  fiscal_year_id      uuid not null references public.fiscal_years (id) on delete cascade,
  mapping_version     text not null,
  generated_at        timestamptz not null default now(),
  generated_by        uuid references public.profiles (id),
  data                jsonb not null,                   -- postes calculés N et N-1
  checks              jsonb not null default '[]'::jsonb,
  pdf_document_id     uuid references public.documents (id),
  excel_document_id   uuid references public.documents (id),
  is_final            boolean not null default false
);
create index financial_statements_fy_idx on public.financial_statements (fiscal_year_id, generated_at desc);
create trigger financial_statements_cabinet before insert or update on public.financial_statements for each row execute function public.check_entity_cabinet();

create table public.dgi_cell_mappings (
  id             uuid primary key default gen_random_uuid(),
  version        text not null,                    -- version du modèle Excel DGI
  sheet_name     text not null,
  cell_ref       text not null,                    -- ex. D15
  post_code      text,                             -- poste des états ou …
  field_code     text,                             -- … champ de la fiche R (ex. R1.ifu)
  column_year    text not null default 'N' check (column_year in ('N', 'N-1', 'none')),
  note           text,
  unique (version, sheet_name, cell_ref)
);
comment on table public.dgi_cell_mappings is 'Cartographie des cellules du modèle Excel DGI (versionnée) utilisée par le service de documents.';

create table public.closing_archives (
  id              uuid primary key default gen_random_uuid(),
  cabinet_id      uuid not null references public.cabinets (id) on delete cascade,
  entity_id       uuid not null references public.entities (id) on delete cascade,
  fiscal_year_id  uuid not null references public.fiscal_years (id) on delete cascade,
  archived_at     timestamptz not null default now(),
  archived_by     uuid references public.profiles (id),
  manifest        jsonb not null,                   -- empreintes : grand livre, balance, états, pièces
  hash            text not null,                    -- empreinte du manifeste
  unique (fiscal_year_id)
);
create trigger closing_archives_cabinet before insert or update on public.closing_archives for each row execute function public.check_entity_cabinet();

create or replace function public.closing_archives_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'Une archive de clôture est intangible' using errcode = '42501';
end $$;
create trigger closing_archives_no_update before update on public.closing_archives for each row execute function public.closing_archives_immutable();
create trigger closing_archives_no_delete before delete on public.closing_archives for each row execute function public.closing_archives_immutable();

-- -----------------------------------------------------------------------------
-- RLS : lecture par accès au dossier, écriture par permission unitaire
-- -----------------------------------------------------------------------------
do $$
declare
  t record;
  -- table → permission d''écriture
  perms constant jsonb := '{
    "letterings": "lettering.manage",
    "bank_statements": "reconciliation.manage", "reconciliation_matches": "reconciliation.manage", "reconciliations": "reconciliation.manage",
    "fixed_assets": "inventory.prepare", "inventory_stocks": "inventory.prepare", "provisions": "inventory.prepare",
    "accruals": "inventory.prepare", "fx_revaluations": "inventory.prepare",
    "closing_checks": "closing.provisional", "tax_computations": "closing.provisional", "financial_statements": "statements.generate",
    "closing_archives": "closing.final"
  }'::jsonb;
begin
  for t in select key as tbl, value #>> '{}' as perm from jsonb_each(perms) loop
    execute format('alter table public.%I enable row level security', t.tbl);
    execute format('create policy %I on public.%I for select to authenticated using (public.can_access_entity(entity_id))', t.tbl || '_select', t.tbl);
    execute format('create policy %I on public.%I for all to authenticated using (public.has_permission(entity_id, %L)) with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, %L))',
                   t.tbl || '_write', t.tbl, t.perm, t.perm);
  end loop;
end $$;

-- Tables filles sans cabinet_id : via leur parent
alter table public.bank_statement_lines enable row level security;
create policy bank_statement_lines_select on public.bank_statement_lines for select to authenticated using (public.can_access_entity(entity_id));
create policy bank_statement_lines_write on public.bank_statement_lines for all to authenticated
  using (public.has_permission(entity_id, 'reconciliation.manage')) with check (public.has_permission(entity_id, 'reconciliation.manage'));

alter table public.reconciliation_match_statement_lines enable row level security;
create policy rmsl_select on public.reconciliation_match_statement_lines for select to authenticated
  using (exists (select 1 from public.reconciliation_matches m where m.id = match_id and public.can_access_entity(m.entity_id)));
create policy rmsl_write on public.reconciliation_match_statement_lines for all to authenticated
  using (exists (select 1 from public.reconciliation_matches m where m.id = match_id and public.has_permission(m.entity_id, 'reconciliation.manage')))
  with check (exists (select 1 from public.reconciliation_matches m where m.id = match_id and public.has_permission(m.entity_id, 'reconciliation.manage')));

alter table public.reconciliation_match_entry_lines enable row level security;
create policy rmel_select on public.reconciliation_match_entry_lines for select to authenticated
  using (exists (select 1 from public.reconciliation_matches m where m.id = match_id and public.can_access_entity(m.entity_id)));
create policy rmel_write on public.reconciliation_match_entry_lines for all to authenticated
  using (exists (select 1 from public.reconciliation_matches m where m.id = match_id and public.has_permission(m.entity_id, 'reconciliation.manage')))
  with check (exists (select 1 from public.reconciliation_matches m where m.id = match_id and public.has_permission(m.entity_id, 'reconciliation.manage')));

alter table public.depreciation_schedules enable row level security;
create policy depreciation_schedules_select on public.depreciation_schedules for select to authenticated using (public.can_access_entity(entity_id));
create policy depreciation_schedules_write on public.depreciation_schedules for all to authenticated
  using (public.has_permission(entity_id, 'inventory.prepare')) with check (public.has_permission(entity_id, 'inventory.prepare'));

-- Gabarits de relevés : cabinet ou dossier
alter table public.bank_statement_templates enable row level security;
create policy bank_statement_templates_select on public.bank_statement_templates for select to authenticated
  using (cabinet_id = public.current_cabinet_id() and (entity_id is null or public.can_access_entity(entity_id)));
create policy bank_statement_templates_write on public.bank_statement_templates for all to authenticated
  using (cabinet_id = public.current_cabinet_id() and ((entity_id is null and public.has_permission_anywhere('reconciliation.manage')) or (entity_id is not null and public.has_permission(entity_id, 'reconciliation.manage'))))
  with check (cabinet_id = public.current_cabinet_id() and ((entity_id is null and public.has_permission_anywhere('reconciliation.manage')) or (entity_id is not null and public.has_permission(entity_id, 'reconciliation.manage'))));

-- Paramètres du cabinet : cours de clôture, règles fiscales, correspondances d''états (livrées = lisibles par tous)
alter table public.closing_rates enable row level security;
create policy closing_rates_select on public.closing_rates for select to authenticated using (cabinet_id = public.current_cabinet_id());
create policy closing_rates_write on public.closing_rates for all to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission_anywhere('inventory.prepare'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission_anywhere('inventory.prepare'));

alter table public.tax_rules enable row level security;
create policy tax_rules_select on public.tax_rules for select to authenticated using (cabinet_id is null or cabinet_id = public.current_cabinet_id());
create policy tax_rules_write on public.tax_rules for all to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'cabinet.settings'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'cabinet.settings'));

alter table public.statement_mappings enable row level security;
create policy statement_mappings_select on public.statement_mappings for select to authenticated using (cabinet_id is null or cabinet_id = public.current_cabinet_id());
create policy statement_mappings_write on public.statement_mappings for all to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'cabinet.settings'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(null, 'cabinet.settings'));

alter table public.dgi_cell_mappings enable row level security;
create policy dgi_cell_mappings_select on public.dgi_cell_mappings for select to authenticated using (true);
