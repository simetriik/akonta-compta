import '../connectivity/connectivity.dart';
import '../../domain/repositories/entries_repository.dart';
import '../../domain/entry_models.dart';

/// Cas d'usage entries : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class EntriesService {
  EntriesService(this._repository, this._online);

  final EntriesRepository _repository;
  final OnlinePolicy _online;

  Future<List<EntryModel>> list(String entityId, EntryFilter f, {String? fiscalYearId, int limit = 300}) async {
    return _repository.list(entityId, f, fiscalYearId: fiscalYearId, limit: limit);
  }

  Future<EntryModel> get(String id) async {
    return _repository.get(id);
  }

  Future<String> saveDraft(String cabinetId, String entityId, EntryDraft d) async {
    return _repository.saveDraft(cabinetId, entityId, d);
  }

  Future<void> deleteDraft(String id) async {
    return _repository.deleteDraft(id);
  }

  Future<int> validate(String id) async {
    _online.require('La validation des écritures');
    return _repository.validate(id);
  }

  Future<void> validateMany(List<String> ids) async {
    _online.require('La validation et la revue des écritures');
    return _repository.validateMany(ids);
  }

  Future<String> reverse(String id, {required String reason, DateTime? date}) async {
    _online.require('La contre-passation');
    return _repository.reverse(id, reason: reason, date: date);
  }

  Future<void> review(String id, {required String status, String? comment}) async {
    _online.require('La revue des écritures');
    return _repository.review(id, status: status, comment: comment);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    _online.require('La validation et la revue des écritures');
    return _repository.notifications();
  }

  Future<void> markRead(int id) async {
    _online.require('La validation et la revue des écritures');
    return _repository.markRead(id);
  }
}
