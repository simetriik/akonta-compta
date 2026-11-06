import '../../../domain/consultation_models.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

LedgerLine ledgerLineFromJson(Map<String, dynamic> j) => LedgerLine(
        accountCode: j['account_code'] as String,
        accountLabel: j['account_label'] as String,
        entryId: j['entry_id'] as String,
        entryDate: DateTime.parse(j['entry_date'] as String),
        journalCode: j['journal_code'] as String,
        number: (j['number'] as num).toInt(),
        reference: j['reference'] as String?,
        label: j['label'] as String,
        thirdPartyCode: j['third_party_code'] as String?,
        thirdPartyName: j['third_party_name'] as String?,
        debit: (j['debit'] as num).toInt(),
        credit: (j['credit'] as num).toInt(),
        runningBalance: (j['running_balance'] as num).toInt(),
        letterCode: j['letter_code'] as String?,
        counterparts: [
          for (final c in (j['counterparts'] as List?) ?? const [])
            Counterpart(code: (c as Map<String, dynamic>)['code'] as String, label: (c['label'] as String?) ?? '', amount: (c['amount'] as num).toInt()),
        ],
      );

BalanceRow balanceRowFromJson(Map<String, dynamic> j) => BalanceRow(
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

AgedRow agedRowFromJson(Map<String, dynamic> j) => AgedRow(
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

CentralizationRow centralizationRowFromJson(Map<String, dynamic> j) => CentralizationRow(
        journalCode: j['journal_code'] as String,
        journalLabel: j['journal_label'] as String,
        periodNo: (j['period_no'] as num).toInt(),
        monthStart: DateTime.parse(j['month_start'] as String),
        entriesCount: (j['entries_count'] as num).toInt(),
        totalDebit: (j['total_debit'] as num).toInt(),
        totalCredit: (j['total_credit'] as num).toInt(),
      );
