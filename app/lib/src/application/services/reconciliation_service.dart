import '../connectivity/connectivity.dart';
import '../../domain/repositories/reconciliation_repository.dart';
import '../../domain/bank_models.dart';

/// Cas d'usage reconciliation : les écrans passent par ce service, qui applique la règle de connexion avant d'appeler le dépôt.
class ReconciliationService {
  ReconciliationService(this._repository, this._online);

  final ReconciliationRepository _repository;
  final OnlinePolicy _online;

  Future<List<StatementTemplate>> templates() async {
    _online.require('Le rapprochement bancaire');
    return _repository.templates();
  }

  Future<StatementTemplate> saveTemplate(String cabinetId, StatementTemplate t) async {
    _online.require('Le rapprochement bancaire');
    return _repository.saveTemplate(cabinetId, t);
  }

  Future<String> importStatement({required String journalId, required DateTime from, required DateTime to, required List<ParsedStatementLine> lines, int? opening, int? closing, String? templateId, String? fileName}) async {
    _online.require('Le rapprochement bancaire');
    return _repository.importStatement(journalId: journalId, from: from, to: to, lines: lines, opening: opening, closing: closing, templateId: templateId, fileName: fileName);
  }

  Future<List<StatementLine>> unmatchedStatementLines(String journalId, {DateTime? until}) async {
    _online.require('Le rapprochement bancaire');
    return _repository.unmatchedStatementLines(journalId, until: until);
  }

  Future<List<BookLine>> unmatchedBookLines(String journalId, {DateTime? until}) async {
    _online.require('Le rapprochement bancaire');
    return _repository.unmatchedBookLines(journalId, until: until);
  }

  Future<List<ReconciliationProposalModel>> proposals(String journalId, {DateTime? until}) async {
    _online.require('Le rapprochement bancaire');
    return _repository.proposals(journalId, until: until);
  }

  Future<String> match(String journalId, List<int> statementLineIds, List<String> entryLineIds, {String? note}) async {
    _online.require('Le rapprochement bancaire');
    return _repository.match(journalId, statementLineIds, entryLineIds, note: note);
  }

  Future<ReconciliationStateModel> state(String journalId, DateTime asOf) async {
    _online.require('Le rapprochement bancaire');
    return _repository.state(journalId, asOf);
  }

/// Crée (et valide puis pointe) l'écriture d'une ligne de relevé ; [entryDate] permet de la dater
  /// dans une période ouverte quand celle de l'opération est verrouillée.
  Future<String> entryFromLine(int lineId, {required String accountId, String? thirdPartyId, String? label, DateTime? entryDate, bool validate = true}) async {
    _online.require('Le rapprochement bancaire');
    return _repository.entryFromLine(lineId, accountId: accountId, thirdPartyId: thirdPartyId, label: label, entryDate: entryDate, validate: validate);
  }

  Future<String> finalize(String journalId, DateTime asOf) async {
    _online.require('Le rapprochement bancaire');
    return _repository.finalize(journalId, asOf);
  }

  Future<List<Map<String, dynamic>>> finalStatements(String journalId) async {
    _online.require('Le rapprochement bancaire');
    return _repository.finalStatements(journalId);
  }
}
