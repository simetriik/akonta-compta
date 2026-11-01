import 'package:akonta/design/design.dart';
import 'package:akonta/src/domain/entry_models.dart';
import 'package:akonta/src/domain/suggestion_models.dart';
import 'package:akonta/src/presentation/entries/entry_suggestions_panel.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/domain/repositories/suggestions_repository.dart';

class _FakeRepo implements SuggestionsRepository {
  _FakeRepo({this.fail = false});

  final bool fail;
  final calls = <String>[];

  @override
  Future<List<EntrySuggestion>> entries(String entityId, String label, {int limit = 3}) async {
    calls.add('entries:$label');
    if (fail) throw Exception('réseau');
    return [
      EntrySuggestion(
        entryId: 'e1',
        entryDate: DateTime(2026, 2, 28),
        journalCode: 'AC',
        label: 'Loyer février 2026',
        similarity: 1,
        lines: const [
          SuggestedLine(accountId: 'a1', accountCode: '6222000', accountLabel: 'Locations de bâtiments', side: 'debit'),
          SuggestedLine(accountId: 'a2', accountCode: '4011000', accountLabel: 'Fournisseurs', thirdPartyId: 't1', thirdPartyCode: 'SOB', side: 'credit'),
        ],
      ),
    ];
  }

  @override
  Future<List<TemplateSuggestion>> templates(String entityId, String label, {int limit = 2}) async => const [TemplateSuggestion(templateId: 'm1', code: 'LOYER', label: 'Loyer sans TVA')];

  @override
  Future<List<AccountSuggestion>> accounts(String entityId, String label, {String? thirdPartyId, int limit = 3}) async =>
      const [AccountSuggestion(accountId: 'a1', accountCode: '6222000', accountLabel: 'Locations de bâtiments', source: 'label', uses: 2)];

  @override
  Future<List<DuplicateEntry>> duplicates(String entityId, {required String reference, required int amount, String? thirdPartyId, String? excludeEntryId}) async {
    calls.add('duplicates:$reference:$amount');
    return [DuplicateEntry(entryId: 'd1', number: 3, journalCode: 'AC', entryDate: DateTime(2026, 3, 5), status: 'validated', label: 'Fournitures')];
  }
}

void main() {
  final label = TextEditingController();
  final reference = TextEditingController();
  late EntryDraft draft;

  setUpAll(() => initializeDateFormatting('fr_FR'));
  setUp(() {
    label.clear();
    reference.clear();
    draft = EntryDraft();
  });

  Future<_FakeRepo> pumpPanel(WidgetTester tester, {bool enabled = true, bool fail = false, ValueChanged<EntrySuggestion>? onEntry, ValueChanged<AccountSuggestion>? onAccount}) async {
    final repo = _FakeRepo(fail: fail);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [suggestionsRepositoryProvider.overrideWithValue(repo), currentUserIdProvider.overrideWithValue('test-user')],
        child: MaterialApp(
          theme: buildAkontaTheme(),
          home: Scaffold(
            body: EntrySuggestionsPanel(
              entityId: 'ent',
              labelController: label,
              referenceController: reference,
              currentDraft: () => draft,
              enabled: enabled,
              debounce: const Duration(milliseconds: 10),
              onUseEntry: onEntry ?? (_) {},
              onUseTemplate: (_) {},
              onUseAccount: onAccount ?? (_) {},
            ),
          ),
        ),
      ),
    );
    return repo;
  }

  testWidgets('un libellé de 3 caractères ou plus affiche écritures, modèles et comptes proches', (tester) async {
    await pumpPanel(tester);
    label.text = 'loyer';
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('Loyer février 2026 · 28/02/2026'), findsOneWidget);
    expect(find.text('LOYER — Loyer sans TVA'), findsOneWidget);
    expect(find.text('6222000 Locations de bâtiments · 2 fois'), findsOneWidget);
  });

  testWidgets('moins de 3 caractères : aucune requête, rien d\'affiché', (tester) async {
    final repo = await pumpPanel(tester);
    label.text = 'lo';
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(repo.calls, isEmpty);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('toucher une écriture proche la transmet à l\'éditeur, sans rien appliquer seul', (tester) async {
    EntrySuggestion? used;
    await pumpPanel(tester, onEntry: (e) => used = e);
    label.text = 'loyer';
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(used, isNull);
    await tester.tap(find.byKey(const Key('suggest-entry-e1')));
    expect(used?.entryId, 'e1');
    expect(used?.lines.last.thirdPartyCode, 'SOB');
  });

  testWidgets('référence et montant saisis : alerte de doublon', (tester) async {
    draft.lines.first.debit = 50000;
    final repo = await pumpPanel(tester);
    reference.text = 'F-2026-001';
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.byKey(const Key('duplicate-warning')), findsOneWidget);
    expect(find.textContaining('AC-3 du 05/03/2026'), findsOneWidget);
    expect(repo.calls, contains('duplicates:F-2026-001:50000'));
  });

  testWidgets('panneau désactivé (écriture validée) : rien n\'est demandé', (tester) async {
    final repo = await pumpPanel(tester, enabled: false);
    label.text = 'loyer';
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.calls, isEmpty);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('échec du serveur : message discret, la saisie reste possible', (tester) async {
    await pumpPanel(tester, fail: true);
    label.text = 'loyer';
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.byKey(const Key('suggestions-failed')), findsOneWidget);
  });
}
