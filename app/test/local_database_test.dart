import 'dart:io';
import 'dart:typed_data';

import 'package:akonta/src/application/offline/response_cache.dart';
import 'package:akonta/src/domain/outbox_models.dart';
import 'package:akonta/src/infrastructure/local/local_database_native.dart';
import 'package:akonta/src/infrastructure/local/local_outbox_repository.dart';
import 'package:akonta/src/infrastructure/local/local_response_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// Base locale chiffrée (SQLite3 Multiple Ciphers) : les données survivent à la fermeture, ne se lisent pas sans la clé et ne sont pas
/// en clair sur le disque.
void main() {
  const key = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('akonta_db_');
    file = File('${dir.path}/local.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('file d\'envoi et cache survivent à la fermeture et à la réouverture', () async {
    var db = openLocalDatabaseAt(file, key);
    final outbox = LocalOutboxRepository(db);
    final id = await outbox.enqueue(OutboxKind.entryDraft, {'label': 'Loyer', 'lines': [1, 2]});
    await LocalResponseCache(db).write('k', CachedResponse(status: 200, headers: const {'content-type': 'application/json'}, body: Uint8List.fromList([7, 8, 9])));
    await db.close();

    db = openLocalDatabaseAt(file, key);
    final item = (await LocalOutboxRepository(db).get(id))!;
    expect(item.payload['label'], 'Loyer');
    expect(item.kind, OutboxKind.entryDraft);
    final cached = (await LocalResponseCache(db).read('k'))!;
    expect(cached.body, [7, 8, 9]);
    expect(cached.headers['content-type'], 'application/json');
    await db.close();
  });

  test('le fichier n\'est pas lisible sans la clé et ne contient pas de SQLite en clair', () async {
    final db = openLocalDatabaseAt(file, key);
    await LocalOutboxRepository(db).enqueue(OutboxKind.entryDraft, {'label': 'DONNEE-CONFIDENTIELLE'});
    await db.close();

    final bytes = file.readAsBytesSync();
    expect(String.fromCharCodes(bytes.take(16)), isNot(startsWith('SQLite format 3')));
    expect(String.fromCharCodes(bytes).contains('DONNEE-CONFIDENTIELLE'), isFalse);

    final wrong = openLocalDatabaseAt(file, 'ff' * 32);
    await expectLater(LocalOutboxRepository(wrong).all(), throwsA(anything));
    await wrong.close();
  });

  test('mise à jour, échec et suppression d\'un élément de la file', () async {
    final db = openLocalDatabaseAt(file, key);
    final outbox = LocalOutboxRepository(db);
    final id = await outbox.enqueue(OutboxKind.documentUpload, {'file_name': 'a.pdf'});
    await outbox.recordFailure(id, 'Format refusé');
    var item = (await outbox.get(id))!;
    expect((item.attempts, item.lastError), (1, 'Format refusé'));
    await outbox.update(id, {'file_name': 'b.pdf'});
    item = (await outbox.get(id))!;
    expect((item.payload['file_name'], item.attempts, item.lastError), ('b.pdf', 0, null));
    expect((await outbox.watch().first).length, 1);
    await outbox.remove(id);
    expect(await outbox.all(), isEmpty);
    await db.close();
  });
}
