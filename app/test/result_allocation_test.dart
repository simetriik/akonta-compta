import 'package:flutter_test/flutter_test.dart';
import 'package:akonta/src/application/rules/result_allocation.dart';

void main() {
  int total({int legal = 0, int free = 0, int div = 0, int carry = 0}) => legal + free + div + carry;

  test('nature du résultat en instance', () {
    expect(ResultAllocation.kind(500000), ResultKind.profit);
    expect(ResultAllocation.kind(-100000), ResultKind.loss);
    expect(ResultAllocation.kind(0), ResultKind.none);
    expect(total(), 0);
  });

  test('perte : aucune répartition acceptée, montants à zéro acceptés (AN-38)', () {
    expect(ResultAllocation.check(-100000, legal: 0, free: 0, dividends: 0, carry: 0), isNull);
    expect(ResultAllocation.check(-100000, legal: 0, free: 0, dividends: 0, carry: 100000), contains('perte'));
  });

  test('bénéfice : le total doit égaler le résultat en instance', () {
    expect(ResultAllocation.check(500000, legal: 50000, free: 100000, dividends: 0, carry: 350000), isNull);
    expect(ResultAllocation.check(500000, legal: 50000, free: 100000, dividends: 0, carry: 300000), contains('doit égaler'));
  });

  test('aucun résultat en instance : montant nul refusé, montant positif accepté', () {
    expect(ResultAllocation.check(0, legal: 0, free: 0, dividends: 0, carry: 0), contains('à-nouveaux'));
    expect(ResultAllocation.check(0, legal: 0, free: 0, dividends: 0, carry: 1000), isNull);
  });
}
