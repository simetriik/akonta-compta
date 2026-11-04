/// Mémoire du dernier dossier ouvert par utilisateur ; implémentée par l'infrastructure (stockage local de l'appareil).
abstract interface class LastEntityStore {
  /// Identifiant du dernier dossier choisi par cet utilisateur, ou null.
  Future<String?> read(String userId);

  /// Mémorise le dossier choisi (null : l'oublie).
  Future<void> write(String userId, String? entityId);
}

/// Aucune mémoire : valeur par défaut (tests, première génération) avant branchement de l'adaptateur réel.
class NoLastEntityStore implements LastEntityStore {
  const NoLastEntityStore();

  @override
  Future<String?> read(String userId) async => null;

  @override
  Future<void> write(String userId, String? entityId) async {}
}
