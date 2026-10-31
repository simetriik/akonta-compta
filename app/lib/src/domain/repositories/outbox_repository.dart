import '../outbox_models.dart';

/// Stockage de la file d'envoi (base locale sur ordinateur et mobile, mémoire sur le web).
abstract interface class OutboxRepository {
  Future<int> enqueue(String kind, Map<String, dynamic> payload);

  Future<List<OutboxItem>> all();

  Future<OutboxItem?> get(int id);

  /// Remplace les données d'une action encore en attente (brouillon modifié avant la reconnexion).
  Future<void> update(int id, Map<String, dynamic> payload);

  Future<void> remove(int id);

  /// Consigne un échec de rejeu qui n'est pas un défaut de connexion.
  Future<void> recordFailure(int id, String error);

  /// Contenu de la file à chaque changement.
  Stream<List<OutboxItem>> watch();
}
