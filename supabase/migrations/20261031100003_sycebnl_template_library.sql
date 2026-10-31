-- Bibliothèque de modèles d'écritures SYCEBNL (décision D-022) : 19 modèles pour les associations.
-- Les numéros de compte sont ceux du plan SYCEBNL du dépôt (seed précédent), sans TVA (associations en général non
-- assujetties). À faire valider par ABC avant la recette (Q-017). Rejouable : n'ajoute que les modèles absents du cabinet.
-- Les modèles de paie ne tiennent pas compte des retenues (CNSS, impôt sur salaires) : à compléter après validation.

create or replace function public.seed_sycebnl_template_library(p_cabinet uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  r record; t uuid; n smallint; l jsonb;
begin
  for r in
    select * from (values
    ('AS_COTIS_APPEL', 'Appel de cotisations aux adhérents', 'sales', 'Cotisation due : adhérent débiteur, cotisation en produit', '[{"a": "701", "tp": false, "s": "credit", "f": "input", "ref": null, "tax": null, "l": "Cotisations des adhérents"}, {"a": "411", "tp": true, "s": "debit", "f": "balance", "ref": null, "tax": null, "l": "Adhérent"}]'::jsonb),
    ('AS_COTIS_BQ', 'Cotisation encaissée par banque', 'bank', 'Encaissement direct d''une cotisation', '[{"a": "5211", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Banque"}, {"a": "701", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Cotisations des adhérents"}]'::jsonb),
    ('AS_COTIS_CAISSE', 'Cotisation encaissée en espèces', 'cash', 'Encaissement direct d''une cotisation en espèces', '[{"a": "571", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Caisse"}, {"a": "701", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Cotisations des adhérents"}]'::jsonb),
    ('AS_REGL_ADHERENT', 'Règlement d''un adhérent par banque', 'bank', 'Cotisation appelée puis réglée : banque et adhérent soldé', '[{"a": "5211", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Banque"}, {"a": "411", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Adhérent"}]'::jsonb),
    ('AS_DON_BQ', 'Don en numéraire reçu par banque', 'bank', 'Revenus liés à la générosité : dons', '[{"a": "5211", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Banque"}, {"a": "7041", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Dons"}]'::jsonb),
    ('AS_DON_CAISSE', 'Don en numéraire reçu en espèces', 'cash', 'Revenus liés à la générosité : dons', '[{"a": "571", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Caisse"}, {"a": "7041", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Dons"}]'::jsonb),
    ('AS_SUBV_ETAT', 'Subvention d''exploitation reçue de l''État', 'bank', 'Subvention de l''État ou d''une collectivité publique encaissée', '[{"a": "5211", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Banque"}, {"a": "711", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Subvention d''exploitation, État et collectivités"}]'::jsonb),
    ('AS_SUBV_ORG', 'Subvention d''exploitation reçue d''un organisme', 'bank', 'Subvention d''un organisme national ou international encaissée', '[{"a": "5211", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Banque"}, {"a": "713", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Subvention d''exploitation, organismes"}]'::jsonb),
    ('AS_SUBV_A_RECEVOIR', 'Subvention d''exploitation notifiée, à recevoir', 'misc', 'Constatation de la subvention avant encaissement', '[{"a": "4732", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Subvention d''exploitation à recevoir"}, {"a": "713", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Subvention d''exploitation, organismes"}]'::jsonb),
    ('AS_ACHAT', 'Achat de biens et services liés à l''activité', 'purchases', 'Achat sans TVA : charge et fournisseur', '[{"a": "6011", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Achat"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur"}]'::jsonb),
    ('AS_LOYER', 'Loyer', 'purchases', 'Loyer sans TVA : charge et fournisseur', '[{"a": "6222", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Loyer"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur"}]'::jsonb),
    ('AS_ELECTRICITE', 'Facture d''électricité', 'purchases', 'Électricité sans TVA : charge et fournisseur', '[{"a": "6052", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Électricité"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur"}]'::jsonb),
    ('AS_TELECOM', 'Téléphone et internet', 'purchases', 'Téléphone sans TVA : charge et fournisseur', '[{"a": "6281", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Téléphone et internet"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur"}]'::jsonb),
    ('AS_REGL_FOURN', 'Règlement fournisseur par banque', 'bank', 'Fournisseur soldé, banque décaissée', '[{"a": "4011", "tp": true, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Fournisseur"}, {"a": "5211", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Banque"}]'::jsonb),
    ('AS_PAIEMENT_CAISSE', 'Paiement fournisseur en espèces', 'cash', 'Fournisseur soldé, caisse décaissée', '[{"a": "4011", "tp": true, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Fournisseur"}, {"a": "571", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Caisse"}]'::jsonb),
    ('AS_VERSEMENT_ESP', 'Versement d''espèces en banque', 'cash', 'Banque créditée, caisse déchargée', '[{"a": "5211", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Banque"}, {"a": "571", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Caisse"}]'::jsonb),
    ('AS_FRAIS_BANCAIRES', 'Frais bancaires', 'bank', 'Frais prélevés par la banque', '[{"a": "6318", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Frais bancaires"}, {"a": "5211", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Banque"}]'::jsonb),
    ('AS_SALAIRES', 'Rémunérations du personnel (simplifié)', 'payroll', 'Rémunération brute et net à payer ; retenues sociales et fiscales à ajouter selon le cas', '[{"a": "6611", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Appointements et salaires"}, {"a": "422", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Personnel, rémunérations dues"}]'::jsonb),
    ('AS_PAIEMENT_SALAIRES', 'Paiement des rémunérations par banque', 'bank', 'Personnel soldé, banque décaissée', '[{"a": "422", "tp": true, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Personnel, rémunérations dues"}, {"a": "5211", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Banque"}]'::jsonb)
    ) as v(code, label, journal_type, description, lines)
  loop
    if exists (select 1 from public.entry_templates where cabinet_id = p_cabinet and entity_id is null and code = r.code) then continue; end if;
    insert into public.entry_templates (cabinet_id, code, label, journal_type, description, accounting_system)
    values (p_cabinet, r.code, r.label, r.journal_type::public.journal_type, r.description, 'sycebnl') returning id into t;
    n := 0;
    for l in select * from jsonb_array_elements(r.lines) loop
      n := n + 1;
      insert into public.entry_template_lines (template_id, line_no, account_code, uses_third_party, side, formula, ref_line_no, tax_rate_code, label)
      values (t, n, l->>'a', (l->>'tp')::boolean, (l->>'s')::public.posting_side, (l->>'f')::public.amount_formula,
              nullif(l->>'ref', '')::smallint, nullif(l->>'tax', ''), l->>'l');
    end loop;
  end loop;
end $$;
revoke execute on function public.seed_sycebnl_template_library(uuid) from public, anon, authenticated;

create or replace function public.handle_new_cabinet()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.seed_default_roles(new.id);
  perform public.seed_default_referentials(new.id);
  perform public.seed_entry_template_library(new.id);
  perform public.seed_sycebnl_template_library(new.id);
  return new;
end $$;

-- Cabinets existants (dont celui de la recette)
select public.seed_sycebnl_template_library(id) from public.cabinets;
