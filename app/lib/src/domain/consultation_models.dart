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
}

class AgedRow {
  const AgedRow({required this.accountCode, required this.thirdPartyCode, required this.thirdPartyName, required this.d0_30, required this.d31_60, required this.d61_90, required this.d91_180, required this.over180, required this.total});

  final String accountCode;
  final String thirdPartyCode;
  final String thirdPartyName;
  final int d0_30, d31_60, d61_90, d91_180, over180, total;
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
