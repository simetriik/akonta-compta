import 'package:akonta/src/presentation/admin/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('l\'invitation exige un nom et une adresse e-mail valide', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: InviteUserDialog()))));
    await tester.enterText(find.byKey(const Key('invite-email')), 'pas-un-email');
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pump();
    expect(find.text('Nom requis'), findsOneWidget);
    expect(find.text('Adresse e-mail invalide'), findsOneWidget);
  });
}
