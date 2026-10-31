class UnletteredLine {
  const UnletteredLine({required this.lineId, required this.entryId, required this.entryDate, required this.journalCode, required this.number, this.reference, required this.label, this.thirdPartyId, this.thirdPartyCode, required this.debit, required this.credit});

  final String lineId;
  final String entryId;
  final DateTime entryDate;
  final String journalCode;
  final int number;
  final String? reference;
  final String label;
  final String? thirdPartyId;
  final String? thirdPartyCode;
  final int debit;
  final int credit;
}

class LetteringProposal {
  const LetteringProposal({required this.debitLineId, required this.creditLineIds, this.thirdPartyCode, required this.amount, required this.rule});

  final String debitLineId;
  final List<String> creditLineIds;
  final String? thirdPartyCode;
  final int amount;
  final String rule;

  List<String> get allLineIds => [debitLineId, ...creditLineIds];
  String get ruleLabel => rule == 'same_amount' ? 'même montant' : 'facture = règlement + retenue';
}

class LetteringGroup {
  const LetteringGroup({required this.id, required this.code, required this.isPartial, required this.totalDebit, required this.totalCredit, required this.createdAt, this.unletteredAt});

  final String id;
  final String code;
  final bool isPartial;
  final int totalDebit;
  final int totalCredit;
  final DateTime createdAt;
  final DateTime? unletteredAt;
}
