import 'package:akonta/design/design.dart';
import 'package:akonta/src/data/closing_repository.dart';
import 'package:akonta/src/presentation/closing/statement_notes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

NoteLine _line(String note, String title, String code, String label, int amount, {int? previous, String kind = 'line'}) =>
    NoteLine(noteCode: note, noteTitle: title, lineCode: code, label: label, kind: kind, amount: amount, previous: previous);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  final notes = [
    _line('16', 'Réserves', '16-1', 'Réserves statutaires ou contractuelles', 100000, previous: 80000),
    _line('16', 'Réserves', '16-T', 'TOTAL RÉSERVES', 100000, previous: 80000, kind: 'subtotal'),
    _line('23', 'Revenus et autres produits', '23-1', 'Cotisations des adhérents', 400000),
    _line('23', 'Revenus et autres produits', '23-T', 'TOTAL', 400000, kind: 'total'),
  ];

  Future<void> pumpSection(WidgetTester tester, List<NoteLine> lines) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAkontaTheme(), home: Scaffold(body: SingleChildScrollView(child: StatementNotesSection(notes: lines)))));
  }

  testWidgets('la première note s\'affiche avec ses colonnes N, N-1, variation et pourcentage', (tester) async {
    await pumpSection(tester, notes);
    expect(find.text('Réserves statutaires ou contractuelles'), findsOneWidget);
    expect(find.text('Année N-1'), findsOneWidget);
    expect(find.text('Variation'), findsOneWidget);
    expect(find.text('25,0 %'), findsNWidgets(2)); // ligne et total : (100 000 - 80 000) / 80 000
  });

  testWidgets('une note sans exercice précédent n\'affiche pas de colonnes de variation', (tester) async {
    await pumpSection(tester, notes.where((n) => n.noteCode == '23').toList());
    expect(find.text('Cotisations des adhérents'), findsOneWidget);
    expect(find.text('Année N-1'), findsNothing);
    expect(find.text('Variation'), findsNothing);
  });

  testWidgets('rien n\'est affiché sans notes (système normal)', (tester) async {
    await pumpSection(tester, const []);
    expect(find.byKey(const Key('notes-section')), findsNothing);
  });

  test('variation et pourcentage d\'une ligne', () {
    final l = _line('16', 'Réserves', '16-1', 'x', 120000, previous: 100000);
    expect(l.variation, 20000);
    expect(l.variationPercent, 20);
    expect(_line('16', 'Réserves', '16-1', 'x', 5, previous: 0).variationPercent, isNull);
    expect(_line('16', 'Réserves', '16-1', 'x', 5).variation, isNull);
  });
}
