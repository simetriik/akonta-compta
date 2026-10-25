import 'package:akonta/src/core/formatting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('Fmt.fcfa', () {
    test('sépare les milliers avec une espace insécable et masque zéro', () {
      expect(Fmt.fcfa(1180000), '1 180 000');
      expect(Fmt.fcfa(0), '');
      expect(Fmt.fcfa(0, showZero: true), '0');
      expect(Fmt.fcfa(null), '');
    });
    test('analyse un montant saisi avec espaces ou points', () {
      expect(Fmt.parseAmount('1 180 000'), 1180000);
      expect(Fmt.parseAmount('1.180.000'), 1180000);
      expect(Fmt.parseAmount('12a'), null);
      expect(Fmt.parseAmount(''), null);
    });
  });

  group('Fmt.date', () {
    test('formate et analyse jj/mm/aaaa', () {
      expect(Fmt.date(DateTime(2026, 1, 5)), '05/01/2026');
      expect(Fmt.parseDate('31/12/2026'), DateTime(2026, 12, 31));
      expect(Fmt.parseDate('31/02/2026'), null);
      expect(Fmt.parseDate('2026-01-05'), null);
    });
  });
}
