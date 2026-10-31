/// File d'envoi : actions saisies hors connexion, rejouées à la reconnexion.
library;

/// Nature d'une action en attente.
abstract final class OutboxKind {
  /// Enregistrement d'un brouillard d'écriture (nouveau ou modifié).
  static const entryDraft = 'entry_draft';

  /// Dépôt d'une pièce justificative.
  static const documentUpload = 'document_upload';
}

class OutboxItem {
  const OutboxItem({required this.id, required this.kind, required this.payload, required this.createdAt, this.attempts = 0, this.lastError});

  final int id;
  final String kind;

  /// Données de l'action, au format JSON simple (voir `application/offline/outbox_codec.dart`).
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// Nombre d'échecs de rejeu non liés à la connexion.
  final int attempts;
  final String? lastError;

  bool get hasFailed => lastError != null;
}
