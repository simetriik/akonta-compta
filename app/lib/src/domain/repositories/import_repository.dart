import '../import_models.dart';

abstract interface class ImportRepository {
  Future<List<ImportBatch>> batches(String entityId);

  Future<ImportBatch> createBatch({required String cabinetId, required String entityId, required String kind, required String fileName, String? targetJournalId});

  Future<Map<String, dynamic>> parseJournalText(String batchId, String text);

  Future<int> loadLines(String batchId, List<Map<String, dynamic>> lines);

  Future<Map<String, dynamic>> proposeMappings(String batchId);

  Future<List<AccountMapping>> mappings(String entityId, String batchId);

  Future<void> updateMapping(String id, {String? accountCode, String? thirdPartyCode, String? thirdPartyName, bool? createThirdParty});

  Future<Map<String, dynamic>> apply(String batchId, {required bool dryRun});

  Future<void> setTargetJournal(String batchId, String? journalId);
}
