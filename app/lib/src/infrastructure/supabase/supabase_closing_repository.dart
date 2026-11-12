import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/closing_models.dart';
import '../../domain/repositories/closing_repository.dart';
import 'mappers/closing_repository_mappers.dart';

/// Module 9 : assistant de clôture — contrôles, fiscalité, états, clôture provisoire, arrêté, N+1.
class SupabaseClosingRepository implements ClosingRepository {
  SupabaseClosingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ClosingCheck>> runChecks(String entityId, String fyId) async {
    final rows = await _client.rpc('run_closing_checks', params: {'p_entity': entityId, 'p_fiscal_year': fyId}) as List;
    return rows.map((j) => closingCheckFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> waive(String fyId, String code, String comment) => _client.rpc('waive_closing_check', params: {'p_fiscal_year': fyId, 'p_code': code, 'p_comment': comment});

  @override
  Future<int> accountingResult(String entityId, String fyId) async => ((await _client.rpc('accounting_result', params: {'p_entity': entityId, 'p_fiscal_year': fyId, 'p_as_of': null})) as num).toInt();

  @override
  Future<List<TaxAdjustment>> proposeAdjustments(String entityId, String fyId) async {
    final rows = await _client.rpc('propose_tax_adjustments', params: {'p_entity': entityId, 'p_fiscal_year': fyId, 'p_version': '2026'}) as List;
    return rows.map((j) => taxAdjustmentFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<TaxComputation> computeTax(String entityId, String fyId, List<TaxAdjustment> adjustments) async {
    final id = await _client.rpc('compute_income_tax', params: {'p_entity': entityId, 'p_fiscal_year': fyId, 'p_adjustments': [for (final a in adjustments) a.toJson()], 'p_rules_version': '2026', 'p_minimum_floor': 250000}) as String;
    return taxComputationFromJson(await _client.from('tax_computations').select().eq('id', id).single());
  }

  @override
  Future<TaxComputation?> taxComputation(String fyId) async {
    final row = await _client.from('tax_computations').select().eq('fiscal_year_id', fyId).maybeSingle();
    return row == null ? null : taxComputationFromJson(row);
  }

  @override
  Future<FinancialStatements> generateStatements(String entityId, String fyId) async {
    final id = await _client.rpc('generate_financial_statements', params: {'p_entity': entityId, 'p_fiscal_year': fyId}) as String;
    return financialStatementsFromJson(await _client.from('financial_statements').select().eq('id', id).single());
  }

  @override
  Future<FinancialStatements?> latestStatements(String fyId) async {
    final row = await _client.from('financial_statements').select().eq('fiscal_year_id', fyId).order('generated_at', ascending: false).limit(1).maybeSingle();
    return row == null ? null : financialStatementsFromJson(row);
  }

  @override
  Future<String?> generateResultEntry(String entityId, String fyId) async => (await _client.rpc('generate_result_entry', params: {'p_entity': entityId, 'p_fiscal_year': fyId})) as String?;

  @override
  Future<void> closeProvisional(String entityId, String fyId) => _client.rpc('close_provisional', params: {'p_entity': entityId, 'p_fiscal_year': fyId});

  @override
  Future<int> pendingResult(String entityId, String nextFyId) async =>
      ((await _client.rpc('pending_result', params: {'p_entity': entityId, 'p_fiscal_year_next': nextFyId})) as num).toInt();

  @override
  Future<void> reopen(String entityId, String fyId, String reason) => _client.rpc('reopen_fiscal_year', params: {'p_entity': entityId, 'p_fiscal_year': fyId, 'p_reason': reason});

  @override
  Future<String> closeFinal(String entityId, String fyId, String confirmation) async =>
      (await _client.rpc('close_final', params: {'p_entity': entityId, 'p_fiscal_year': fyId, 'p_confirmation': confirmation})) as String;

  @override
  Future<String?> generateOpeningBalances(String entityId, String fyId) async => (await _client.rpc('generate_opening_balances', params: {'p_entity': entityId, 'p_fiscal_year': fyId})) as String?;

  @override
  Future<String?> allocateResult(String entityId, String nextFyId, DateTime date, {required int legalReserve, required int freeReserve, required int dividends, required int carryForward}) async =>
      (await _client.rpc('allocate_result', params: {'p_entity': entityId, 'p_fiscal_year_next': nextFyId, 'p_date': date.toIso8601String().substring(0, 10), 'p_legal_reserve': legalReserve, 'p_free_reserve': freeReserve, 'p_dividends': dividends, 'p_carry_forward': carryForward})) as String?;
}
