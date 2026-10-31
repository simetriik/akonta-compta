import '../bank_models.dart';

abstract interface class ReconciliationRepository {
  Future<List<StatementTemplate>> templates();

  Future<StatementTemplate> saveTemplate(String cabinetId, StatementTemplate t);

  Future<String> importStatement({required String journalId, required DateTime from, required DateTime to, required List<ParsedStatementLine> lines, int? opening, int? closing, String? templateId, String? fileName});

  Future<List<StatementLine>> unmatchedStatementLines(String journalId, {DateTime? until});

  Future<List<BookLine>> unmatchedBookLines(String journalId, {DateTime? until});

  Future<List<ReconciliationProposalModel>> proposals(String journalId, {DateTime? until});

  Future<String> match(String journalId, List<int> statementLineIds, List<String> entryLineIds, {String? note});

  Future<ReconciliationStateModel> state(String journalId, DateTime asOf);

  /// Crée (et valide puis pointe) l'écriture d'une ligne de relevé ; [entryDate] permet de la dater
  /// dans une période ouverte quand celle de l'opération est verrouillée.
  Future<String> entryFromLine(int lineId, {required String accountId, String? thirdPartyId, String? label, DateTime? entryDate, bool validate = true});

  Future<String> finalize(String journalId, DateTime asOf);

  Future<List<Map<String, dynamic>>> finalStatements(String journalId);
}
