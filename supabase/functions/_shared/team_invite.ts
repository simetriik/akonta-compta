// Règles propres à la création de comptes par un associé (droit team.manage) : il crée l'équipe et les clients, avec un rôle et un
// dossier cohérents. La base applique les mêmes règles ; ceci évite de créer un compte pour le défaire ensuite.
export const TEAM_ROLES = ["manager", "assistant", "trainee"] as const;
/** Rôles des clients du cabinet (D-044) : ils visent toujours un dossier précis. */
export const CLIENT_ROLES = ["client_gerant", "client_saisie"] as const;
const ASSIGNABLE_ROLES: readonly string[] = [...TEAM_ROLES, ...CLIENT_ROLES];

export interface TeamInviteRequest {
  csv?: string;
  first_partner?: boolean;
  role?: string;
  entity_id?: string;
}

/**
 * Rôle tenu pour cette demande. Un associé qui cumule `users.manage` agit en associé dès qu'il donne un rôle sur un dossier
 * (le rôle d'équipe ou client est son affaire) ; sinon l'administrateur technique garde la main (CSV, premier associé).
 */
export function actsAsAdmin(caller: { isAdmin: boolean; isPartner: boolean }, req: TeamInviteRequest): boolean {
  if (!caller.isAdmin) return false;
  return !(caller.isPartner && (req.role || req.entity_id));
}

/** Message d'erreur si la demande dépasse ce que peut faire l'appelant, sinon null. */
export function validateInvite(req: TeamInviteRequest, isAdmin: boolean): string | null {
  if (isAdmin) {
    return req.role || req.entity_id ? "L'administrateur technique ne donne pas de rôle d'équipe : c'est l'affaire de l'associé" : null;
  }
  if (req.first_partner) return "Réservé à l'administrateur technique";
  if (req.csv) return "L'import CSV est réservé à l'administrateur technique";
  if (req.role && !ASSIGNABLE_ROLES.includes(req.role)) return "Rôle non attribuable : chef de mission, assistant, stagiaire ou rôle client seulement";
  if (req.role && !req.entity_id) return "Un rôle d'équipe s'attribue sur un dossier précis";
  if (!req.role && req.entity_id) return "Choisissez aussi le rôle de la personne sur ce dossier";
  return null;
}
