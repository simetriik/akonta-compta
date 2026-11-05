import { assertEquals } from "jsr:@std/assert@1";
import { type MfaAdmin, resetMemberFactors } from "./mfa_reset.ts";

function fake(factors: string[], failOn?: string): { mfa: MfaAdmin; deleted: string[] } {
  const deleted: string[] = [];
  const mfa: MfaAdmin = {
    listFactors: () => Promise.resolve({ data: { factors: factors.map((id) => ({ id })) }, error: null }),
    deleteFactor: ({ id }) => {
      if (id === failOn) return Promise.resolve({ error: { message: "refusé" } });
      deleted.push(id);
      return Promise.resolve({ error: null });
    },
  };
  return { mfa, deleted };
}

Deno.test("supprime tous les facteurs du membre", async () => {
  const { mfa, deleted } = fake(["f1", "f2"]);
  assertEquals(await resetMemberFactors(mfa, "u1"), { removed: 2 });
  assertEquals(deleted, ["f1", "f2"]);
});

Deno.test("un membre sans facteur : rien à supprimer, pas d'erreur", async () => {
  const { mfa } = fake([]);
  assertEquals(await resetMemberFactors(mfa, "u1"), { removed: 0 });
});

Deno.test("s'arrête à la première erreur et la signale", async () => {
  const { mfa, deleted } = fake(["f1", "f2", "f3"], "f2");
  const result = await resetMemberFactors(mfa, "u1");
  assertEquals("failure" in result, true);
  assertEquals(deleted, ["f1"]);
});

Deno.test("une lecture en échec est signalée", async () => {
  const mfa: MfaAdmin = {
    listFactors: () => Promise.resolve({ data: null, error: { message: "réseau" } }),
    deleteFactor: () => Promise.resolve({ error: null }),
  };
  assertEquals("failure" in (await resetMemberFactors(mfa, "u1")), true);
});
