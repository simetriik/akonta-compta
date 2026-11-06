import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/consultation_models.dart';
import 'mappers/consultation_repository_mappers.dart';
import '../../domain/repositories/consultation_repository.dart';

/// Module 6 : états calculés par PostgreSQL (écritures validées uniquement) et exports via l'Edge Function.
class SupabaseConsultationRepository implements ConsultationRepository {
  SupabaseConsultationRepository(this._client);

  final SupabaseClient _client;

  static String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Future<List<LedgerLine>> generalLedger(ConsultationParams p) async {
    final rows = await _client.rpc('general_ledger', params: {'p_entity': p.entityId, 'p_from': _d(p.from), 'p_to': _d(p.to), 'p_account_from': p.accountFrom, 'p_account_to': p.accountTo, 'p_third_party': null}) as List;
    return rows.map((j) => ledgerLineFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<BalanceRow>> trialBalance(ConsultationParams p) async {
    final rows = await _client.rpc('trial_balance', params: {'p_entity': p.entityId, 'p_from': _d(p.from), 'p_to': _d(p.to), 'p_class': p.classNo}) as List;
    return rows.map((j) => balanceRowFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<BalanceRow>> auxiliaryBalance(ConsultationParams p) async {
    final rows = await _client.rpc('auxiliary_balance', params: {'p_entity': p.entityId, 'p_from': _d(p.from), 'p_to': _d(p.to), 'p_account': null}) as List;
    return rows.map((j) => balanceRowFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<AgedRow>> agedBalance(ConsultationParams p) async {
    final rows = await _client.rpc('aged_balance', params: {'p_entity': p.entityId, 'p_as_of': _d(p.to), 'p_side': p.side}) as List;
    return rows.map((j) => agedRowFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<CentralizationRow>> centralization(ConsultationParams p) async {
    if (p.fiscalYearId == null) return const [];
    final rows = await _client.rpc('journal_centralization', params: {'p_entity': p.entityId, 'p_fiscal_year': p.fiscalYearId}) as List;
    return rows.map((j) => centralizationRowFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<AccountingControl>> accountingControls(String entityId, String fiscalYearId) async {
    final rows = await _client.rpc('accounting_controls', params: {'p_entity': entityId, 'p_fiscal_year': fiscalYearId}) as List;
    return rows.map((j) => accountingControlFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<AuditTrailEvent>> entryAuditTrail(ConsultationParams p) async {
    final rows = await _client.rpc('entry_audit_trail', params: {'p_entity': p.entityId, 'p_from': _d(p.from), 'p_to': _d(p.to)}) as List;
    return rows.map((j) => auditTrailEventFromJson(j as Map<String, dynamic>)).toList();
  }

  /// Export PDF / Excel : renvoie le nom du fichier et son contenu.
  @override
  Future<(String, Uint8List)> export({required ConsultationParams p, required String kind, required String format, bool allCounterparts = false}) async {
    final res = await _client.functions.invoke('export-document', body: {
      'entity_id': p.entityId,
      'kind': kind,
      'format': format,
      'from': _d(p.from),
      'to': _d(p.to),
      'journal_id': ?p.journalId,
      'account_from': ?p.accountFrom,
      'account_to': ?p.accountTo,
      'class': ?p.classNo,
      'side': p.side,
      if (kind == 'general_ledger') 'counterpart': allCounterparts ? 'all' : 'main',
    });
    if (res.status != 200) throw FunctionException(status: res.status, details: res.data);
    final base = switch (kind) { 'trial_balance' => 'balance', 'general_ledger' => 'grand-livre', 'journal' => 'journal', 'reconciliation' => 'rapprochement', 'financial_statements' => 'etats-financiers', 'dgi' => 'liasse-dgi', _ => 'balance-agee' };
    final name = '$base-${p.entityId.substring(0, 8)}-${_d(p.from)}-${_d(p.to)}.$format';
    return (name, res.data as Uint8List);
  }
}
