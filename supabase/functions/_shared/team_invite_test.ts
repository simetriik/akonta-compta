import { assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { validateInvite } from "./team_invite.ts";

Deno.test("l'administrateur crée un compte sans rôle d'équipe", () => {
  assertEquals(validateInvite({}, true), null);
  assertEquals(validateInvite({ first_partner: true }, true), null);
  assertEquals(validateInvite({ csv: "a;b" }, true), null);
  assertNotEquals(validateInvite({ role: "assistant", entity_id: "e1" }, true), null);
});

Deno.test("l'associé crée un compte sans rôle, ou avec un rôle d'équipe sur un dossier", () => {
  assertEquals(validateInvite({}, false), null);
  assertEquals(validateInvite({ role: "assistant", entity_id: "e1" }, false), null);
  assertEquals(validateInvite({ role: "manager", entity_id: "e1" }, false), null);
});

Deno.test("l'associé ne crée ni associé, ni administrateur, ni import en masse", () => {
  assertNotEquals(validateInvite({ first_partner: true }, false), null);
  assertNotEquals(validateInvite({ csv: "x" }, false), null);
  assertNotEquals(validateInvite({ role: "partner", entity_id: "e1" }, false), null);
  assertNotEquals(validateInvite({ role: "tech_admin", entity_id: "e1" }, false), null);
});

Deno.test("un rôle d'équipe va avec un dossier, et inversement", () => {
  assertNotEquals(validateInvite({ role: "assistant" }, false), null);
  assertNotEquals(validateInvite({ entity_id: "e1" }, false), null);
});
