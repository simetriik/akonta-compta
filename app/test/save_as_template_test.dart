import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/connectivity/connectivity.dart';
import 'package:akonta/src/application/providers/references_providers.dart';
import 'package:akonta/src/application/providers/services.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/application/services/references_service.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/reference_models.dart';
import 'package:akonta/src/domain/repositories/references_repository.dart';
import 'package:akonta/src/presentation/entries/entry_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FakeReferences implements ReferencesRepository {
  final saved = <({String? entityId, String code, String label, List<TemplateLine> lines})>[];

  @override
  Future<void> saveTemplate(String cabinetId, String? entityId, {required String code, required String label, String? journalType, String? description, required List<TemplateLine> lines}) async {
    saved.add((entityId: entityId, code: code, label: label, lines: lines));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedEntity extends CurrentEntityNotifier {
  @override
  EntitySummary? build() => const EntitySummary(id: 'e1', name: 'SARL Démo', fiscalYearLabel: '2026');
}

const _clients = Account(id: 'a411', code: '4111000', label: 'Clients', classNo: 4, normalSide: 'debit', isCollective: true, isLetterable: true, allowPosting: true, isActive: true);
const _ventes = Account(id: 'a701', code: '7011000', label: 'Ventes', classNo: 7, normalSide: 'credit', isCollective: false, isLetterable: false, allowPosting: true, isActive: true);
const _chu = ThirdParty(id: 't1', code: 'CHU', name: 'CHU Cotonou', type: 'customer', isActive: true);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Widget app(_FakeReferences repo, Set<String> entityPerms, {Set<String> cabinetPerms = const {}}) => ProviderScope(
    overrides: [
      currentEntityProvider.overrideWith(_FixedEntity.new),
      accountsProvider.overrideWith((ref, id) async => const [_clients, _ventes]),
      thirdPartiesProvider.overrideWith((ref, id) async => const [_chu]),
      templatesProvider.overrideWith((ref, id) async => const <EntryTemplate>[]),
      journalsProvider.overrideWith((ref, id) async => const [Journal(id: 'j1', code: 'VT', label: 'Ventes', type: 'sales', isActive: true)]),
      currentCabinetProvider.overrideWith((ref) async => const Cabinet(id: 'c1', name: 'ABC', defaultAccountLength: 7, inactivityMinutes: 30)),
      permissionsProvider.overrideWith((ref) async => PermissionSet(byEntity: {'e1': entityPerms}, cabinetWide: cabinetPerms, roles: const [])),
      referencesServiceProvider.overrideWithValue(ReferencesService(repo, const OnlinePolicy(AlwaysOnline()))),
    ],
    child: MaterialApp(theme: buildAkontaTheme(), home: const Scaffold(body: EntryEditorScreen())),
  );

  Future<void> fillEntry(WidgetTester tester) async {
    Future<void> account(int line, String code) async =>
        tester.enterText(find.descendant(of: find.byKey(Key('line-account-$line')), matching: find.byType(EditableText)), code);
    await account(0, '4111000');
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AkThirdPartyField).first, matching: find.byType(EditableText)), 'CHU');
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHU · CHU Cotonou').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(AkAmountField).at(0), '1180');
    await account(1, '7011000');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(AkAmountField).at(3), '1180');
    await tester.pumpAndSettle();
  }

  testWidgets('un assistant enregistre l\'écriture comme modèle de son dossier : comptes génériques, tiers à choisir, sans montants', (tester) async {
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeReferences();
    await tester.pumpWidget(app(repo, {'entries.draft', 'templates.manage_entity'}));
    await tester.pumpAndSettle();
    await fillEntry(tester);

    await tester.tap(find.byKey(const Key('save-as-template')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byKey(const Key('template-name')), matching: find.byType(EditableText)), 'Vente CHU');
    await tester.tap(find.byKey(const Key('template-save')));
    await tester.pumpAndSettle();

    expect(repo.saved, hasLength(1));
    final t = repo.saved.single;
    expect(t.entityId, 'e1', reason: 'sans droit commun, le modèle est celui du dossier');
    expect(t.code, 'VENTE_CHU');
    expect(t.lines.map((l) => l.accountCode), ['4111', '7011']);
    expect(t.lines.map((l) => l.usesThirdParty), [true, false]);
    expect(t.lines.map((l) => l.side), ['debit', 'credit']);
  });

  testWidgets('un chef de mission choisit entre « ce dossier » et « tous les dossiers »', (tester) async {
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeReferences();
    await tester.pumpWidget(app(repo, {'entries.draft', 'templates.manage_entity', 'templates.manage_common'}));
    await tester.pumpAndSettle();
    await fillEntry(tester);
    await tester.tap(find.byKey(const Key('save-as-template')));
    await tester.pumpAndSettle();
    expect(find.text('Disponible pour'), findsOneWidget);
  });

  testWidgets('sans aucun droit sur les modèles, l\'enregistrement est refusé avec un message', (tester) async {
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeReferences();
    await tester.pumpWidget(app(repo, {'entries.draft'}));
    await tester.pumpAndSettle();
    await fillEntry(tester);
    await tester.tap(find.byKey(const Key('save-as-template')));
    await tester.pumpAndSettle();
    expect(find.textContaining('pas le droit de créer un modèle'), findsOneWidget);
    expect(repo.saved, isEmpty);
  });
}
