import 'package:akonta/src/domain/entry_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le filtre « à corriger » ne touche pas au statut de l\'écriture', () {
    const f = EntryFilter(reviewStatus: 'to_correct');
    expect(f.status, isNull);
    expect(f.toReviewOnly, isFalse);
  });

  test('un brouillon n\'a pas de numéro de pièce', () {
    final e = EntryModel(
      id: 'x',
      entityId: 'e',
      journalId: 'j',
      journalCode: 'OD',
      entryDate: DateTime(2026, 1, 1),
      label: 'L',
      status: 'draft',
      reviewStatus: 'none',
      isGenerated: false,
    );
    expect(e.number, isNull);
  });
}
