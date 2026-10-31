import 'dart:typed_data';

/// Réponse de lecture conservée pour le travail hors connexion.
class CachedResponse {
  const CachedResponse({required this.status, required this.headers, required this.body});

  final int status;
  final Map<String, String> headers;
  final Uint8List body;
}

/// Cache des lectures déjà effectuées ; implémenté par la base locale chiffrée.
abstract interface class ResponseCache {
  Future<CachedResponse?> read(String key);

  Future<void> write(String key, CachedResponse response);

  /// Vide le cache (déconnexion, changement d'utilisateur).
  Future<void> clear();
}
