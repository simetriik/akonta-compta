import '../../../domain/entry_models.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

EntryLineModel entryLineModelFromJson(Map<String, dynamic> j) => EntryLineModel(
        id: j['id'] as String,
        lineNo: (j['line_no'] as num).toInt(),
        accountId: j['account_id'] as String,
        accountCode: (j['accounts'] as Map)['code'] as String,
        accountLabel: (j['accounts'] as Map)['label'] as String,
        isCollective: ((j['accounts'] as Map)['is_collective'] as bool?) ?? false,
        thirdPartyId: j['third_party_id'] as String?,
        thirdPartyCode: (j['third_parties'] as Map?)?['code'] as String?,
        label: j['label'] as String?,
        debit: (j['debit'] as num).toInt(),
        credit: (j['credit'] as num).toInt(),
        currencyCode: (j['currency_code'] as String?) ?? 'XOF',
        amountCurrency: j['amount_currency'] == null ? null : double.parse('${j['amount_currency']}'),
        exchangeRate: j['exchange_rate'] == null ? null : double.parse('${j['exchange_rate']}'),
        letterCode: j['letter_code'] as String?,
      );

EntryModel entryModelFromJson(Map<String, dynamic> j) {
    final lines = [for (final l in (j['entry_lines'] as List? ?? const [])) entryLineModelFromJson(l as Map<String, dynamic>)]..sort((a, b) => a.lineNo.compareTo(b.lineNo));
    return EntryModel(
      id: j['id'] as String,
      entityId: j['entity_id'] as String,
      journalId: j['journal_id'] as String,
      journalCode: (j['journals'] as Map?)?['code'] as String? ?? '',
      entryDate: DateTime.parse(j['entry_date'] as String),
      number: (j['number'] as num?)?.toInt(),
      reference: j['reference'] as String?,
      label: j['label'] as String,
      status: j['status'] as String,
      reviewStatus: j['review_status'] as String,
      reviewComment: j['review_comment'] as String?,
      returnedComment: j['returned_comment'] as String?,
      isGenerated: (j['is_generated'] as bool?) ?? false,
      reversalOf: j['reversal_of'] as String?,
      reversedBy: j['reversed_by'] as String?,
      createdBy: j['created_by'] as String?,
      totalDebit: lines.fold(0, (s, l) => s + l.debit),
      totalCredit: lines.fold(0, (s, l) => s + l.credit),
      lines: lines,
    );
  }

extension DraftLineJson on DraftLine {
  Map<String, dynamic> toJson(int lineNo) => {
        'line_no': lineNo,
        'account_id': accountId,
        'third_party_id': thirdPartyId,
        'label': label.trim().isEmpty ? null : label.trim(),
        'debit': debit,
        'credit': credit,
      };
}
