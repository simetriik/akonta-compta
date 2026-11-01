import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/core/errors/errors.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/repositories/admin_repository.dart';
import 'package:akonta/src/presentation/admin/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faux dépôt : ne répond qu'à la liste des profils et à la suppression ; refuse celle du membre « busy ».
class _FakeAdmin implements AdminRepository {
  final deleted = <String>[];

  @override
  Future<List<Profile>> profiles() async => [
    const Profile(id: 'fresh', cabinetId: 'c', email: 'fresh@a.test', fullName: 'Neuf', isActive: true),
    const Profile(id: 'busy', cabinetId: 'c', email: 'busy@a.test', fullName: 'Actif', isActive: true),
  ];

  final updated = <String, String>{};

  @override
  Future<void> updateProfile(String userId, {required String fullName, String? jobTitle}) async => updated[userId] = '$fullName|${jobTitle ?? ''}';

  @override
  Future<void> deleteMember(String userId) async {
    if (userId == 'busy') throw const AppError.business('Ce membre a des traces : désactivez-le.');
    deleted.add(userId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<_FakeAdmin> pumpScreen(WidgetTester tester) async {
    final repo = _FakeAdmin();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(repo), currentUserIdProvider.overrideWithValue('admin')],
        child: MaterialApp(
          theme: buildAkontaTheme(),
          home: const Scaffold(body: UsersScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('annuler la confirmation ne supprime rien', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('delete-member-fresh')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
  });

  testWidgets('confirmer supprime le membre', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('delete-member-fresh')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['fresh']);
  });

  testWidgets('un membre avec des traces : le refus de la base est affiché, rien n\'est supprimé', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('delete-member-busy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
    expect(find.textContaining('désactivez-le'), findsWidgets);
  });

  testWidgets('modifier un membre enregistre son nom et sa fonction', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('edit-member-fresh')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit-name')), 'Nouveau Nom');
    await tester.enterText(find.byKey(const Key('edit-job')), 'Comptable');
    await tester.tap(find.byKey(const Key('edit-submit')));
    await tester.pumpAndSettle();
    expect(repo.updated['fresh'], 'Nouveau Nom|Comptable');
  });

  testWidgets('modifier un membre exige un nom', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('edit-member-fresh')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit-name')), '');
    await tester.tap(find.byKey(const Key('edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Nom requis'), findsOneWidget);
    expect(repo.updated, isEmpty);
  });
}
