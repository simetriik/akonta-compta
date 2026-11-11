import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { buildProposal, type Extracted, runScan, ScanError, type ScanPorts } from "./scan.ts";

const base: Extracted = {
  supplier: "Cimenterie du Golfe", document_date: "2027-01-03", reference: "FA-FCG-0215", currency: "FCFA",
  amount_excl_tax: 4200000, vat_amount: 756000, total: 4956000, exchange_rate: null, counter_value: null, tax_id: null,
  consistent: true, method: "pdf-text",
};
const ids = { thirdParty: "t1", supplierAccount: "a401", expenseAccount: "a601", vatAccount: "a445" };

Deno.test("achat avec TVA : charge HT, TVA récupérable, fournisseur TTC", () => {
  const { proposal, warnings } = buildProposal(base, ids);
  assertEquals(proposal.lines.map((l) => [l.account_id, l.debit ?? 0, l.credit ?? 0]), [["a601", 4200000, 0], ["a445", 756000, 0], ["a401", 0, 4956000]]);
  assertEquals(proposal.lines[2].third_party_id, "t1");
  assertEquals(proposal.label, "Cimenterie du Golfe FA-FCG-0215");
  assertEquals(warnings, []);
});

Deno.test("sans ventilation TVA : tout en charge, équilibré", () => {
  const { proposal } = buildProposal({ ...base, amount_excl_tax: null, vat_amount: null }, ids);
  assertEquals(proposal.lines.length, 2);
  assertEquals(proposal.lines[0].debit, 4956000);
});

Deno.test("HT + TVA ne bouclent pas : tout en charge et avertissement", () => {
  const { proposal, warnings } = buildProposal({ ...base, total: 5000000, consistent: false }, ids);
  assertEquals(proposal.lines.length, 2);
  assertEquals(proposal.lines[0].debit, 5000000);
  assertEquals(warnings.length >= 2, true);
});

Deno.test("pièce en devise : contre-valeur en FCFA, sans TVA", () => {
  const { proposal } = buildProposal({ ...base, currency: "EUR", total: 3000, counter_value: 1967871, amount_excl_tax: null, vat_amount: null }, ids);
  assertEquals(proposal.lines[1].credit, 1967871);
});

Deno.test("devise sans contre-valeur, ou date illisible : refus 422 avec les champs lus", () => {
  for (const x of [{ ...base, currency: "USD", counter_value: null }, { ...base, document_date: null }, { ...base, total: null }]) {
    try { buildProposal(x, ids); throw new Error("attendu : refus"); } catch (e) {
      assertEquals(e instanceof ScanError && e.status === 422 && e.extracted !== undefined, true);
    }
  }
});

function fakePorts(over: Partial<ScanPorts> = {}): ScanPorts & { generated: unknown[] } {
  const generated: unknown[] = [];
  return {
    generated,
    loadDocument: () => Promise.resolve({ id: "d1", entity_id: "e1", storage_path: "p", mime_type: "application/pdf", file_name: "f.pdf" }),
    existingEntry: () => Promise.resolve(null),
    download: () => Promise.resolve(new Uint8Array([1])),
    extract: () => Promise.resolve(base),
    findThirdParty: () => Promise.resolve("t1"),
    accountIdByCode: (_e, code) => Promise.resolve(code === "4711" ? "a471" : `a${code}`),
    suggestExpenseAccount: () => Promise.resolve("a601"),
    generate: (_d, proposal) => { generated.push(proposal); return Promise.resolve("entry1"); },
    ...over,
  };
}

Deno.test("runScan : génère le brouillard avec le compte de charge suggéré", async () => {
  const ports = fakePorts();
  const out = await runScan("d1", ports);
  assertEquals([out.entry_id, out.existing, out.warnings], ["entry1", false, []]);
  assertEquals(ports.generated.length, 1);
});

Deno.test("runScan : sans suggestion, charge au compte d'attente 4711 avec avertissement", async () => {
  const ports = fakePorts({ suggestExpenseAccount: () => Promise.resolve(null) });
  const out = await runScan("d1", ports);
  assertEquals((ports.generated[0] as { lines: { account_id: string }[] }).lines[0].account_id, "a471");
  assertEquals(out.warnings.some((w) => w.includes("4711")), true);
});

Deno.test("runScan : pièce déjà proposée, aucune lecture ni écriture", async () => {
  let extracted = false;
  const ports = fakePorts({ existingEntry: () => Promise.resolve("old"), extract: () => { extracted = true; return Promise.resolve(base); } });
  const out = await runScan("d1", ports);
  assertEquals([out.entry_id, out.existing, extracted, ports.generated.length], ["old", true, false, 0]);
});

Deno.test("runScan : pièce inaccessible et plan sans compte fournisseur", async () => {
  await assertRejects(() => runScan("d1", fakePorts({ loadDocument: () => Promise.resolve(null) })), ScanError, "inaccessible");
  await assertRejects(() => runScan("d1", fakePorts({ accountIdByCode: (_e, c) => Promise.resolve(c === "4011" ? null : "x") })), ScanError, "4011");
});
