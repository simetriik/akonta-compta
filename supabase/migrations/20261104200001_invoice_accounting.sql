-- =============================================================================
-- Akonta — Pont facturation → comptabilité (D-043, tranche 2)
-- Une facture e-MECeF confirmée (hors test) génère une écriture de vente en brouillard, marquée « générée »,
-- que le comptable valide. Les comptes viennent d'une table paramétrable et versionnée par dossier.
-- =============================================================================

create table public.invoice_account_settings (
  cabinet_id                uuid not null references public.cabinets (id) on delete cascade,
  entity_id                 uuid not null references public.entities (id) on delete cascade,
  valid_from                date not null,
  client_account_id         uuid not null references public.accounts (id),   -- client TTC (collectif : le tiers est rapproché par IFU ou nom)
  sales_exempt_account_id   uuid not null references public.accounts (id),   -- ventes du groupe A (exonéré)
  sales_taxable_account_id  uuid not null references public.accounts (id),   -- ventes du groupe B (hors taxe)
  vat_account_id            uuid not null references public.accounts (id),   -- TVA facturée
  aib_account_id            uuid references public.accounts (id),            -- AIB (obligatoire seulement pour une facture avec AIB)
  journal_id                uuid references public.journals (id),            -- journal de ventes (défaut : premier journal de ventes actif)
  created_at                timestamptz not null default now(),
  primary key (entity_id, valid_from)
);
comment on table public.invoice_account_settings is 'Comptes utilisés pour comptabiliser les factures normalisées d''un dossier, versionnés par date d''effet.';
create trigger invoice_account_settings_audit after insert or update or delete on public.invoice_account_settings
  for each row execute function public.audit_row_change();

create or replace function public.invoice_account_settings_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not exists (select 1 from public.entities e where e.id = new.entity_id and e.cabinet_id = new.cabinet_id) then
    raise exception 'Cabinet incohérent' using errcode = '23514';
  end if;
  for v_id in select unnest(array[new.client_account_id, new.sales_exempt_account_id, new.sales_taxable_account_id, new.vat_account_id, new.aib_account_id]) loop
    if v_id is not null and not exists (select 1 from public.accounts a where a.id = v_id and a.entity_id = new.entity_id and a.is_active and a.allow_posting) then
      raise exception 'Chaque compte doit appartenir au dossier, être actif et accepter des écritures' using errcode = '23514';
    end if;
  end loop;
  if new.journal_id is not null and not exists (select 1 from public.journals j where j.id = new.journal_id and j.entity_id = new.entity_id and j.type = 'sales' and j.is_active) then
    raise exception 'Le journal doit être un journal de ventes actif du dossier' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger invoice_account_settings_guard before insert or update on public.invoice_account_settings
  for each row execute function public.invoice_account_settings_guard();

alter table public.invoice_account_settings enable row level security;
create policy invoice_account_settings_select on public.invoice_account_settings for select to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.can_access_entity(entity_id));
create policy invoice_account_settings_write on public.invoice_account_settings for all to authenticated
  using (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'references.manage'))
  with check (cabinet_id = public.current_cabinet_id() and public.has_permission(entity_id, 'references.manage'));
grant select, insert, update, delete on public.invoice_account_settings to authenticated;

-- -----------------------------------------------------------------------------
-- Génération de l'écriture d'une facture confirmée
-- Vente (FV) : débit client (total + AIB) ; crédit ventes exonérées (groupe A), ventes taxables (HT du groupe B),
--              TVA facturée, AIB. Avoir (FA) : même écriture, sens inversé.
-- Les montants sont ceux de la DGI (invoices.dgi_response). Hypothèse à vérifier avec les cas de test de la DGI :
-- l'AIB s'ajoute au total de la facture (la spécification ne le précise pas).
-- -----------------------------------------------------------------------------
create or replace function public.generate_invoice_entry(p_invoice uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_inv public.invoices%rowtype;
  v_set public.invoice_account_settings%rowtype;
  v_date date;
  v_taa bigint; v_hab bigint; v_vab bigint; v_aib bigint; v_total bigint;
  v_third uuid; v_dr text; v_cr text;
  v_lines jsonb := '[]'::jsonb; v_entry uuid; v_label text;
begin
  select * into v_inv from public.invoices where id = p_invoice;
  if v_inv.id is null or not public.can_access_entity(v_inv.entity_id) then
    raise exception 'Facture inaccessible' using errcode = '42501';
  end if;
  if not public.has_permission(v_inv.entity_id, 'entries.draft') then
    raise exception 'Permission refusée : entries.draft' using errcode = '42501';
  end if;
  if v_inv.status <> 'confirmed' then
    raise exception 'Seule une facture confirmée par la DGI se comptabilise' using errcode = '23514';
  end if;
  if v_inv.is_test then
    raise exception 'Facture émise en test : aucune écriture comptable' using errcode = '23514';
  end if;

  v_date := (v_inv.issued_at at time zone 'Africa/Porto-Novo')::date;
  select * into v_set from public.invoice_account_settings
   where entity_id = v_inv.entity_id and valid_from <= v_date order by valid_from desc limit 1;
  if v_set.entity_id is null then
    raise exception 'Définissez d''abord les comptes de facturation du dossier (paramètres de facturation)' using errcode = '23514';
  end if;

  v_taa := coalesce((v_inv.dgi_response ->> 'taa')::bigint, 0);
  v_hab := coalesce((v_inv.dgi_response ->> 'hab')::bigint, 0);
  v_vab := coalesce((v_inv.dgi_response ->> 'vab')::bigint, 0);
  v_aib := coalesce((v_inv.dgi_response ->> 'aib')::bigint, 0);
  v_total := coalesce((v_inv.dgi_response ->> 'total')::bigint, v_inv.total, 0);
  if v_aib > 0 and v_set.aib_account_id is null then
    raise exception 'Cette facture comporte de l''AIB : choisissez le compte de l''AIB dans les paramètres de facturation' using errcode = '23514';
  end if;
  if v_taa + v_hab + v_vab <> v_total then
    raise exception 'Les montants de la DGI ne s''équilibrent pas (total %, détail %)', v_total, v_taa + v_hab + v_vab using errcode = '23514';
  end if;

  -- Tiers : rapprochement par IFU, sinon par nom exact (sans casse) ; à défaut le comptable le choisit dans le brouillard.
  select t.id into v_third from public.third_parties t
   where t.entity_id = v_inv.entity_id and t.is_active
     and ((v_inv.client_ifu is not null and t.tax_id = v_inv.client_ifu)
          or (v_inv.client_ifu is null and v_inv.client_name is not null and lower(trim(t.name)) = lower(trim(v_inv.client_name))))
   order by (t.tax_id = v_inv.client_ifu) desc nulls last, t.code limit 1;

  -- Sens : vente = client au débit ; avoir = client au crédit
  v_dr := case when v_inv.type = 'FV' then 'debit' else 'credit' end;
  v_cr := case when v_inv.type = 'FV' then 'credit' else 'debit' end;
  v_lines := jsonb_build_array(jsonb_build_object('account_id', v_set.client_account_id, 'third_party_id', v_third, v_dr, v_total + v_aib,
                                                  'label', coalesce(v_inv.client_name, 'Client')));
  if v_taa > 0 then v_lines := v_lines || jsonb_build_object('account_id', v_set.sales_exempt_account_id, v_cr, v_taa, 'label', 'Ventes exonérées (groupe A)'); end if;
  if v_hab > 0 then v_lines := v_lines || jsonb_build_object('account_id', v_set.sales_taxable_account_id, v_cr, v_hab, 'label', 'Ventes taxables HT (groupe B)'); end if;
  if v_vab > 0 then v_lines := v_lines || jsonb_build_object('account_id', v_set.vat_account_id, v_cr, v_vab, 'label', 'TVA facturée'); end if;
  if v_aib > 0 then v_lines := v_lines || jsonb_build_object('account_id', v_set.aib_account_id, v_cr, v_aib, 'label', 'AIB'); end if;

  v_label := case when v_inv.type = 'FV' then 'Facture de vente' else 'Facture d''avoir' end || coalesce(' — ' || v_inv.client_name, '');
  v_entry := public.generated_entry(v_inv.entity_id, v_date, v_label, 'invoice:' || v_inv.id, v_lines, 'sales');
  update public.entries set reference = v_inv.code_mecef, journal_id = coalesce(v_set.journal_id, journal_id) where id = v_entry;
  return v_entry;
end $$;
revoke all on function public.generate_invoice_entry(uuid) from public, anon;
grant execute on function public.generate_invoice_entry(uuid) to authenticated, service_role;

-- Écriture liée à une facture (RLS de l'appelant) : identifiant, statut et numéro (null tant que le brouillard n'est pas validé).
create or replace function public.invoice_entry(p_invoice uuid)
returns table (entry_id uuid, status public.entry_status, number bigint)
language sql stable security invoker set search_path = public as $$
  select e.id, e.status, e.number from public.entries e where e.generated_source = 'invoice:' || p_invoice::text;
$$;
grant execute on function public.invoice_entry(uuid) to authenticated;
