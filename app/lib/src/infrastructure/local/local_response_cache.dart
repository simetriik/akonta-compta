import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../../application/offline/response_cache.dart';
import 'local_database.dart';

/// Cache des lectures dans la base locale chiffrée.
class LocalResponseCache implements ResponseCache {
  LocalResponseCache(this._db);

  final LocalDatabase _db;

  @override
  Future<CachedResponse?> read(String key) async {
    final r = await (_db.select(_db.cachedResponseRows)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (r == null) return null;
    return CachedResponse(status: r.status, headers: Map<String, String>.from(jsonDecode(r.headers) as Map), body: r.body);
  }

  @override
  Future<void> write(String key, CachedResponse response) => _db.into(_db.cachedResponseRows).insertOnConflictUpdate(
        CachedResponseRowsCompanion.insert(key: key, status: response.status, headers: jsonEncode(response.headers), body: response.body, savedAt: DateTime.now().millisecondsSinceEpoch),
      );

  @override
  Future<void> clear() => _db.delete(_db.cachedResponseRows).go();
}

/// Cache en mémoire : web et tests ; perdu au rechargement.
class InMemoryResponseCache implements ResponseCache {
  final Map<String, CachedResponse> _entries = {};

  @override
  Future<CachedResponse?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, CachedResponse response) async => _entries[key] = CachedResponse(status: response.status, headers: Map.of(response.headers), body: Uint8List.fromList(response.body));

  @override
  Future<void> clear() async => _entries.clear();
}
