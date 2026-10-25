// Export PDF / Excel des états de consultation (module 6, §10.6) : les données sont calculées par les
// fonctions SQL au nom de l'appelant (RLS, permission ledger.read), rendues par le service de documents,
// et l'export est tracé dans la piste d'audit.
import { callerClient, error } from "../_shared/auth.ts";
import { buildPayload, type ExportRequest, servicePath, validateRequest } from "../_shared/documents.ts";

const SERVICE_URL = Deno.env.get("DOCUMENTS_SERVICE_URL") ?? "http://host.containers.internal:8100";
const SERVICE_KEY = Deno.env.get("DOCUMENTS_SERVICE_KEY") ?? "";

Deno.serve(async (req) => {
  if (req.method !== "POST") return error("Méthode non autorisée", 405);
  const caller = callerClient(req);
  if (!caller) return error("Non authentifié", 401);
  let r: ExportRequest;
  try { r = await req.json(); } catch { return error("Corps JSON attendu"); }
  const invalid = validateRequest(r);
  if (invalid) return error(invalid);

  const { data: user } = await caller.auth.getUser();
  if (!user.user) return error("Non authentifié", 401);

  // En-tête du document
  const { data: entity, error: entityError } = await caller.from("entities").select("name, tax_id, cabinets(name)").eq("id", r.entity_id).single();
  if (entityError || !entity) return error("Dossier inaccessible", 403);
  const { data: fy } = await caller.from("fiscal_years").select("label").eq("entity_id", r.entity_id).lte("start_date", r.from).gte("end_date", r.from).maybeSingle();
  const { data: profile } = await caller.from("profiles").select("full_name").eq("id", user.user.id).maybeSingle();
  const header = {
    cabinet_name: (entity.cabinets as unknown as { name: string } | null)?.name ?? "",
    entity_name: entity.name as string,
    entity_tax_id: (entity.tax_id as string | null) ?? null,
    fiscal_year_label: (fy?.label as string | undefined) ?? r.from.slice(0, 4),
    generated_by: (profile?.full_name as string | undefined) ?? null,
  };

  // Données (fonctions SQL, RLS et permission ledger.read au nom de l'appelant)
  let rows: Record<string, unknown>[] = [];
  let extra: Record<string, unknown> = {};
  let rpcError: { message: string } | null = null;
  switch (r.kind) {
    case "trial_balance": {
      const res = await caller.rpc("trial_balance", { p_entity: r.entity_id, p_from: r.from, p_to: r.to, p_class: r.class ?? null });
      rows = res.data ?? []; rpcError = res.error; break;
    }
    case "general_ledger": {
      const res = await caller.rpc("general_ledger", { p_entity: r.entity_id, p_from: r.from, p_to: r.to, p_account_from: r.account_from ?? null, p_account_to: r.account_to ?? null, p_third_party: null });
      rows = res.data ?? []; rpcError = res.error; break;
    }
    case "journal": {
      const res = await caller.rpc("journal_book", { p_entity: r.entity_id, p_journal: r.journal_id, p_from: r.from, p_to: r.to });
      rows = res.data ?? []; rpcError = res.error;
      const { data: j } = await caller.from("journals").select("code, label").eq("id", r.journal_id!).single();
      extra = { journal_code: j?.code ?? "", journal_label: j?.label ?? "" };
      break;
    }
    case "aged_balance": {
      const res = await caller.rpc("aged_balance", { p_entity: r.entity_id, p_as_of: r.to, p_side: r.side ?? "debit" });
      rows = res.data ?? []; rpcError = res.error; extra = { side: r.side ?? "debit" }; break;
    }
    case "reconciliation": {
      const state = await caller.rpc("reconciliation_state", { p_journal: r.journal_id, p_as_of: r.to });
      rpcError = state.error;
      const st = (state.data as Record<string, number>[] | null)?.[0];
      const book = await caller.rpc("unmatched_book_lines", { p_journal: r.journal_id, p_until: r.to });
      const bank = await caller.rpc("unmatched_statement_lines", { p_journal: r.journal_id, p_until: r.to });
      const { data: j } = await caller.from("journals").select("code, label").eq("id", r.journal_id!).single();
      const bookLines = (book.data ?? []) as Record<string, unknown>[];
      const bankLines = (bank.data ?? []) as Record<string, unknown>[];
      extra = {
        journal_code: j?.code ?? "", journal_label: j?.label ?? "", as_of: r.to,
        book_balance: st?.book_balance ?? 0, bank_balance: st?.bank_balance ?? 0, difference: st?.difference ?? 0,
        deposits_in_transit: bookLines.filter((l) => (l.debit as number) > 0).map((l) => ({ date: l.entry_date, label: l.label, reference: l.reference ?? null, amount: l.debit })),
        outstanding_payments: bookLines.filter((l) => (l.credit as number) > 0).map((l) => ({ date: l.entry_date, label: l.label, reference: l.reference ?? null, amount: l.credit })),
        unmatched_bank_credits: bankLines.filter((l) => (l.credit as number) > 0).map((l) => ({ date: l.operation_date, label: l.label, reference: l.reference ?? null, amount: l.credit })),
        unmatched_bank_debits: bankLines.filter((l) => (l.debit as number) > 0).map((l) => ({ date: l.operation_date, label: l.label, reference: l.reference ?? null, amount: l.debit })),
      };
      rows = [];
      break;
    }
  }
  if (rpcError) return error(rpcError.message, rpcError.message.includes("Permission") ? 403 : 500);

  const route = servicePath(r.kind, r.format)!;
  const upstream = await fetch(`${SERVICE_URL}${route.path}`, {
    method: "POST",
    headers: { "content-type": "application/json", "X-Akonta-Service-Key": SERVICE_KEY },
    body: JSON.stringify(buildPayload(r, header, rows, extra)),
  });
  if (!upstream.ok) return error(`Service de documents : ${upstream.status} ${await upstream.text()}`, 502);

  await caller.rpc("log_audit_event", {
    p_action: "export", p_entity: r.entity_id,
    p_payload: { kind: r.kind, format: r.format, from: r.from, to: r.to, rows: rows.length },
  });
  return new Response(await upstream.arrayBuffer(), {
    headers: { "content-type": upstream.headers.get("content-type") ?? "application/octet-stream", "content-disposition": `attachment; filename="${route.filename}"` },
  });
});
