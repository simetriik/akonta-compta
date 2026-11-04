import 'package:shared_preferences/shared_preferences.dart';

import '../../application/preferences/last_entity_store.dart';

/// Dernier dossier ouvert, gardé dans les préférences de l'appareil (localStorage sur le web), une clé par utilisateur.
/// Seul un identifiant est conservé : aucune donnée comptable.
class SharedPrefsLastEntityStore implements LastEntityStore {
  const SharedPrefsLastEntityStore(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String userId) => 'last_entity.$userId';

  @override
  Future<String?> read(String userId) async => _prefs.getString(_key(userId));

  @override
  Future<void> write(String userId, String? entityId) async {
    if (entityId == null) {
      await _prefs.remove(_key(userId));
    } else {
      await _prefs.setString(_key(userId), entityId);
    }
  }
}
