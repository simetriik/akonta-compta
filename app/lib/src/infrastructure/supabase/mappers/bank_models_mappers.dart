import '../../../domain/bank_models.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

StatementTemplate statementTemplateFromJson(Map<String, dynamic> j) => StatementTemplate(
        id: j['id'] as String,
        bankName: j['bank_name'] as String,
        label: j['label'] as String,
        delimiter: (j['delimiter'] as String?) ?? ';',
        hasHeader: (j['has_header'] as bool?) ?? true,
        skipRows: (j['skip_rows'] as num?)?.toInt() ?? 0,
        dateColumn: (j['date_column'] as num).toInt(),
        labelColumn: (j['label_column'] as num).toInt(),
        debitColumn: (j['debit_column'] as num?)?.toInt(),
        creditColumn: (j['credit_column'] as num?)?.toInt(),
        amountColumn: (j['amount_column'] as num?)?.toInt(),
        referenceColumn: (j['reference_column'] as num?)?.toInt(),
        valueDateColumn: (j['value_date_column'] as num?)?.toInt(),
        dateFormat: (j['date_format'] as String?) ?? 'DD/MM/YYYY',
        decimalSeparator: (j['decimal_separator'] as String?) ?? ',',
        amountSignInverted: (j['amount_sign_inverted'] as bool?) ?? false,
      );

StatementLine statementLineFromJson(Map<String, dynamic> j) => StatementLine(
        id: (j['line_id'] as num).toInt(),
        statementId: j['statement_id'] as String,
        date: DateTime.parse(j['operation_date'] as String),
        valueDate: j['value_date'] == null ? null : DateTime.parse(j['value_date'] as String),
        label: j['label'] as String,
        reference: j['reference'] as String?,
        debit: (j['debit'] as num).toInt(),
        credit: (j['credit'] as num).toInt(),
      );

BookLine bookLineFromJson(Map<String, dynamic> j) => BookLine(
        id: j['line_id'] as String,
        entryId: j['entry_id'] as String,
        date: DateTime.parse(j['entry_date'] as String),
        number: (j['number'] as num).toInt(),
        reference: j['reference'] as String?,
        label: j['label'] as String,
        debit: (j['debit'] as num).toInt(),
        credit: (j['credit'] as num).toInt(),
      );

ReconciliationStateModel reconciliationStateModelFromJson(Map<String, dynamic> j) => ReconciliationStateModel(
        bookBalance: (j['book_balance'] as num).toInt(),
        bankBalance: (j['bank_balance'] as num).toInt(),
        depositsInTransit: (j['deposits_in_transit'] as num).toInt(),
        outstandingPayments: (j['outstanding_payments'] as num).toInt(),
        unmatchedBankCredits: (j['unmatched_bank_credits'] as num).toInt(),
        unmatchedBankDebits: (j['unmatched_bank_debits'] as num).toInt(),
        difference: (j['difference'] as num).toInt(),
      );

ReconciliationProposalModel reconciliationProposalModelFromJson(Map<String, dynamic> j) => ReconciliationProposalModel(
        statementLineId: (j['statement_line_id'] as num).toInt(),
        entryLineId: j['entry_line_id'] as String,
        amount: (j['amount'] as num).toInt(),
        dayGap: (j['day_gap'] as num).toInt(),
      );

extension StatementTemplateJson on StatementTemplate {
  Map<String, dynamic> toJson() => {
        'bank_name': bankName,
        'label': label,
        'delimiter': delimiter,
        'has_header': hasHeader,
        'skip_rows': skipRows,
        'date_column': dateColumn,
        'label_column': labelColumn,
        'debit_column': debitColumn,
        'credit_column': creditColumn,
        'amount_column': amountColumn,
        'reference_column': referenceColumn,
        'value_date_column': valueDateColumn,
        'date_format': dateFormat,
        'decimal_separator': decimalSeparator,
        'amount_sign_inverted': amountSignInverted,
      };
}

extension ParsedStatementLineJson on ParsedStatementLine {
  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().substring(0, 10),
        'value_date': valueDate?.toIso8601String().substring(0, 10),
        'label': label,
        'reference': reference,
        'debit': debit,
        'credit': credit,
      };
}
