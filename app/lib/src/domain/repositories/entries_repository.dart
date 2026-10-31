import '../entry_models.dart';

abstract interface class EntriesRepository {
  Future<List<EntryModel>> list(String entityId, EntryFilter f, {String? fiscalYearId, int limit = 300});

  Future<EntryModel> get(String id);

  Future<String> saveDraft(String cabinetId, String entityId, EntryDraft d);

  Future<void> deleteDraft(String id);

  Future<int> validate(String id);

  Future<void> validateMany(List<String> ids);

  Future<String> reverse(String id, {required String reason, DateTime? date});

  Future<void> review(String id, {required String status, String? comment});

  Future<List<Map<String, dynamic>>> notifications();

  Future<void> markRead(int id);
}
