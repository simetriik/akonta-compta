import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_providers.dart';
import '../infrastructure/supabase/mappers/closing_repository_mappers.dart';

class ClosingCheck {
  const ClosingCheck({required this.code, required this.label, required this.severity, required this.status, required this.details});

  final String code;
  final String label;
  final String severity;
  final String status;
  final Map<String, dynamic> details;
}

class TaxAdjustment {
  TaxAdjustment({required this.code, required this.label, required this.kind, required this.amount});

  final String code;
  final String label;
  final String kind;
  int amount;
}

class TaxComputation {
  const TaxComputation({required this.accountingResult, required this.taxableResult, required this.revenue, required this.isRate, required this.computedTax, required this.minimumTax, required this.taxDue, required this.prepayments, required this.balanceDue, this.entryId});

  final int accountingResult, taxableResult, revenue, computedTax, minimumTax, taxDue, prepayments, balanceDue;
  final double isRate;
  final String? entryId;
}

class StatementPost {
  const StatementPost({required this.code, required this.label, required this.columnRole, required this.amount});

  final String code;
  final String label;
  final String columnRole;
  final int amount;
}

/// Ligne d'une note annexe : montants de N et de N-1 (null sans exercice précédent) ; `kind` vaut `line`, `subtotal` ou `total`.
class NoteLine {
  const NoteLine({required this.noteCode, required this.noteTitle, required this.lineCode, required this.label, required this.kind, required this.amount, this.previous});

  final String noteCode;
  final String noteTitle;
  final String lineCode;
  final String label;
  final String kind;
  final int amount;
  final int? previous;

  bool get isTotal => kind != 'line';
  int? get variation => previous == null ? null : amount - previous!;

  /// Variation en % de N-1 ; absente si N-1 est nul ou inconnu.
  double? get variationPercent => previous == null || previous == 0 ? null : (amount - previous!) / previous!.abs() * 100;
}

class FinancialStatements {
  const FinancialStatements({required this.id, required this.generatedAt, required this.assets, required this.liabilities, required this.income, required this.previous, required this.checks, required this.isFinal, this.cashFlow = const [], this.notes = const []});

  final String id;
  final DateTime generatedAt;
  final List<StatementPost> assets;
  final List<StatementPost> liabilities;
  final List<StatementPost> income;

  /// Tableau des flux de trésorerie (référentiel SYCEBNL seulement) ; vide pour le système normal.
  final List<StatementPost> cashFlow;

  /// Notes annexes calculables (référentiel SYCEBNL seulement), dans l'ordre du catalogue.
  final List<NoteLine> notes;
  final Map<String, List<StatementPost>>? previous;
  final List<Map<String, dynamic>> checks;
  final bool isFinal;
}

/// Module 9 : assistant de clôture — contrôles, fiscalité, états, clôture provisoire, arrêté, N+1.
class ClosingRepository {
  ClosingRepository(this._client);

  final SupabaseClient _client;

  Future<List<ClosingCheck>> runChecks(String entityId, String fyId) async {
    final rows = await _client.rpc('run_closing_checks', params: {'p_entity': entityId, 'p_fiscal_year': fyId}) as List;
    return rows.map((j) => closingCheckFromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> waive(String fyId, String code, String comment) => _client.rpc('waive_closing_check', params: {'p_fiscal_year': fyId, 'p_code': code, 'p_comment': comment});

  Future<int> accountingResult(String entityId, String fyId) async => ((await _client.rpc('accounting_result', params: {'p_entity': entityId, 'p_fiscal_year': fyId, 'p_as_of': null})) as num).toInt();

  Future<List<TaxAdjustment>> proposeAdjustments(String entityId, String fyId) async {
    final rows = await _client.rpc('propose_tax_adjustments', params: {'p_entity': entityId, 'p_fiscal_year': fyId, 'p_version': '2026'}) as List;
    return rows.map((j) => taxAdjustmentFromJson(j as Map<String, dynamic>)).toList();
  }

  Future<TaxComputation> computeTax(String entityId, String fyId, List<TaxAdjustment> adjustments) async {
    final id = await _client.rpc('compute_income_tax', params: {'p_entity': entityId, 'p_fiscal_year': fyId, 'p_adjustments': [for (final a in adjustments) a.toJson()], 'p_rules_version': '2026', 'p_minimum_floor': 250000}) as String;
    return taxComputationFromJson(await _client.from('tax_computations').select().eq('id', id).single());
  }

  Future<TaxComputation?> taxComputation(String fyId) async {
    final row = await _client.from('tax_computations').select().eq('fiscal_year_id', fyId).maybeSingle();
    return row == null ? null : taxComputationFromJson(row);
  }

  Future<FinancialStatements> generateStatements(String entityId, String fyId) async {
    final id = await _client.rpc('generate_financial_statements', params: {'p_entity': entityId, 'p_fiscal_year': fyId}) as String;
    return financialStatementsFromJson(await _client.from('financial_statements').select().eq('id', id).single());
  }

  Future<FinancialStatements?> latestStatements(String fyId) async {
    final row = await _client.from('financial_statements').select().eq('fiscal_year_id', fyId).order('generated_at', ascending: false).limit(1).maybeSingle();
    return row == null ? null : financialStatementsFromJson(row);
  }

  Future<String?> generateResultEntry(String entityId, String fyId) async => (await _client.rpc('generate_result_entry', params: {'p_entity': entityId, 'p_fiscal_year': fyId})) as String?;

  Future<void> closeProvisional(String entityId, String fyId) => _client.rpc('close_provisional', params: {'p_entity': entityId, 'p_fiscal_year': fyId});

  Future<void> reopen(String entityId, String fyId, String reason) => _client.rpc('reopen_fiscal_year', params: {'p_entity': entityId, 'p_fiscal_year': fyId, 'p_reason': reason});

  Future<String> closeFinal(String entityId, String fyId, String confirmation) async =>
      (await _client.rpc('close_final', params: {'p_entity': entityId, 'p_fiscal_year': fyId, 'p_confirmation': confirmation})) as String;

  Future<String?> generateOpeningBalances(String entityId, String fyId) async => (await _client.rpc('generate_opening_balances', params: {'p_entity': entityId, 'p_fiscal_year': fyId})) as String?;

  Future<String?> allocateResult(String entityId, String nextFyId, DateTime date, {required int legalReserve, required int freeReserve, required int dividends, required int carryForward}) async =>
      (await _client.rpc('allocate_result', params: {'p_entity': entityId, 'p_fiscal_year_next': nextFyId, 'p_date': date.toIso8601String().substring(0, 10), 'p_legal_reserve': legalReserve, 'p_free_reserve': freeReserve, 'p_dividends': dividends, 'p_carry_forward': carryForward})) as String?;
}

final closingRepositoryProvider = Provider<ClosingRepository>((ref) => ClosingRepository(ref.watch(supabaseClientProvider)));
