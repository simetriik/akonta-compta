-- Enregistrement atomique d'un brouillon de facture (D-043) : la facture, ses lignes et ses paiements dans une seule transaction.
-- La fonction s'exécute avec les droits de l'appelant : la RLS et les déclencheurs de 20261104100001 s'appliquent.
-- Les avoirs naissent de create_credit_note() (type et facture d'origine ne changent pas) ; cette fonction n'en crée pas.
create or replace function public.save_invoice_draft(p_invoice uuid, p_data jsonb)
returns uuid language plpgsql security invoker set search_path = public as $$
declare
  v_id uuid := p_invoice;
  v_aib text := nullif(trim(p_data ->> 'aib'), '');
begin
  if v_id is null then
    if coalesce(p_data ->> 'type', 'FV') <> 'FV' then
      raise exception 'Un avoir se crée à partir d''une facture de vente confirmée' using errcode = '23514';
    end if;
    insert into public.invoices (cabinet_id, entity_id, device_id, type, aib, client_ifu, client_name, client_contact, client_address,
                                 operator_name, commercial_message)
    values ((p_data ->> 'cabinet_id')::uuid, (p_data ->> 'entity_id')::uuid, (p_data ->> 'device_id')::uuid, 'FV', v_aib,
            nullif(trim(p_data ->> 'client_ifu'), ''), nullif(trim(p_data ->> 'client_name'), ''),
            nullif(trim(p_data ->> 'client_contact'), ''), nullif(trim(p_data ->> 'client_address'), ''),
            p_data ->> 'operator_name', nullif(trim(p_data ->> 'commercial_message'), ''))
    returning id into v_id;
  else
    update public.invoices set aib = v_aib,
           client_ifu = nullif(trim(p_data ->> 'client_ifu'), ''), client_name = nullif(trim(p_data ->> 'client_name'), ''),
           client_contact = nullif(trim(p_data ->> 'client_contact'), ''), client_address = nullif(trim(p_data ->> 'client_address'), ''),
           operator_name = p_data ->> 'operator_name', commercial_message = nullif(trim(p_data ->> 'commercial_message'), '')
     where id = v_id and status = 'draft';
    if not found then
      raise exception 'Brouillon introuvable ou déjà émis' using errcode = '23514';
    end if;
    delete from public.invoice_lines where invoice_id = v_id;
    delete from public.invoice_payments where invoice_id = v_id;
  end if;

  insert into public.invoice_lines (invoice_id, position, code, name, price, quantity, tax_group)
  select v_id, l.ord::smallint, nullif(trim(l.v ->> 'code'), ''), l.v ->> 'name', (l.v ->> 'price')::bigint,
         (l.v ->> 'quantity')::numeric, l.v ->> 'tax_group'
    from jsonb_array_elements(coalesce(p_data -> 'lines', '[]'::jsonb)) with ordinality as l(v, ord);
  insert into public.invoice_payments (invoice_id, name, amount)
  select v_id, p.v ->> 'name', (p.v ->> 'amount')::bigint
    from jsonb_array_elements(coalesce(p_data -> 'payments', '[]'::jsonb)) as p(v);
  return v_id;
end $$;
revoke all on function public.save_invoice_draft(uuid, jsonb) from public, anon;
grant execute on function public.save_invoice_draft(uuid, jsonb) to authenticated;
