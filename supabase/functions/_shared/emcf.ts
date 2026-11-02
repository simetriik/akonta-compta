// Client de l'API e-MCF de la DGI du Bénin (facturation normalisée) et règles pures associées.
// Référence : intrants/emcf-dgi/04-specification-api.md (spécification 1.0 du 15/01/2021) et l'OpenAPI.
// Périmètre déclaré : factures de vente (FV) et d'avoir (FA), groupes de taxe A et B, AIB 1 % (A) et 5 % (B).

export type EmcfMode = "test" | "production";
export type InvoiceType = "FV" | "FA";
export type TaxGroup = "A" | "B";

export interface InvoiceRow {
  type: InvoiceType;
  seller_ifu: string;
  aib: "A" | "B" | null;
  client_ifu: string | null;
  client_name: string | null;
  client_contact: string | null;
  client_address: string | null;
  operator_name: string;
  reference: string | null;
}
export interface LineRow {
  code: string | null;
  name: string;
  price: number;
  quantity: number | string;
  tax_group: TaxGroup;
  original_price: number | null;
  price_modification: string | null;
}
export interface PaymentRow { name: string; amount: number }

/** Totaux renvoyés par la demande de facture (InvoiceResponseDataDto). */
export interface InvoiceTotals {
  uid?: string | null;
  ta?: number; tb?: number;
  taa?: number; tab?: number;
  hab?: number; vab?: number;
  aib?: number; ts?: number; total?: number;
  errorCode?: string | null; errorDesc?: string | null;
}
/** Éléments de sécurité renvoyés par la finalisation (SecurityElementsDto). */
export interface SecurityElements {
  dateTime?: string | null; qrCode?: string | null; codeMECeFDGI?: string | null;
  counters?: string | null; nim?: string | null;
  errorCode?: string | null; errorDesc?: string | null;
}
/** Totaux de contrôle calculés par la base (invoice_expected_totals). */
export interface ExpectedTotals { taa: number; tab: number; hab: number; vab: number; total: number }

/** Adresse de base de l'API selon l'environnement. EMCF_TEST_URL permet de pointer vers un faux serveur en développement. */
export function baseUrl(mode: EmcfMode, env: { get(name: string): string | undefined } = Deno.env): string {
  if (mode === "production") return env.get("EMCF_PRODUCTION_URL") ?? "https://sygmef.impots.bj/emcf";
  return env.get("EMCF_TEST_URL") ?? "https://developper.impots.bj/sygmef-emcf";
}

/** Messages en français des codes d'erreur de l'annexe de la spécification. */
const ERROR_MESSAGES: Record<string, string> = {
  "1": "Trop de factures sont en attente de finalisation chez la DGI (maximum 10). Réessayez dans deux minutes.",
  "3": "Type de facture non valide.",
  "4": "La référence de la facture d'origine est manquante.",
  "5": "La référence de la facture d'origine doit comporter 24 caractères.",
  "6": "La valeur de l'AIB n'est pas valide.",
  "7": "Le type de paiement n'est pas valide.",
  "8": "La facture doit contenir au moins un article.",
  "9": "Le groupe de taxation d'un article n'est pas valide.",
  "10": "La référence de la facture d'origine ne peut pas être vérifiée pour le moment ; réessayez plus tard.",
  "11": "La facture d'origine est introuvable chez la DGI.",
  "12": "Le montant de l'avoir dépasse celui de la facture d'origine.",
  "20": "La demande n'existe pas ou elle est déjà finalisée, annulée ou expirée.",
  "99": "La DGI n'a pas pu traiter la demande. Réessayez.",
};
export function emcfErrorMessage(code: string | null | undefined, description?: string | null): string {
  const known = code ? ERROR_MESSAGES[String(code)] : undefined;
  if (known) return known;
  return description ? `Refus de la DGI (code ${code ?? "?"}) : ${description}` : `Refus de la DGI (code ${code ?? "?"}).`;
}

/** Corps de la demande de facture. Les champs facultatifs vides sont omis ; le paiement par défaut (ESPECES) est laissé à la DGI. */
export function buildInvoiceRequest(inv: InvoiceRow, lines: LineRow[], payments: PaymentRow[]): Record<string, unknown> {
  const body: Record<string, unknown> = {
    ifu: inv.seller_ifu,
    type: inv.type,
    items: lines.map((l) => {
      const item: Record<string, unknown> = { name: l.name, price: Number(l.price), quantity: Number(l.quantity), taxGroup: l.tax_group };
      if (l.code) item.code = l.code;
      if (l.original_price != null) item.originalPrice = Number(l.original_price);
      if (l.price_modification) item.priceModification = l.price_modification;
      return item;
    }),
    operator: { name: inv.operator_name },
  };
  if (inv.aib) body.aib = inv.aib;
  const client: Record<string, string> = {};
  if (inv.client_ifu) client.ifu = inv.client_ifu;
  if (inv.client_name) client.name = inv.client_name;
  if (inv.client_contact) client.contact = inv.client_contact;
  if (inv.client_address) client.address = inv.client_address;
  if (Object.keys(client).length > 0) body.client = client;
  if (payments.length > 0) body.payment = payments.map((p) => ({ name: p.name, amount: Number(p.amount) }));
  if (inv.type === "FA" && inv.reference) body.reference = inv.reference;
  return body;
}

/**
 * Le SFE doit recalculer les totaux et les comparer à ceux de la DGI avant de confirmer (spécification, flux étape 3).
 * Renvoie la liste des écarts (vide si tout concorde). L'AIB n'est pas comparé : sa base de calcul n'est pas documentée.
 */
export function compareTotals(expected: ExpectedTotals, dgi: InvoiceTotals): string[] {
  const gaps: string[] = [];
  const check = (label: string, ours: number, theirs: number | undefined) => {
    if (theirs === undefined || Number(theirs) !== Number(ours)) gaps.push(`${label} : calculé ${ours}, DGI ${theirs ?? "absent"}`);
  };
  check("Total groupe A", expected.taa, dgi.taa);
  check("Total groupe B", expected.tab, dgi.tab);
  check("HT groupe B", expected.hab, dgi.hab);
  check("TVA groupe B", expected.vab, dgi.vab);
  check("Total", expected.total, dgi.total);
  return gaps;
}

/** « 21/11/2020 14:44:23 » (heure du Bénin, UTC+1) vers un horodatage ISO ; null si le format n'est pas reconnu. */
export function parseDgiDateTime(value: string | null | undefined): string | null {
  const m = /^(\d{2})\/(\d{2})\/(\d{4}) (\d{2}):(\d{2}):(\d{2})$/.exec(value ?? "");
  if (!m) return null;
  return `${m[3]}-${m[2]}-${m[1]}T${m[4]}:${m[5]}:${m[6]}+01:00`;
}

export class EmcfError extends Error {
  constructor(message: string, readonly code: string | null = null, readonly httpStatus: number | null = null, readonly network = false) {
    super(message);
  }
}

/** Appels HTTP vers l'e-MCF avec le jeton d'un point de vente. */
export class EmcfClient {
  constructor(private readonly root: string, private readonly token: string, private readonly timeoutMs = 20000) {}

  private async call<T>(method: string, path: string, body?: unknown): Promise<T> {
    let res: Response;
    try {
      res = await fetch(`${this.root}${path}`, {
        method,
        headers: { "content-type": "application/json", accept: "application/json", authorization: `Bearer ${this.token}` },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (e) {
      throw new EmcfError(`Le serveur e-MECeF est injoignable : ${(e as Error).message}`, null, null, true);
    }
    if (res.status === 401) throw new EmcfError("Jeton refusé ou expiré : demandez un nouveau jeton à la DGI.", null, 401);
    const text = await res.text();
    let parsed: unknown = null;
    try { parsed = text ? JSON.parse(text) : null; } catch { /* corps non JSON */ }
    if (!res.ok) throw new EmcfError(`Réponse inattendue de la DGI (HTTP ${res.status}).`, null, res.status);
    return parsed as T;
  }

  /** Disponibilité de l'API, validité du jeton et demandes en attente. */
  status(): Promise<Record<string, unknown>> { return this.call("GET", "/api/invoice"); }
  /** Liste des e-MCF rattachés au jeton. */
  info(): Promise<Record<string, unknown>> { return this.call("GET", "/api/info/status"); }

  /** Soumet la facture ; en cas de refus (errorCode), lève EmcfError avec un message français. */
  async submit(request: Record<string, unknown>): Promise<InvoiceTotals & { uid: string }> {
    const res = await this.call<InvoiceTotals>("POST", "/api/invoice", request);
    if (!res || res.errorCode || !res.uid) throw new EmcfError(emcfErrorMessage(res?.errorCode, res?.errorDesc), res?.errorCode ?? null);
    return res as InvoiceTotals & { uid: string };
  }

  /** Confirme (`confirm`) ou annule (`cancel`) la demande ; PUT, comme dans l'OpenAPI et l'exemple de la spécification. */
  async finalize(uid: string, action: "confirm" | "cancel"): Promise<SecurityElements> {
    const res = await this.call<SecurityElements>("PUT", `/api/invoice/${encodeURIComponent(uid)}/${action}`);
    if (!res || res.errorCode) throw new EmcfError(emcfErrorMessage(res?.errorCode, res?.errorDesc), res?.errorCode ?? null);
    return res;
  }

  /** Relit une demande en attente. */
  details(uid: string): Promise<Record<string, unknown>> { return this.call("GET", `/api/invoice/${encodeURIComponent(uid)}`); }
}
