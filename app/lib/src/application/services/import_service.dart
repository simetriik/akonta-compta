import '../connectivity/connectivity.dart';
import '../../domain/repositories/import_repository.dart';
import '../../domain/import_models.dart';

/// Cas d'usage import : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class ImportService {
  ImportService(this._repository, this._online);

  final ImportRepository _repository;
  final OnlinePolicy _online;

  Future<List<ImportBatch>> batches(String entityId) async {
    _online.require('L\'import');
    return _repository.batches(entityId);
  }

  Future<ImportBatch> createBatch({
    required String cabinetId,
    required String entityId,
    required String kind,
    required String fileName,
    String? targetJournalId,
  }) async {
    _online.require('L\'import');
    return _repository.createBatch(cabinetId: cabinetId, entityId: entityId, kind: kind, fileName: fileName, targetJournalId: targetJournalId);
  }

  Future<Map<String, dynamic>> parseJournalText(String batchId, String text) async {
    _online.require('L\'import');
    return _repository.parseJournalText(batchId, text);
  }

  Future<int> loadLines(String batchId, List<Map<String, dynamic>> lines) async {
    _online.require('L\'import');
    return _repository.loadLines(batchId, lines);
  }

  Future<Map<String, dynamic>> proposeMappings(String batchId) async {
    _online.require('L\'import');
    return _repository.proposeMappings(batchId);
  }

  Future<List<AccountMapping>> mappings(String entityId, String batchId) async {
    _online.require('L\'import');
    return _repository.mappings(entityId, batchId);
  }

  Future<void> updateMapping(String id, {String? accountCode, String? thirdPartyCode, String? thirdPartyName, bool? createThirdParty}) async {
    _online.require('L\'import');
    return _repository.updateMapping(
      id,
      accountCode: accountCode,
      thirdPartyCode: thirdPartyCode,
      thirdPartyName: thirdPartyName,
      createThirdParty: createThirdParty,
    );
  }

  Future<Map<String, dynamic>> apply(String batchId, {required bool dryRun}) async {
    _online.require('L\'import');
    return _repository.apply(batchId, dryRun: dryRun);
  }

  Future<void> setTargetJournal(String batchId, String? journalId) async {
    _online.require('L\'import');
    return _repository.setTargetJournal(batchId, journalId);
  }
}
