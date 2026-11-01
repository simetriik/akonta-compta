-- Correspondances comptes → postes des états : plus aucun compte n'est compté dans deux postes à la fois,
-- et un bilan déséquilibré ne peut plus être clos (recette de bout en bout du 1er nov. 2026, A11 et A12).
--
-- 1. Plages qui se chevauchaient (version SYSCOHADA-2017, correspondances livrées) :
--      AM « 24 » / « 284 » couvraient aussi 245 / 2845 (poste AN, matériel de transport) ;
--      BJ « 42-47 » couvrait 478 (poste BU) et 479 ; DM « 45-47 » couvrait 478 et 479 (poste DV) ;
--      RL « 68-69 » couvrait 697 (poste RN) ; TJ « 791-799 » couvrait 797 (poste TL) ;
--      TO « 84-88 » couvrait 85 (poste RP) et 87 (poste RQ).
--    Les lignes trop larges sont remplacées par des plages qui s'excluent ; libellé, sens, signe, rôle et ordre sont conservés.
-- 2. Clôture : tant que les états financiers les plus récents ont un contrôle en échec (équilibre du bilan, résultat),
--    la clôture provisoire et l'arrêté définitif sont refusés.

create temporary table _mapping_fix (post_code text, old_from text, old_to text, new_from text, new_to text);
insert into _mapping_fix values
  ('AM', '24',  '24',  '240',  '244'), ('AM', '24',  '24',  '246',  '249'),
  ('AM', '284', '284', '2840', '2844'), ('AM', '284', '284', '2846', '2849'),
  ('BJ', '42',  '47',  '42',   '46'),  ('BJ', '42',  '47',  '470',  '477'),
  ('DM', '45',  '47',  '45',   '46'),  ('DM', '45',  '47',  '470',  '477'),
  ('RL', '68',  '69',  '68',   '68'),  ('RL', '68',  '69',  '690',  '696'), ('RL', '68', '69', '698', '699'),
  ('TJ', '791', '799', '791',  '796'), ('TJ', '791', '799', '798',  '799'),
  ('TO', '84',  '88',  '84',   '84'),  ('TO', '84',  '88',  '86',   '86'),  ('TO', '84', '88', '88', '88');

-- Insère les plages de remplacement (même ligne que l'ancienne, bornes remplacées), puis supprime les anciennes.
insert into public.statement_mappings (cabinet_id, version, statement, post_code, post_label, account_from, account_to, balance_side, sign, column_role, sort_order, valid_from, valid_to)
select m.cabinet_id, m.version, m.statement, m.post_code, m.post_label, f.new_from, f.new_to, m.balance_side, m.sign, m.column_role, m.sort_order, m.valid_from, m.valid_to
  from public.statement_mappings m
  join _mapping_fix f on f.post_code = m.post_code and f.old_from = m.account_from and f.old_to = m.account_to
 where m.cabinet_id is null and m.version = 'SYSCOHADA-2017' and m.valid_to is null;

delete from public.statement_mappings m
 using (select distinct post_code, old_from, old_to from _mapping_fix) f
 where m.cabinet_id is null and m.version = 'SYSCOHADA-2017' and m.valid_to is null
   and m.post_code = f.post_code and m.account_from = f.old_from and m.account_to = f.old_to;

drop table _mapping_fix;

-- Équilibre des états : vrai tant que le dernier jeu d'états n'a aucun contrôle en échec.
create or replace function public.latest_statements_failed_check(p_fiscal_year uuid)
returns text language sql stable security definer set search_path = public as $$
  select c ->> 'label'
    from (select checks from public.financial_statements where fiscal_year_id = p_fiscal_year order by generated_at desc limit 1) s,
         jsonb_array_elements(s.checks) c
   where (c ->> 'passed') = 'false'
   limit 1
$$;

create or replace function public.close_provisional(p_entity uuid, p_fiscal_year uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_blocking int; v_failed text;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.provisional') then
    raise exception 'Permission refusée : clôture provisoire' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity for update;
  if v_fy.status <> 'open' then raise exception 'L''exercice n''est pas ouvert' using errcode = '23514'; end if;
  perform public.run_closing_checks(p_entity, p_fiscal_year);
  select count(*) into v_blocking from public.closing_checks where fiscal_year_id = p_fiscal_year and status = 'failed' and severity = 'blocking';
  if v_blocking > 0 then raise exception '% contrôle(s) bloquant(s) en échec', v_blocking using errcode = '23514'; end if;
  if exists (select 1 from public.closing_checks where fiscal_year_id = p_fiscal_year and status = 'failed' and severity = 'warning') then
    raise exception 'Des alertes ne sont pas levées : commenter chaque levée' using errcode = '23514';
  end if;
  v_failed := public.latest_statements_failed_check(p_fiscal_year);
  if v_failed is not null then
    raise exception 'États financiers en échec : « % ». Corriger puis régénérer les états avant la clôture', v_failed using errcode = '23514';
  end if;
  update public.fiscal_years set status = 'closing' where id = p_fiscal_year;
  update public.periods set is_locked = true, locked_at = now(), locked_by = auth.uid() where fiscal_year_id = p_fiscal_year and not is_locked;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_fy.cabinet_id, auth.uid(), 'close_provisional', 'fiscal_years', p_fiscal_year::text, p_entity, jsonb_build_object('label', v_fy.label));
end $$;

create or replace function public.close_final(p_entity uuid, p_fiscal_year uuid, p_confirmation text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_fy public.fiscal_years%rowtype; v_manifest jsonb; v_hash text; v_id uuid; v_statements uuid; v_failed text;
begin
  if auth.uid() is not null and not public.has_permission(p_entity, 'closing.final') then
    raise exception 'Permission refusée : arrêté définitif (associé avec TOTP)' using errcode = '42501';
  end if;
  select * into v_fy from public.fiscal_years where id = p_fiscal_year and entity_id = p_entity for update;
  if v_fy.status <> 'closing' then raise exception 'L''exercice doit être en clôture provisoire' using errcode = '23514'; end if;
  if p_confirmation is distinct from 'ARRETER ' || v_fy.label then
    raise exception 'Confirmation attendue : « ARRETER % »', v_fy.label using errcode = '23514';
  end if;
  if not exists (select 1 from public.entries where entity_id = p_entity and generated_source = 'result:' || p_fiscal_year and status = 'validated') then
    raise exception 'L''écriture de détermination du résultat doit être validée' using errcode = '23514';
  end if;
  select id into v_statements from public.financial_statements where fiscal_year_id = p_fiscal_year order by generated_at desc limit 1;
  if v_statements is null then raise exception 'Générer les états financiers avant l''arrêté' using errcode = '23514'; end if;
  v_failed := public.latest_statements_failed_check(p_fiscal_year);
  if v_failed is not null then
    raise exception 'États financiers en échec : « % ». Corriger puis régénérer les états avant l''arrêté', v_failed using errcode = '23514';
  end if;
  v_manifest := jsonb_build_object(
    'fiscal_year', v_fy.label, 'archived_at', now(),
    'ledger_hash', encode(extensions.digest(coalesce((select string_agg(concat_ws('|', l.entry_date, l.journal_code, l.number, l.account_code, l.third_party_code, l.debit, l.credit), E'\n' order by l.entry_date, l.journal_code, l.number, l.line_id)
                                                     from public.ledger_lines l where l.entity_id = p_entity and l.fiscal_year_id = p_fiscal_year), ''), 'sha256'), 'hex'),
    'balance_hash', encode(extensions.digest(coalesce((select string_agg(concat_ws('|', account_code, balance), E'\n' order by account_code) from public.closing_balances(p_entity, p_fiscal_year)), ''), 'sha256'), 'hex'),
    'statements_id', v_statements,
    'statements_hash', encode(extensions.digest((select data::text from public.financial_statements where id = v_statements), 'sha256'), 'hex'),
    'entries_count', (select count(*) from public.entries where entity_id = p_entity and fiscal_year_id = p_fiscal_year and status = 'validated'),
    'documents_count', (select count(distinct ed.document_id) from public.entry_documents ed join public.entries e on e.id = ed.entry_id where e.entity_id = p_entity and e.fiscal_year_id = p_fiscal_year));
  v_hash := encode(extensions.digest(v_manifest::text, 'sha256'), 'hex');
  insert into public.closing_archives (cabinet_id, entity_id, fiscal_year_id, archived_by, manifest, hash)
  values (v_fy.cabinet_id, p_entity, p_fiscal_year, auth.uid(), v_manifest, v_hash) returning id into v_id;
  update public.financial_statements set is_final = true where id = v_statements;
  update public.fiscal_years set status = 'closed', final_closed_at = now(), final_closed_by = auth.uid() where id = p_fiscal_year;
  insert into public.audit_log (cabinet_id, actor_id, action, table_name, record_id, entity_id, payload)
  values (v_fy.cabinet_id, auth.uid(), 'close_final', 'fiscal_years', p_fiscal_year::text, p_entity, jsonb_build_object('label', v_fy.label, 'archive', v_id, 'hash', v_hash));
  return v_id;
end $$;

grant execute on function public.close_provisional(uuid, uuid), public.close_final(uuid, uuid, text) to authenticated;
revoke execute on function public.latest_statements_failed_check(uuid) from public, anon, authenticated;
