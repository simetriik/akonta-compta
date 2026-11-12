import '../entity_models.dart';

abstract interface class EntitiesRepository {
  Future<List<EntityDetail>> list();

  Future<EntityDetail> get(String id);

  /// [requestId] rend la création idempotente : rejouée, elle renvoie le dossier déjà créé.
  Future<EntityDetail> create(String cabinetId, EntityInput input, {String? requestId});

  /// Supprime un dossier en double qui ne contient aucune donnée de travail.
  Future<void> deleteEmptyDuplicate(String id);

  Future<void> update(String id, EntityInput input);

  Future<void> setActive(String id, bool active);

  Future<List<Director>> directors(String entityId);

  Future<void> addDirector(String cabinetId, String entityId, {required String fullName, required String position, String? nationality, String? address, bool board = false});

  Future<void> removeDirector(String id);

  Future<List<FiscalYear>> fiscalYears(String entityId);

  Future<FiscalYear> createFiscalYear(String cabinetId, String entityId, {required DateTime start, required DateTime end, String? label, int? capital, int? headcount});

  Future<void> updateFiscalYear(String id, {int? capital, int? headcount});

  Future<List<FiscalYearPartner>> partners(String fiscalYearId);

  Future<void> addPartner(String cabinetId, String fiscalYearId, {required String name, required double sharePercent});

  Future<void> removePartner(String id);

  Future<List<Period>> periods(String fiscalYearId);

  Future<void> lockPeriod(String id);

  Future<void> unlockPeriod(String id, String reason);

  Future<List<EntityHistoryItem>> history(String entityId);

  Future<List<JournalTemplate>> journalTemplates();

  Future<int> createJournalsFromTemplate(String entityId, List<String> codes);

  Future<void> createTreasuryJournal(String cabinetId, String entityId, {required String code, required String label, required String type, required String accountId});

  Future<List<AccountRef>> treasuryAccounts(String entityId);

  Future<int> accountCount(String entityId);
}
