import 'package:akonta/design/design.dart';
import 'package:akonta/src/data/supabase_providers.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/reference_models.dart';
import 'package:akonta/src/presentation/entries/entry_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:akonta/src/application/providers/references_providers.dart';

/// Dossier courant pré-sélectionné pour les tests.
class _FixedEntity extends CurrentEntityNotifier {
  @override
  EntitySummary? build() => const EntitySummary(id: 'e1', name: 'SARL Démo', fiscalYearLabel: '2026');
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  const accounts = [
    Account(id: 'a1', code: '6221000', label: 'Locations', classNo: 6, normalSide: 'debit', isCollective: false, isLetterable: false, allowPosting: true, isActive: true),
    Account(id: 'a2', code: '5210000', label: 'Banques locales', classNo: 5, normalSide: 'debit', isCollective: false, isLetterable: false, allowPosting: true, isActive: true),
  ];
  const journals = [Journal(id: 'j1', code: 'OD', label: 'Opérations diverses', type: 'misc', isActive: true)];

  Widget app() => ProviderScope(
        overrides: [
          currentEntityProvider.overrideWith(_FixedEntity.new),
          accountsProvider.overrideWith((ref, id) async => accounts),
          thirdPartiesProvider.overrideWith((ref, id) async => const <ThirdParty>[]),
          journalsProvider.overrideWith((ref, id) async => journals),
          permissionsProvider.overrideWith((ref) async => const PermissionSet(byEntity: {'e1': {'entries.draft', 'entries.validate'}}, cabinetWide: {}, roles: [])),
        ],
        child: const MaterialApp(home: Scaffold(body: EntryEditorScreen())),
      );

  testWidgets('la grille affiche l\'écart puis l\'équilibre après contrepartie automatique', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Équilibrée'), findsOneWidget);

    // Saisie d'un débit de 100 000 sur la première ligne
    final debitFields = find.byType(AkAmountField);
    await tester.enterText(debitFields.at(0), '100000');
    await tester.pumpAndSettle();
    expect(find.textContaining('Écart'), findsOneWidget);

    // Contrepartie automatique (bouton) → crédit 100 000 sur la ligne vide
    await tester.tap(find.text('Contrepartie (Ctrl+B)'));
    await tester.pumpAndSettle();
    expect(find.text('Équilibrée'), findsOneWidget);
  });

  testWidgets('valider sans compte ni libellé liste les erreurs sans appel réseau', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('validate-entry')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Journal requis'), findsOneWidget);
    expect(find.textContaining('Libellé requis'), findsOneWidget);
    expect(find.textContaining('Au moins deux lignes'), findsOneWidget);
  });
}
