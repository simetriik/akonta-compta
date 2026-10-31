import '../connectivity/connectivity.dart';
import '../../domain/repositories/references_repository.dart';
import '../../domain/reference_models.dart';

/// Cas d'usage references : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class ReferencesService {
  ReferencesService(this._repository, this._online);

  final ReferencesRepository _repository;
  final OnlinePolicy _online;

  Future<List<Account>> accounts(String entityId, {String? prefix, String? search, bool onlyActive = false}) async {
    return _repository.accounts(entityId, prefix: prefix, search: search, onlyActive: onlyActive);
  }

  Future<Account> createAccount(String cabinetId, String entityId, {required String code, required String label, bool? isCollective}) async {
    _online.require('La modification des référentiels');
    return _repository.createAccount(cabinetId, entityId, code: code, label: label, isCollective: isCollective);
  }

  Future<void> renameAccount(String id, String label) async {
    _online.require('La modification des référentiels');
    return _repository.renameAccount(id, label);
  }

  Future<void> setAccountActive(String id, bool active) async {
    _online.require('La modification des référentiels');
    return _repository.setAccountActive(id, active);
  }

  Future<void> deleteAccount(String id) async {
    _online.require('La modification des référentiels');
    return _repository.deleteAccount(id);
  }

  Future<List<ThirdParty>> thirdParties(String entityId, {String? search}) async {
    return _repository.thirdParties(entityId, search: search);
  }

  Future<ThirdParty> saveThirdParty(
    String cabinetId,
    String entityId, {
    String? id,
    required String code,
    required String name,
    required String type,
    String? taxId,
    String? address,
    String? phone,
    String? email,
    required List<String> collectiveAccountIds,
  }) async {
    _online.require('La modification des référentiels');
    return _repository.saveThirdParty(
      cabinetId,
      entityId,
      id: id,
      code: code,
      name: name,
      type: type,
      taxId: taxId,
      address: address,
      phone: phone,
      email: email,
      collectiveAccountIds: collectiveAccountIds,
    );
  }

  Future<void> setThirdPartyActive(String id, bool active) async {
    _online.require('La modification des référentiels');
    return _repository.setThirdPartyActive(id, active);
  }

  Future<List<Journal>> journals(String entityId) async {
    return _repository.journals(entityId);
  }

  Future<void> saveJournal(
    String cabinetId,
    String entityId, {
    String? id,
    required String code,
    required String label,
    required String type,
    String? treasuryAccountId,
  }) async {
    _online.require('La modification des référentiels');
    return _repository.saveJournal(cabinetId, entityId, id: id, code: code, label: label, type: type, treasuryAccountId: treasuryAccountId);
  }

  Future<void> setJournalActive(String id, bool active) async {
    _online.require('La modification des référentiels');
    return _repository.setJournalActive(id, active);
  }

  Future<List<EntryTemplate>> templates(String entityId) async {
    return _repository.templates(entityId);
  }

  Future<void> saveTemplate(
    String cabinetId,
    String? entityId, {
    required String code,
    required String label,
    String? journalType,
    String? description,
    required List<TemplateLine> lines,
  }) async {
    _online.require('La modification des référentiels');
    return _repository.saveTemplate(cabinetId, entityId, code: code, label: label, journalType: journalType, description: description, lines: lines);
  }

  Future<void> deactivateTemplate(String id) async {
    _online.require('La modification des référentiels');
    return _repository.deactivateTemplate(id);
  }

  Future<List<TaxRate>> taxRates() async {
    return _repository.taxRates();
  }

  /// Nouveau taux à partir d'une date : le taux précédent du même code est borné à la veille.
  Future<void> addTaxRate(String cabinetId, {required String code, required String label, required double rate, required DateTime validFrom}) async {
    _online.require('La modification des référentiels');
    return _repository.addTaxRate(cabinetId, code: code, label: label, rate: rate, validFrom: validFrom);
  }
}
