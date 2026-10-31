import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/bank_models.dart';
import 'mappers/bank_models_mappers.dart';
import '../../domain/repositories/reconciliation_repository.dart';

/// Module 7 — rapprochement : gabarits, relevés, lignes non pointées, propositions, pointage, état, écriture depuis le relevé, état figé.
class SupabaseReconciliationRepository implements ReconciliationRepository {
  SupabaseReconciliationRepository(this._client);

  final SupabaseClient _client;

  static String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Future<List<StatementTemplate>> templates() async {
    final rows = await _client.from('bank_statement_templates').select().order('bank_name', ascending: true);
    return rows.map(statementTemplateFromJson).toList();
  }

  @override
  Future<StatementTemplate> saveTemplate(String cabinetId, StatementTemplate t) async {
    final row = await _client.from('bank_statement_templates').insert({'cabinet_id': cabinetId, ...t.toJson()}).select().single();
    return statementTemplateFromJson(row);
  }

  @override
  Future<String> importStatement({required String journalId, required DateTime from, required DateTime to, required List<ParsedStatementLine> lines, int? opening, int? closing, String? templateId, String? fileName}) async =>
      (await _client.rpc('import_bank_statement', params: {
        'p_journal': journalId, 'p_from': _d(from), 'p_to': _d(to), 'p_lines': [for (final l in lines) l.toJson()],
        'p_opening': opening, 'p_closing': closing, 'p_template': templateId, 'p_file_name': fileName,
      })) as String;

  @override
  Future<List<StatementLine>> unmatchedStatementLines(String journalId, {DateTime? until}) async {
    final rows = await _client.rpc('unmatched_statement_lines', params: {'p_journal': journalId, 'p_until': until == null ? null : _d(until)}) as List;
    return rows.map((j) => statementLineFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<BookLine>> unmatchedBookLines(String journalId, {DateTime? until}) async {
    final rows = await _client.rpc('unmatched_book_lines', params: {'p_journal': journalId, 'p_until': until == null ? null : _d(until)}) as List;
    return rows.map((j) => bookLineFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<ReconciliationProposalModel>> proposals(String journalId, {DateTime? until}) async {
    final rows = await _client.rpc('reconciliation_proposals', params: {'p_journal': journalId, 'p_until': until == null ? null : _d(until)}) as List;
    return rows.map((j) => reconciliationProposalModelFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<String> match(String journalId, List<int> statementLineIds, List<String> entryLineIds, {String? note}) async =>
      (await _client.rpc('match_bank_lines', params: {'p_journal': journalId, 'p_statement_line_ids': statementLineIds, 'p_entry_line_ids': entryLineIds, 'p_note': note})) as String;

  @override
  Future<ReconciliationStateModel> state(String journalId, DateTime asOf) async {
    final rows = await _client.rpc('reconciliation_state', params: {'p_journal': journalId, 'p_as_of': _d(asOf)}) as List;
    return reconciliationStateModelFromJson(rows.first as Map<String, dynamic>);
  }

  /// Crée (et valide puis pointe) l'écriture d'une ligne de relevé ; [entryDate] permet de la dater
  /// dans une période ouverte quand celle de l'opération est verrouillée.
  @override
  Future<String> entryFromLine(int lineId, {required String accountId, String? thirdPartyId, String? label, DateTime? entryDate, bool validate = true}) async =>
      (await _client.rpc('entry_from_statement_line', params: {'p_line': lineId, 'p_account': accountId, 'p_third_party': thirdPartyId, 'p_label': label, 'p_validate': validate, 'p_entry_date': entryDate == null ? null : _d(entryDate)})) as String;

  @override
  Future<String> finalize(String journalId, DateTime asOf) async =>
      (await _client.rpc('finalize_reconciliation', params: {'p_journal': journalId, 'p_as_of': _d(asOf)})) as String;

  @override
  Future<List<Map<String, dynamic>>> finalStatements(String journalId) async =>
      (await _client.from('reconciliations').select().eq('journal_id', journalId).order('as_of', ascending: false)).cast<Map<String, dynamic>>();
}
