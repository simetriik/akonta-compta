import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/bank_models.dart';
import 'supabase_providers.dart';

/// Module 7 — rapprochement : gabarits, relevés, lignes non pointées, propositions, pointage, état, écriture depuis le relevé, état figé.
class ReconciliationRepository {
  ReconciliationRepository(this._client);

  final SupabaseClient _client;

  static String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<List<StatementTemplate>> templates() async {
    final rows = await _client.from('bank_statement_templates').select().order('bank_name', ascending: true);
    return rows.map(StatementTemplate.fromJson).toList();
  }

  Future<StatementTemplate> saveTemplate(String cabinetId, StatementTemplate t) async {
    final row = await _client.from('bank_statement_templates').insert({'cabinet_id': cabinetId, ...t.toJson()}).select().single();
    return StatementTemplate.fromJson(row);
  }

  Future<String> importStatement({required String journalId, required DateTime from, required DateTime to, required List<ParsedStatementLine> lines, int? opening, int? closing, String? templateId, String? fileName}) async =>
      (await _client.rpc('import_bank_statement', params: {
        'p_journal': journalId, 'p_from': _d(from), 'p_to': _d(to), 'p_lines': [for (final l in lines) l.toJson()],
        'p_opening': opening, 'p_closing': closing, 'p_template': templateId, 'p_file_name': fileName,
      })) as String;

  Future<List<StatementLine>> unmatchedStatementLines(String journalId, {DateTime? until}) async {
    final rows = await _client.rpc('unmatched_statement_lines', params: {'p_journal': journalId, 'p_until': until == null ? null : _d(until)}) as List;
    return rows.map((j) => StatementLine.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<BookLine>> unmatchedBookLines(String journalId, {DateTime? until}) async {
    final rows = await _client.rpc('unmatched_book_lines', params: {'p_journal': journalId, 'p_until': until == null ? null : _d(until)}) as List;
    return rows.map((j) => BookLine.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<ReconciliationProposalModel>> proposals(String journalId, {DateTime? until}) async {
    final rows = await _client.rpc('reconciliation_proposals', params: {'p_journal': journalId, 'p_until': until == null ? null : _d(until)}) as List;
    return rows.map((j) => ReconciliationProposalModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<String> match(String journalId, List<int> statementLineIds, List<String> entryLineIds, {String? note}) async =>
      (await _client.rpc('match_bank_lines', params: {'p_journal': journalId, 'p_statement_line_ids': statementLineIds, 'p_entry_line_ids': entryLineIds, 'p_note': note})) as String;

  Future<ReconciliationStateModel> state(String journalId, DateTime asOf) async {
    final rows = await _client.rpc('reconciliation_state', params: {'p_journal': journalId, 'p_as_of': _d(asOf)}) as List;
    return ReconciliationStateModel.fromJson(rows.first as Map<String, dynamic>);
  }

  Future<String> entryFromLine(int lineId, {required String accountId, String? thirdPartyId, String? label, bool validate = true}) async =>
      (await _client.rpc('entry_from_statement_line', params: {'p_line': lineId, 'p_account': accountId, 'p_third_party': thirdPartyId, 'p_label': label, 'p_validate': validate})) as String;

  Future<String> finalize(String journalId, DateTime asOf) async =>
      (await _client.rpc('finalize_reconciliation', params: {'p_journal': journalId, 'p_as_of': _d(asOf)})) as String;

  Future<List<Map<String, dynamic>>> finalStatements(String journalId) async =>
      (await _client.from('reconciliations').select().eq('journal_id', journalId).order('as_of', ascending: false)).cast<Map<String, dynamic>>();
}

final reconciliationRepositoryProvider = Provider<ReconciliationRepository>((ref) => ReconciliationRepository(ref.watch(supabaseClientProvider)));
final statementTemplatesProvider = FutureProvider<List<StatementTemplate>>((ref) => ref.watch(reconciliationRepositoryProvider).templates());
