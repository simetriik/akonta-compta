import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/connectivity/connectivity.dart';
import 'package:akonta/src/application/providers/invoices_providers.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/application/providers/services.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/application/rules/client_rules.dart';
import 'package:akonta/src/domain/entry_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/admin_models.dart';
import 'package:akonta/src/domain/repositories/client_access_repository.dart';
import 'package:akonta/src/presentation/dashboard/client_home_screen.dart';
import 'package:akonta/src/presentation/entities/client_access_tab.dart';
import 'package:akonta/src/presentation/entries/return_draft_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Repo implements ClientAccessRepository {
  final changes = <String>[];
  final returned = <String>[];

  @override
  Future<String> access(String entityId) async => 'disabled';
  @override
  Future<void> setAccess(String entityId, String status, {String? reason}) async => changes.add('$entityId:$status');
  @override
  Future<void> returnDraft(String entryId, String comment) async => returned.add('$entryId:$comment');
}

AssignedRole _role(String code, {bool client = false}) =>
    AssignedRole(roleId: code, code: code, name: code, entityId: client ? 'e1' : null, requiresMfa: false, grantsAllEntities: !client, accountingAccess: !client, isClient: client);

EntryModel _entry({String? returned, String status = 'draft', String? createdBy}) => EntryModel(
  id: 'x1', entityId: 'e1', journalId: 'j1', journalCode: 'VT', entryDate: DateTime(2026, 2, 1), label: 'Vente', status: status, reviewStatus: 'not_reviewed',
  returnedComment: returned, isGenerated: false, createdBy: createdBy,
);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('un client n\'ouvre que l\'accueil, la saisie, les pièces et les factures', () {
    for (final ok in ['/', '/saisie', '/saisie/nouvelle', '/saisie/abc', '/pieces', '/factures', '/factures/42']) {
      expect(ClientRules.allows(ok), isTrue, reason: ok);
    }
    for (final no in ['/consultation', '/cloture', '/referentiels', '/utilisateurs', '/cabinet', '/dossiers', '/lettrage', '/import', '/saisieX', '/facturesX']) {
      expect(ClientRules.allows(no), isFalse, reason: no);
    }
  });

  test('un compte est « client » seulement si tous ses rôles le sont', () {
    expect(PermissionSet(byEntity: const {}, cabinetWide: const {}, roles: [_role('client_gerant', client: true)]).isClient, isTrue);
    expect(PermissionSet(byEntity: const {}, cabinetWide: const {}, roles: [_role('client_gerant', client: true), _role('partner')]).isClient, isFalse);
    expect(PermissionSet.empty.isClient, isFalse);
    expect(PermissionSet(byEntity: const {}, cabinetWide: const {}, roles: [_role('client_saisie', client: true)]).isTechAdminOnly, isFalse);
  });

  test('la création est masquée seulement pour un client dont l\'accès n\'est pas actif', () {
    final client = PermissionSet(byEntity: const {}, cabinetWide: const {}, roles: [_role('client_gerant', client: true)]);
    final staff = PermissionSet(byEntity: const {}, cabinetWide: const {}, roles: [_role('partner')]);
    const suspended = EntitySummary(id: 'e1', name: 'A', clientAccess: 'suspended');
    const active = EntitySummary(id: 'e1', name: 'A', clientAccess: 'active');
    expect(suspended.isClientSuspended(client), isTrue);
    expect(active.isClientSuspended(client), isFalse);
    expect(suspended.isClientSuspended(staff), isFalse);
  });

  Future<_Repo> pump(WidgetTester tester, Widget home, {Set<String> perms = const {}, Set<String> cabinet = const {}, List<EntitySummary> entities = const [], String status = 'disabled'}) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        clientAccessRepositoryProvider.overrideWithValue(repo),
        onlinePolicyProvider.overrideWithValue(const OnlinePolicy(AlwaysOnline())),
        permissionsProvider.overrideWith((ref) async => PermissionSet(byEntity: {'e1': perms}, cabinetWide: cabinet, roles: [_role('client_gerant', client: true)])),
        entityDashboardProvider.overrideWith((ref) async => entities),
        invoicesProvider('e1').overrideWith((ref) async => []),
        clientAccessProvider('e1').overrideWith((ref) async => status),
        clientMembersProvider('e1').overrideWith((ref) async => [const Assignment(id: 'a1', userId: 'u2', userName: 'Koffi Client', roleId: 'r', roleName: 'Client — saisie', roleCode: 'client_saisie', entityId: 'e1')]),
      ],
      child: MaterialApp(theme: buildAkontaTheme(), home: Scaffold(body: home)),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('accueil client : dossier fermé → message clair, aucun chiffre', (tester) async {
    await pump(tester, const ClientHomeScreen());
    expect(find.textContaining('Votre cabinet doit activer votre accès'), findsOneWidget);
  });

  testWidgets('accueil client suspendu : bannière lecture seule et brouillards à corriger signalés', (tester) async {
    await pump(tester, const ClientHomeScreen(), entities: const [EntitySummary(id: 'e1', name: 'Boutique Awa', draftCount: 3, toCorrectCount: 2, clientAccess: 'suspended')]);
    expect(find.text('Boutique Awa'), findsOneWidget);
    expect(find.textContaining('accès est suspendu'), findsOneWidget);
    expect(find.textContaining('2 brouillards renvoyés'), findsOneWidget);
    expect(find.text('Écritures non revues'), findsNothing);
  });

  testWidgets('onglet Clients : l\'associé ouvre l\'accès après confirmation', (tester) async {
    final repo = await pump(tester, const ClientAccessTab(entityId: 'e1'), cabinet: const {'client_access.manage', 'assignments.manage'}, perms: const {'client_access.manage'});
    expect(find.byKey(const Key('client-access-status')), findsOneWidget);
    expect(find.text('Fermé'), findsOneWidget);
    expect(find.byKey(const Key('client-access-suspend')), findsNothing);
    expect(find.text('Koffi Client'), findsOneWidget);
    await tester.tap(find.byKey(const Key('client-access-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(repo.changes, ['e1:active']);
  });

  testWidgets('onglet Clients : accès ouvert → suspendre et fermer proposés', (tester) async {
    await pump(tester, const ClientAccessTab(entityId: 'e1'), cabinet: const {'client_access.manage'}, status: 'active');
    expect(find.byKey(const Key('client-access-suspend')), findsOneWidget);
    expect(find.byKey(const Key('client-access-close')), findsOneWidget);
    expect(find.byKey(const Key('client-access-open')), findsNothing);
  });

  testWidgets('onglet Clients : sans le droit, aucun bouton de changement', (tester) async {
    await pump(tester, const ClientAccessTab(entityId: 'e1'), status: 'active');
    expect(find.byKey(const Key('client-access-suspend')), findsNothing);
    expect(find.byKey(const Key('invite-client')), findsNothing);
    expect(find.textContaining('Seul un associé'), findsOneWidget);
  });

  testWidgets('renvoi d\'un brouillard : le motif est obligatoire, puis transmis', (tester) async {
    final repo = await pump(
      tester,
      Consumer(builder: (context, ref, _) => AkButton.primary('Ouvrir', onPressed: () => showReturnDraftDialog(context, ref, 'x1'))),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('return-submit')));
    await tester.pumpAndSettle();
    expect(repo.returned, isEmpty);
    expect(find.text('Le motif est obligatoire.'), findsOneWidget);

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('return-comment')), '  Pièce illisible  ');
    await tester.tap(find.byKey(const Key('return-submit')));
    await tester.pumpAndSettle();
    expect(repo.returned, ['x1:Pièce illisible']);
  });

  testWidgets('zone de retour : le client lit le motif, le comptable voit le bouton sur un brouillard', (tester) async {
    await pump(tester, DraftReturnArea(entry: _entry(returned: 'Joindre la facture'), canReturn: false, onReturn: () {}));
    expect(find.text('À corriger : Joindre la facture'), findsOneWidget);
    expect(find.byKey(const Key('return-draft')), findsNothing);

    await pump(tester, DraftReturnArea(entry: _entry(), canReturn: true, onReturn: () {}));
    expect(find.byKey(const Key('return-draft')), findsOneWidget);

    await pump(tester, DraftReturnArea(entry: _entry(status: 'validated'), canReturn: true, onReturn: () {}));
    expect(find.byKey(const Key('return-draft')), findsNothing);
  });
}
