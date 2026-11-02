/// Accès des clients du cabinet à leur dossier (D-044) : interrupteur par dossier et retour d'un brouillard au client.
abstract interface class ClientAccessRepository {
  /// État de l'accès : `disabled`, `active` ou `suspended`.
  Future<String> access(String entityId);

  /// Ouvre, suspend (lecture seule) ou ferme l'accès des clients ; la base inscrit le changement dans la piste d'audit.
  Future<void> setAccess(String entityId, String status, {String? reason});

  /// Renvoie un brouillard de client avec un motif ; le client est notifié.
  Future<void> returnDraft(String entryId, String comment);
}
