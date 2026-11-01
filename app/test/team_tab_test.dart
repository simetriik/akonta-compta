import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/providers/admin_providers.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/domain/admin_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/presentation/entities/team_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _team = [
  Assignment(id: 'a1', userId: 'u1', userName: 'Kofi Chef', roleId: 'm', roleName: 'Chef de mission', roleCode: 'manager', entityId: 'e1'),
  Assignment(id: 'a2', userId: 'u2', userName: 'Awa Assistante', roleId: 'a', roleName: 'Assistant', roleCode: 'assistant', entityId: 'e1'),
];

Future<void> _pump(WidgetTester tester, PermissionSet perms, {List<Assignment> team = _team}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        permissionsProvider.overrideWith((ref) async => perms),
        teamProvider('e1').overrideWith((ref) async => team),
        rolesProvider.overrideWith((ref) async => <RoleDef>[]),
        teamCandidatesProvider((entityId: 'e1', role: null)).overrideWith((ref) async => <TeamCandidate>[]),
      ],
      child: MaterialApp(theme: buildAkontaTheme(), home: const Scaffold(body: TeamTab(entityId: 'e1'))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('l\'associé voit l\'équipe, peut affecter, remplacer le chef de mission et retirer', (tester) async {
    await _pump(tester, const PermissionSet(byEntity: {}, cabinetWide: {'assignments.manage', 'team.assign'}, roles: []));
    expect(find.text('Kofi Chef'), findsOneWidget);
    expect(find.text('Awa Assistante'), findsOneWidget);
    expect(find.byKey(const Key('team-add')), findsOneWidget);
    expect(find.byKey(const Key('team-replace-manager')), findsOneWidget);
    expect(find.byKey(const Key('team-remove-a2')), findsOneWidget);
  });

  testWidgets('le chef de mission affecte et retire assistants et stagiaires, sans remplacer le chef de mission', (tester) async {
    await _pump(tester, const PermissionSet(byEntity: {'e1': {'team.assign'}}, cabinetWide: {}, roles: []));
    expect(find.byKey(const Key('team-add')), findsOneWidget);
    expect(find.byKey(const Key('team-remove-a2')), findsOneWidget);
    expect(find.byKey(const Key('team-replace-manager')), findsNothing);
    expect(find.byKey(const Key('team-remove-a1')), findsNothing);
  });

  testWidgets('un assistant consulte l\'équipe sans pouvoir la modifier', (tester) async {
    await _pump(tester, const PermissionSet(byEntity: {'e1': {'entries.draft'}}, cabinetWide: {}, roles: []));
    expect(find.text('Kofi Chef'), findsOneWidget);
    expect(find.byKey(const Key('team-add')), findsNothing);
    expect(find.byKey(const Key('team-remove-a2')), findsNothing);
  });

  testWidgets('un dossier sans chef de mission le signale', (tester) async {
    await _pump(tester, const PermissionSet(byEntity: {}, cabinetWide: {'assignments.manage'}, roles: []), team: [_team[1]]);
    expect(find.text('Ce dossier n\'a pas de chef de mission.'), findsOneWidget);
  });

  testWidgets('une équipe vide propose d\'affecter', (tester) async {
    await _pump(tester, const PermissionSet(byEntity: {}, cabinetWide: {'assignments.manage'}, roles: []), team: const []);
    expect(find.text('Personne n\'est encore affecté à ce dossier.'), findsOneWidget);
    expect(find.text('Affecter un collaborateur'), findsOneWidget);
  });
}
