import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/providers/admin_providers.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/core/errors/errors.dart';
import 'package:akonta/src/domain/admin_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/repositories/admin_repository.dart';
import 'package:akonta/src/presentation/admin/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faux dépôt : liste deux membres ; la réinitialisation du membre « busy » est refusée par le serveur.
class _FakeAdmin implements AdminRepository {
  final reset = <String>[];

  @override
  Future<List<Profile>> profiles() async => [
    const Profile(id: 'lost', cabinetId: 'c', email: 'lost@a.test', fullName: 'Téléphone perdu', isActive: true),
    const Profile(id: 'busy', cabinetId: 'c', email: 'busy@a.test', fullName: 'Refusé', isActive: true),
  ];

  @override
  Future<int> resetMfa(String userId) async {
    if (userId == 'busy') throw const AppError.business('Vous ne pouvez pas gérer ce membre');
    reset.add(userId);
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<_FakeAdmin> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeAdmin();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('admin'),
          permissionsProvider.overrideWith((ref) async => const PermissionSet(byEntity: {}, cabinetWide: {'users.manage'}, roles: [])),
          assignmentsProvider.overrideWith((ref) async => <Assignment>[]),
        ],
        child: MaterialApp(
          theme: buildAkontaTheme(),
          home: const Scaffold(body: UsersScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('annuler la confirmation ne réinitialise rien', (tester) async {
    final repo = await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('reset-mfa-lost')));
    await tester.pumpAndSettle();
    expect(find.text('Réinitialiser la double vérification'), findsWidgets);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repo.reset, isEmpty);
  });

  testWidgets('confirmer réinitialise la double vérification du membre', (tester) async {
    final repo = await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('reset-mfa-lost')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.reset, ['lost']);
    expect(find.textContaining('réinitialisée'), findsOneWidget);
  });

  testWidgets('un refus du serveur est affiché et rien n\'est réinitialisé', (tester) async {
    final repo = await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('reset-mfa-busy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.reset, isEmpty);
    expect(find.textContaining('gérer ce membre'), findsOneWidget);
  });
}
