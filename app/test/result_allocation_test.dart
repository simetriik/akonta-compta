import 'package:flutter_test/flutter_test.dart';
import 'package:akonta/src/application/rules/result_allocation.dart';

void main() {
  test('bénéfice en instance : le total doit lui être égal', () {
    expect(ResultAllocation.check(650000, legal: 65000, free: 85000, dividends: 0, carry: 500000), isNull);
    expect(ResultAllocation.check(650000, legal: 65000, free: 85000, dividends: 0, carry: 300000), contains('doit égaler'));
  });

  test('aucun bénéfice en instance : montant nul refusé, montant positif accepté', () {
    expect(ResultAllocation.check(0, legal: 0, free: 0, dividends: 0, carry: 0), contains('à-nouveaux'));
    expect(ResultAllocation.check(0, legal: 0, free: 0, dividends: 0, carry: 1000), isNull);
  });
}
