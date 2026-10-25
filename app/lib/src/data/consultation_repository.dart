import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_providers.dart';

class LedgerLine {
  const LedgerLine({required this.accountCode, required this.accountLabel, required this.entryId, required this.entryDate, required this.journalCode, required this.number, this.reference, required this.label, this.thirdPartyCode, required this.debit, required this.credit, required this.runningBalance, this.letterCode});

  final String accountCode;
  final String accountLabel;
  final String entryId;
  final DateTime entryDate;
  final String journalCode;
  final int number;
  final String? reference;
  final String label;
  final String? thirdPartyCode;
  final int debit;
  final int credit;
  final int runningBalance;
  final String? letterCode;

  factory LedgerLine.fromJson(Map<String, dynamic> j) => LedgerLine(
        accountCode: j['account_code'] as String,
        accountLabel: j['account_label'] as String,
        entryId: j['entry_id'] as String,
        entryDate: DateTime.parse(j['entry_date'] as String),
        journalCode: j['journal_code'] as String,
        number: (j['number'] as num).toInt(),
        reference: j['reference'] as String?,
        label: j['label'] as String,
        thirdPartyCode: j['third_party_code'] as String?,
        debit: (j['debit'] as num).toInt(),
        credit: (j['credit'] as num).toInt(),
        runningBalance: (j['running_balance'] as num).toInt(),
        letterCode: j['letter_code'] as String?,
      );
}

class BalanceRow {
  const BalanceRow({required this.accountCode, required this.accountLabel, this.thirdPartyCode, this.thirdPartyName, required this.openingDebit, required this.openingCredit, required this.periodDebit, required this.periodCredit, required this.closingDebit, required this.closingCredit});

  final String accountCode;
  final String accountLabel;
  final String? thirdPartyCode;
  final String? thirdPartyName;
  final int openingDebit;
  final int openingCredit;
  final int periodDebit;
  final int periodCredit;
  final int closingDebit;
  final int closingCredit;

  factory BalanceRow.fromJson(Map<String, dynamic> j) => BalanceRow(
        accountCode: j['account_code'] as String,
        accountLabel: (j['account_label'] as String?) ?? '',
        thirdPartyCode: j['third_party_code'] as String?,
        thirdPartyName: j['third_party_name'] as String?,
        openingDebit: (j['opening_debit'] as num).toInt(),
        openingCredit: (j['opening_credit'] as num).toInt(),
        periodDebit: (j['period_debit'] as num).toInt(),
        periodCredit: (j['period_credit'] as num).toInt(),
        closingDebit: (j['closing_debit'] as num).toInt(),
        closingCredit: (j['closing_credit'] as num).toInt(),
      );
}

class AgedRow {
  const AgedRow({required this.accountCode, required this.thirdPartyCode, required this.thirdPartyName, required this.d0_30, required this.d31_60, required this.d61_90, required this.d91_180, required this.over180, required this.total});

  final String accountCode;
  final String thirdPartyCode;
  final String thirdPartyName;
  final int d0_30, d31_60, d61_90, d91_180, over180, total;

  factory AgedRow.fromJson(Map<String, dynamic> j) => AgedRow(
        accountCode: j['account_code'] as String,
        thirdPartyCode: j['third_party_code'] as String,
        thirdPartyName: j['third_party_name'] as String,
        d0_30: (j['d0_30'] as num).toInt(),
        d31_60: (j['d31_60'] as num).toInt(),
        d61_90: (j['d61_90'] as num).toInt(),
        d91_180: (j['d91_180'] as num).toInt(),
        over180: (j['over_180'] as num).toInt(),
        total: (j['total'] as num).toInt(),
      );
}

class CentralizationRow {
  const CentralizationRow({required this.journalCode, required this.journalLabel, required this.periodNo, required this.monthStart, required this.entriesCount, required this.totalDebit, required this.totalCredit});

  final String journalCode;
  final String journalLabel;
  final int periodNo;
  final DateTime monthStart;
  final int entriesCount;
  final int totalDebit;
  final int totalCredit;

  factory CentralizationRow.fromJson(Map<String, dynamic> j) => CentralizationRow(
        journalCode: j['journal_code'] as String,
        journalLabel: j['journal_label'] as String,
        periodNo: (j['period_no'] as num).toInt(),
        monthStart: DateTime.parse(j['month_start'] as String),
        entriesCount: (j['entries_count'] as num).toInt(),
        totalDebit: (j['total_debit'] as num).toInt(),
        totalCredit: (j['total_credit'] as num).toInt(),
      );
}

class ConsultationParams {
  const ConsultationParams({required this.entityId, required this.from, required this.to, this.accountFrom, this.accountTo, this.journalId, this.classNo, this.side = 'debit', this.fiscalYearId});

  final String entityId;
  final DateTime from;
  final DateTime to;
  final String? accountFrom;
  final String? accountTo;
  final String? journalId;
  final int? classNo;
  final String side;
  final String? fiscalYearId;

  @override
  bool operator ==(Object other) => other is ConsultationParams && other.entityId == entityId && other.from == from && other.to == to && other.accountFrom == accountFrom && other.accountTo == accountTo && other.journalId == journalId && other.classNo == classNo && other.side == side && other.fiscalYearId == fiscalYearId;

  @override
  int get hashCode => Object.hash(entityId, from, to, accountFrom, accountTo, journalId, classNo, side, fiscalYearId);
}

/// Module 6 : états calculés par PostgreSQL (écritures validées uniquement) et exports via l'Edge Function.
class ConsultationRepository {
  ConsultationRepository(this._client);

  final SupabaseClient _client;

  static String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<List<LedgerLine>> generalLedger(ConsultationParams p) async {
    final rows = await _client.rpc('general_ledger', params: {'p_entity': p.entityId, 'p_from': _d(p.from), 'p_to': _d(p.to), 'p_account_from': p.accountFrom, 'p_account_to': p.accountTo, 'p_third_party': null}) as List;
    return rows.map((j) => LedgerLine.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<BalanceRow>> trialBalance(ConsultationParams p) async {
    final rows = await _client.rpc('trial_balance', params: {'p_entity': p.entityId, 'p_from': _d(p.from), 'p_to': _d(p.to), 'p_class': p.classNo}) as List;
    return rows.map((j) => BalanceRow.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<BalanceRow>> auxiliaryBalance(ConsultationParams p) async {
    final rows = await _client.rpc('auxiliary_balance', params: {'p_entity': p.entityId, 'p_from': _d(p.from), 'p_to': _d(p.to), 'p_account': null}) as List;
    return rows.map((j) => BalanceRow.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<AgedRow>> agedBalance(ConsultationParams p) async {
    final rows = await _client.rpc('aged_balance', params: {'p_entity': p.entityId, 'p_as_of': _d(p.to), 'p_side': p.side}) as List;
    return rows.map((j) => AgedRow.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<CentralizationRow>> centralization(ConsultationParams p) async {
    if (p.fiscalYearId == null) return const [];
    final rows = await _client.rpc('journal_centralization', params: {'p_entity': p.entityId, 'p_fiscal_year': p.fiscalYearId}) as List;
    return rows.map((j) => CentralizationRow.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Export PDF / Excel : renvoie le nom du fichier et son contenu.
  Future<(String, Uint8List)> export({required ConsultationParams p, required String kind, required String format}) async {
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
    });
    if (res.status != 200) throw Exception('Export refusé (${res.status}) : ${res.data}');
    final base = switch (kind) { 'trial_balance' => 'balance', 'general_ledger' => 'grand-livre', 'journal' => 'journal', 'reconciliation' => 'rapprochement', 'financial_statements' => 'etats-financiers', 'dgi' => 'liasse-dgi', _ => 'balance-agee' };
    final name = '$base-${p.entityId.substring(0, 8)}-${_d(p.from)}-${_d(p.to)}.$format';
    return (name, res.data as Uint8List);
  }
}

final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) => ConsultationRepository(ref.watch(supabaseClientProvider)));
final generalLedgerProvider = FutureProvider.family<List<LedgerLine>, ConsultationParams>((ref, p) => ref.watch(consultationRepositoryProvider).generalLedger(p));
final trialBalanceProvider = FutureProvider.family<List<BalanceRow>, ConsultationParams>((ref, p) => ref.watch(consultationRepositoryProvider).trialBalance(p));
final auxiliaryBalanceProvider = FutureProvider.family<List<BalanceRow>, ConsultationParams>((ref, p) => ref.watch(consultationRepositoryProvider).auxiliaryBalance(p));
final agedBalanceProvider = FutureProvider.family<List<AgedRow>, ConsultationParams>((ref, p) => ref.watch(consultationRepositoryProvider).agedBalance(p));
final centralizationProvider = FutureProvider.family<List<CentralizationRow>, ConsultationParams>((ref, p) => ref.watch(consultationRepositoryProvider).centralization(p));
