import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/providers/admin_providers.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/application/rules/member_rules.dart';
import 'package:akonta/src/domain/admin_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/repositories/admin_repository.dart';
import 'package:akonta/src/presentation/admin/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const admin = PermissionSet(byEntity: {}, cabinetWide: {'users.manage'}, roles: []);
const partner = PermissionSet(byEntity: {}, cabinetWide: {'team.manage', 'assignments.manage'}, roles: []);
const assistant = PermissionSet(byEntity: {'e1': {'entries.draft'}}, cabinetWide: {}, roles: []);

Assignment _a(String user, String code, String name) => Assignment(id: '$user-$code', userId: user, userName: user, roleId: code, roleName: name, roleCode: code);

class _FakeAdmin implements AdminRepository {
  @override
  Future<List<Profile>> profiles() async => [
    const Profile(id: 'me', cabinetId: 'c', email: 'me@a', fullName: 'Moi', isActive: true),
    const Profile(id: 'p2', cabinetId: 'c', email: 'p2@a', fullName: 'Associé Deux', isActive: true),
    const Profile(id: 'ast', cabinetId: 'c', email: 'ast@a', fullName: 'Assistante', isActive: true),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('qui gère qui', () {
    test('l\'administrateur gère tout le monde sauf lui-même', () {
      expect(MemberRules.canManage(admin, {'partner'}, isSelf: false), isTrue);
      expect(MemberRules.canManage(admin, {'tech_admin'}, isSelf: false), isTrue);
      expect(MemberRules.canManage(admin, {'partner'}, isSelf: true), isFalse);
    });

    test('l\'associé gère son équipe et les comptes sans rôle, pas les associés ni l\'administrateur', () {
      expect(MemberRules.canManage(partner, {'assistant'}, isSelf: false), isTrue);
      expect(MemberRules.canManage(partner, {}, isSelf: false), isTrue);
      expect(MemberRules.canManage(partner, {'partner'}, isSelf: false), isFalse);
      expect(MemberRules.canManage(partner, {'tech_admin'}, isSelf: false), isFalse);
      expect(MemberRules.canManage(partner, {'assistant'}, isSelf: true), isFalse);
    });

    test('un assistant ne gère personne et n\'ouvre pas l\'écran', () {
      expect(MemberRules.canManage(assistant, {}, isSelf: false), isFalse);
      expect(MemberRules.canOpenMembers(assistant), isFalse);
      expect(MemberRules.canOpenMembers(partner), isTrue);
      expect(MemberRules.canOpenMembers(admin), isTrue);
    });

    test('seul l\'administrateur désigne ou retire un associé', () {
      expect(MemberRules.canDesignatePartner(admin, {'assistant'}, isSelf: false), isTrue);
      expect(MemberRules.canDesignatePartner(admin, {'partner'}, isSelf: false), isFalse);
      expect(MemberRules.canDesignatePartner(partner, {}, isSelf: false), isFalse);
      expect(MemberRules.canRevokePartner(admin, {'partner'}, isSelf: false), isTrue);
      expect(MemberRules.canRevokePartner(admin, {'assistant'}, isSelf: false), isFalse);
      expect(MemberRules.canRevokePartner(partner, {'partner'}, isSelf: false), isFalse);
    });

    test('libellé des rôles d\'un membre', () {
      final all = [_a('u', 'manager', 'Chef de mission'), _a('u', 'assistant', 'Assistant'), _a('u', 'assistant', 'Assistant'), _a('v', 'partner', 'Associé')];
      expect(MemberRules.rolesLabel(all, 'u'), 'Chef de mission, Assistant');
      expect(MemberRules.rolesLabel(all, 'w'), '');
      expect(MemberRules.roleCodesByUser(all)['u'], {'manager', 'assistant'});
    });
  });

  group('écran Collaborateurs', () {
    Future<void> pump(WidgetTester tester, PermissionSet perms) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminRepositoryProvider.overrideWithValue(_FakeAdmin()),
            currentUserIdProvider.overrideWithValue('me'),
            permissionsProvider.overrideWith((ref) async => perms),
            assignmentsProvider.overrideWith((ref) async => [_a('me', 'partner', 'Associé'), _a('p2', 'partner', 'Associé'), _a('ast', 'assistant', 'Assistant')]),
            cabinetHasPartnerProvider.overrideWith((ref) async => true),
          ],
          child: MaterialApp(theme: buildAkontaTheme(), home: const Scaffold(body: UsersScreen())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('l\'associé gère l\'assistante mais n\'a aucune action sur un autre associé', (tester) async {
      await pump(tester, partner);
      expect(find.byKey(const Key('delete-member-ast')), findsOneWidget);
      expect(find.byKey(const Key('reset-password-ast')), findsOneWidget);
      expect(find.byKey(const Key('delete-member-p2')), findsNothing);
      expect(find.byKey(const Key('edit-member-p2')), findsNothing);
      expect(find.byKey(const Key('designate-partner-ast')), findsNothing);
      expect(find.byKey(const Key('member-roles-ast')), findsOneWidget);
      expect(find.text('Importer des collaborateurs (CSV)'), findsNothing);
    });

    testWidgets('l\'administrateur désigne l\'assistante associée et peut retirer le rôle d\'un associé', (tester) async {
      await pump(tester, admin);
      expect(find.byKey(const Key('designate-partner-ast')), findsOneWidget);
      expect(find.byKey(const Key('revoke-partner-p2')), findsOneWidget);
      expect(find.byKey(const Key('designate-partner-p2')), findsNothing);
      expect(find.byKey(const Key('delete-member-me')), findsNothing);
      expect(find.text('Importer des collaborateurs (CSV)'), findsOneWidget);
    });
  });
}
