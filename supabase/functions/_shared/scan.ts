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
}

export interface ScanDocument { id: string; entity_id: string; storage_path: string; mime_type: string; file_name: string }
export interface ProposalLine { account_id: string; third_party_id?: string | null; debit?: number; credit?: number; label: string }
export interface Proposal { date: string; label: string; reference: string | null; journal_type: "purchases"; lines: ProposalLine[] }

/** Erreur portant le statut HTTP à renvoyer, et les champs déjà lus pour préremplir la saisie manuelle. */
export class ScanError extends Error {
  constructor(message: string, readonly status: number, readonly extracted?: Extracted) { super(message); }
}

export interface ScanPorts {
  loadDocument(id: string): Promise<ScanDocument | null>;
  existingEntry(documentId: string): Promise<string | null>;
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

export async function runScan(documentId: string, ports: ScanPorts): Promise<ScanOutcome> {
  const doc = await ports.loadDocument(documentId);
  if (!doc) throw new ScanError("Pièce inaccessible", 403);

  const existing = await ports.existingEntry(documentId);
  if (existing) return { entry_id: existing, existing: true, warnings: [] };

  const extracted = await ports.extract(await ports.download(doc.storage_path), doc.mime_type);
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
