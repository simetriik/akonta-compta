import 'package:akonta/src/application/rules/invoice_rules.dart';
import 'package:akonta/src/domain/invoice_models.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceLine _line(String name, int price, double qty, String group) => InvoiceLine(name: name, price: price, quantity: qty, taxGroup: group);

InvoiceDraft _draft({List<InvoiceLine>? lines, String operator = 'Jacques', String? clientIfu, String type = 'FV', String? reference}) => InvoiceDraft(
      entityId: 'e1',
      deviceId: 'd1',
      type: type,
      operatorName: operator,
      lines: lines ?? [_line('Jus', 1800, 2, 'B')],
      clientIfu: clientIfu,
      reference: reference,
    );

void main() {
  test('exemple de la spécification DGI : 2 × 1 800 (B) et 3 × 450 (A)', () {
    final t = previewTotals([_line('Jus d\'orange', 1800, 2, 'B'), _line('Lait', 450, 3, 'A')]);
    expect([t.totalA, t.totalB, t.htB, t.vatB, t.total], [1350, 3600, 3051, 549, 4950]);
  });

  test('le montant d\'une ligne est arrondi au franc, quantités décimales comprises', () {
    expect(_line('x', 1800, 2, 'B').amount, 3600);
    expect(_line('x', 450, 2.5, 'A').amount, 1125);
    expect(_line('x', 333, 1.5, 'B').amount, 500); // 499,5 arrondi vers le haut
    expect(_line('x', 1000, 3.25, 'B').amount, 3250);
  });

  test('sans article taxable, ni HT ni TVA', () {
    final t = previewTotals([_line('Eau', 500, 4, 'A')]);
    expect([t.totalB, t.htB, t.vatB, t.total], [0, 0, 0, 2000]);
  });

  test('taux de l\'AIB : A = 1 %, B = 5 %', () {
    expect([aibRate(null), aibRate('A'), aibRate('B')], [0, 1, 5]);
  });

  test('un brouillon valide n\'a aucun problème', () {
    expect(draftProblems(_draft(), forIssue: true), isEmpty);
  });

  test('refus des articles incomplets, de l\'IFU client mal formé et de l\'opérateur absent', () {
    expect(draftProblems(_draft(lines: const [], ), forIssue: true), contains('Ajoutez au moins un article.'));
    expect(draftProblems(_draft(lines: []), forIssue: false), isEmpty); // un brouillon vide peut être enregistré
    final p = draftProblems(_draft(lines: [_line('', 0, 0, 'B')], operator: ' ', clientIfu: '123'), forIssue: true);
    expect(p, containsAll(['Indiquez le nom de l\'opérateur.', 'L\'IFU du client comporte 13 caractères.', 'Article 1 : le nom est obligatoire.', 'Article 1 : le prix unitaire doit être supérieur à 0.', 'Article 1 : la quantité doit être supérieure à 0.']));
  });

  test('un avoir exige la référence de 24 caractères de la facture d\'origine', () {
    expect(draftProblems(_draft(type: 'FA'), forIssue: true), contains('La référence de la facture d\'origine doit comporter 24 caractères.'));
    expect(draftProblems(_draft(type: 'FA', reference: 'X537E4DBAJUUHHXNFWISFEKJ'), forIssue: true), isEmpty);
  });
}
