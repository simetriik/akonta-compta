import 'package:akonta/src/domain/entity_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premier exercice : durée libre mais fin au 31 décembre', () {
    expect(validateFiscalYearDates(start: DateTime(2025, 7, 1), end: DateTime(2025, 12, 31), previousEnd: null), isNull);
    expect(validateFiscalYearDates(start: DateTime(2025, 7, 1), end: DateTime(2026, 6, 30), previousEnd: null), contains('31 décembre'));
    expect(validateFiscalYearDates(start: DateTime(2024, 1, 1), end: DateTime(2026, 12, 31), previousEnd: null), contains('24 mois'));
  });

  test('exercice suivant : continuité et année civile', () {
    final prev = DateTime(2025, 12, 31);
    expect(validateFiscalYearDates(start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 31), previousEnd: prev), isNull);
    expect(validateFiscalYearDates(start: DateTime(2026, 2, 1), end: DateTime(2026, 12, 31), previousEnd: prev), contains('lendemain'));
    expect(validateFiscalYearDates(start: DateTime(2026, 1, 1), end: DateTime(2027, 12, 31), previousEnd: prev), contains('1er janvier au 31 décembre'));
  });

  test('fiche entité : dénomination et IFU', () {
    expect(EntityInput.validateName(''), isNotNull);
    expect(EntityInput.validateName('SARL Démo'), isNull);
    expect(EntityInput.validateTaxId('3201900000001'), isNull);
    expect(EntityInput.validateTaxId('12'), isNotNull);
    expect(EntityInput.validateTaxId(''), isNull);
  });
}
