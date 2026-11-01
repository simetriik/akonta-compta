import 'package:akonta/src/application/providers/admin_providers.dart';
import 'package:akonta/src/presentation/admin/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('l\'invitation exige un nom et une adresse e-mail valide', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: InviteUserDialog())),
      ),
    );
    await tester.enterText(find.byKey(const Key('invite-email')), 'pas-un-email');
    await tester.tap(find.byKey(const Key('invite-submit')));
    await tester.pump();
    expect(find.text('Nom requis'), findsOneWidget);
    expect(find.text('Adresse e-mail invalide'), findsOneWidget);
  });

  Future<void> pumpDialog(WidgetTester tester, bool hasPartner) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cabinetHasPartnerProvider.overrideWith((ref) async => hasPartner)],
        child: const MaterialApp(home: Scaffold(body: InviteUserDialog())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la case « premier associé » est proposée tant que le cabinet n\'a aucun associé', (tester) async {
    await pumpDialog(tester, false);
    expect(find.byKey(const Key('invite-first-partner')), findsOneWidget);
  });

  testWidgets('la case « premier associé » disparaît dès que le cabinet a un associé', (tester) async {
    await pumpDialog(tester, true);
    expect(find.byKey(const Key('invite-first-partner')), findsNothing);
  });
}
