import 'package:akonta/src/application/rules/inventory_forms.dart';
import 'package:akonta/src/core/formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('décimal saisi avec virgule ou point', () {
    expect(Fmt.parseDecimal('2,5'), 2.5);
    expect(Fmt.parseDecimal(' 2.5 '), 2.5);
    expect(Fmt.parseDecimal('abc'), isNull);
    expect(Fmt.parseDecimal(''), isNull);
  });

  group('taux de provision', () {
    test('une virgule est comprise (elle était lue comme 0 auparavant)', () {
      final r = InventoryForms.provisionRates(r91: '2,5', r180: '50').value!;
      expect((r.rate91to180, r.rateOver180), (0.025, 0.5));
    });

    test('un champ vide vaut 0, un texte ou une valeur hors 0-100 est refusé', () {
      expect(InventoryForms.provisionRates(r91: '', r180: '').value!.rate91to180, 0);
      expect(InventoryForms.provisionRates(r91: 'x', r180: '10').error, isNotNull);
      expect(InventoryForms.provisionRates(r91: '101', r180: '10').error, isNotNull);
      expect(InventoryForms.provisionRates(r91: '-1', r180: '10').error, isNotNull);
    });
  });

  group('régularisation', () {
    FormResult<AccrualValues> accrual({String desc = 'Loyer', String? account = 'a', String? counterpart = 'c', String total = '120 000', String from = '01/10/2026', String to = '31/03/2027'}) =>
        InventoryForms.accrual(description: desc, accountId: account, counterpartAccountId: counterpart, total: total, from: from, to: to);

    test('valeurs valides', () {
      final v = accrual().value!;
      expect((v.description, v.totalAmount, v.from, v.to), ('Loyer', 120000, DateTime(2026, 10), DateTime(2027, 3, 31)));
    });

    test('refus : description, comptes, montant, période inversée', () {
      for (final r in [accrual(desc: ' '), accrual(account: null), accrual(counterpart: null), accrual(total: '0'), accrual(total: ''), accrual(from: '01/04/2027'), accrual(to: 'x')]) {
        expect(r.error, 'Description, comptes, montant et période requis');
      }
    });
  });

  group('cession', () {
    test('prix vide = 0, date illisible ou prix invalide refusés', () {
      expect(InventoryForms.disposal(date: '30/09/2026', price: '').value!.price, 0);
      expect(InventoryForms.disposal(date: '30/09/2026', price: '1 500 000').value!.price, 1500000);
      expect(InventoryForms.disposal(date: '99/99/2026', price: '').error, isNotNull);
      expect(InventoryForms.disposal(date: '30/09/2026', price: 'beaucoup').error, isNotNull);
    });
  });

  group('cours de change', () {
    test('devise en majuscules et cours avec virgule', () {
      final v = InventoryForms.fxRate(currency: ' eur ', rate: '655,957').value!;
      expect((v.currency, v.rate), ('EUR', 655.957));
    });

    test('devise sur 3 lettres, cours strictement positif', () {
      expect(InventoryForms.fxRate(currency: 'EU', rate: '655').error, isNotNull);
      expect(InventoryForms.fxRate(currency: 'EUR', rate: '0').error, isNotNull);
      expect(InventoryForms.fxRate(currency: 'EUR', rate: 'x').error, isNotNull);
    });
  });

  test('stock final : valeur positive et compte de variation obligatoires', () {
    expect(InventoryForms.stockValue(closing: '1 250 000', variationAccountId: 'v').value, 1250000);
    expect(InventoryForms.stockValue(closing: '', variationAccountId: 'v').error, isNotNull);
    expect(InventoryForms.stockValue(closing: '5', variationAccountId: null).error, isNotNull);
  });
}
