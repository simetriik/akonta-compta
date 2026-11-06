import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/presentation/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _dossier = EntitySummary(id: 'e1', name: 'Maître ASSANI');

Future<ProviderContainer> _pump(WidgetTester tester) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: DossierCard(entity: _dossier))),
      GoRoute(path: '/dossiers/:id', builder: (_, s) => Text('fiche ${s.pathParameters['id']}')),
    ],
  );
  final container = ProviderContainer(overrides: [currentUserIdProvider.overrideWithValue(null)]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: buildAkontaTheme(), routerConfig: router)));
  return container;
}

void main() {
  testWidgets('un clic sur un dossier l\'ouvre et en fait le dossier actif', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.byType(DossierCard));
    await tester.pumpAndSettle();
    expect(container.read(currentEntityProvider)?.id, 'e1');
    expect(find.text('fiche e1'), findsOneWidget);
  });

  testWidgets('Entrée sur un dossier l\'ouvre aussi', (tester) async {
    final container = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(container.read(currentEntityProvider)?.id, 'e1');
    expect(find.text('fiche e1'), findsOneWidget);
  });
}
