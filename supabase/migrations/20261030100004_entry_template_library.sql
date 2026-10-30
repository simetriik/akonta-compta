-- Bibliothèque de modèles d'écritures (décision D-021) : 25 modèles ajoutés aux 5 modèles fournis, et correction des
-- comptes signalés en Q-013 (SALAIRES visait 4221, inexistant : 422 ; banque visée 5211 « Banque X » : 521, aligné sur le journal de banque).
-- Les numéros de compte sont ceux du plan de référence SYSCOHADA du dépôt ; à faire valider par ABC avant la recette.
-- Rejouable : n'ajoute que les modèles absents du cabinet et ne touche pas aux modèles modifiés par le cabinet.

create or replace function public.seed_entry_template_library(p_cabinet uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  r record; t uuid; n smallint; l jsonb;
begin
  for r in
    select * from (values
    ('ACHAT_SERVICES', 'Achat de prestations de services avec TVA', 'purchases', 'Prestation de services, TVA récupérable, fournisseur', '[{"a": "6057", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Prestation de services HT"}, {"a": "4454", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA récupérable"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('LOYER', 'Loyer sans TVA', 'purchases', 'Bailleur non assujetti à la TVA : loyer et fournisseur', '[{"a": "6222", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Loyer HT"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur"}]'::jsonb),
    ('LOYER_TVA', 'Loyer avec TVA', 'purchases', 'Bailleur assujetti à la TVA', '[{"a": "6222", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Loyer HT"}, {"a": "4454", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA récupérable"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('ELECTRICITE', 'Facture d''électricité avec TVA', 'purchases', 'Électricité, TVA récupérable, fournisseur', '[{"a": "6052", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Électricité HT"}, {"a": "4454", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA récupérable"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('EAU', 'Facture d''eau avec TVA', 'purchases', 'Eau, TVA récupérable, fournisseur', '[{"a": "6051", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Eau HT"}, {"a": "4454", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA récupérable"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('TELECOM', 'Téléphone et internet avec TVA', 'purchases', 'Téléphone et internet, TVA récupérable, fournisseur', '[{"a": "6281", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Téléphone et internet HT"}, {"a": "4454", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA récupérable"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('FOURNITURES', 'Fournitures de bureau avec TVA', 'purchases', 'Fournitures de bureau, TVA récupérable, fournisseur', '[{"a": "6055", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Fournitures de bureau HT"}, {"a": "4452", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA récupérable"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('HONORAIRES', 'Honoraires avec TVA', 'purchases', 'Honoraires, TVA récupérable, fournisseur', '[{"a": "6324", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Honoraires HT"}, {"a": "4454", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA récupérable"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('ENTRETIEN', 'Entretien et réparations avec TVA', 'purchases', 'Entretien et réparations, TVA récupérable, fournisseur', '[{"a": "6242", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Entretien et réparations HT"}, {"a": "4454", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA récupérable"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('ASSURANCE', 'Prime d''assurance', 'purchases', 'Assurance non soumise à la TVA : prime et fournisseur', '[{"a": "6251", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Prime d''assurance HT"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur"}]'::jsonb),
    ('PUBLICITE', 'Publicité et annonces avec TVA', 'purchases', 'Publicité, TVA récupérable, fournisseur', '[{"a": "6271", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Publicité HT"}, {"a": "4454", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA récupérable"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('DEPLACEMENTS', 'Voyages et déplacements avec TVA', 'purchases', 'Voyages et déplacements, TVA récupérable, fournisseur', '[{"a": "6181", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Voyages et déplacements HT"}, {"a": "4454", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA récupérable"}, {"a": "4011", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('ACHAT_IMMO', 'Achat de matériel de bureau (immobilisation)', 'purchases', 'Immobilisation HT, TVA sur immobilisations, fournisseur d''investissement', '[{"a": "2441", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Matériel de bureau HT"}, {"a": "4451", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA récupérable"}, {"a": "4812", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('VENTE_SERVICES', 'Vente de services avec TVA', 'sales', 'Client TTC, prestation HT, TVA sur prestations', '[{"a": "7061", "tp": false, "s": "credit", "f": "input", "ref": null, "tax": null, "l": "Prestation HT"}, {"a": "4432", "tp": false, "s": "credit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA sur prestations"}, {"a": "4111", "tp": true, "s": "debit", "f": "balance", "ref": null, "tax": null, "l": "Client TTC"}]'::jsonb),
    ('VENTE_EXONEREE', 'Vente exonérée de TVA', 'sales', 'Vente sans TVA : client et vente', '[{"a": "7011", "tp": false, "s": "credit", "f": "input", "ref": null, "tax": null, "l": "Vente"}, {"a": "4111", "tp": true, "s": "debit", "f": "balance", "ref": null, "tax": null, "l": "Client"}]'::jsonb),
    ('AVOIR_VENTE', 'Avoir client avec TVA', 'sales', 'Annulation partielle d''une vente : vente et TVA en diminution, client en crédit', '[{"a": "7011", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Avoir HT"}, {"a": "4431", "tp": false, "s": "debit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA à reprendre"}, {"a": "4111", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Client TTC"}]'::jsonb),
    ('AVOIR_ACHAT', 'Avoir fournisseur avec TVA', 'purchases', 'Annulation partielle d''un achat : achat et TVA en diminution, fournisseur en débit', '[{"a": "6011", "tp": false, "s": "credit", "f": "input", "ref": null, "tax": null, "l": "Avoir HT"}, {"a": "4452", "tp": false, "s": "credit", "f": "percent_of", "ref": 1, "tax": "TVA", "l": "TVA à reprendre"}, {"a": "4011", "tp": true, "s": "debit", "f": "balance", "ref": null, "tax": null, "l": "Fournisseur TTC"}]'::jsonb),
    ('REGL_CLIENT', 'Règlement client par banque', 'bank', 'Banque encaissée, client soldé', '[{"a": "521", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Banque"}, {"a": "4111", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Client"}]'::jsonb),
    ('REGL_FOURNISSEUR', 'Règlement fournisseur par banque', 'bank', 'Fournisseur soldé, banque décaissée', '[{"a": "4011", "tp": true, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Fournisseur"}, {"a": "521", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Banque"}]'::jsonb),
    ('ENCAISSEMENT_CAISSE', 'Encaissement client en espèces', 'cash', 'Caisse encaissée, client soldé', '[{"a": "571", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Caisse"}, {"a": "4111", "tp": true, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Client"}]'::jsonb),
    ('PAIEMENT_CAISSE', 'Paiement fournisseur en espèces', 'cash', 'Fournisseur soldé, caisse décaissée', '[{"a": "4011", "tp": true, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Fournisseur"}, {"a": "571", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Caisse"}]'::jsonb),
    ('VERSEMENT_ESPECES', 'Versement d''espèces en banque', 'cash', 'Banque créditée, caisse déchargée', '[{"a": "521", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Banque"}, {"a": "571", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Caisse"}]'::jsonb),
    ('PAIEMENT_TVA', 'Paiement de la TVA due', 'bank', 'Reversement de la TVA due à l''État par banque', '[{"a": "4441", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "TVA due"}, {"a": "521", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Banque"}]'::jsonb),
    ('PAIEMENT_CNSS', 'Paiement des cotisations CNSS', 'bank', 'Reversement des cotisations sociales par banque', '[{"a": "4311", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Cotisations CNSS"}, {"a": "521", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Banque"}]'::jsonb),
    ('PAIEMENT_IRPP', 'Paiement de l''impôt sur salaires', 'bank', 'Reversement de l''impôt retenu sur salaires par banque', '[{"a": "4472", "tp": false, "s": "debit", "f": "input", "ref": null, "tax": null, "l": "Impôt sur salaires"}, {"a": "521", "tp": false, "s": "credit", "f": "balance", "ref": null, "tax": null, "l": "Banque"}]'::jsonb)
    ) as v(code, label, journal_type, description, lines)
  loop
    if exists (select 1 from public.entry_templates where cabinet_id = p_cabinet and entity_id is null and code = r.code) then continue; end if;
    insert into public.entry_templates (cabinet_id, code, label, journal_type, description)
    values (p_cabinet, r.code, r.label, r.journal_type::public.journal_type, r.description) returning id into t;
    n := 0;
    for l in select * from jsonb_array_elements(r.lines) loop
      n := n + 1;
      insert into public.entry_template_lines (template_id, line_no, account_code, uses_third_party, side, formula, ref_line_no, tax_rate_code, label)
      values (t, n, l->>'a', (l->>'tp')::boolean, (l->>'s')::public.posting_side, (l->>'f')::public.amount_formula,
              nullif(l->>'ref', '')::smallint, nullif(l->>'tax', ''), l->>'l');
    end loop;
  end loop;

  -- Q-013 : comptes absents du plan ou différents du journal de banque, dans les modèles fournis par défaut
  update public.entry_template_lines l set account_code = '422'
    from public.entry_templates t where t.id = l.template_id and t.cabinet_id = p_cabinet and t.entity_id is null
     and t.code = 'SALAIRES' and l.account_code = '4221';
  update public.entry_template_lines l set account_code = '521'
    from public.entry_templates t where t.id = l.template_id and t.cabinet_id = p_cabinet and t.entity_id is null
     and t.code in ('REGL_CLIENT_RET', 'FRAIS_BQ_TAF') and l.account_code = '5211';
end $$;
revoke execute on function public.seed_entry_template_library(uuid) from public, anon, authenticated;

create or replace function public.handle_new_cabinet()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.seed_default_roles(new.id);
  perform public.seed_default_referentials(new.id);
  perform public.seed_entry_template_library(new.id);
  return new;
end $$;

-- Cabinets existants (dont celui de la recette)
select public.seed_entry_template_library(id) from public.cabinets;
