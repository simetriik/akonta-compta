import 'dart:async';

import '../../domain/outbox_models.dart';
import '../../domain/repositories/outbox_repository.dart';

/// File d'envoi en mémoire : valeur par défaut (web, tests) ; perdue à la fermeture de l'application.
class InMemoryOutboxRepository implements OutboxRepository {
  final Map<int, OutboxItem> _items = {};
  final StreamController<List<OutboxItem>> _changes = StreamController<List<OutboxItem>>.broadcast();
  int _nextId = 1;

  List<OutboxItem> get _snapshot => (_items.values.toList()..sort((a, b) => a.id.compareTo(b.id)));

  void _notify() => _changes.add(_snapshot);

  @override
  Future<int> enqueue(String kind, Map<String, dynamic> payload) async {
    final id = _nextId++;
    _items[id] = OutboxItem(id: id, kind: kind, payload: Map.of(payload), createdAt: DateTime.now());
    _notify();
    return id;
  }

  @override
  Future<List<OutboxItem>> all() async => _snapshot;

  @override
  Future<OutboxItem?> get(int id) async => _items[id];

  @override
  Future<void> update(int id, Map<String, dynamic> payload) async {
    final old = _items[id];
    if (old == null) return;
    _items[id] = OutboxItem(id: id, kind: old.kind, payload: Map.of(payload), createdAt: old.createdAt);
    _notify();
  }

  @override
  Future<void> remove(int id) async {
    _items.remove(id);
    _notify();
  }

  @override
  Future<void> recordFailure(int id, String error) async {
    final old = _items[id];
    if (old == null) return;
    _items[id] = OutboxItem(id: id, kind: old.kind, payload: old.payload, createdAt: old.createdAt, attempts: old.attempts + 1, lastError: error);
    _notify();
  }

  @override
  Stream<List<OutboxItem>> watch() async* {
    yield _snapshot;
    yield* _changes.stream;
  }
}
