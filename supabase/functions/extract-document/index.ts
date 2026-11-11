// Saisie par scan de pièce : lit une pièce déposée (service d'extraction local, sans modèle en ligne) et crée une écriture
// proposée en brouillard, marquée « générée », liée à la pièce. L'appelant agit sous RLS (entries.draft et documents.attach).
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { callerClient, error, json, requirePermission } from "../_shared/auth.ts";
import { type Extracted, runScan, ScanError, type ScanPorts } from "../_shared/scan.ts";

const SERVICE_URL = Deno.env.get("DOCUMENTS_SERVICE_URL") ?? "http://host.containers.internal:8100";
const SERVICE_KEY = Deno.env.get("DOCUMENTS_SERVICE_KEY") ?? "";

Deno.serve(async (req) => {
  if (req.method !== "POST") return error("Méthode non autorisée", 405);
  const caller = callerClient(req);
  if (!caller) return error("Non authentifié", 401);
  let body: { document_id?: string };
  try { body = await req.json(); } catch { return error("Corps JSON attendu"); }
  if (!body.document_id) return error("document_id requis");

  const { data: doc } = await caller.from("documents").select("entity_id").eq("id", body.document_id).maybeSingle();
  if (!doc) return error("Pièce inaccessible", 403);
  for (const permission of ["entries.draft", "documents.attach"]) {
    const ctx = await requirePermission(caller, permission, doc.entity_id as string);
    if (ctx instanceof Response) return ctx;
  }
  try {
    return json(await runScan(body.document_id, ports(caller)));
  } catch (e) {
    if (e instanceof ScanError) return json({ error: e.message, extracted: e.extracted ?? null }, e.status);
    return error(`Lecture de la pièce impossible : ${(e as Error).message}`, 500);
  }
});

/** Branche l'orchestration sur la base (sous RLS) et sur le service d'extraction. */
function ports(caller: SupabaseClient): ScanPorts {
  return {
    async loadDocument(id) {
      const { data } = await caller.from("documents").select("id, entity_id, storage_path, mime_type, file_name").eq("id", id).maybeSingle();
      return data ?? null;
    },
    async existingEntry(documentId) {
      const { data } = await caller.from("entries").select("id").eq("generated_source", `document:${documentId}`).maybeSingle();
      return (data?.id as string | undefined) ?? null;
    },
    async download(path) {
      const { data, error: err } = await caller.storage.from("documents").download(path);
      if (err || !data) throw new ScanError("Fichier de la pièce introuvable", 404);
      return new Uint8Array(await data.arrayBuffer());
    },
    async extract(bytes, mimeType) {
      let res: Response;
      try {
        res = await fetch(`${SERVICE_URL}/extract/document`, { method: "POST", headers: { "x-akonta-service-key": SERVICE_KEY, "content-type": mimeType }, body: new Blob([bytes as BlobPart]) });
      } catch {
        throw new ScanError("Service de lecture des pièces injoignable", 502);
      }
      if (!res.ok) {
        const detail = (await res.json().catch(() => ({})) as { detail?: string }).detail;
        throw new ScanError(detail ?? "Lecture de la pièce refusée", res.status === 415 ? 422 : 502);
      }
      return await res.json() as Extracted;
    },
    async findThirdParty(entityId, taxId, name) {
      const { data } = await caller.from("third_parties").select("id, name, tax_id").eq("entity_id", entityId).eq("is_active", true);
      const rows = (data ?? []) as { id: string; name: string; tax_id: string | null }[];
      const byIfu = taxId ? rows.find((t) => t.tax_id === taxId) : undefined;
      const byName = name ? rows.find((t) => t.name.trim().toLowerCase() === name.trim().toLowerCase()) : undefined;
      return (byIfu ?? byName)?.id ?? null;
    },
    async accountIdByCode(entityId, code) {
      const { data } = await caller.rpc("account_id_by_code", { p_entity: entityId, p_code: code });
      return (data as string | null) ?? null;
    },
    async suggestExpenseAccount(entityId, label, thirdPartyId) {
      const { data } = await caller.rpc("suggest_accounts", { p_entity: entityId, p_label: label, p_third_party: thirdPartyId, p_limit: 5 });
      const rows = (data ?? []) as { account_id: string; account_code: string }[];
      return rows.find((r) => r.account_code.startsWith("6"))?.account_id ?? null;
    },
    async generate(documentId, proposal) {
      const { data, error: err } = await caller.rpc("generate_scan_entry", { p_document: documentId, p_proposal: proposal });
      if (err || !data) throw new ScanError(err?.message ?? "Création du brouillard impossible", 422);
      return data as string;
    },
  };
}
