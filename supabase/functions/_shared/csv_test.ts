import { assertEquals } from "jsr:@std/assert@1";
import { parseUsersCsv } from "./csv.ts";

Deno.test("CSV d'utilisateurs avec en-tête, point-virgule et accents", () => {
  const r = parseUsersCsv("﻿Nom;E-mail;Fonction\nAwa DOSSOU;awa@abc.bj;Assistante\nKofi MENSAH;kofi@abc.bj;Chef de mission\n");
  assertEquals(r.errors, []);
  assertEquals(r.rows.length, 2);
  assertEquals(r.rows[0], { fullName: "Awa DOSSOU", email: "awa@abc.bj", jobTitle: "Assistante" });
});

Deno.test("sans en-tête, virgules, champs entre guillemets", () => {
  const r = parseUsersCsv('"Dossou, Awa",AWA@abc.bj,\n');
  assertEquals(r.rows, [{ fullName: "Dossou, Awa", email: "awa@abc.bj", jobTitle: null }]);
});

Deno.test("e-mails invalides et doublons signalés par ligne", () => {
  const r = parseUsersCsv("nom;email\nA;pas-un-mail\nB;b@abc.bj\nC;b@abc.bj\n");
  assertEquals(r.rows.length, 1);
  assertEquals(r.errors.map((e) => e.line), [2, 4]);
});
