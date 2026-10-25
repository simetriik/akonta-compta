import 'package:akonta/src/presentation/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('refuse un mot de passe de moins de 12 caractères avant tout appel réseau', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
    await tester.enterText(find.byKey(const Key('login-email')), 'assistant@abc.bj');
    await tester.enterText(find.byKey(const Key('login-password')), 'court');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(find.text('Au moins 12 caractères'), findsOneWidget);
    expect(find.byKey(const Key('login-error')), findsNothing);
  });

  testWidgets('exige une adresse e-mail valide', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
    await tester.enterText(find.byKey(const Key('login-email')), 'pas-un-email');
    await tester.enterText(find.byKey(const Key('login-password')), 'Motdepasse-Robuste-2026');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(find.text('Adresse e-mail invalide'), findsOneWidget);
  });
}
