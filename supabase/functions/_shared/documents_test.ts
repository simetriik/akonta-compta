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
