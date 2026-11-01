import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/core/password_policy.dart';
import 'package:akonta/src/domain/admin_models.dart';
import 'package:akonta/src/domain/repositories/auth_repository.dart';
import 'package:akonta/src/presentation/admin/users_screen.dart';
import 'package:akonta/src/presentation/auth/change_password.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth implements AuthRepository {
  final changed = <String>[];

  @override
  Future<void> changePassword(String newPassword) async => changed.add(newPassword);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('politique de mot de passe', () {
    test('refuse un mot de passe trop court, sans majuscule, sans chiffre', () {
      expect(PasswordPolicy.validate(''), isNotNull);
      expect(PasswordPolicy.validate('Court1'), contains('12'));
      expect(PasswordPolicy.validate('minuscules-seulement1'), contains('majuscule'));
      expect(PasswordPolicy.validate('SansChiffreDuTout'), contains('chiffre'));
    });

    test('accepte un mot de passe conforme', () => expect(PasswordPolicy.validate('Akonta-Demo-2026!'), isNull));

    test('la confirmation doit être identique', () {
      expect(PasswordPolicy.validateConfirmation('a', 'b'), isNotNull);
      expect(PasswordPolicy.validateConfirmation('a', 'a'), isNull);
    });
  });

  group('changement de mot de passe', () {
    Future<_FakeAuth> pump(WidgetTester tester, {required VoidCallback onDone}) async {
      final auth = _FakeAuth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
          child: MaterialApp(theme: buildAkontaTheme(), home: Scaffold(body: ChangePasswordForm(onDone: onDone))),
        ),
      );
      return auth;
    }

    testWidgets('un mot de passe faible ou une confirmation différente est refusé, rien n\'est envoyé', (tester) async {
      var done = false;
      final auth = await pump(tester, onDone: () => done = true);
      await tester.enterText(find.byKey(const Key('new-password')), 'faible');
      await tester.enterText(find.byKey(const Key('confirm-password')), 'autre');
      await tester.tap(find.byKey(const Key('password-submit')));
      await tester.pump();
      expect(find.textContaining('Au moins 12'), findsOneWidget);
      expect(find.text('Les deux saisies sont différentes'), findsOneWidget);
      expect(auth.changed, isEmpty);
      expect(done, isFalse);
    });

    testWidgets('un mot de passe conforme est enregistré', (tester) async {
      var done = false;
      final auth = await pump(tester, onDone: () => done = true);
      await tester.enterText(find.byKey(const Key('new-password')), 'Mon-Nouveau-2027');
      await tester.enterText(find.byKey(const Key('confirm-password')), 'Mon-Nouveau-2027');
      await tester.tap(find.byKey(const Key('password-submit')));
      await tester.pumpAndSettle();
      expect(auth.changed, ['Mon-Nouveau-2027']);
      expect(done, isTrue);
    });
  });

  testWidgets('l\'accès provisoire montre le mot de passe et prépare le message à envoyer', (tester) async {
    const access = TemporaryAccess(email: 'associe@akonta.test', password: 'Kx7mPq2RvT9n');
    await tester.pumpWidget(MaterialApp(theme: buildAkontaTheme(), home: const Scaffold(body: TemporaryAccessDialog(title: 'Compte créé', accesses: [access]))));
    expect(find.text('Kx7mPq2RvT9n'), findsOneWidget);
    expect(find.textContaining('ne seront plus affichés'), findsOneWidget);
    expect(TemporaryAccessDialog.message(access), allOf(contains('associe@akonta.test'), contains('Kx7mPq2RvT9n'), contains('première connexion')));
  });
}
