// Réinitialisation de la double vérification d'un membre : suppression de tous ses facteurs (TOTP).
// Le mot de passe et le compte ne changent pas ; à sa prochaine connexion, un rôle qui exige la double
// vérification renvoie le membre vers l'enrôlement d'un nouvel authentificateur.

/** Partie de l'API d'administration Auth dont on a besoin (permet de tester sans réseau). */
export interface MfaAdmin {
  listFactors(args: { userId: string }): Promise<{ data: { factors: { id: string }[] } | null; error: { message: string } | null }>;
  deleteFactor(args: { id: string; userId: string }): Promise<{ error: { message: string } | null }>;
}

export type MfaResetResult = { removed: number } | { failure: string };

/** Supprime tous les facteurs du membre ; s'arrête à la première erreur (rien n'est avalé). */
export async function resetMemberFactors(mfa: MfaAdmin, userId: string): Promise<MfaResetResult> {
  const listed = await mfa.listFactors({ userId });
  if (listed.error || !listed.data) return { failure: `Lecture des facteurs impossible : ${listed.error?.message ?? "inconnu"}` };
  let removed = 0;
  for (const factor of listed.data.factors) {
    const result = await mfa.deleteFactor({ id: factor.id, userId });
    if (result.error) return { failure: `Suppression impossible : ${result.error.message}` };
    removed++;
  }
  return { removed };
}
