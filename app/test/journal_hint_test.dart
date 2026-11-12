import 'package:flutter_test/flutter_test.dart';
import 'package:akonta/src/application/rules/journal_hint.dart';
import 'package:akonta/src/domain/reference_models.dart';

void main() {
  const od = Journal(id: 'od', code: 'OD', label: 'Opérations diverses', type: 'misc', isActive: true);
  const bq = Journal(id: 'bq', code: 'BQ', label: 'Ecobank', type: 'bank', treasuryAccountId: 'a52', treasuryAccountCode: '5210000', isActive: true);
  final journals = [od, bq];

  test('compte de banque saisi dans le journal OD : avertissement qui nomme le journal BQ', () {
    final hint = JournalHint.treasuryMismatch(journals: journals, journalId: 'od', lineAccountIds: ['a52', 'a61']);
    expect(hint, contains('5210000'));
    expect(hint, contains('BQ'));
  });

  test('journal de banque correct : pas d\'avertissement', () {
    expect(JournalHint.treasuryMismatch(journals: journals, journalId: 'bq', lineAccountIds: ['a52', 'a61']), isNull);
  });

  test('aucun compte de trésorerie : pas d\'avertissement', () {
    expect(JournalHint.treasuryMismatch(journals: journals, journalId: 'od', lineAccountIds: ['a61', null]), isNull);
  });
}
