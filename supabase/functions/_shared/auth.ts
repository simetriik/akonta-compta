// Utilitaires communs des Edge Functions : clients Supabase (appelant et service), vérification de permission.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

export const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json; charset=utf-8" } });
}

export function error(message: string, status = 400): Response {
  return json({ error: message }, status);
}

/** Client agissant au nom de l'appelant (RLS appliquée), construit depuis son en-tête Authorization. */
export function callerClient(req: Request): SupabaseClient | null {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  return createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: auth } }, auth: { persistSession: false } });
}

/** Client de service (jamais exposé à l'application) pour les opérations d'administration Auth. */
export function serviceClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
}

/** Vérifie que l'appelant est connecté et détient la permission (fonction SQL has_permission). */
export async function requirePermission(
  caller: SupabaseClient,
  permission: string,
  entityId: string | null = null,
): Promise<{ userId: string; cabinetId: string } | Response> {
  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData.user) return error("Non authentifié", 401);
  const { data: allowed, error: permError } = await caller.rpc("has_permission", { p_entity: entityId, p_code: permission });
  if (permError) return error(`Vérification des permissions impossible : ${permError.message}`, 500);
  if (!allowed) return error(`Permission refusée : ${permission}`, 403);
  const { data: cabinetId } = await caller.rpc("current_cabinet_id");
  if (!cabinetId) return error("Aucun cabinet pour cet utilisateur", 403);
  return { userId: userData.user.id, cabinetId: cabinetId as string };
}
