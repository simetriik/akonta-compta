import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_database.dart';

const _keyName = 'akonta_local_db_key';

/// Ouvre une base chiffrée (SQLite3 Multiple Ciphers) avec la clé hexadécimale donnée ; `PRAGMA key` doit être la première instruction.
LocalDatabase openLocalDatabaseAt(File file, String hexKey) => LocalDatabase(NativeDatabase(file, setup: (db) => db.execute('PRAGMA key = "x\'$hexKey\'";')));

String _newKey() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Base locale de l'application : fichier dans le dossier de l'application, clé de chiffrement dans le trousseau du système.
/// Renvoie null si la clé ne peut pas être conservée en sécurité (aucune donnée n'est alors écrite sur disque).
Future<LocalDatabase?> openLocalDatabase() async {
  try {
    const storage = FlutterSecureStorage();
    var key = await storage.read(key: _keyName);
    if (key == null) {
      key = _newKey();
      await storage.write(key: _keyName, value: key);
    }
    final dir = await getApplicationSupportDirectory();
    return openLocalDatabaseAt(File(p.join(dir.path, 'akonta_local.db')), key);
  } catch (_) {
    return null;
  }
}
