import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/domain/entity_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/presentation/entities/duplicate_entity_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _detail = EntityDetail(id: 'e1', cabinetId: 'c1', name: 'Maître ASSANI');

Future<void> _pump(WidgetTester tester, {required EntitySummary summary, Set<String> perms = const {'entities.manage'}}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        entityDashboardProvider.overrideWith((ref) async => [summary]),
        permissionsProvider.overrideWith((ref) async => PermissionSet(byEntity: {'e1': perms}, cabinetWide: const {}, roles: const [])),
      ],
      child: MaterialApp(theme: buildAkontaTheme(), home: const Scaffold(body: DuplicateEntityButton(entity: _detail))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const button = Key('delete-duplicate-entity');

  testWidgets('dossier vide avec le droit : le bouton est proposé', (tester) async {
    await _pump(tester, summary: const EntitySummary(id: 'e1', name: 'Maître ASSANI'));
    expect(find.byKey(button), findsOneWidget);
  });

  testWidgets('dossier en service : le bouton est masqué (UX-16)', (tester) async {
    await _pump(tester, summary: EntitySummary(id: 'e1', name: 'Maître ASSANI', lastEntryDate: DateTime(2026, 10, 31)));
    expect(find.byKey(button), findsNothing);
    await _pump(tester, summary: const EntitySummary(id: 'e1', name: 'Maître ASSANI', draftCount: 3));
    expect(find.byKey(button), findsNothing);
  });

  testWidgets('dossier vide sans le droit de gestion : le bouton est masqué', (tester) async {
    await _pump(tester, summary: const EntitySummary(id: 'e1', name: 'Maître ASSANI'), perms: const {'ledger.read'});
    expect(find.byKey(button), findsNothing);
  });
}
