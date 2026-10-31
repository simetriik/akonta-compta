import 'package:drift/drift.dart';

part 'local_database.g.dart';

/// Réponses de lecture mises en cache pour le travail hors connexion (clé = requête + utilisateur).
class CachedResponseRows extends Table {
  TextColumn get key => text()();
  IntColumn get status => integer()();
  TextColumn get headers => text()();
  BlobColumn get body => blob()();
  IntColumn get savedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// File d'envoi : actions saisies hors connexion, rejouées à la reconnexion (brouillons d'écritures, pièces).
class OutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  IntColumn get createdAt => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

@DriftDatabase(tables: [CachedResponseRows, OutboxEntries])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
