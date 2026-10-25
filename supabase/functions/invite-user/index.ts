// Invitation de collaborateurs par e-mail (module 1, §10.1) : un utilisateur ou une liste (import CSV eABC).
// L'appelant doit détenir « users.manage » ; le profil est créé par le déclencheur Auth à partir des métadonnées.
import { callerClient, error, json, requirePermission, serviceClient } from "../_shared/auth.ts";
import { parseUsersCsv, type UserRow } from "../_shared/csv.ts";

interface InvitePayload {
  email?: string;
  full_name?: string;
  job_title?: string | null;
  csv?: string;
  redirect_to?: string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return error("Méthode non autorisée", 405);
  const caller = callerClient(req);
  if (!caller) return error("Non authentifié", 401);
  const ctx = await requirePermission(caller, "users.manage");
  if (ctx instanceof Response) return ctx;

  let payload: InvitePayload;
  try { payload = await req.json(); } catch { return error("Corps JSON attendu"); }

  let rows: UserRow[] = [];
  let parseErrors: { line: number; error: string }[] = [];
  if (payload.csv) {
    const parsed = parseUsersCsv(payload.csv);
    rows = parsed.rows; parseErrors = parsed.errors;
  } else if (payload.email && payload.full_name) {
    rows = [{ email: payload.email.trim().toLowerCase(), fullName: payload.full_name.trim(), jobTitle: payload.job_title ?? null }];
  } else {
    return error("email et full_name, ou csv, requis");
  }

  const admin = serviceClient();
  const invited: { email: string; user_id: string }[] = [];
  const failed: { email: string; error: string }[] = [];
  for (const row of rows) {
    const { data, error: inviteError } = await admin.auth.admin.inviteUserByEmail(row.email, {
      data: { cabinet_id: ctx.cabinetId, full_name: row.fullName, job_title: row.jobTitle },
      redirectTo: payload.redirect_to,
    });
    if (inviteError || !data.user) failed.push({ email: row.email, error: inviteError?.message ?? "inconnu" });
    else invited.push({ email: row.email, user_id: data.user.id });
  }
  // Piste d'audit (au nom de l'appelant)
  await caller.rpc("log_audit_event", {
    p_action: "invite_users",
    p_payload: { invited: invited.map((i) => i.email), failed: failed.map((f) => f.email) },
  });
  return json({ invited, failed, parse_errors: parseErrors });
});
