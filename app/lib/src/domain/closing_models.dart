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
