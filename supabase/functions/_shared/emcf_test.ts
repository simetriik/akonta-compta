// Tests du client e-MCF et du flux d'émission contre un faux serveur qui reproduit la spécification de la DGI
// (prix TTC, TVA 18 % sur le groupe B, erreurs 8 et 20, 401 sans jeton). Aucun appel réel à la DGI.
import { assert, assertEquals, assertRejects, assertStringIncludes } from "jsr:@std/assert@1";
import {
  baseUrl, buildInvoiceRequest, compareTotals, EmcfClient, EmcfError, emcfErrorMessage, type InvoiceRow, type InvoiceTotals, type LineRow,
  parseDgiDateTime,
} from "./emcf.ts";
import { cancelPending, confirmPending, runIssue, type StorePort } from "./emcf_flow.ts";

const TOKEN = "jeton.de.test";

interface MockOptions { tamperTotal?: boolean; dropConfirm?: boolean }
/** Faux e-MCF : garde en mémoire les demandes en attente et applique les règles de la spécification. */
function startMock(options: MockOptions = {}) {
  const pending = new Map<string, number>();   // uid → total
  const log: string[] = [];
  let counter = 0;
  const server = Deno.serve({ port: 0, onListen: () => {} }, async (req) => {
    const url = new URL(req.url);
    log.push(`${req.method} ${url.pathname}`);
    if (req.headers.get("authorization") !== `Bearer ${TOKEN}`) return new Response("", { status: 401 });
    const reply = (body: unknown) => Response.json(body);
    if (req.method === "GET" && url.pathname === "/api/invoice") {
      return reply({ status: true, version: "1.0", ifu: "3201900000001", nim: "XX01000001", tokenValid: "2026-12-31T00:00:00+01:00", pendingRequestsCount: pending.size });
    }
    if (req.method === "POST" && url.pathname === "/api/invoice") {
      const b = await req.json() as { items?: { price: number; quantity: number; taxGroup: string }[]; type: string; reference?: string };
      if (!b.items || b.items.length === 0) return reply({ uid: null, errorCode: "8", errorDesc: "La facture doit contenu les articles" });
      if (b.type === "FA" && !b.reference) return reply({ uid: null, errorCode: "4", errorDesc: "La référence de la facture originale est manquante" });
      let taa = 0, tab = 0;
      for (const i of b.items) { const amount = Math.round(i.price * i.quantity); if (i.taxGroup === "B") tab += amount; else taa += amount; }
      const hab = Math.round(tab * 100 / 118);
      const total = taa + tab + (options.tamperTotal ? 1 : 0);
      const uid = `uid-${++counter}`;
      pending.set(uid, total);
      return reply({ uid, ta: 0, tb: 18, tc: 0, td: 18, taa, tab, tac: 0, tad: 0, tae: 0, taf: 0, hab, had: 0, vab: tab - hab, vad: 0, aib: 0, ts: 0, total });
    }
    const m = /^\/api\/invoice\/([^/]+)\/(confirm|cancel)$/.exec(url.pathname);
    if (req.method === "PUT" && m) {
      if (options.dropConfirm && m[2] === "confirm") { pending.delete(m[1]); return reply({ errorCode: "20", errorDesc: "expirée" }); }
      if (!pending.has(m[1])) return reply({ errorCode: "20", errorDesc: "La facture n'existe pas ou elle est déjà finalisée / annulée" });
      pending.delete(m[1]);
      if (m[2] === "cancel") return reply({ dateTime: "04/11/2026 13:17:08", qrCode: "", codeMECeFDGI: "", counters: "", nim: "XX01000001" });
      return reply({ dateTime: "04/11/2026 13:17:08", qrCode: "F;XX01000001;X537E4DBAJUUHHXNFWISFEKJ;3201900000001;20261104131708", codeMECeFDGI: "X537-E4DB-AJUU-HHXN-FWIS-FEKJ", counters: "1/1 FV", nim: "XX01000001" });
    }
    return new Response("", { status: 404 });
  });
  const addr = server.addr as Deno.NetAddr;
  return { root: `http://127.0.0.1:${addr.port}`, log, close: () => server.shutdown() };
}

const invoice: InvoiceRow = {
  type: "FV", seller_ifu: "3201900000001", aib: null, client_ifu: null, client_name: "Supermarché SARL", client_contact: null,
  client_address: null, operator_name: "Jacques", reference: null,
};
// Exemple de la spécification : 2 × 1 800 (groupe B) et 3 × 450 (groupe A).
const lines: LineRow[] = [
  { code: null, name: "Jus d'orange", price: 1800, quantity: 2, tax_group: "B", original_price: null, price_modification: null },
  { code: null, name: "Lait 1/1 EX", price: 450, quantity: 3, tax_group: "A", original_price: null, price_modification: null },
];
const expected = { taa: 1350, tab: 3600, hab: 3051, vab: 549, total: 4950 };

function fakeStore() {
  const calls: string[] = [];
  const store: StorePort = {
    markPending: (uid) => { calls.push(`pending:${uid}`); return Promise.resolve(); },
    markConfirmed: (s) => { calls.push(`confirmed:${(s as { codeMECeFDGI: string }).codeMECeFDGI}`); return Promise.resolve(); },
    markCancelled: (r) => { calls.push(`cancelled:${r}`); return Promise.resolve(); },
    revertToDraft: (r) => { calls.push(`draft:${r}`); return Promise.resolve(); },
  };
  return { store, calls };
}

Deno.test("adresses de l'API selon l'environnement", () => {
  const env = (m: Record<string, string>) => ({ get: (k: string) => m[k] });
  assertEquals(baseUrl("production", env({})), "https://sygmef.impots.bj/emcf");
  assertEquals(baseUrl("test", env({})), "https://developper.impots.bj/sygmef-emcf");
  assertEquals(baseUrl("test", env({ EMCF_TEST_URL: "http://localhost:9999" })), "http://localhost:9999");
});

Deno.test("demande de facture : champs facultatifs omis, avoir avec référence", () => {
  const body = buildInvoiceRequest(invoice, lines, []) as Record<string, unknown>;
  assertEquals(body.ifu, "3201900000001");
  assertEquals(body.type, "FV");
  assertEquals(body.client, { name: "Supermarché SARL" });
  assertEquals("payment" in body, false);
  assertEquals("aib" in body, false);
  assertEquals("reference" in body, false);
  const credit = buildInvoiceRequest({ ...invoice, type: "FA", aib: "B", reference: "X537E4DBAJUUHHXNFWISFEKJ" }, lines, [{ name: "MOBILEMONEY", amount: 4950 }]) as Record<string, unknown>;
  assertEquals(credit.reference, "X537E4DBAJUUHHXNFWISFEKJ");
  assertEquals(credit.aib, "B");
  assertEquals(credit.payment, [{ name: "MOBILEMONEY", amount: 4950 }]);
});

Deno.test("comparaison des totaux et date de la DGI", () => {
  assertEquals(compareTotals(expected, { taa: 1350, tab: 3600, hab: 3051, vab: 549, total: 4950 }), []);
  assertEquals(compareTotals(expected, { taa: 1350, tab: 3600, hab: 3051, vab: 549, total: 4951 }).length, 1);
  assertEquals(compareTotals(expected, {}).length, 5);
  assertEquals(parseDgiDateTime("21/11/2020 14:44:23"), "2020-11-21T14:44:23+01:00");
  assertEquals(parseDgiDateTime("n'importe quoi"), null);
});

Deno.test("messages d'erreur de la DGI en français", () => {
  assertStringIncludes(emcfErrorMessage("12"), "dépasse");
  assertStringIncludes(emcfErrorMessage("777", "inconnue"), "777");
});

Deno.test("client : exemple de la spécification, 401, erreurs 8 et 20", async () => {
  const mock = startMock();
  try {
    const client = new EmcfClient(mock.root, TOKEN);
    const st = await client.status();
    assertEquals(st.nim, "XX01000001");

    const totals = await client.submit(buildInvoiceRequest(invoice, lines, []));
    assertEquals([totals.taa, totals.tab, totals.hab, totals.vab, totals.total], [1350, 3600, 3051, 549, 4950]);

    const err = await assertRejects(() => client.submit(buildInvoiceRequest(invoice, [], [])), EmcfError);
    assertEquals(err.code, "8");
    assertStringIncludes(err.message, "au moins un article");

    await assertRejects(() => new EmcfClient(mock.root, "mauvais").status(), EmcfError, "Jeton refusé");
    const unknown = await assertRejects(() => client.finalize("inconnu", "confirm"), EmcfError);
    assertEquals(unknown.code, "20");
    const security = await client.finalize(totals.uid, "confirm");
    assertEquals(security.codeMECeFDGI, "X537-E4DB-AJUU-HHXN-FWIS-FEKJ");
  } finally { await mock.close(); }
});

Deno.test("client : serveur injoignable = erreur réseau", async () => {
  const mock = startMock();
  const root = mock.root;
  await mock.close();
  const e = await assertRejects(() => new EmcfClient(root, TOKEN, 2000).status(), EmcfError);
  assertEquals(e.network, true);
});

Deno.test("flux : émission réussie", async () => {
  const mock = startMock();
  try {
    const { store, calls } = fakeStore();
    const out = await runIssue(invoice, lines, [], expected, new EmcfClient(mock.root, TOKEN), store);
    assertEquals(out.state, "confirmed");
    assertEquals(calls, ["pending:uid-1", "confirmed:X537-E4DB-AJUU-HHXN-FWIS-FEKJ"]);
    assertEquals(mock.log.filter((l) => l.startsWith("PUT")), ["PUT /api/invoice/uid-1/confirm"]);
  } finally { await mock.close(); }
});

Deno.test("flux : totaux divergents = annulation chez la DGI et retour en brouillon", async () => {
  const mock = startMock({ tamperTotal: true });
  try {
    const { store, calls } = fakeStore();
    const out = await runIssue(invoice, lines, [], expected, new EmcfClient(mock.root, TOKEN), store);
    assertEquals(out.state, "draft");
    assert(out.state === "draft" && (out.gaps?.length ?? 0) === 1);
    assertEquals(mock.log.filter((l) => l.startsWith("PUT")), ["PUT /api/invoice/uid-1/cancel"]);
    assertEquals(calls.length, 1);
    assert(calls[0].startsWith("draft:"));
  } finally { await mock.close(); }
});

Deno.test("flux : refus de la DGI (aucun article) = brouillon avec le motif", async () => {
  const mock = startMock();
  try {
    const { store, calls } = fakeStore();
    const out = await runIssue(invoice, [], [], { ...expected, total: 0 }, new EmcfClient(mock.root, TOKEN), store);
    assertEquals(out.state, "draft");
    assertStringIncludes(calls[0], "au moins un article");
  } finally { await mock.close(); }
});

Deno.test("flux : demande expirée à la confirmation (code 20) = brouillon", async () => {
  const mock = startMock({ dropConfirm: true });
  try {
    const { store, calls } = fakeStore();
    const out = await runIssue(invoice, lines, [], expected, new EmcfClient(mock.root, TOKEN), store);
    assertEquals(out.state, "draft");
    assertEquals(calls[0], "pending:uid-1");
    assert(calls[1].startsWith("draft:"));
  } finally { await mock.close(); }
});

Deno.test("flux : coupure réseau à la confirmation = facture en cours, reprenable", async () => {
  const mock = startMock();
  const { store, calls } = fakeStore();
  // La coupure survient entre la soumission et la confirmation : le client bascule sur un port fermé après la soumission.
  const real = new EmcfClient(mock.root, TOKEN);
  const flaky = {
    submit: (r: Record<string, unknown>) => real.submit(r),
    finalize: () => Promise.reject(new EmcfError("Le serveur e-MECeF est injoignable : coupure", null, null, true)),
  };
  try {
    const out = await runIssue(invoice, lines, [], expected, flaky, store);
    assertEquals(out.state, "pending");
    assertEquals(calls, ["pending:uid-1"]);
    // Reprise dans les deux minutes : la confirmation aboutit.
    const resumed = await confirmPending("uid-1", real, store);
    assertEquals(resumed.state, "confirmed");
    assertEquals(calls[1], "confirmed:X537-E4DB-AJUU-HHXN-FWIS-FEKJ");
  } finally { await mock.close(); }
});

Deno.test("flux : annulation d'une demande en cours", async () => {
  const mock = startMock();
  try {
    const { store, calls } = fakeStore();
    const dgi = new EmcfClient(mock.root, TOKEN);
    const totals = await dgi.submit(buildInvoiceRequest(invoice, lines, []));
    const out = await cancelPending(totals.uid, dgi, store);
    assertEquals(out.state, "draft");
    assertEquals(calls.length, 1);
    assert(calls[0].startsWith("cancelled:"));
  } finally { await mock.close(); }
});
