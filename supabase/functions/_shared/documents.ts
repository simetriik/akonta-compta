// Construction des charges utiles du service de documents à partir des résultats des fonctions SQL de consultation.

export type DocumentKind = "trial_balance" | "general_ledger" | "journal" | "aged_balance" | "reconciliation" | "financial_statements" | "dgi";
export type DocumentFormat = "pdf" | "xlsx" | "xlsm";

export interface ExportRequest {
  entity_id: string;
  kind: DocumentKind;
  format: DocumentFormat;
  from: string;      // AAAA-MM-JJ
  to: string;
  journal_id?: string;
  account_from?: string;
  account_to?: string;
  class?: number;
  side?: "debit" | "credit";
}

export interface HeaderInfo {
  cabinet_name: string;
  entity_name: string;
  entity_tax_id: string | null;
  fiscal_year_label: string;
  generated_by: string | null;
  /** Référentiel de l'entité : détermine le modèle des états financiers (`normal` par défaut). */
  accounting_system?: string;
}

const TITLES: Record<DocumentKind, string> = {
  trial_balance: "Balance générale",
  general_ledger: "Grand livre",
  journal: "Livre-journal",
  aged_balance: "Balance âgée",
  reconciliation: "État de rapprochement bancaire",
  financial_statements: "États financiers SYSCOHADA",
  dgi: "Liasse DGI",
};

/** Routes du service Python et nom de fichier par type et format ; les états financiers d'une entité SYCEBNL ont leur propre modèle (PDF seulement). */
export function servicePath(kind: DocumentKind, format: DocumentFormat, accountingSystem = "normal"): { path: string; filename: string } | null {
  const ext = format === "pdf" ? "pdf" : "xlsx";
  const prefix = format === "pdf" ? "/pdf" : "/excel";
  switch (kind) {
    case "trial_balance": return { path: `${prefix}/trial-balance`, filename: `balance.${ext}` };
    case "general_ledger": return { path: `${prefix}/general-ledger`, filename: `grand-livre.${ext}` };
    case "journal": return format === "pdf" ? { path: "/pdf/journal", filename: "journal.pdf" } : null;
    case "aged_balance": return format === "pdf" ? { path: "/pdf/aged-balance", filename: "balance-agee.pdf" } : null;
    case "reconciliation": return format === "pdf" ? { path: "/pdf/reconciliation", filename: "rapprochement.pdf" } : null;
    case "financial_statements":
      if (format !== "pdf") return null;
      return accountingSystem === "sycebnl"
        ? { path: "/pdf/financial-statements-sycebnl", filename: "etats-financiers-sycebnl.pdf" }
        : { path: "/pdf/financial-statements", filename: "etats-financiers.pdf" };
    case "dgi": return format === "xlsm" ? { path: "/excel/dgi", filename: "etats-financiers-dgi.xlsm" } : null;
  }
}

export function validateRequest(r: Partial<ExportRequest>): string | null {
  if (!r.entity_id) return "entity_id requis";
  if (!r.kind || !(r.kind in TITLES)) return "kind invalide";
  if (r.format !== "pdf" && r.format !== "xlsx" && r.format !== "xlsm") return "format invalide (pdf | xlsx | xlsm)";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(r.from ?? "") || !/^\d{4}-\d{2}-\d{2}$/.test(r.to ?? "")) return "from et to au format AAAA-MM-JJ";
  if ((r.kind === "journal" || r.kind === "reconciliation") && !r.journal_id) return "journal_id requis pour un livre-journal ou un rapprochement";
  if (!servicePath(r.kind, r.format)) return `format ${r.format} indisponible pour ${r.kind}`;
  return null;
}

export function buildPayload(r: ExportRequest, header: HeaderInfo, rows: Record<string, unknown>[], extra: Record<string, unknown> = {}): Record<string, unknown> {
  const base = {
    header: {
      cabinet_name: header.cabinet_name,
      entity_name: header.entity_name,
      entity_tax_id: header.entity_tax_id,
      fiscal_year_label: header.fiscal_year_label,
      period_from: r.from,
      period_to: r.to,
      title: r.kind === "financial_statements" && header.accounting_system === "sycebnl"
        ? "États financiers SYCEBNL"
        : TITLES[r.kind] + (r.kind === "aged_balance" ? (r.side === "credit" ? " fournisseurs" : " clients") : ""),
      generated_by: header.generated_by,
    },
  };
  switch (r.kind) {
    case "trial_balance":
    case "aged_balance":
      return { ...base, ...extra, rows };
    case "general_ledger":
      return { ...base, lines: rows.map((l) => ({ ...l, reference: l.reference ?? null, third_party_code: l.third_party_code ?? null, letter_code: l.letter_code ?? null })) };
    case "journal":
      return { ...base, ...extra, lines: rows };
    case "reconciliation":
    case "financial_statements":
      return { ...base, ...extra };
    case "dgi":
      return { template_version: "SN-2025", cells: rows };
  }
}

/** En-têtes de la réponse d'un export. Le type est toujours `application/octet-stream` : le client Supabase de l'application ne rend des
 *  octets que pour ce type, tout autre (application/pdf, Excel…) est lu comme du texte et échoue sur un fichier binaire. */
export function exportResponseHeaders(filename: string): Record<string, string> {
  return { "content-type": "application/octet-stream", "content-disposition": `attachment; filename="${filename}"` };
}
