import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/connectivity/connectivity.dart';
import 'package:akonta/src/application/providers/references_providers.dart';
import 'package:akonta/src/application/providers/services.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/application/rules/account_selection.dart';
import 'package:akonta/src/application/services/references_service.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/reference_models.dart';
import 'package:akonta/src/domain/repositories/references_repository.dart';
import 'package:akonta/src/presentation/entries/entry_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Faux dépôt : enregistre les tiers et comptes créés.
class _FakeReferences implements ReferencesRepository {
  final saved = <String>[];

  @override
  Future<ThirdParty> saveThirdParty(String cabinetId, String entityId,
      {String? id, required String code, required String name, required String type, String? taxId, String? address, String? phone, String? email, required List<String> collectiveAccountIds}) async {
    saved.add('$code|$name|$type|${collectiveAccountIds.join(',')}');
    return ThirdParty(id: 't-$code', code: code, name: name, type: type, taxId: taxId, isActive: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedEntity extends CurrentEntityNotifier {
  @override
  EntitySummary? build() => const EntitySummary(id: 'e1', name: 'SARL Démo', fiscalYearLabel: '2026');
}

const _customers = Account(id: 'a411', code: '4111000', label: 'Clients', classNo: 4, normalSide: 'debit', isCollective: true, isLetterable: true, allowPosting: true, isActive: true);
const _suppliers = Account(id: 'a401', code: '4011000', label: 'Fournisseurs', classNo: 4, normalSide: 'credit', isCollective: true, isLetterable: true, allowPosting: true, isActive: true);
const _existing = ThirdParty(id: 't1', code: 'CHU', name: 'CHU Cotonou', type: 'customer', isActive: true);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('règles', () {
    test('le code proposé est valide, sans accents, et unique', () {
      expect(suggestThirdPartyCode('Maître ASSANI', const []), 'MAITRE');
      expect(suggestThirdPartyCode('Ça', const []), 'CA');
      expect(suggestThirdPartyCode('chu', const ['CHU']), 'CHU2');
      expect(suggestThirdPartyCode('chu', const ['CHU', 'CHU2']), 'CHU3');
      expect(suggestThirdPartyCode('!', const []), 'TIERS');
      for (final n in ['Société Générale du Bénin', 'A', '12 rue', 'Établissements Dossou et Fils']) {
        expect(validateThirdPartyCode(suggestThirdPartyCode(n, const ['TIERS'])), isNull, reason: n);
      }
    });

    test('le collectif proposé suit le type du tiers', () {
      const all = [_customers, _suppliers];
      expect(AccountSelection.defaultCollective(all, 'customer')?.code, '4111000');
      expect(AccountSelection.defaultCollective(all, 'supplier')?.code, '4011000');
      expect(AccountSelection.defaultCollective(all, 'other')?.code, '4111000');
      expect(AccountSelection.defaultCollective(const [], 'customer'), isNull);
    });
  });

  group('champ tiers', () {
    Future<List<String>> pumpField(WidgetTester tester, {Future<ThirdParty?> Function(String)? onCreate, List<ThirdParty>? picked}) async {
      final log = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAkontaTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 320,
                child: AkThirdPartyField(
                  thirdParties: const [_existing],
                  onCreate: onCreate == null
                      ? null
                      : (q) {
                          log.add('create:$q');
                          return onCreate(q);
                        },
                  onSelected: (t) => log.add('select:${t.code}'),
                ),
              ),
            ),
          ),
        ),
      );
      return log;
    }

    testWidgets('un nom inconnu propose « Créer ce tiers », le tiers créé est retenu', (tester) async {
      final log = await pumpField(tester, onCreate: (q) async => const ThirdParty(id: 'n', code: 'NOUVEAU', name: 'Nouveau client', type: 'customer', isActive: true));
      await tester.enterText(find.byType(EditableText), 'Nouveau client');
      await tester.pumpAndSettle();
      expect(find.text('Créer ce tiers « Nouveau client »'), findsOneWidget);
      await tester.tap(find.text('Créer ce tiers « Nouveau client »'));
      await tester.pumpAndSettle();
      expect(log, ['create:Nouveau client', 'select:NOUVEAU']);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'NOUVEAU');
    });

    testWidgets('au clavier : Entrée sur la ligne de création lance la création', (tester) async {
      final log = await pumpField(tester, onCreate: (q) async => null);
      await tester.tap(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'Zorro');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(log, ['create:Zorro']);
    });

    testWidgets('un tiers existant ne propose pas la création, et sans droit la ligne est absente', (tester) async {
      await pumpField(tester, onCreate: (q) async => null);
      await tester.enterText(find.byType(EditableText), 'chu');
      await tester.pumpAndSettle();
      expect(find.textContaining('Créer ce tiers'), findsNothing);
      expect(find.text('CHU · CHU Cotonou'), findsOneWidget);
    });

    testWidgets('sans droit de créer, aucune ligne de création', (tester) async {
      await pumpField(tester);
      await tester.enterText(find.byType(EditableText), 'Inconnu');
      await tester.pumpAndSettle();
      expect(find.textContaining('Créer ce tiers'), findsNothing);
    });
  });

  testWidgets('champ compte : un numéro absent du plan propose « Créer le compte »', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAkontaTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: AkAccountField(
              accounts: const [_customers],
              onSelected: (a) => log.add('select:${a.code}'),
              onCreate: (q) async {
                log.add('create:$q');
                return const Account(id: 'x', code: '6099000', label: 'Divers', classNo: 6, normalSide: 'debit', isCollective: false, isLetterable: false, allowPosting: true, isActive: true);
              },
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), '6099');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer le compte « 6099 »'));
    await tester.pumpAndSettle();
    expect(log, ['create:6099', 'select:6099000']);
  });

  group('éditeur d\'écriture', () {
    final repo = _FakeReferences();
    Widget app() => ProviderScope(
      overrides: [
        currentEntityProvider.overrideWith(_FixedEntity.new),
        accountsProvider.overrideWith((ref, id) async => const [_customers, _suppliers]),
        thirdPartiesProvider.overrideWith((ref, id) async => const [_existing]),
        journalsProvider.overrideWith((ref, id) async => const [Journal(id: 'j1', code: 'OD', label: 'Opérations diverses', type: 'misc', isActive: true)]),
        currentCabinetProvider.overrideWith((ref) async => const Cabinet(id: 'c1', name: 'ABC', defaultAccountLength: 7, inactivityMinutes: 30)),
        permissionsProvider.overrideWith(
          (ref) async => const PermissionSet(
            byEntity: {
              'e1': {'entries.draft', 'references.manage'},
            },
            cabinetWide: {},
            roles: [],
          ),
        ),
        referencesServiceProvider.overrideWithValue(ReferencesService(repo, const OnlinePolicy(AlwaysOnline()))),
      ],
      child: MaterialApp(theme: buildAkontaTheme(), home: const Scaffold(body: EntryEditorScreen())),
    );

    testWidgets('créer un tiers depuis la ligne : le panneau s\'ouvre, le tiers revient sur la même ligne, la saisie est intacte', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // Une saisie déjà faite doit survivre à la création : libellé de la ligne 1 et montant.
      await tester.enterText(find.byType(AkAmountField).at(0), '100000');
      final accountField = find.byKey(const Key('line-account-0'));
      await tester.enterText(find.descendant(of: accountField, matching: find.byType(EditableText)), '4111000');
      await tester.pumpAndSettle();

      final thirdFields = find.byType(AkThirdPartyField);
      expect(thirdFields, findsWidgets);
      await tester.enterText(find.descendant(of: thirdFields.first, matching: find.byType(EditableText)), 'Boulangerie Dossou');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer ce tiers « Boulangerie Dossou »'));
      await tester.pumpAndSettle();

      expect(find.text('Créer ce tiers'), findsOneWidget); // titre du panneau
      expect(tester.widget<EditableText>(find.descendant(of: find.byKey(const Key('quick-tp-name')), matching: find.byType(EditableText))).controller.text, 'Boulangerie Dossou');
      // Double clic sur « Créer le tiers » : un seul enregistrement.
      final submit = find.byKey(const Key('quick-tp-submit'));
      await tester.tap(submit);
      await tester.tap(submit, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repo.saved, ['BOULAN|Boulangerie Dossou|customer|a411']);
      expect(find.text('Créer ce tiers'), findsNothing);
      final field = tester.widget<EditableText>(find.descendant(of: thirdFields.first, matching: find.byType(EditableText)));
      expect(field.controller.text, 'BOULAN');
      expect(tester.widget<EditableText>(find.descendant(of: accountField, matching: find.byType(EditableText))).controller.text, contains('4111000'));
      final amount = tester.widget<EditableText>(find.descendant(of: find.byType(AkAmountField).at(0), matching: find.byType(EditableText)));
      expect(amount.controller.text.replaceAll(RegExp(r'\D'), ''), '100000');
    });
  });
}
