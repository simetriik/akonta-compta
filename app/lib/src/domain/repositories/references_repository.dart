import '../reference_models.dart';

abstract interface class ReferencesRepository {
  Future<List<Account>> accounts(String entityId, {String? prefix, String? search, bool onlyActive = false});

  Future<Account> createAccount(String cabinetId, String entityId, {required String code, required String label, bool? isCollective});

  Future<void> renameAccount(String id, String label);

  Future<void> setAccountActive(String id, bool active);

  Future<void> deleteAccount(String id);

  Future<List<ThirdParty>> thirdParties(String entityId, {String? search});

  Future<ThirdParty> saveThirdParty(String cabinetId, String entityId, {String? id, required String code, required String name, required String type, String? taxId, String? address, String? phone, String? email, required List<String> collectiveAccountIds});

  Future<void> setThirdPartyActive(String id, bool active);

  Future<List<Journal>> journals(String entityId);

  Future<void> saveJournal(String cabinetId, String entityId, {String? id, required String code, required String label, required String type, String? treasuryAccountId});

  Future<void> setJournalActive(String id, bool active);

  Future<List<EntryTemplate>> templates(String entityId);

  Future<void> saveTemplate(String cabinetId, String? entityId, {required String code, required String label, String? journalType, String? description, required List<TemplateLine> lines});

  Future<void> deactivateTemplate(String id);

  Future<List<TaxRate>> taxRates();

  /// Nouveau taux à partir d'une date : le taux précédent du même code est borné à la veille.
  Future<void> addTaxRate(String cabinetId, {required String code, required String label, required double rate, required DateTime validFrom});
}
