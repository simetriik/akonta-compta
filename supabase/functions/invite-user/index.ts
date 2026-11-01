// Création de collaborateurs (module 1, §10.1) : un utilisateur ou une liste (import CSV eABC), ou nouveau mot de passe
// provisoire pour un membre existant. Aucun e-mail n'est nécessaire : le compte est créé avec un mot de passe provisoire
// que l'administrateur technique reçoit une seule fois et transmet ; l'intéressé doit le changer à sa première connexion.
// L'appelant doit détenir « users.manage » ; le profil est créé par le déclencheur Auth à partir des métadonnées.
import { callerClient, error, json, requirePermission, serviceClient } from "../_shared/auth.ts";
import { parseUsersCsv, type UserRow } from "../_shared/csv.ts";
import { generateTemporaryPassword } from "../_shared/passwords.ts";

interface InvitePayload {
  email?: string;
  full_name?: string;
  job_title?: string | null;
  csv?: string;
  /** Donne le rôle Associé à l'invité : permis une seule fois, tant que le cabinet n'a aucun associé (Q-016). */
  first_partner?: boolean;
  /** Nouveau mot de passe provisoire pour ce membre (oubli, première remise perdue). */
  reset_user_id?: string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return error("Méthode non autorisée", 405);
  const caller = callerClient(req);
  if (!caller) return error("Non authentifié", 401);
  const ctx = await requirePermission(caller, "users.manage");
  if (ctx instanceof Response) return ctx;

  let payload: InvitePayload;
  try { payload = await req.json(); } catch { return error("Corps JSON attendu"); }

  if (payload.reset_user_id) return await resetPassword(caller, ctx, payload.reset_user_id);

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

  if (payload.first_partner) {
    if (payload.csv || rows.length !== 1) return error("Le premier associé se crée seul, sans import CSV");
    const { data: hasPartner, error: partnerError } = await caller.rpc("cabinet_has_partner");
    if (partnerError) return error(`Vérification impossible : ${partnerError.message}`, 500);
    if (hasPartner) return error("Le cabinet a déjà un associé : c'est lui qui affecte les rôles", 409);
  }

  const admin = serviceClient();
  const invited: { email: string; user_id: string; temporary_password: string }[] = [];
  const failed: { email: string; error: string }[] = [];
  for (const row of rows) {
    const temporaryPassword = generateTemporaryPassword();
    const { data, error: createError } = await admin.auth.admin.createUser({
      email: row.email,
      password: temporaryPassword,
      email_confirm: true,
      user_metadata: { cabinet_id: ctx.cabinetId, full_name: row.fullName, job_title: row.jobTitle, must_change_password: true },
    });
    if (createError || !data.user) {
      const exists = /already|registered|exists/i.test(createError?.message ?? "");
      failed.push({ email: row.email, error: exists ? "adresse e-mail déjà utilisée" : (createError?.message ?? "inconnu") });
      continue;
    }
    if (payload.first_partner) {
      // La règle (un seul premier associé par cabinet) est appliquée par la base, sous verrou.
      const { error: grantError } = await admin.rpc("grant_first_partner", {
        p_cabinet: ctx.cabinetId, p_user: data.user.id, p_by: ctx.userId,
      });
      if (grantError) {
        // Compte créé mais sans rôle : on le retire pour que l'administrateur puisse recommencer proprement.
        await admin.auth.admin.deleteUser(data.user.id);
        failed.push({ email: row.email, error: `rôle Associé refusé : ${grantError.message}` });
        continue;
      }
    }
    invited.push({ email: row.email, user_id: data.user.id, temporary_password: temporaryPassword });
  }
  // Piste d'audit (au nom de l'appelant) : jamais les mots de passe.
  await caller.rpc("log_audit_event", {
    p_action: "invite_users",
    p_payload: { invited: invited.map((i) => i.email), failed: failed.map((f) => f.email), first_partner: payload.first_partner === true },
  });
  return json({ invited, failed, parse_errors: parseErrors });
});

async function resetPassword(
  caller: ReturnType<typeof callerClient> & object,
  ctx: { userId: string; cabinetId: string },
  userId: string,
): Promise<Response> {
  if (userId === ctx.userId) return error("Pour changer votre propre mot de passe, utilisez « Mon compte »");
  // Lecture au nom de l'appelant : la RLS limite aux membres de son cabinet.
  const { data: profile } = await caller.from("profiles").select("id, email").eq("id", userId).maybeSingle();
  if (!profile) return error("Membre introuvable", 404);
  const admin = serviceClient();
  const { data: existing, error: readError } = await admin.auth.admin.getUserById(userId);
  if (readError || !existing.user) return error("Compte introuvable", 404);
  const temporaryPassword = generateTemporaryPassword();
  const { error: updateError } = await admin.auth.admin.updateUserById(userId, {
    password: temporaryPassword,
    user_metadata: { ...existing.user.user_metadata, must_change_password: true },
  });
  if (updateError) return error(`Réinitialisation impossible : ${updateError.message}`, 500);
  await caller.rpc("log_audit_event", { p_action: "reset_password", p_payload: { user: profile.email } });
  return json({ reset: { email: profile.email, user_id: userId, temporary_password: temporaryPassword } });
}
