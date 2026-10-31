import 'package:akonta/src/core/formatting.dart';
import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/closing/tax_worksheet.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/domain/closing_models.dart';
import 'package:akonta/src/domain/entity_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/repositories/closing_repository.dart';
import 'package:akonta/src/presentation/closing/tax_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'golden/golden_harness.dart';

class _FakeClosing implements ClosingRepository {
  _FakeClosing({this.failLoad = false});

  final bool failLoad;
  List<TaxAdjustment>? sent;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');

  @override
  Future<List<TaxAdjustment>> proposeAdjustments(String entityId, String fyId) async {
    if (failLoad) throw Exception('Connection refused');
    return [
      TaxAdjustment(code: 'amende', label: 'Amendes et pénalités', kind: 'add_back', amount: 200000),
      TaxAdjustment(code: 'plus_value', label: 'Plus-values non imposables', kind: 'deduction', amount: 50000),
    ];
  }

  @override
  Future<int> accountingResult(String entityId, String fyId) async => 1000000;

  @override
  Future<TaxComputation?> taxComputation(String fyId) async => null;

  @override
  Future<TaxComputation> computeTax(String entityId, String fyId, List<TaxAdjustment> adjustments) async {
    sent = adjustments;
    return const TaxComputation(accountingResult: 1000000, taxableResult: 1150000, revenue: 9000000, isRate: 0.25, computedTax: 287500, minimumTax: 250000, taxDue: 287500, prepayments: 100000, balanceDue: 187500);
  }
}

void main() {
  setUpAll(setUpGolden);

  const entity = EntitySummary(id: 'e1', name: 'Société test');
  final fy = FiscalYear(id: 'fy1', entityId: 'e1', label: '2026', startDate: DateTime(2026), endDate: DateTime(2026, 12, 31), status: 'open');

  Future<void> pump(WidgetTester tester, _FakeClosing repo) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [closingRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: buildAkontaTheme(), home: Scaffold(body: TaxStep(entity: entity, fy: fy))),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('le résultat fiscal ajoute les réintégrations et retire les déductions', () {
    final w = TaxWorksheet(
      accountingResult: 1000000,
      adjustments: [
        TaxAdjustment(code: 'a', label: 'a', kind: 'add_back', amount: 200000),
        TaxAdjustment(code: 'b', label: 'b', kind: 'add_back', amount: 50000),
        TaxAdjustment(code: 'c', label: 'c', kind: 'deduction', amount: 80000),
      ],
    );
    expect((w.addBacks, w.deductions, w.taxableResult), (250000, 80000, 1170000));
    w.adjustments.last.amount = 0;
    expect(w.taxableResult, 1250000);
  });

  testWidgets('affiche le tableau de passage et le résultat fiscal', (tester) async {
    await pump(tester, _FakeClosing());
    expect(find.text('Amendes et pénalités'), findsOneWidget);
    expect(find.textContaining('Résultat fiscal : '), findsOneWidget);
    expect(find.textContaining(Fmt.fcfa(1150000)), findsOneWidget);
  });

  testWidgets('une lecture qui échoue est annoncée avec un bouton Réessayer, sans chargement infini', (tester) async {
    await pump(tester, _FakeClosing(failLoad: true));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Connection refused'), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('le calcul envoie les montants affichés et montre l\'impôt dû', (tester) async {
    final repo = _FakeClosing();
    await pump(tester, repo);
    await tester.tap(find.text('Calculer l\'IS et générer l\'écriture (brouillard)'));
    await tester.pumpAndSettle();
    expect(repo.sent!.length, 2);
    expect(find.textContaining('IS dû : '), findsOneWidget);
    expect(find.textContaining(Fmt.fcfa(187500)), findsOneWidget);
  });
}
