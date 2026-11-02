// Orchestration de l'émission d'une facture normalisée, indépendante du réseau et de la base (dépendances injectées) :
// soumettre → recalculer et comparer les totaux → confirmer ou annuler → enregistrer le résultat.
// Flux de la spécification (intrants/emcf-dgi/04-specification-api.md §4) : une demande non finalisée expire après 2 minutes.
import {
  buildInvoiceRequest, compareTotals, EmcfError, type ExpectedTotals, type InvoiceRow, type InvoiceTotals, type LineRow,
  parseDgiDateTime, type PaymentRow, type SecurityElements,
} from "./emcf.ts";

/** Ce dont le flux a besoin du client DGI (EmcfClient le satisfait ; les tests fournissent un faux). */
export interface DgiPort {
  submit(request: Record<string, unknown>): Promise<InvoiceTotals & { uid: string }>;
  finalize(uid: string, action: "confirm" | "cancel"): Promise<SecurityElements>;
}
/** Ce dont le flux a besoin de la base (fonctions réservées à la clé de service). */
export interface StorePort {
  markPending(uid: string, response: InvoiceTotals): Promise<void>;
  markConfirmed(security: Record<string, unknown>): Promise<void>;
  markCancelled(reason: string): Promise<void>;
  revertToDraft(reason: string): Promise<void>;
}

export type IssueOutcome =
  | { state: "confirmed"; security: SecurityElements }
  | { state: "draft"; reason: string; gaps?: string[] }       // refus, divergence ou expiration : la facture redevient modifiable
  | { state: "pending"; uid: string; reason: string };        // coupure réseau avant confirmation : à reprendre

/** Convertit les éléments de sécurité de la DGI en charge enregistrée par la base (avec l'horodatage ISO). */
export function securityPayload(sec: SecurityElements, now: () => Date = () => new Date()): Record<string, unknown> {
  const issuedAt = parseDgiDateTime(sec.dateTime) ?? now().toISOString();
  return { ...sec, issuedAt };
}

export async function runIssue(
  invoice: InvoiceRow, lines: LineRow[], payments: PaymentRow[], expected: ExpectedTotals,
  dgi: DgiPort, store: StorePort,
): Promise<IssueOutcome> {
  // 1. Soumission : la DGI calcule les totaux.
  let totals: InvoiceTotals & { uid: string };
  try {
    totals = await dgi.submit(buildInvoiceRequest(invoice, lines, payments));
  } catch (e) {
    const reason = (e as Error).message;
    await store.revertToDraft(reason);
    return { state: "draft", reason };
  }

  // 2. Le SFE recalcule et compare avant de confirmer.
  const gaps = compareTotals(expected, totals);
  if (gaps.length > 0) {
    const reason = "Les totaux de la DGI diffèrent du calcul d'Akonta : la demande a été annulée.";
    try { await dgi.finalize(totals.uid, "cancel"); } catch { /* la demande expirera d'elle-même après 2 minutes */ }
    await store.revertToDraft(`${reason} ${gaps.join(" ; ")}`);
    return { state: "draft", reason, gaps };
  }

  // 3. La facture est « en cours » localement avant la confirmation (la demande existe chez la DGI).
  try {
    await store.markPending(totals.uid, totals);
  } catch (e) {
    try { await dgi.finalize(totals.uid, "cancel"); } catch { /* expiration automatique */ }
    throw e;
  }

  // 4. Confirmation : c'est ici que la facture devient normalisée.
  return await confirmPending(totals.uid, dgi, store);
}

/** Confirme une demande déjà soumise (aussi utilisé pour reprendre après une coupure réseau). */
export async function confirmPending(uid: string, dgi: DgiPort, store: StorePort): Promise<IssueOutcome> {
  try {
    const security = await dgi.finalize(uid, "confirm");
    if (!security.codeMECeFDGI || !security.qrCode) {
      throw new EmcfError("La DGI n'a pas renvoyé le code MECeF/DGI ni le QR code.");
    }
    await store.markConfirmed(securityPayload(security));
    return { state: "confirmed", security };
  } catch (e) {
    if (e instanceof EmcfError && e.network) {
      return { state: "pending", uid, reason: `${e.message} La facture reste en cours : reprenez-la dans les deux minutes.` };
    }
    // Refus (par exemple code 20 : expirée) ou réponse incomplète : retour en brouillon.
    const reason = (e as Error).message;
    await store.revertToDraft(reason);
    return { state: "draft", reason };
  }
}

/** Annule une demande en cours : la DGI l'enregistre comme annulée, sans code MECeF/DGI. */
export async function cancelPending(uid: string, dgi: DgiPort, store: StorePort): Promise<IssueOutcome> {
  try {
    await dgi.finalize(uid, "cancel");
  } catch (e) {
    if (e instanceof EmcfError && e.network) {
      return { state: "pending", uid, reason: `${e.message} La demande n'a pas pu être annulée ; réessayez.` };
    }
    // Code 20 : déjà expirée ou finalisée chez la DGI ; l'annulation locale est alors sans risque pour une demande expirée.
  }
  await store.markCancelled("Annulée avant confirmation.");
  return { state: "draft", reason: "Annulée avant confirmation." };
}

/** Sort de la génération de l'écriture comptable après une émission réussie : n'altère jamais l'émission (la facture est normalisée quoi qu'il arrive). */
export type EntryOutcome =
  | { state: "generated"; entry_id: string }
  | { state: "skipped"; message: string }
  | { state: "failed"; message: string };

export function entryOutcome(isTest: boolean, result: { data: unknown; error: { message: string } | null }): EntryOutcome {
  if (isTest) return { state: "skipped", message: "Facture de test : aucune écriture comptable." };
  if (result.error) return { state: "failed", message: result.error.message };
  if (!result.data) return { state: "failed", message: "Aucune écriture n'a été générée." };
  return { state: "generated", entry_id: String(result.data) };
}
