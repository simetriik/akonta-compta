// Analyse du CSV d'utilisateurs exporté d'eABC : colonnes nom, e-mail, fonction (en-tête tolérante, séparateur ; ou ,).

export interface UserRow {
  fullName: string;
  email: string;
  jobTitle: string | null;
}

export interface ParsedUsers {
  rows: UserRow[];
  errors: { line: number; error: string }[];
}

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function detectDelimiter(header: string): string {
  const semis = (header.match(/;/g) ?? []).length;
  const commas = (header.match(/,/g) ?? []).length;
  return semis >= commas ? ";" : ",";
}

function splitLine(line: string, delimiter: string): string[] {
  const out: string[] = [];
  let cur = "";
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === '"') {
      if (quoted && line[i + 1] === '"') { cur += '"'; i++; } else quoted = !quoted;
    } else if (c === delimiter && !quoted) {
      out.push(cur); cur = "";
    } else cur += c;
  }
  out.push(cur);
  return out.map((s) => s.trim());
}

function normalize(h: string): string {
  return h.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z]/g, "");
}

export function parseUsersCsv(text: string): ParsedUsers {
  const lines = text.replace(/^﻿/, "").split(/\r?\n/).filter((l) => l.trim() !== "");
  const result: ParsedUsers = { rows: [], errors: [] };
  if (lines.length === 0) return result;
  const delimiter = detectDelimiter(lines[0]);
  const header = splitLine(lines[0], delimiter).map(normalize);
  const idx = (names: string[]) => header.findIndex((h) => names.includes(h));
  let nameCol = idx(["nom", "nomcomplet", "name", "fullname", "collaborateur"]);
  let emailCol = idx(["email", "mail", "courriel", "adresseemail"]);
  let jobCol = idx(["fonction", "poste", "jobtitle", "titre", "role"]);
  let start = 1;
  if (emailCol < 0) {
    // Pas d'en-tête reconnu : nom ; e-mail ; fonction dans cet ordre
    nameCol = 0; emailCol = 1; jobCol = 2; start = 0;
  }
  const seen = new Set<string>();
  for (let i = start; i < lines.length; i++) {
    const cols = splitLine(lines[i], delimiter);
    const email = (cols[emailCol] ?? "").toLowerCase();
    const fullName = cols[nameCol] ?? "";
    if (!EMAIL.test(email)) { result.errors.push({ line: i + 1, error: `Adresse e-mail invalide : « ${email} »` }); continue; }
    if (!fullName) { result.errors.push({ line: i + 1, error: "Nom manquant" }); continue; }
    if (seen.has(email)) { result.errors.push({ line: i + 1, error: `Adresse en double : ${email}` }); continue; }
    seen.add(email);
    result.rows.push({ fullName, email, jobTitle: jobCol >= 0 && cols[jobCol] ? cols[jobCol] : null });
  }
  return result;
}
