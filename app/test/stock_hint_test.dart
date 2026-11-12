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

  test('compte de variation de marchandises : 6031, jamais le regroupement 603 (AN-37)', () {
    expect(StockHint.variationPrefix('3111000'), '6031');
    expect(StockHint.variationPrefix('3210000'), '6032');
    expect(StockHint.variationPrefix('3310000'), '6033');
    expect(StockHint.variationPrefix('3600000'), '73');
  });

  test('compte de regroupement 6030000 : avertissement qui nomme les comptes précis', () {
    const plan = ['6030000', '6031000', '6032000', '6033000'];
    expect(StockHint.groupingVariation('6030000', plan), allOf(contains('regroupement'), contains('6031000')));
  });

  test('compte précis 6031000 : pas d\'avertissement', () {
    expect(StockHint.groupingVariation('6031000', const ['6030000', '6031000', '6032000']), isNull);
  });
}
