// Usage : ANON=<clé anon> SERVICE=<clé service locale> deno run --allow-all scripts/e2e-client-access.ts   (base locale uniquement, jamais la production)
// Essai réel : un client du cabinet se connecte et agit par l'API (PostgREST + Storage), comme le fait l'application.
import { createClient } from "npm:@supabase/supabase-js@2";
const URL_ = "http://127.0.0.1:54321";
const ANON = Deno.env.get("ANON")!, SERVICE = Deno.env.get("SERVICE")!;
const results: string[] = [];
const ok = (cond: boolean, label: string, extra = "") => results.push(`${cond ? "OK  " : "ÉCHEC"} ${label}${extra ? " — " + extra : ""}`);
const pdf = () => new Blob([new TextEncoder().encode("%PDF-1.4 test")], { type: "application/pdf" });
const sha = async (s: string) => Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)))).map((b) => b.toString(16).padStart(2, "0")).join("");

const svc = createClient(URL_, SERVICE, { auth: { persistSession: false } });
const tag = Date.now();
const pw = "Motdepasse-E2E-123";
const must = <T>(r: { data: T; error: { message: string } | null }, what: string): T => { if (r.error) throw new Error(`${what}: ${r.error.message}`); return r.data; };

try {
  const cab = must(await svc.from("cabinets").insert({ name: `E2E client ${tag}` }).select().single(), "cabinet");
  const mkUser = async (name: string) => must(await svc.auth.admin.createUser({ email: `${name}-${tag}@akonta.test`, password: pw, email_confirm: true, user_metadata: { cabinet_id: cab.id, full_name: name } }), name).user!;
  const client = await mkUser("client"), staff = await mkUser("staff");
  const mkEntity = async (n: string) => must(await svc.from("entities").insert({ cabinet_id: cab.id, name: n }).select().single(), "entité");
  const e1 = await mkEntity("Client E2E"), e2 = await mkEntity("Autre client E2E");
  for (const e of [e1, e2]) {
    must(await svc.from("fiscal_years").insert({ cabinet_id: cab.id, entity_id: e.id, start_date: "2026-01-01", end_date: "2026-12-31" }).select(), "exercice");
    must(await svc.rpc("create_journals_from_template", { p_entity: e.id, p_codes: null }), "journaux");
  }
  const role = async (code: string) => must(await svc.from("roles").select("id").eq("cabinet_id", cab.id).eq("code", code).single(), "rôle").id;
  must(await svc.from("assignments").insert({ cabinet_id: cab.id, user_id: client.id, entity_id: e1.id, role_id: await role("client_saisie") }).select(), "affectation client");
  must(await svc.from("assignments").insert({ cabinet_id: cab.id, user_id: staff.id, entity_id: e1.id, role_id: await role("assistant") }).select(), "affectation personnel");
  must(await svc.rpc("set_client_access", { p_entity: e1.id, p_status: "active" }), "ouverture");

  // Écriture validée et pièce du cabinet, côté personnel
  const jVT = must(await svc.from("journals").select("id").eq("entity_id", e1.id).eq("code", "VT").single(), "journal").id;
  const fy = must(await svc.from("fiscal_years").select("id").eq("entity_id", e1.id).single(), "fy").id;
  const per = must(await svc.from("periods").select("id").eq("entity_id", e1.id).lte("start_date", "2026-02-01").gte("end_date", "2026-02-01").single(), "période").id;
  const acc = async (c: string) => must(await svc.from("accounts").select("id").eq("entity_id", e1.id).eq("code", c).single(), "compte " + c).id;
  const mkEntry = async (label: string, by: string) => {
    const en = must(await svc.from("entries").insert({ cabinet_id: cab.id, entity_id: e1.id, fiscal_year_id: fy, period_id: per, journal_id: jVT, entry_date: "2026-02-01", label, created_by: by, currency_code: "XOF" }).select().single(), "écriture");
    must(await svc.from("entry_lines").insert([
      { cabinet_id: cab.id, entity_id: e1.id, entry_id: en.id, account_id: await acc("5210000"), debit: 100, credit: 0, currency_code: "XOF" },
      { cabinet_id: cab.id, entity_id: e1.id, entry_id: en.id, account_id: await acc("7011000"), debit: 0, credit: 100, currency_code: "XOF" }]).select(), "lignes");
    return en;
  };
  const validated = await mkEntry("Validée du cabinet", staff.id);
  must(await svc.rpc("validate_entry", { p_entry: validated.id }), "validation");
  const staffPath = `${cab.id}/${e1.id}/cabinet.pdf`;
  must(await svc.storage.from("documents").upload(staffPath, pdf(), { contentType: "application/pdf" }), "fichier cabinet");
  must(await svc.from("documents").insert({ cabinet_id: cab.id, entity_id: e1.id, storage_path: staffPath, file_name: "cabinet.pdf", mime_type: "application/pdf", size_bytes: 13, sha256: await sha("c"), captured_by: staff.id }).select(), "pièce cabinet");

  // --- Le client agit
  const me = createClient(URL_, ANON, { auth: { persistSession: false } });
  must(await me.auth.signInWithPassword({ email: client.email!, password: pw }), "connexion client");

  const roles = must(await me.from("assignments").select("role_id, entity_id, roles(code, name, requires_mfa, grants_all_entities, accounting_access, is_client)").eq("user_id", client.id), "rôles");
  ok(roles.length === 1 && (roles[0] as any).roles.is_client === true, "l'application reconnaît un client (is_client)");
  const dash = must(await me.rpc("entity_dashboard"), "tableau de bord") as any[];
  ok(dash.length === 1 && dash[0].client_access === "active" && dash[0].entity_id === e1.id, "tableau de bord : son dossier seulement, accès actif");
  for (const t of ["accounts", "journals", "periods", "fiscal_years", "third_parties"]) {
    const { data, error } = await me.from(t).select("id").eq("entity_id", e1.id).limit(1);
    ok(!error && (t === "third_parties" || (data?.length ?? 0) > 0), `lecture du référentiel ${t}`, error?.message ?? "");
  }
  const other = await me.from("accounts").select("id").eq("entity_id", e2.id).limit(1);
  ok((other.data?.length ?? 0) === 0, "aucun compte de l'autre client");

  // Saisie d'un brouillard, comme l'application
  const drafted = must(await me.from("entries").insert({ cabinet_id: cab.id, entity_id: e1.id, fiscal_year_id: fy, period_id: per, journal_id: jVT, entry_date: "2026-02-10", label: "Mon brouillard", created_by: client.id, currency_code: "XOF" }).select().single(), "brouillard client");
  must(await me.from("entry_lines").insert([
    { cabinet_id: cab.id, entity_id: e1.id, entry_id: drafted.id, account_id: await acc("5210000"), debit: 500, credit: 0, currency_code: "XOF" },
    { cabinet_id: cab.id, entity_id: e1.id, entry_id: drafted.id, account_id: await acc("7011000"), debit: 0, credit: 500, currency_code: "XOF" }]).select(), "lignes du client");
  ok(true, "le client saisit un brouillard et ses lignes");
  const listed = must(await me.from("entries").select("id, label, status, returned_comment, journals(code), entry_lines(id, debit, credit, accounts(code, label), third_parties(code))"), "liste") as any[];
  ok(listed.length === 1 && listed[0].label === "Mon brouillard" && listed[0].entry_lines.length === 2 && listed[0].entry_lines[0].accounts?.code, "liste avec les mêmes jointures que l'application : son brouillard seulement");
  ok(listed.every((e) => e.status === "draft"), "aucune écriture validée visible");
  const v = await me.rpc("validate_entry", { p_entry: drafted.id });
  ok(!!v.error, "il ne peut pas valider", v.error?.message ?? "");
  const v2 = await me.rpc("return_draft_to_client", { p_entry: drafted.id, p_comment: "x" });
  ok(!!v2.error, "il ne peut pas se renvoyer un brouillard", v2.error?.message ?? "");
  const lines = must(await me.from("entry_lines").select("id"), "lignes lues") as any[];
  ok(lines.length === 2, "ne lit que les lignes de son brouillard");
  const profs = must(await me.from("profiles").select("id"), "profils") as any[];
  ok(profs.length === 1, "ne voit que son propre profil");
  ok(((await me.from("audit_log").select("id")).data?.length ?? 0) === 0, "aucune piste d'audit");
  const copy = await me.rpc("copy_reference_plan", { p_entity: e2.id });
  ok(!!copy.error, "copy_reference_plan sur un autre dossier refusé", copy.error?.message ?? "");
  const jr = await me.rpc("create_journals_from_template", { p_entity: e1.id, p_codes: null });
  ok(!!jr.error, "create_journals_from_template refusé à un client", jr.error?.message ?? "");

  // Pièces et stockage
  const myPath = `${cab.id}/${e1.id}/mienne.pdf`;
  const up = await me.storage.from("documents").upload(myPath, pdf(), { contentType: "application/pdf" });
  ok(!up.error, "envoi d'un fichier dans son dossier", up.error?.message ?? "");
  const ins = await me.from("documents").insert({ cabinet_id: cab.id, entity_id: e1.id, storage_path: myPath, file_name: "mienne.pdf", mime_type: "application/pdf", size_bytes: 13, sha256: await sha("m"), captured_by: client.id }).select();
  ok(!ins.error, "enregistrement de sa pièce", ins.error?.message ?? "");
  const docs = must(await me.from("documents").select("file_name"), "pièces") as any[];
  ok(docs.length === 1 && docs[0].file_name === "mienne.pdf", "ne voit que sa pièce, pas celle du cabinet");
  ok(!(await me.storage.from("documents").createSignedUrl(myPath, 60)).error, "lien signé de sa pièce");
  ok(!!(await me.storage.from("documents").createSignedUrl(staffPath, 60)).error, "pas de lien signé pour la pièce du cabinet");
  const dl = await me.storage.from("documents").download(staffPath);
  ok(!!dl.error, "pas de téléchargement du fichier du cabinet");
  const wrongEntity = await me.storage.from("documents").upload(`${cab.id}/${e2.id}/intrus.pdf`, pdf(), { contentType: "application/pdf" });
  ok(!!wrongEntity.error, "pas d'envoi dans le dossier d'un autre client", wrongEntity.error?.message ?? "");
  const rmStaff = await me.storage.from("documents").remove([staffPath]);
  const stillThere = await svc.storage.from("documents").download(staffPath);
  ok(!stillThere.error, "le fichier du cabinet n'a pas pu être supprimé", rmStaff.error?.message ?? `supprimés: ${rmStaff.data?.length ?? 0}`);
  const rmMine = await me.storage.from("documents").remove([myPath]);
  ok(!rmMine.error && (rmMine.data?.length ?? 0) === 1, "il supprime son propre fichier", rmMine.error?.message ?? "");

  // Suspension : lecture oui, écriture non
  must(await svc.rpc("set_client_access", { p_entity: e1.id, p_status: "suspended" }), "suspension");
  const blocked = await me.from("entries").insert({ cabinet_id: cab.id, entity_id: e1.id, fiscal_year_id: fy, period_id: per, journal_id: jVT, entry_date: "2026-02-11", label: "Refusé", created_by: client.id, currency_code: "XOF" }).select();
  ok(!!blocked.error, "suspendu : plus de saisie", blocked.error?.message ?? "");
  const blockedUp = await me.storage.from("documents").upload(`${cab.id}/${e1.id}/refuse.pdf`, pdf(), { contentType: "application/pdf" });
  ok(!!blockedUp.error, "suspendu : plus d'envoi de fichier", blockedUp.error?.message ?? "");
  ok(((await me.from("entries").select("id")).data?.length ?? 0) === 1, "suspendu : il relit son brouillard");
  must(await svc.rpc("set_client_access", { p_entity: e1.id, p_status: "disabled" }), "fermeture");
  ok(((await me.from("entries").select("id")).data?.length ?? 0) === 0, "fermé : plus rien");
} catch (e) {
  results.push(`ERREUR ${(e as Error).message}`);
}
console.log(results.join("\n"));
console.log(results.some((r) => r.startsWith("ÉCHEC") || r.startsWith("ERREUR")) ? "\nRÉSULTAT : ÉCHEC" : "\nRÉSULTAT : TOUT PASSE");
Deno.exit(0);
