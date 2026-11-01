import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/providers/admin_providers.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/domain/admin_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/presentation/admin/cabinet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  const roles = [
    RoleDef(id: 'partner', code: 'partner', name: 'Associé', isSystem: true, permissions: {'closing.final', 'users.manage'}),
    RoleDef(id: 'manager', code: 'manager', name: 'Chef de mission', isSystem: true, permissions: {'closing.final'}),
    RoleDef(id: 'assistant', code: 'assistant', name: 'Assistant', isSystem: true, permissions: {}),
    RoleDef(id: 'trainee', code: 'trainee', name: 'Stagiaire', isSystem: true, permissions: {}),
  ];
  const permissions = [
    PermissionDef(code: 'closing.final', label: 'Arrêté définitif', category: 'cloture'),
    PermissionDef(code: 'users.manage', label: 'Gérer utilisateurs et sécurité', category: 'securite'),
    PermissionDef(code: 'assignments.manage', label: 'Affecter les dossiers', category: 'cabinet'),
  ];

  testWidgets('la fenêtre d\'affectation ne propose que chef de mission, assistant et stagiaire', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rolesProvider.overrideWith((ref) async => roles),
          profilesProvider.overrideWith((ref) async => <Profile>[]),
          adminEntitiesProvider.overrideWith((ref) async => <({String id, String name})>[]),
          currentCabinetProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: buildAkontaTheme(), home: const Scaffold(body: AssignmentDialog())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AkDropdown<String>).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Chef de mission'), findsWidgets);
    expect(find.text('Assistant'), findsWidgets);
    expect(find.text('Stagiaire'), findsWidgets);
    expect(find.text('Associé'), findsNothing);
  });

  testWidgets('la matrice des droits fige le rôle associé et masque les droits d\'administration', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rolesProvider.overrideWith((ref) async => roles),
          permissionDefsProvider.overrideWith((ref) async => permissions),
        ],
        child: MaterialApp(theme: buildAkontaTheme(), home: const Scaffold(body: RolesTab())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Arrêté définitif'), findsOneWidget);
    expect(find.text('Gérer utilisateurs et sécurité'), findsNothing);
    expect(find.text('Affecter les dossiers'), findsNothing);
    final boxes = tester.widgetList<AkCheckbox>(find.byType(AkCheckbox)).toList();
    // 4 colonnes de rôles, une ligne : la première (associé) est figée, les trois autres modifiables.
    expect(boxes.length, 4);
    expect(boxes.first.onChanged, isNull);
    expect(boxes.skip(1).every((b) => b.onChanged != null), isTrue);
  });
}
