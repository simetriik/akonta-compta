import 'package:akonta/src/domain/reference_models.dart';
import 'package:flutter_test/flutter_test.dart';

Account _acc(String code) => Account(id: code, code: code, label: code, classNo: int.parse(code[0]), normalSide: 'debit', isCollective: false, isLetterable: false, allowPosting: true, isActive: true);

void main() {
  final plan = [_acc('4011000'), _acc('4111000'), _acc('6318000')];

  test('un code complet tapé au clavier désigne le compte', () {
    expect(matchAccountCode(plan, '6318000')?.code, '6318000');
    expect(matchAccountCode(plan, ' 4111000 ')?.code, '4111000');
  });

  test('un code court est complété par des zéros à la longueur du plan', () {
    expect(matchAccountCode(plan, '6318')?.code, '6318000');
    expect(matchAccountCode(plan, '4011')?.code, '4011000');
  });

  test('texte libre, code inconnu ou vide : aucun compte', () {
    expect(matchAccountCode(plan, 'frais'), isNull);
    expect(matchAccountCode(plan, '6319'), isNull);
    expect(matchAccountCode(plan, ''), isNull);
    expect(matchAccountCode(const <Account>[], '6318'), isNull);
  });
}
