import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { generateTemporaryPassword } from "./passwords.ts";

Deno.test("le mot de passe provisoire respecte la politique (12+ caractères, minuscule, majuscule, chiffre)", () => {
  for (let i = 0; i < 200; i++) {
    const p = generateTemporaryPassword();
    assertEquals(p.length, 14);
    assert(/[a-z]/.test(p) && /[A-Z]/.test(p) && /[0-9]/.test(p), p);
  }
});

Deno.test("le mot de passe provisoire évite les caractères ambigus", () => {
  for (let i = 0; i < 200; i++) assert(!/[0O1lI]/.test(generateTemporaryPassword()));
});

Deno.test("deux mots de passe provisoires diffèrent", () => {
  assertNotEquals(generateTemporaryPassword(), generateTemporaryPassword());
});
