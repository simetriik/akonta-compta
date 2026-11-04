import 'package:akonta/src/application/providers/entries_providers.dart';
import 'package:akonta/src/application/providers/references_providers.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/domain/entry_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/reference_models.dart';
import 'package:akonta/src/presentation/entries/entries_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden/golden_harness.dart';

class _FixedEntity extends CurrentEntityNotifier {
  @override
  EntitySummary? build() => const EntitySummary(id: 'e1', name: 'SARL Démo', fiscalYearLabel: '2026');
}

void main() {
  setUpAll(setUpGolden);

  final entry = EntryModel(
    id: 'x1',
    entityId: 'e1',
    journalId: 'j1',
    journalCode: 'OD',
    entryDate: DateTime(2026, 11, 2),
    label: 'Loyer novembre',
    status: 'draft',
    reviewStatus: 'none',
    isGenerated: false,
    totalDebit: 150000,
    totalCredit: 150000,
  );

  Widget app() => goldenApp(
    home: const EntriesScreen(),
    overrides: [
      currentEntityProvider.overrideWith(_FixedEntity.new),
      entriesListProvider.overrideWith((ref, id) async => [entry]),
      journalsProvider.overrideWith((ref, id) async => const [Journal(id: 'j1', code: 'OD', label: 'Opérations diverses', type: 'misc', isActive: true)]),
      permissionsProvider.overrideWith(
        (ref) async => const PermissionSet(
          byEntity: {
            'e1': {'entries.draft'},
          },
          cabinetWide: {},
          roles: [],
        ),
      ),
    ],
  );

  testWidgets('sur mobile, journal et mois sont repliés derrière « Filtres », le statut reste visible', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Brouillards'), findsOneWidget);
    expect(find.text('Tous les journaux'), findsNothing);
    expect(find.text('Tout l\'exercice'), findsNothing);
    await tester.tap(find.byKey(const Key('entries-filters-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Tout l\'exercice'), findsOneWidget);
    expect(find.text('Tous les journaux'), findsWidgets);
  });

  testWidgets('sur ordinateur, tous les filtres sont affichés sans bouton « Filtres »', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('entries-filters-toggle')), findsNothing);
    expect(find.text('Tout l\'exercice'), findsOneWidget);
    expect(find.text('Brouillards'), findsOneWidget);
  });
}
