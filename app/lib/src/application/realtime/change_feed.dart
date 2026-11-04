/// Famille de données dont un autre utilisateur peut avoir modifié le contenu.
enum ChangeTopic { entries, documents, notifications, invoices }

/// Écoute ouverte sur les changements : un simple signal « quelque chose a changé », sans donnée métier.
abstract interface class ChangeSubscription {
  /// Un élément par changement détecté dans le dossier (ou pour l'utilisateur) écouté.
  Stream<ChangeTopic> get changes;

  /// Vrai tant que le canal est abonné ; faux pendant une coupure ou une reconnexion.
  Stream<bool> get connection;

  bool get isConnected;

  Future<void> close();
}

/// Ouvre les écoutes de changements ; implémenté par l'infrastructure (Supabase Realtime).
abstract interface class ChangeFeedPort {
  /// Écoute le dossier `entityId` (null : seulement ce qui concerne l'utilisateur). Renvoie null si l'écoute n'est pas disponible.
  ChangeSubscription? open({required String userId, String? entityId});
}

/// Aucune écoute : valeur par défaut (tests, première génération) avant branchement de l'adaptateur réel.
class NoChangeFeed implements ChangeFeedPort {
  const NoChangeFeed();

  @override
  ChangeSubscription? open({required String userId, String? entityId}) => null;
}
