/// Modèles du rapprochement bancaire : gabarit de relevé, lignes analysées, lignes non pointées, état.
library;

class StatementTemplate {
  const StatementTemplate({
    this.id,
    required this.bankName,
    required this.label,
    this.delimiter = ';',
    this.hasHeader = true,
    this.skipRows = 0,
    required this.dateColumn,
    required this.labelColumn,
    this.debitColumn,
    this.creditColumn,
    this.amountColumn,
    this.referenceColumn,
    this.valueDateColumn,
    this.dateFormat = 'DD/MM/YYYY',
    this.decimalSeparator = ',',
    this.amountSignInverted = false,
  });

  final String? id;
  final String bankName;
  final String label;
  final String delimiter;
  final bool hasHeader;
  final int skipRows;
  final int dateColumn; // index 1-based
  final int labelColumn;
  final int? debitColumn;
  final int? creditColumn;
  final int? amountColumn;
  final int? referenceColumn;
  final int? valueDateColumn;
  final String dateFormat;
  final String decimalSeparator;
  final bool amountSignInverted;
}

class ParsedStatementLine {
  const ParsedStatementLine({required this.date, this.valueDate, required this.label, this.reference, required this.debit, required this.credit});

  final DateTime date;
  final DateTime? valueDate;
  final String label;
  final String? reference;
  final int debit;
  final int credit;
}

class StatementParseResult {
  const StatementParseResult({required this.lines, required this.errors});

  final List<ParsedStatementLine> lines;
  final List<String> errors;
}

DateTime? _parseDate(String raw, String format) {
  final s = raw.trim();
  final digits = RegExp(r'\d+').allMatches(s).map((m) => m.group(0)!).toList();
  if (digits.length < 3) return null;
  int y, mo, d;
  switch (format) {
    case 'YYYY-MM-DD':
      y = int.parse(digits[0]);
      mo = int.parse(digits[1]);
      d = int.parse(digits[2]);
    case 'MM/DD/YYYY':
      mo = int.parse(digits[0]);
      d = int.parse(digits[1]);
      y = int.parse(digits[2]);
    default: // DD/MM/YYYY
      d = int.parse(digits[0]);
      mo = int.parse(digits[1]);
      y = int.parse(digits[2]);
  }
  if (y < 100) y += 2000;
  final date = DateTime(y, mo, d);
  return (date.month == mo && date.day == d) ? date : null;
}

int? _parseAmount(String raw, String decimalSeparator) {
  var s = raw.trim().replaceAll(RegExp(r'[\s  ]'), '').replaceAll('FCFA', '').replaceAll('XOF', '');
  if (s.isEmpty) return 0;
  final negative = s.startsWith('-') || s.startsWith('(') || s.endsWith('-');
  s = s.replaceAll(RegExp(r'[()\-+]'), '');
  if (decimalSeparator == ',') {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else {
    s = s.replaceAll(',', '');
  }
  final v = double.tryParse(s);
  if (v == null) return null;
  final n = v.round();
  return negative ? -n : n;
}

List<String> _splitCsvLine(String line, String delimiter) {
  final out = <String>[];
  final cur = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        cur.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == delimiter && !quoted) {
      out.add(cur.toString());
      cur.clear();
    } else {
      cur.write(c);
    }
  }
  out.add(cur.toString());
  return out;
}

/// Analyse un relevé CSV selon le gabarit de la banque (§10.7). Point de vue entreprise : debit = sortie, credit = entrée.
StatementParseResult parseStatementCsv(String text, StatementTemplate t) {
  final lines = <ParsedStatementLine>[];
  final errors = <String>[];
  final rows = text.replaceAll('\r', '').split('\n');
  final delimiter = t.delimiter == '\\t' ? '\t' : t.delimiter;
  var skipped = 0;
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row.trim().isEmpty) continue;
    if (skipped < t.skipRows + (t.hasHeader ? 1 : 0)) {
      skipped++;
      continue;
    }
    final cols = _splitCsvLine(row, delimiter);
    String col(int? n) => (n == null || n < 1 || n > cols.length) ? '' : cols[n - 1];
    final date = _parseDate(col(t.dateColumn), t.dateFormat);
    if (date == null) {
      errors.add('ligne ${i + 1} : date illisible « ${col(t.dateColumn)} »');
      continue;
    }
    int debit = 0, credit = 0;
    if (t.amountColumn != null) {
      final a = _parseAmount(col(t.amountColumn), t.decimalSeparator);
      if (a == null) {
        errors.add('ligne ${i + 1} : montant illisible « ${col(t.amountColumn)} »');
        continue;
      }
      final signed = t.amountSignInverted ? -a : a;
      if (signed < 0) {
        debit = -signed;
      } else {
        credit = signed;
      }
    } else {
      final d = _parseAmount(col(t.debitColumn), t.decimalSeparator);
      final c = _parseAmount(col(t.creditColumn), t.decimalSeparator);
      if (d == null || c == null) {
        errors.add('ligne ${i + 1} : montant illisible');
        continue;
      }
      debit = d.abs();
      credit = c.abs();
    }
    if (debit == 0 && credit == 0) continue;
    lines.add(ParsedStatementLine(
      date: date,
      valueDate: t.valueDateColumn == null ? null : _parseDate(col(t.valueDateColumn), t.dateFormat),
      label: col(t.labelColumn).trim(),
      reference: t.referenceColumn == null || col(t.referenceColumn).trim().isEmpty ? null : col(t.referenceColumn).trim(),
      debit: debit,
      credit: credit,
    ));
  }
  return StatementParseResult(lines: lines, errors: errors);
}

class StatementLine {
  const StatementLine({required this.id, required this.statementId, required this.date, this.valueDate, required this.label, this.reference, required this.debit, required this.credit});

  final int id;
  final String statementId;
  final DateTime date;
  final DateTime? valueDate;
  final String label;
  final String? reference;
  final int debit;
  final int credit;

  int get net => credit - debit;
}

class BookLine {
  const BookLine({required this.id, required this.entryId, required this.date, required this.number, this.reference, required this.label, required this.debit, required this.credit});

  final String id;
  final String entryId;
  final DateTime date;
  final int number;
  final String? reference;
  final String label;
  final int debit;
  final int credit;

  int get net => debit - credit;
}

class ReconciliationStateModel {
  const ReconciliationStateModel({required this.bookBalance, required this.bankBalance, required this.depositsInTransit, required this.outstandingPayments, required this.unmatchedBankCredits, required this.unmatchedBankDebits, required this.difference});

  final int bookBalance, bankBalance, depositsInTransit, outstandingPayments, unmatchedBankCredits, unmatchedBankDebits, difference;
}

class ReconciliationProposalModel {
  const ReconciliationProposalModel({required this.statementLineId, required this.entryLineId, required this.amount, required this.dayGap});

  final int statementLineId;
  final String entryLineId;
  final int amount;
  final int dayGap;
}
