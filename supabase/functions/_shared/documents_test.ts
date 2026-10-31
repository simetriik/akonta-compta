import { assertEquals } from "jsr:@std/assert@1";
import { buildPayload, servicePath, validateRequest } from "./documents.ts";

Deno.test("validation des demandes d'export", () => {
  assertEquals(validateRequest({}), "entity_id requis");
  assertEquals(validateRequest({ entity_id: "e", kind: "journal", format: "pdf", from: "2026-01-01", to: "2026-01-31" }), "journal_id requis pour un livre-journal ou un rapprochement");
  assertEquals(validateRequest({ entity_id: "e", kind: "aged_balance", format: "xlsx", from: "2026-01-01", to: "2026-01-31" }), "format xlsx indisponible pour aged_balance");
  assertEquals(validateRequest({ entity_id: "e", kind: "trial_balance", format: "xlsx", from: "2026-01-01", to: "2026-12-31" }), null);
});

Deno.test("routes du service", () => {
  assertEquals(servicePath("trial_balance", "pdf"), { path: "/pdf/trial-balance", filename: "balance.pdf" });
  assertEquals(servicePath("general_ledger", "xlsx"), { path: "/excel/general-ledger", filename: "grand-livre.xlsx" });
});

Deno.test("charge utile d'une balance", () => {
  const p = buildPayload(
    { entity_id: "e", kind: "trial_balance", format: "pdf", from: "2026-01-01", to: "2026-12-31" },
    { cabinet_name: "ABC", entity_name: "SARL Démo", entity_tax_id: null, fiscal_year_label: "2026", generated_by: "Awa" },
    [{ account_code: "4111000", account_label: "Clients", closing_debit: 10 }],
  ) as { header: { title: string }; rows: unknown[] };
  assertEquals(p.header.title, "Balance générale");
  assertEquals(p.rows.length, 1);
});

Deno.test("rapprochement : journal requis, PDF seulement", () => {
  assertEquals(validateRequest({ entity_id: "e", kind: "reconciliation", format: "pdf", from: "2026-01-01", to: "2026-01-31" }), "journal_id requis pour un livre-journal ou un rapprochement");
  assertEquals(validateRequest({ entity_id: "e", kind: "reconciliation", format: "xlsx", from: "2026-01-01", to: "2026-01-31", journal_id: "j" }), "format xlsx indisponible pour reconciliation");
  assertEquals(servicePath("reconciliation", "pdf"), { path: "/pdf/reconciliation", filename: "rapprochement.pdf" });
});

Deno.test("liasse DGI : xlsm uniquement, charge utile = cellules", () => {
  assertEquals(servicePath("dgi", "xlsm"), { path: "/excel/dgi", filename: "etats-financiers-dgi.xlsm" });
  assertEquals(servicePath("dgi", "pdf"), null);
  const p = buildPayload({ entity_id: "e", kind: "dgi", format: "xlsm", from: "2026-01-01", to: "2026-12-31" },
    { cabinet_name: "", entity_name: "", entity_tax_id: null, fiscal_year_label: "2026", generated_by: null },
    [{ sheet: "BILAN", cell: "F12", value: 10 }]) as { cells: unknown[] };
  assertEquals(p.cells.length, 1);
});

Deno.test("états financiers : modèle SYSCOHADA ou SYCEBNL selon le référentiel, PDF seulement", () => {
  assertEquals(servicePath("financial_statements", "pdf"), { path: "/pdf/financial-statements", filename: "etats-financiers.pdf" });
  assertEquals(servicePath("financial_statements", "pdf", "normal"), { path: "/pdf/financial-statements", filename: "etats-financiers.pdf" });
  assertEquals(servicePath("financial_statements", "pdf", "sycebnl"), { path: "/pdf/financial-statements-sycebnl", filename: "etats-financiers-sycebnl.pdf" });
  assertEquals(servicePath("financial_statements", "xlsx", "sycebnl"), null);
  assertEquals(servicePath("trial_balance", "pdf", "sycebnl"), { path: "/pdf/trial-balance", filename: "balance.pdf" });
});

Deno.test("charge utile des états financiers : titre selon le référentiel", () => {
  const request = { entity_id: "e", kind: "financial_statements" as const, format: "pdf" as const, from: "2026-01-01", to: "2026-12-31" };
  const base = { cabinet_name: "ABC", entity_name: "Association Espoir", entity_tax_id: null, fiscal_year_label: "2026", generated_by: "Awa" };
  const sycebnl = buildPayload(request, { ...base, accounting_system: "sycebnl" }, [], { notes: [], has_previous: false }) as { header: { title: string }; has_previous: boolean };
  assertEquals(sycebnl.header.title, "États financiers SYCEBNL");
  assertEquals(sycebnl.has_previous, false);
  const normal = buildPayload(request, base, [], {}) as { header: { title: string } };
  assertEquals(normal.header.title, "États financiers SYSCOHADA");
});

