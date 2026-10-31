import 'dart:io';
import 'dart:typed_data';

import 'package:akonta/src/application/offline/in_memory_outbox.dart';
import 'package:akonta/src/application/offline/response_cache.dart';
import 'package:akonta/src/domain/outbox_models.dart';
import 'package:akonta/src/domain/repositories/outbox_repository.dart';
import 'package:akonta/src/infrastructure/local/local_database.dart';
import 'package:akonta/src/infrastructure/local/local_database_native.dart';
import 'package:akonta/src/infrastructure/local/local_outbox_repository.dart';
import 'package:akonta/src/infrastructure/local/local_response_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de conformité : toute implémentation d'un port de stockage (mémoire, base locale chiffrée, demain un autre moteur) doit les réussir.
void outboxContract(String name, Future<OutboxRepository> Function() create, Future<void> Function() dispose) {
  group('file d\'envoi : $name', () {
    late OutboxRepository outbox;

    setUp(() async => outbox = await create());
    tearDown(dispose);

    test('les éléments sont rendus dans l\'ordre d\'arrivée avec leurs données', () async {
      final a = await outbox.enqueue(OutboxKind.entryDraft, {'n': 1, 'lignes': [1, 2]});
      final b = await outbox.enqueue(OutboxKind.documentUpload, {'n': 2});
      final all = await outbox.all();
      expect(all.map((i) => i.id), [a, b]);
      expect(all.first.kind, OutboxKind.entryDraft);
      expect(all.first.payload['lignes'], [1, 2]);
      expect(all.last.hasFailed, isFalse);
    });

    test('un échec est consigné, une mise à jour le remet à zéro', () async {
      final id = await outbox.enqueue(OutboxKind.entryDraft, {'n': 1});
      await outbox.recordFailure(id, 'refusé');
      await outbox.recordFailure(id, 'refusé encore');
      var item = (await outbox.get(id))!;
      expect((item.attempts, item.lastError), (2, 'refusé encore'));
      await outbox.update(id, {'n': 2});
      item = (await outbox.get(id))!;
      expect((item.payload['n'], item.attempts, item.lastError), (2, 0, null));
    });

    test('la suppression retire l\'élément ; un élément inconnu est ignoré sans erreur', () async {
      final id = await outbox.enqueue(OutboxKind.entryDraft, {});
      await outbox.remove(id);
      await outbox.remove(id);
      await outbox.update(999, {});
      await outbox.recordFailure(999, 'x');
      expect(await outbox.get(id), isNull);
      expect(await outbox.all(), isEmpty);
    });

    test('l\'observation émet l\'état courant puis chaque changement', () async {
      final emitted = <int>[];
      final sub = outbox.watch().listen((items) => emitted.add(items.length));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final id = await outbox.enqueue(OutboxKind.entryDraft, {});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await outbox.remove(id);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel();
      expect(emitted.first, 0);
      expect(emitted, containsAllInOrder([0, 1, 0]));
    });
  });
}

void cacheContract(String name, Future<ResponseCache> Function() create, Future<void> Function() dispose) {
  group('cache des lectures : $name', () {
    late ResponseCache cache;

    setUp(() async => cache = await create());
    tearDown(dispose);

    CachedResponse response(int b) => CachedResponse(status: 200, headers: {'content-type': 'application/json'}, body: Uint8List.fromList([b, b + 1]));

    test('lecture après écriture, remplacement et clé inconnue', () async {
      expect(await cache.read('absente'), isNull);
      await cache.write('k', response(1));
      await cache.write('k', response(5));
      final hit = (await cache.read('k'))!;
      expect(hit.body, [5, 6]);
      expect(hit.status, 200);
      expect(hit.headers['content-type'], 'application/json');
    });

    test('le vidage supprime tout', () async {
      await cache.write('a', response(1));
      await cache.write('b', response(2));
      await cache.clear();
      expect(await cache.read('a'), isNull);
      expect(await cache.read('b'), isNull);
    });
  });
}

void main() {
  outboxContract('mémoire', () async => InMemoryOutboxRepository(), () async {});
  cacheContract('mémoire', () async => InMemoryResponseCache(), () async {});

  late Directory dir;
  late LocalDatabase db;
  Future<LocalDatabase> open() async {
    dir = Directory.systemTemp.createTempSync('akonta_contract_');
    db = openLocalDatabaseAt(File('${dir.path}/c.db'), 'ab' * 32);
    return db;
  }

  Future<void> close() async {
    await db.close();
    dir.deleteSync(recursive: true);
  }

  outboxContract('base locale chiffrée', () async => LocalOutboxRepository(await open()), close);
  cacheContract('base locale chiffrée', () async => LocalResponseCache(await open()), close);
}
