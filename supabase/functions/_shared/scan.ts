// Saisie par scan de pièce : orchestration indépendante du réseau et de la base (dépendances injectées).
// Lire la pièce (service d'extraction) → rapprocher le tiers → proposer les comptes → demander à la base le brouillard.
// La proposition est toujours prudente : à défaut de compte de charge connu, la charge va au compte d'attente 4711,
// que le comptable reclasse et que le contrôle de clôture signale tant qu'il n'est pas soldé.

/** Champs lus par `POST /extract/document` du service de documents. Tout champ non trouvé vaut null. */
export interface Extracted {
  supplier: string | null;
  document_date: string | null; // AAAA-MM-JJ
  reference: string | null;
  currency: string | null;
  amount_excl_tax: number | null;
  vat_amount: number | null;
  total: number | null;
  exchange_rate: number | null;
  counter_value: number | null;
  tax_id: string | null;
  consistent: boolean | null;
  method: string | null;
  /** Texte lu sur la pièce, utilisé pour reconnaître son genre (paie, avis bancaire…). */
  raw_text?: string | null;
}

export interface ScanDocument { id: string; entity_id: string; storage_path: string; mime_type: string; file_name: string }
/** Identité du dossier : sert à reconnaître une facture émise par le dossier lui-même (vente). */
export interface EntityIdentity { name: string; tax_id: string | null }
export interface ProposalLine { account_id: string; third_party_id?: string | null; debit?: number; credit?: number; label: string }
export interface Proposal { date: string; label: string; reference: string | null; journal_type: "purchases"; lines: ProposalLine[] }

/** Erreur portant le statut HTTP à renvoyer, et les champs déjà lus pour préremplir la saisie manuelle. */
export class ScanError extends Error {
  constructor(message: string, readonly status: number, readonly extracted?: Extracted) { super(message); }
}

export interface ScanPorts {
  loadDocument(id: string): Promise<ScanDocument | null>;
  existingEntry(documentId: string): Promise<string | null>;
  /** Écriture déjà liée à une autre pièce de même empreinte (même fichier déposé deux fois). */
  duplicateEntry(documentId: string): Promise<string | null>;
  entityIdentity(entityId: string): Promise<EntityIdentity>;
  download(path: string): Promise<Uint8Array>;
  extract(bytes: Uint8Array, mimeType: string): Promise<Extracted>;
  findThirdParty(entityId: string, taxId: string | null, name: string | null): Promise<string | null>;
  accountIdByCode(entityId: string, code: string): Promise<string | null>;
  suggestExpenseAccount(entityId: string, label: string, thirdPartyId: string | null): Promise<string | null>;
  generate(documentId: string, proposal: Proposal): Promise<string>;
}

export interface ScanOutcome { entry_id: string; existing: boolean; extracted?: Extracted; warnings: string[] }

/** Montant en FCFA entier : la contre-valeur pour une pièce en devise, sinon le montant lu. */
function fcfaAmounts(x: Extracted): { ht: number | null; vat: number; total: number } | null {
  const foreign = x.currency !== null && x.currency !== "FCFA";
  if (foreign) {
    if (x.counter_value === null) return null;
    return { ht: null, vat: 0, total: Math.round(x.counter_value) };
  }
  if (x.total === null) return null;
  const total = Math.round(x.total);
  const vat = Math.round(x.vat_amount ?? 0);
  const ht = x.amount_excl_tax === null ? null : Math.round(x.amount_excl_tax);
  return { ht, vat, total };
}

/** Construit la proposition d'écriture d'achat : charge (HT) + TVA récupérable au débit, fournisseur (TTC) au crédit. */
export function buildProposal(
  x: Extracted,
  ids: { thirdParty: string | null; supplierAccount: string; expenseAccount: string; vatAccount: string | null },
): { proposal: Proposal; warnings: string[] } {
  const warnings: string[] = [];
  const amounts = fcfaAmounts(x);
  if (!x.document_date) throw new ScanError("Date illisible : saisissez l'écriture à la main.", 422, x);
  if (!amounts) throw new ScanError(x.currency && x.currency !== "FCFA"
    ? `Pièce en ${x.currency} sans contre-valeur en FCFA : saisissez l'écriture à la main.`
    : "Montant total illisible : saisissez l'écriture à la main.", 422, x);

  // HT et TVA fiables seulement s'ils bouclent sur le total ; sinon tout le total va à la charge, sans TVA séparée.
  let expense = amounts.total;
  let vat = 0;
  if (amounts.ht !== null && amounts.vat > 0 && amounts.ht + amounts.vat === amounts.total && ids.vatAccount) {
    expense = amounts.ht;
    vat = amounts.vat;
  } else if (amounts.vat > 0) {
    warnings.push("HT et TVA ne bouclent pas sur le total : tout le montant est en charge, à ventiler.");
  }
  const supplier = x.supplier ?? "Fournisseur";
  const lines: ProposalLine[] = [{ account_id: ids.expenseAccount, debit: expense, label: supplier }];
  if (vat > 0 && ids.vatAccount) lines.push({ account_id: ids.vatAccount, debit: vat, label: "TVA récupérable" });
  lines.push({ account_id: ids.supplierAccount, third_party_id: ids.thirdParty, credit: amounts.total, label: supplier });
  if (!ids.thirdParty) warnings.push("Fournisseur non retrouvé dans les tiers : à choisir avant la validation.");
  if (x.consistent === false) warnings.push("Les montants lus sont incohérents : à vérifier sur la pièce.");
  return {
    proposal: { date: x.document_date, label: [supplier, x.reference].filter(Boolean).join(" ").slice(0, 120), reference: x.reference, journal_type: "purchases", lines },
    warnings,
  };
}

const normalize = (s: string) => s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();

/**
 * Reconnaît ce que la pièce n'est pas : une facture d'achat. Le scan ne propose une écriture d'achat que pour un achat ;
 * une vente du dossier, une paie ou un avis bancaire se saisissent autrement (vente, paie, relevé). Renvoie le motif du refus, sinon null.
 */
export function notAPurchase(x: Extracted, entity: EntityIdentity): string | null {
  const supplier = normalize(x.supplier ?? "");
  const own = normalize(entity.name);
  if ((x.tax_id && entity.tax_id && x.tax_id === entity.tax_id) || (supplier.length >= 3 && own.length >= 3 && (supplier.includes(own) || own.includes(supplier)))) {
    return "Cette pièce est émise par le dossier lui-même (facture de vente) : saisissez-la en vente, le scan ne propose que des achats.";
  }
  const text = normalize(`${x.raw_text ?? ""} ${x.reference ?? ""}`);
  if (/\b(bulletin de paie|fiche de paie|salaires?|paie)\b/.test(text)) {
    return "Cette pièce est une paie, pas une facture d'achat : saisissez-la dans le journal de paie.";
  }
  if (/\b(avis de (debit|credit|virement)|avis de prelevement|bordereau de (retenue|versement|remise)|releve (de compte|bancaire)|retenue a la source)\b/.test(text)) {
    return "Cette pièce est un avis ou un bordereau bancaire, pas une facture d'achat : créez l'écriture depuis le rapprochement bancaire.";
  }
  return null;
}

export async function runScan(documentId: string, ports: ScanPorts): Promise<ScanOutcome> {
  const doc = await ports.loadDocument(documentId);
  if (!doc) throw new ScanError("Pièce inaccessible", 403);

  const existing = await ports.existingEntry(documentId);
  if (existing) return { entry_id: existing, existing: true, warnings: [] };

  // Même fichier déjà traité : on renvoie son écriture au lieu d'en créer une seconde (AN-34).
  const duplicate = await ports.duplicateEntry(documentId);
  if (duplicate) return { entry_id: duplicate, existing: true, warnings: ["Cette pièce est identique à une pièce déjà traitée : aucun second brouillard n'a été créé."] };

  const extracted = await ports.extract(await ports.download(doc.storage_path), doc.mime_type);
  const refusal = notAPurchase(extracted, await ports.entityIdentity(doc.entity_id));
  if (refusal) throw new ScanError(refusal, 422, extracted);
  const thirdParty = await ports.findThirdParty(doc.entity_id, extracted.tax_id, extracted.supplier);
  const supplierAccount = await ports.accountIdByCode(doc.entity_id, "4011");
  const vatAccount = await ports.accountIdByCode(doc.entity_id, "4452");
  if (!supplierAccount) throw new ScanError("Compte fournisseurs (4011) introuvable dans le plan du dossier", 422, extracted);
  const suggested = extracted.supplier ? await ports.suggestExpenseAccount(doc.entity_id, extracted.supplier, thirdParty) : null;
  const expenseAccount = suggested ?? await ports.accountIdByCode(doc.entity_id, "4711");
  if (!expenseAccount) throw new ScanError("Compte d'attente (4711) introuvable dans le plan du dossier", 422, extracted);

  const { proposal, warnings } = buildProposal(extracted, { thirdParty, supplierAccount, expenseAccount, vatAccount });
  if (!suggested) warnings.push("Compte de charge inconnu pour ce fournisseur : imputé au compte d'attente 4711, à reclasser.");
  const entryId = await ports.generate(documentId, proposal);
  return { entry_id: entryId, existing: false, extracted, warnings };
}
