// Règles propres à la création de comptes par un associé (droit team.manage) : il ne crée que l'équipe, avec un rôle et un
// dossier cohérents. La base applique les mêmes règles ; ceci évite de créer un compte pour le défaire ensuite.
export const TEAM_ROLES = ["manager", "assistant", "trainee"] as const;

export interface TeamInviteRequest {
  csv?: string;
  first_partner?: boolean;
  role?: string;
  entity_id?: string;
}

/** Message d'erreur si la demande dépasse ce que peut faire l'appelant, sinon null. */
export function validateInvite(req: TeamInviteRequest, isAdmin: boolean): string | null {
  if (isAdmin) {
    return req.role || req.entity_id ? "L'administrateur technique ne donne pas de rôle d'équipe : c'est l'affaire de l'associé" : null;
  }
  if (req.first_partner) return "Réservé à l'administrateur technique";
  if (req.csv) return "L'import CSV est réservé à l'administrateur technique";
  if (req.role && !(TEAM_ROLES as readonly string[]).includes(req.role)) return "Rôle non attribuable : chef de mission, assistant ou stagiaire seulement";
  if (req.role && !req.entity_id) return "Un rôle d'équipe s'attribue sur un dossier précis";
  if (!req.role && req.entity_id) return "Choisissez aussi le rôle de la personne sur ce dossier";
  return null;
}
