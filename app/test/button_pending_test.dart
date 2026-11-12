import 'dart:async';

import 'package:akonta/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget button) => tester.pumpWidget(MaterialApp(theme: buildAkontaTheme(), home: Scaffold(body: Center(child: button))));

  testWidgets('une action asynchrone désactive le bouton jusqu\'à sa fin : pas de double déclenchement', (tester) async {
    final done = Completer<void>();
    var calls = 0;
    await pump(
      tester,
      AkButton.primary(
        'Enregistrer',
        onPressed: () async {
          calls++;
          await done.future;
        },
      ),
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.tap(find.byType(AkButton), warnIfMissed: false); // second clic avant la fin de l'action
    await tester.pump();
    expect(calls, 1);
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
    done.complete();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.hourglass_top), findsNothing);
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(calls, 2, reason: 'le bouton redevient actif après l\'action');
  });

  testWidgets('une action qui échoue réactive le bouton', (tester) async {
    await pump(tester, AkButton.primary('Envoyer', onPressed: () async => throw StateError('hors ligne')));
    await tester.runAsync(() async {});
    final errors = <Object>[];
    await runZonedGuarded(() async {
      await tester.tap(find.text('Envoyer'));
      await tester.pump();
    }, (e, _) => errors.add(e));
    await tester.pump();
    expect(find.byIcon(Icons.hourglass_top), findsNothing);
  });

  testWidgets('une action synchrone n\'affiche aucun indicateur', (tester) async {
    var calls = 0;
    await pump(tester, AkButton.secondary('Fermer', onPressed: () => calls++));
    await tester.tap(find.text('Fermer'));
    await tester.pump();
    expect(calls, 1);
    expect(find.byIcon(Icons.hourglass_top), findsNothing);
  });
}
