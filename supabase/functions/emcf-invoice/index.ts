// Émission de factures normalisées auprès de l'e-MCF de la DGI (D-043). Le jeton de l'e-MCF reste ici : il est lu avec la clé
// de service et n'est jamais renvoyé à l'application. L'appelant agit sous RLS (droit invoices.issue ou emcf.manage sur le dossier).
// Actions : set_token, issue, resume, cancel.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { callerClient, error, json, requirePermission, serviceClient } from "../_shared/auth.ts";
import {
  baseUrl, EmcfClient, EmcfError, type EmcfMode, type ExpectedTotals, type InvoiceRow, type LineRow,
  type PaymentRow,
} from "../_shared/emcf.ts";
import { cancelPending, confirmPending, type IssueOutcome, runIssue, type StorePort } from "../_shared/emcf_flow.ts";

interface Payload { action?: string; device_id?: string; token?: string; invoice_id?: string }

Deno.serve(async (req) => {
  if (req.method !== "POST") return error("Méthode non autorisée", 405);
  const caller = callerClient(req);
  if (!caller) return error("Non authentifié", 401);
  let body: Payload;
  try { body = await req.json(); } catch { return error("Corps JSON attendu"); }

  switch (body.action) {
    case "set_token": return await setToken(caller, body);
    case "issue": case "resume": case "cancel": return await handleInvoice(caller, body);
    default: return error("Action inconnue (set_token, issue, resume, cancel)");
  }
});

/** Lit le jeton d'un e-MCF avec la clé de service (aucun autre code n'y a accès). */
async function readToken(deviceId: string): Promise<string | null> {
  const { data } = await serviceClient().from("emcf_device_tokens").select("token").eq("device_id", deviceId).maybeSingle();
  return (data?.token as string | undefined) ?? null;
}

async function setToken(caller: SupabaseClient, body: Payload): Promise<Response> {
  if (!body.device_id || !body.token) return error("device_id et token requis");
  const { data: device } = await caller.from("emcf_devices").select("id, entity_id, nim, mode").eq("id", body.device_id).maybeSingle();
  if (!device) return error("e-MCF inaccessible", 403);
  const ctx = await requirePermission(caller, "emcf.manage", device.entity_id as string);
  if (ctx instanceof Response) return ctx;

  // Le jeton doit être valable et correspondre au NIM du point de vente : on interroge la DGI avant de l'enregistrer.
  const client = new EmcfClient(baseUrl(device.mode as EmcfMode), body.token.trim());
  let status: Record<string, unknown>;
  try { status = await client.status(); } catch (e) { return error((e as Error).message, e instanceof EmcfError && e.network ? 502 : 422); }
  if (status.nim && status.nim !== device.nim) return error(`Ce jeton appartient à l'e-MCF ${status.nim}, pas à ${device.nim}.`, 422);

  const { error: saveError } = await serviceClient().from("emcf_device_tokens")
    .upsert({ device_id: device.id, token: body.token.trim(), updated_at: new Date().toISOString() });
  if (saveError) return error("Enregistrement du jeton impossible", 500);
  await caller.rpc("log_audit_event", { p_action: "emcf_token_set", p_payload: { device_id: device.id, nim: device.nim }, p_entity: device.entity_id });
  return json({ ok: true, nim: status.nim ?? device.nim, token_valid_until: status.tokenValid ?? null });
}

async function handleInvoice(caller: SupabaseClient, body: Payload): Promise<Response> {
  if (!body.invoice_id) return error("invoice_id requis");
  const { data: inv } = await caller.from("invoices").select("*").eq("id", body.invoice_id).maybeSingle();
  if (!inv) return error("Facture inaccessible", 403);
  const ctx = await requirePermission(caller, "invoices.issue", inv.entity_id as string);
  if (ctx instanceof Response) return ctx;

  const { data: device } = await caller.from("emcf_devices").select("id, mode, is_active").eq("id", inv.device_id).single();
  if (!device) return error("e-MCF inaccessible", 403);
  if (!device.is_active) return error("Cet e-MCF est désactivé.", 409);
  const token = await readToken(device.id as string);
  if (!token) return error("Aucun jeton enregistré pour cet e-MCF : demandez à un associé de l'ajouter.", 409);

  const dgi = new EmcfClient(baseUrl(device.mode as EmcfMode), token);
  const svc = serviceClient();
  const store: StorePort = {
    markPending: async (uid, response) => rpc(svc, "invoice_mark_pending", { p_invoice: inv.id, p_uid: uid, p_response: response }),
    markConfirmed: async (security) => rpc(svc, "invoice_mark_confirmed", { p_invoice: inv.id, p_security: security }),
    markCancelled: async (reason) => rpc(svc, "invoice_mark_cancelled", { p_invoice: inv.id, p_reason: reason }),
    revertToDraft: async (reason) => rpc(svc, "invoice_revert_to_draft", { p_invoice: inv.id, p_error: reason }),
  };

  let outcome: IssueOutcome;
  try {
    if (body.action === "issue") {
      if (inv.status !== "draft") return error("Seule une facture en brouillon peut être émise.", 409);
      const [{ data: lines }, { data: payments }, { data: expected, error: expectedError }] = await Promise.all([
        caller.from("invoice_lines").select("*").eq("invoice_id", inv.id).order("position"),
        caller.from("invoice_payments").select("*").eq("invoice_id", inv.id),
        caller.rpc("invoice_expected_totals", { p_invoice: inv.id }),
      ]);
      if (!lines || lines.length === 0) return error("La facture doit contenir au moins un article.", 422);
      if (expectedError || !expected?.[0]) return error("Calcul de contrôle impossible", 500);
      outcome = await runIssue(inv as InvoiceRow, lines as LineRow[], (payments ?? []) as PaymentRow[], toExpected(expected[0]), dgi, store);
    } else {
      if (inv.status !== "pending" || !inv.dgi_uid) return error("Cette facture n'est pas en cours d'émission.", 409);
      outcome = body.action === "resume"
        ? await confirmPending(inv.dgi_uid as string, dgi, store)
        : await cancelPending(inv.dgi_uid as string, dgi, store);
    }
  } catch (e) {
    return error(`Émission interrompue : ${(e as Error).message}`, 500);
  }
  return json({ invoice_id: inv.id, ...outcome }, outcome.state === "confirmed" || outcome.state === "draft" && body.action === "cancel" ? 200 : 202);
}

function toExpected(row: Record<string, unknown>): ExpectedTotals {
  return { taa: Number(row.taa), tab: Number(row.tab), hab: Number(row.hab), vab: Number(row.vab), total: Number(row.total) };
}

async function rpc(svc: SupabaseClient, fn: string, args: Record<string, unknown>): Promise<void> {
  const { error: e } = await svc.rpc(fn, args);
  if (e) throw new Error(e.message);
}
