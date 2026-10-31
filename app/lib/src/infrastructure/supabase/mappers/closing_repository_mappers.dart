import '../../../data/closing_repository.dart';

// Convertisseurs entre le format PostgREST (JSON) et les entités du domaine.

ClosingCheck closingCheckFromJson(Map<String, dynamic> j) => ClosingCheck(
        code: j['code'] as String,
        label: j['label'] as String,
        severity: j['severity'] as String,
        status: j['status'] as String,
        details: (j['details'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

TaxAdjustment taxAdjustmentFromJson(Map<String, dynamic> j) => TaxAdjustment(code: j['code'] as String, label: j['label'] as String, kind: j['kind'] as String, amount: (j['amount'] as num).toInt());

TaxComputation taxComputationFromJson(Map<String, dynamic> j) => TaxComputation(
        accountingResult: (j['accounting_result'] as num).toInt(),
        taxableResult: (j['taxable_result'] as num).toInt(),
        revenue: (j['revenue'] as num).toInt(),
        isRate: double.parse('${j['is_rate']}'),
        computedTax: (j['computed_tax'] as num).toInt(),
        minimumTax: (j['minimum_tax'] as num).toInt(),
        taxDue: (j['tax_due'] as num).toInt(),
        prepayments: (j['prepayments'] as num).toInt(),
        balanceDue: (j['balance_due'] as num).toInt(),
        entryId: j['entry_id'] as String?,
      );

StatementPost statementPostFromJson(Map<String, dynamic> j) => StatementPost(code: j['post_code'] as String, label: j['post_label'] as String, columnRole: j['column_role'] as String, amount: (j['amount'] as num).toInt());

NoteLine noteLineFromJson(Map<String, dynamic> j) => NoteLine(
        noteCode: j['note_code'] as String,
        noteTitle: j['note_title'] as String,
        lineCode: j['line_code'] as String,
        label: j['label'] as String,
        kind: j['kind'] as String,
        amount: (j['amount'] as num).toInt(),
        previous: (j['previous'] as num?)?.toInt(),
      );

FinancialStatements financialStatementsFromJson(Map<String, dynamic> j) {
    final data = (j['data'] as Map).cast<String, dynamic>();
    List<StatementPost> posts(dynamic l) => [for (final p in (l as List? ?? const [])) statementPostFromJson((p as Map).cast<String, dynamic>())];
    final prev = data['previous'] as Map?;
    return FinancialStatements(
      id: j['id'] as String,
      generatedAt: DateTime.parse(j['generated_at'] as String).toLocal(),
      assets: posts(data['assets']),
      liabilities: posts(data['liabilities']),
      income: posts(data['income']),
      cashFlow: posts(data['cash_flow']),
      notes: [for (final n in (data['notes'] as List? ?? const [])) noteLineFromJson((n as Map).cast<String, dynamic>())],
      previous: prev == null ? null : {'assets': posts(prev['assets']), 'liabilities': posts(prev['liabilities']), 'income': posts(prev['income']), 'cash_flow': posts(prev['cash_flow'])},
      checks: ((j['checks'] as List?) ?? const []).map((c) => (c as Map).cast<String, dynamic>()).toList(),
      isFinal: (j['is_final'] as bool?) ?? false,
    );
  }

extension TaxAdjustmentJson on TaxAdjustment {
  Map<String, dynamic> toJson() => {'code': code, 'label': label, 'kind': kind, 'amount': amount};
}
