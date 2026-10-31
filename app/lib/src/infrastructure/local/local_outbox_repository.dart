import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/outbox_models.dart';
import '../../domain/repositories/outbox_repository.dart';
import 'local_database.dart';

/// File d'envoi conservée dans la base locale chiffrée : survit à la fermeture de l'application et à une coupure de courant.
class LocalOutboxRepository implements OutboxRepository {
  LocalOutboxRepository(this._db);

  final LocalDatabase _db;

  OutboxItem _toItem(OutboxEntry r) => OutboxItem(
        id: r.id,
        kind: r.kind,
        payload: Map<String, dynamic>.from(jsonDecode(r.payload) as Map),
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
        attempts: r.attempts,
        lastError: r.lastError,
      );

  @override
  Future<int> enqueue(String kind, Map<String, dynamic> payload) =>
      _db.into(_db.outboxEntries).insert(OutboxEntriesCompanion.insert(kind: kind, payload: jsonEncode(payload), createdAt: DateTime.now().millisecondsSinceEpoch));

  @override
  Future<List<OutboxItem>> all() async => (await (_db.select(_db.outboxEntries)..orderBy([(t) => OrderingTerm.asc(t.id)])).get()).map(_toItem).toList();

  @override
  Future<OutboxItem?> get(int id) async {
    final r = await (_db.select(_db.outboxEntries)..where((t) => t.id.equals(id))).getSingleOrNull();
    return r == null ? null : _toItem(r);
  }

  @override
  Future<void> update(int id, Map<String, dynamic> payload) =>
      (_db.update(_db.outboxEntries)..where((t) => t.id.equals(id))).write(OutboxEntriesCompanion(payload: Value(jsonEncode(payload)), lastError: const Value(null), attempts: const Value(0)));

  @override
  Future<void> remove(int id) => (_db.delete(_db.outboxEntries)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> recordFailure(int id, String error) async {
    final r = await (_db.select(_db.outboxEntries)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (r == null) return;
    await (_db.update(_db.outboxEntries)..where((t) => t.id.equals(id))).write(OutboxEntriesCompanion(attempts: Value(r.attempts + 1), lastError: Value(error)));
  }

  @override
  Stream<List<OutboxItem>> watch() => (_db.select(_db.outboxEntries)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch().map((rows) => rows.map(_toItem).toList());
}
