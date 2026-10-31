import 'package:akonta/src/data/closing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> row(String code, String label, int amount) => {'post_code': code, 'post_label': label, 'column_role': 'amount', 'amount': amount, 'sort_order': 10};

  test('les états SYCEBNL portent le tableau des flux de N et de N-1', () {
    final fs = FinancialStatements.fromJson({
      'id': 's1',
      'generated_at': '2026-12-31T10:00:00Z',
      'is_final': false,
      'checks': <dynamic>[],
      'data': {
        'assets': <dynamic>[],
        'liabilities': <dynamic>[],
        'income': <dynamic>[],
        'cash_flow': [row('ZA', 'Trésorerie au 1er janvier', 1000000), row('ZG', 'Trésorerie au 31 décembre', 1900000)],
        'previous': {
          'assets': <dynamic>[],
          'liabilities': <dynamic>[],
          'income': <dynamic>[],
          'cash_flow': [row('ZG', 'Trésorerie au 31 décembre', 1000000)],
        },
      },
    });
    expect(fs.cashFlow.map((p) => '${p.code}=${p.amount}'), ['ZA=1000000', 'ZG=1900000']);
    expect(fs.previous?['cash_flow']?.single.amount, 1000000);
  });

  test('un état du système normal n\'a pas de tableau des flux', () {
    final fs = FinancialStatements.fromJson({
      'id': 's2',
      'generated_at': '2026-12-31T10:00:00Z',
      'checks': <dynamic>[],
      'data': {'assets': <dynamic>[], 'liabilities': <dynamic>[], 'income': <dynamic>[], 'previous': null},
    });
    expect(fs.cashFlow, isEmpty);
    expect(fs.previous, isNull);
  });
}
