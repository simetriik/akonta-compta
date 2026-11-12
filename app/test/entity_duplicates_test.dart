import 'dart:async';

import 'package:akonta/design/design.dart';
import 'package:akonta/src/core/request_id.dart';
import 'package:akonta/src/infrastructure/supabase/supabase_entities_repository.dart';
import 'package:akonta/src/presentation/entities/entity_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('double clic sur « Créer » : une seule demande, bouton désactivé avec « Création en cours… »', (tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAkontaTheme(),
        home: Scaffold(
          body: EntityForm(
            submitLabel: 'Créer le dossier et continuer',
            busyLabel: 'Création en cours…',
            onSubmit: (_) {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.descendant(of: find.byKey(const Key('entity-name')), matching: find.byType(EditableText)), 'Maître ASSANI');
    final submit = find.byKey(const Key('entity-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.tap(submit); // second clic avant que l'écran ait pu se redessiner
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Création en cours…'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
  });

  test('l\'identifiant de demande est un UUID v4 différent à chaque appel', () {
    final a = newRequestId();
    expect(a, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(newRequestId(), isNot(a));
  });

  test('une demande rejouée est reconnue à l\'index d\'idempotence, pas un autre doublon', () {
    expect(isRequestReplay(const PostgrestException(message: 'duplicate key value violates unique constraint "entities_request_unique"', code: '23505')), isTrue);
    expect(isRequestReplay(const PostgrestException(message: 'duplicate key value violates unique constraint "entities_tax_id_unique"', code: '23505')), isFalse);
    expect(isRequestReplay(const PostgrestException(message: 'autre', code: '42501')), isFalse);
  });
}
