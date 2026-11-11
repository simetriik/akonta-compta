import 'package:akonta/src/domain/bank_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relevé à colonnes débit / crédit, point-virgule, montants français', () {
    const t = StatementTemplate(bankName: 'Ecobank', label: 'Export CSV', dateColumn: 1, labelColumn: 2, debitColumn: 3, creditColumn: 4, referenceColumn: 5);
    final r = parseStatementCsv('Date;Libellé;Débit;Crédit;Réf\n12/01/2026;VIR CHU PARAKOU;;500 000,00;V123\n21/01/2026;"VIR GROUPE; LOYERS";200 000,00;;\n', t);
    expect(r.errors, isEmpty);
    expect(r.lines.length, 2);
    expect(r.lines[0].credit, 500000);
    expect(r.lines[0].reference, 'V123');
    expect(r.lines[1].debit, 200000);
    expect(r.lines[1].label, 'VIR GROUPE; LOYERS');
  });

  test('relevé à montant signé, format ISO, signe inversé', () {
    const t = StatementTemplate(bankName: 'BOA', label: 'Signé', delimiter: ',', dateColumn: 1, labelColumn: 2, amountColumn: 3, dateFormat: 'YYYY-MM-DD', decimalSeparator: '.', amountSignInverted: true);
    final r = parseStatementCsv('date,label,amount\n2026-01-31,FRAIS,16500.00\n2026-01-12,VIREMENT RECU,-500000\n', t);
    expect(r.lines[0].debit, 16500, reason: 'signe inversé : positif = sortie');
    expect(r.lines[1].credit, 500000);
  });

  test('lignes illisibles signalées sans bloquer', () {
    const t = StatementTemplate(bankName: 'X', label: 'x', hasHeader: false, dateColumn: 1, labelColumn: 2, debitColumn: 3, creditColumn: 4);
    final r = parseStatementCsv('pas une date;x;1;0\n05/02/2026;ok;0;10\n', t);
    expect(r.errors.length, 1);
    expect(r.lines.single.credit, 10);
  });

  test('un montant illisible nomme la colonne et son contenu (AN-12)', () {
    // Gabarit par défaut 1/2/3/4 sur un relevé à 7 colonnes : la colonne 3 est le libellé, pas un montant.
    const t = StatementTemplate(bankName: 'Ecobank', label: 'Défaut', delimiter: ';', dateColumn: 1, labelColumn: 2, debitColumn: 3, creditColumn: 4);
    final r = parseStatementCsv('Date;Valeur;Libellé;Débit;Crédit;Réf;Solde\n05/01/2027;05/01/2027;VIR RECU;0;1 770 000;R1;1 770 000\n', t);
    expect(r.lines, isEmpty);
    expect(r.errors.single, allOf(contains('colonne 3'), contains('VIR RECU'), contains('débit')));
  });
}
