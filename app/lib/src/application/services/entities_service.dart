import '../connectivity/connectivity.dart';
import '../../domain/repositories/entities_repository.dart';
import '../../domain/entity_models.dart';

/// Cas d'usage entities : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class EntitiesService {
  EntitiesService(this._repository, this._online);

  final EntitiesRepository _repository;
  final OnlinePolicy _online;

  Future<List<EntityDetail>> list() async {
    return _repository.list();
  }

  Future<EntityDetail> get(String id) async {
    return _repository.get(id);
  }

  Future<EntityDetail> create(String cabinetId, EntityInput input, {String? requestId}) async {
    _online.require('La gestion des dossiers');
    return _repository.create(cabinetId, input, requestId: requestId);
  }

  /// Supprime un dossier en double tant qu'il est vide (refusé par la base dès qu'il contient des données).
  Future<void> deleteEmptyDuplicate(String id) async {
    _online.require('La gestion des dossiers');
    return _repository.deleteEmptyDuplicate(id);
  }

  Future<void> update(String id, EntityInput input) async {
    _online.require('La gestion des dossiers');
    return _repository.update(id, input);
  }

  Future<void> setActive(String id, bool active) async {
    _online.require('La gestion des dossiers');
    return _repository.setActive(id, active);
  }

  Future<List<Director>> directors(String entityId) async {
    _online.require('La gestion des dossiers');
    return _repository.directors(entityId);
  }

  Future<void> addDirector(
    String cabinetId,
    String entityId, {
    required String fullName,
    required String position,
    String? nationality,
    String? address,
    bool board = false,
  }) async {
    _online.require('La gestion des dossiers');
    return _repository.addDirector(cabinetId, entityId, fullName: fullName, position: position, nationality: nationality, address: address, board: board);
  }

  Future<void> removeDirector(String id) async {
    _online.require('La gestion des dossiers');
    return _repository.removeDirector(id);
  }

  Future<List<FiscalYear>> fiscalYears(String entityId) async {
    return _repository.fiscalYears(entityId);
  }

  Future<FiscalYear> createFiscalYear(
    String cabinetId,
    String entityId, {
    required DateTime start,
    required DateTime end,
    String? label,
    int? capital,
    int? headcount,
  }) async {
    _online.require('La gestion des dossiers');
    return _repository.createFiscalYear(cabinetId, entityId, start: start, end: end, label: label, capital: capital, headcount: headcount);
  }

  Future<void> updateFiscalYear(String id, {int? capital, int? headcount}) async {
    _online.require('La gestion des dossiers');
    return _repository.updateFiscalYear(id, capital: capital, headcount: headcount);
  }

  Future<List<FiscalYearPartner>> partners(String fiscalYearId) async {
    _online.require('La gestion des dossiers');
    return _repository.partners(fiscalYearId);
  }

  Future<void> addPartner(String cabinetId, String fiscalYearId, {required String name, required double sharePercent}) async {
    _online.require('La gestion des dossiers');
    return _repository.addPartner(cabinetId, fiscalYearId, name: name, sharePercent: sharePercent);
  }

  Future<void> removePartner(String id) async {
    _online.require('La gestion des dossiers');
    return _repository.removePartner(id);
  }

  Future<List<Period>> periods(String fiscalYearId) async {
    return _repository.periods(fiscalYearId);
  }

  Future<void> lockPeriod(String id) async {
    _online.require('La gestion des dossiers');
    return _repository.lockPeriod(id);
  }

  Future<void> unlockPeriod(String id, String reason) async {
    _online.require('La gestion des dossiers');
    return _repository.unlockPeriod(id, reason);
  }

  Future<List<EntityHistoryItem>> history(String entityId) async {
    _online.require('La gestion des dossiers');
    return _repository.history(entityId);
  }

  Future<List<JournalTemplate>> journalTemplates() async {
    _online.require('La gestion des dossiers');
    return _repository.journalTemplates();
  }

  Future<int> createJournalsFromTemplate(String entityId, List<String> codes) async {
    _online.require('La gestion des dossiers');
    return _repository.createJournalsFromTemplate(entityId, codes);
  }

  Future<void> createTreasuryJournal(
    String cabinetId,
    String entityId, {
    required String code,
    required String label,
    required String type,
    required String accountId,
  }) async {
    _online.require('La gestion des dossiers');
    return _repository.createTreasuryJournal(cabinetId, entityId, code: code, label: label, type: type, accountId: accountId);
  }

  Future<List<AccountRef>> treasuryAccounts(String entityId) async {
    _online.require('La gestion des dossiers');
    return _repository.treasuryAccounts(entityId);
  }

  Future<int> accountCount(String entityId) async {
    _online.require('La gestion des dossiers');
    return _repository.accountCount(entityId);
  }
}
