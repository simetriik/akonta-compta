/// Texte français d'une notification de la base (`notifications.kind` + `payload`).
abstract final class NotificationText {
  static String describe(Map<String, dynamic> n) {
    final payload = (n['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
    switch (n['kind']) {
      case 'assigned':
        final by = payload['by'] as String?;
        final role = (payload['role'] as String? ?? 'membre').toLowerCase();
        final entity = payload['entity'] as String? ?? 'un dossier';
        return 'Vous êtes affecté(e) au dossier « $entity » comme $role${by == null ? '' : ' (par $by)'}.';
      case 'entry_to_correct':
        final comment = payload['comment'] as String?;
        return 'Une écriture est à corriger${payload['number'] == null ? '' : ' (n° ${payload['number']})'}${comment == null || comment.isEmpty ? '' : ' : $comment'}.';
      default:
        return 'Nouvelle notification.';
    }
  }

  /// Dossier concerné, si la notification en désigne un.
  static String? entityId(Map<String, dynamic> n) => n['entity_id'] as String?;
}
