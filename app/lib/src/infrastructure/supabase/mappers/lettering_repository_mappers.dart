import '../../../data/lettering_repository.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

UnletteredLine unletteredLineFromJson(Map<String, dynamic> j) => UnletteredLine(
        lineId: j['line_id'] as String,
        entryId: j['entry_id'] as String,
        entryDate: DateTime.parse(j['entry_date'] as String),
        journalCode: j['journal_code'] as String,
        number: (j['number'] as num).toInt(),
        reference: j['reference'] as String?,
        label: j['label'] as String,
        thirdPartyId: j['third_party_id'] as String?,
        thirdPartyCode: j['third_party_code'] as String?,
        debit: (j['debit'] as num).toInt(),
        credit: (j['credit'] as num).toInt(),
      );

LetteringProposal letteringProposalFromJson(Map<String, dynamic> j) => LetteringProposal(
        debitLineId: j['debit_line_id'] as String,
        creditLineIds: (j['credit_line_ids'] as List).cast<String>(),
        thirdPartyCode: j['third_party_code'] as String?,
        amount: (j['amount'] as num).toInt(),
        rule: j['rule'] as String,
      );

LetteringGroup letteringGroupFromJson(Map<String, dynamic> j) => LetteringGroup(
        id: j['id'] as String,
        code: j['code'] as String,
        isPartial: j['is_partial'] as bool,
        totalDebit: (j['total_debit'] as num).toInt(),
        totalCredit: (j['total_credit'] as num).toInt(),
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        unletteredAt: j['unlettered_at'] == null ? null : DateTime.parse(j['unlettered_at'] as String).toLocal(),
      );
