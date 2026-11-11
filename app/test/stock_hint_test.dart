import 'package:flutter_test/flutter_test.dart';
import 'package:akonta/src/application/rules/stock_hint.dart';

void main() {
  const opening = {'3110000': 0, '3111000': 4800000};

  test('compte sans stock initial alors qu\'un autre en porte un : avertissement qui nomme l\'autre compte', () {
    expect(StockHint.wrongAccount('3110000', opening), contains('3111000'));
  });

  test('compte qui porte le stock initial : pas d\'avertissement', () {
    expect(StockHint.wrongAccount('3111000', opening), isNull);
  });

  test('aucun stock initial nulle part (premier exercice) : pas d\'avertissement', () {
    expect(StockHint.wrongAccount('3110000', const {'3110000': 0, '3111000': 0}), isNull);
  });
}
