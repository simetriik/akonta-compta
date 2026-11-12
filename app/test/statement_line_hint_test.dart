import 'package:flutter_test/flutter_test.dart';
import 'package:akonta/src/application/rules/statement_line_hint.dart';

void main() {
  test('entrée d\'argent sur un compte de charges : avertissement', () {
    expect(StatementLineHint.counterpartWarning(isInflow: true, accountClass: 6), contains('411'));
  });

  test('sortie d\'argent sur un compte de produits : avertissement', () {
    expect(StatementLineHint.counterpartWarning(isInflow: false, accountClass: 7), contains('classe 7'));
  });

  test('sens cohérent ou autre classe : pas d\'avertissement', () {
    expect(StatementLineHint.counterpartWarning(isInflow: true, accountClass: 4), isNull);
    expect(StatementLineHint.counterpartWarning(isInflow: false, accountClass: 6), isNull);
    expect(StatementLineHint.counterpartWarning(isInflow: true, accountClass: 7), isNull);
  });
}
