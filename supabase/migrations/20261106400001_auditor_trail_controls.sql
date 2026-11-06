-- Recette du 05/11/2026, point 4 (partie comptabilité, sans module ISA) :
--   1. rôle « Auditeur » : lecture seule (grand livre, balances, exports, piste d'audit), affecté dossier par dossier ;
--   2. piste d'audit lisible par dossier : qui a saisi, modifié, validé, supprimé une écriture, et quand ;
--   3. contrôles automatiques : soldes anormaux et écritures hors période.
-- Aucune règle comptable n'est touchée : l'auditeur n'a aucun droit d'écriture, les contrôles ne font que lire.
-- Décisions provisoires : les chefs de mission lisent aussi la piste d'audit de leurs dossiers ; l'auditeur exige la double
-- vérification (MFA), comme l'associé.

-- 1. Rôle Auditeur ----------------------------------------------------------------------------------------------------
create or replace function public.seed_auditor_role(p_cabinet uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r_auditor uuid;
begin
  insert into public.roles (cabinet_id, code, name, is_system, grants_all_entities, requires_mfa, accounting_access)
  values (p_cabinet, 'auditor', 'Auditeur', true, false, true, true)
  on conflict (cabinet_id, code) do nothing;
  select id into r_auditor from public.roles where cabinet_id = p_cabinet and code = 'auditor';
  insert into public.role_permissions (role_id, permission_code) values (r_auditor, 'ledger.read'), (r_auditor, 'audit.read')
  on conflict do nothing;
  -- Chef de mission : piste d'audit de ses dossiers
  insert into public.role_permissions (role_id, permission_code)
  select r.id, 'audit.read' from public.roles r where r.cabinet_id = p_cabinet and r.code = 'manager'
  on conflict do nothing;
end $$;
revoke all on function public.seed_auditor_role(uuid) from public, anon, authenticated;

select public.seed_auditor_role(id) from public.cabinets;

create or replace function public.handle_new_cabinet_auditor()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.seed_auditor_role(new.id);
  return new;
end $$;
-- Nom classé après on_cabinet_created (création des rôles).
create trigger on_cabinet_created_zauditor after insert on public.cabinets
  for each row execute function public.handle_new_cabinet_auditor();

-- 2. Piste d'audit par dossier -----------------------------------------------------------------------------------------
-- Lecture des lignes d'un dossier par qui détient audit.read sur ce dossier (en plus de la portée cabinet de l'associé).
drop policy audit_log_select on public.audit_log;
create policy audit_log_select on public.audit_log for select to authenticated
  using (cabinet_id = public.current_cabinet_id()
         and (public.has_permission(null, 'audit.read') or (entity_id is not null and public.has_permission(entity_id, 'audit.read'))));

-- Événements d'écriture lisibles : saisie, modification, validation, suppression d'un brouillard.
create or replace function public.entry_audit_trail(p_entity uuid, p_from date, p_to date, p_limit integer default 500)
returns table (audit_id bigint, occurred_at timestamptz, actor_label text, event text, entry_id uuid, journal_code text,
               entry_number bigint, entry_date date, label text)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null or not public.has_permission(p_entity, 'audit.read') then
    raise exception 'Permission refusée : consulter la piste d''audit' using errcode = '42501';
  end if;
  return query
  with ev as (
    select a.id, a.occurred_at, a.actor_id, a.record_id::uuid as eid,
           case a.action
             when 'insert' then 'created'
             when 'delete' then 'deleted'
             when 'update' then case when a.payload #>> '{old,status}' = 'draft' and a.payload #>> '{new,status}' = 'validated' then 'validated' else 'modified' end
           end as kind,
           coalesce(a.payload -> 'new', a.payload -> 'row') as r
      from public.audit_log a
     where a.cabinet_id = public.current_cabinet_id() and a.entity_id = p_entity and a.table_name = 'entries'
       and a.occurred_at >= p_from::timestamptz and a.occurred_at < (p_to + 1)::timestamptz
  ), labels as (
    select * from public.actor_labels(array(select distinct e.actor_id from ev e where e.actor_id is not null))
  )
  select ev.id, ev.occurred_at, coalesce(l.label, 'Système'), ev.kind, ev.eid, j.code,
         nullif(ev.r ->> 'number', '')::bigint, (ev.r ->> 'entry_date')::date, ev.r ->> 'label'
    from ev
    left join labels l on l.id = ev.actor_id
    left join public.journals j on j.id = (ev.r ->> 'journal_id')::uuid
   where ev.kind is not null
   order by ev.id desc
   limit greatest(p_limit, 1);
end $$;
revoke all on function public.entry_audit_trail(uuid, date, date, integer) from public, anon;
grant execute on function public.entry_audit_trail(uuid, date, date, integer) to authenticated;

-- 3. Contrôles automatiques -------------------------------------------------------------------------------------------
-- Ne modifient rien et ne bloquent rien : ils signalent. Soldes anormaux (dans le sens inverse de la nature du compte) :
--   fournisseurs 40x débiteurs (hors 409), clients 41x créditeurs (hors 419), caisse 57x créditrice, charges (6) créditrices,
--   produits (7) débiteurs. Écritures hors période : date hors de sa période, hors de son exercice, ou datée de plus d'un mois dans le futur.
create or replace function public.accounting_controls(p_entity uuid, p_fiscal_year uuid)
returns table (control_code text, severity text, account_code text, account_label text, entry_id uuid, entry_date date, amount bigint, detail text)
language plpgsql stable as $$
begin
  perform public.require_ledger_read(p_entity);
  return query
  with bal as (
    select l.account_code as code, max(l.account_label) as lbl, sum(l.debit) - sum(l.credit) as b
      from public.ledger_lines l
     where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year
     group by l.account_code
  )
  select 'abnormal_balance'::text, 'warning'::text, bal.code, bal.lbl, null::uuid, null::date, abs(bal.b)::bigint,
         case when bal.b > 0 then 'debit' else 'credit' end
    from bal
   where bal.b <> 0
     and ((bal.code like '40%' and bal.code not like '409%' and bal.b > 0)
       or (bal.code like '41%' and bal.code not like '419%' and bal.b < 0)
       or (bal.code like '57%' and bal.b < 0)
       or (bal.code like '6%'  and bal.b < 0)
       or (bal.code like '7%'  and bal.b > 0))
  union all
  select 'entry_outside_period', 'warning', null, null, e.id, e.entry_date, null::bigint, 'period'
    from public.entries e join public.periods p on p.id = e.period_id
   where e.entity_id = p_entity and e.fiscal_year_id = p_fiscal_year and e.entry_date not between p.start_date and p.end_date
  union all
  select 'entry_outside_period', 'warning', null, null, e.id, e.entry_date, null::bigint, 'fiscal_year'
    from public.entries e join public.fiscal_years f on f.id = e.fiscal_year_id
   where e.entity_id = p_entity and e.fiscal_year_id = p_fiscal_year and e.entry_date not between f.start_date and f.end_date
  union all
  select 'entry_outside_period', 'warning', null, null, e.id, e.entry_date, null::bigint, 'future'
    from public.entries e
   where e.entity_id = p_entity and e.fiscal_year_id = p_fiscal_year and e.entry_date > current_date + 31
  order by 1, 3, 6;
end $$;
grant execute on function public.accounting_controls(uuid, uuid) to authenticated;

-- Retour arrière (à exécuter à la main) :
--   drop function public.accounting_controls(uuid, uuid); drop function public.entry_audit_trail(uuid, date, date, integer);
--   recréer la politique d'origine audit_log_select (socle, ligne 503) ;
--   drop trigger on_cabinet_created_zauditor on public.cabinets; drop function public.handle_new_cabinet_auditor();
--   (réaffecter puis) delete from public.roles where code = 'auditor'; drop function public.seed_auditor_role(uuid);
--   delete from public.role_permissions rp using public.roles r where r.id = rp.role_id and r.code = 'manager' and rp.permission_code = 'audit.read';
