import 'package:akonta/src/infrastructure/supabase/paginate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Source simulée qui plafonne chaque réponse à [cap] lignes, comme PostgREST (`max_rows`).
Future<List<int>> Function(int, int) _server(int total, {int cap = 1000}) => (from, to) async {
      final end = (to < from + cap - 1 ? to : from + cap - 1);
      return [for (var i = from; i <= end && i < total; i++) i];
    };

void main() {
  test('un plan de 1 288 comptes est lu en entier malgré le plafond de 1 000 lignes', () async {
    final rows = await fetchAllPages(_server(1288));
    expect(rows.length, 1288);
    expect(rows.first, 0);
    expect(rows.last, 1287);
  });

  test('sans pagination, le plafond coupait la fin du plan (régression A1)', () async {
    final truncated = await _server(1288)(0, 1999);
    expect(truncated.length, 1000);
  });

  test('un total multiple de la taille de page déclenche une page vide de fin, sans doublon', () async {
    final rows = await fetchAllPages(_server(2000));
    expect(rows.length, 2000);
    expect(rows.toSet().length, 2000);
  });

  test('résultat vide et petite liste : une seule requête utile', () async {
    expect(await fetchAllPages(_server(0)), isEmpty);
    expect((await fetchAllPages(_server(3))).length, 3);
  });
}
