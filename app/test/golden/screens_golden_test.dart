import 'package:akonta/design/design.dart';
import 'package:akonta/src/domain/suggestion_models.dart';
import 'package:akonta/src/domain/entity_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/reference_models.dart';
import 'package:akonta/src/presentation/auth/login_screen.dart';
import 'package:akonta/src/presentation/closing/closing_screen.dart';
import 'package:akonta/src/presentation/consultation/consultation_screen.dart';
import 'package:akonta/src/presentation/dashboard/dashboard_screen.dart';
import 'package:akonta/src/presentation/entries/entry_editor_screen.dart';
import 'package:akonta/src/presentation/lettering/lettering_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'fake_repositories.dart';
import 'golden_harness.dart';
import 'package:akonta/src/application/providers/consultation_providers.dart';
import 'package:akonta/src/application/providers/entities_providers.dart';
import 'package:akonta/src/application/providers/references_providers.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/domain/consultation_models.dart';
import 'package:akonta/src/domain/repositories/suggestions_repository.dart';
import 'package:akonta/src/application/providers/session_providers.dart';

class _FixedEntity extends CurrentEntityNotifier {
  @override
  EntitySummary? build() => _entity;
}

const _entity = EntitySummary(id: 'e1', name: 'SARL Kpédékpo Distribution', fiscalYearId: 'fy1', fiscalYearLabel: '2026', fiscalYearStatus: 'open');

final _fiscalYears = [
  FiscalYear(id: 'fy1', entityId: 'e1', label: '2026', startDate: DateTime(2026), endDate: DateTime(2026, 12, 31), status: 'open'),
  FiscalYear(id: 'fy0', entityId: 'e1', label: '2025', startDate: DateTime(2025), endDate: DateTime(2025, 12, 31), status: 'closed'),
];

const _accounts = [
  Account(
    id: 'a1',
    code: '6221000',
    label: 'Locations de bâtiments',
    classNo: 6,
    normalSide: 'debit',
    isCollective: false,
    isLetterable: false,
    allowPosting: true,
    isActive: true,
  ),
  Account(
    id: 'a2',
    code: '5210000',
    label: 'Banques locales',
    classNo: 5,
    normalSide: 'debit',
    isCollective: false,
    isLetterable: false,
    allowPosting: true,
    isActive: true,
  ),
  Account(
    id: 'a3',
    code: '4110000',
    label: 'Clients',
    classNo: 4,
    normalSide: 'debit',
    isCollective: true,
    isLetterable: true,
    allowPosting: true,
    isActive: true,
  ),
];

const _thirdParties = [
  ThirdParty(id: 't1', code: 'CHU', name: 'Centre Hospitalier Universitaire', type: 'customer', isActive: true, collectiveCodes: ['4110000']),
  ThirdParty(id: 't2', code: 'SOBEBRA', name: 'SOBEBRA Bénin', type: 'customer', isActive: true, collectiveCodes: ['4110000']),
];

const _permissions = PermissionSet(
  byEntity: {
    'e1': {'entries.draft', 'entries.validate', 'lettering.manage', 'closing.override_alerts'},
  },
  cabinetWide: {},
  roles: [],
);

/// Aucune suggestion de saisie : les captures de référence ne dépendent pas de l'historique.
class _NoSuggestions implements SuggestionsRepository {
  @override
  Future<List<EntrySuggestion>> entries(String entityId, String label, {int limit = 3}) async => const [];

  @override
  Future<List<AccountSuggestion>> accounts(String entityId, String label, {String? thirdPartyId, int limit = 3}) async => const [];

  @override
  Future<List<TemplateSuggestion>> templates(String entityId, String label, {int limit = 2}) async => const [];

  @override
  Future<List<DuplicateEntry>> duplicates(String entityId, {required String reference, required int amount, String? thirdPartyId, String? excludeEntryId}) async => const [];
}

List<Override> _common() => [
  currentUserIdProvider.overrideWithValue('golden-user'), // les services sont liés à l'utilisateur connecté
  currentEntityProvider.overrideWith(_FixedEntity.new),
  suggestionsRepositoryProvider.overrideWithValue(_NoSuggestions()),
  fiscalYearsProvider.overrideWith((ref, id) async => _fiscalYears),
  accountsProvider.overrideWith((ref, id) async => _accounts),
  thirdPartiesProvider.overrideWith((ref, id) async => _thirdParties),
  permissionsProvider.overrideWith((ref) async => _permissions),
];

final _dashboard = [
  EntitySummary(
    id: 'e1',
    name: 'SARL Kpédékpo Distribution',
    fiscalYearLabel: '2026',
    fiscalYearStatus: 'open',
    managerNames: 'A. Hounkpatin',
    lastEntryDate: DateTime(2026, 10, 22),
    draftCount: 6,
    unreviewedCount: 14,
    toCorrectCount: 2,
    inboxCount: 5,
  ),
  EntitySummary(
    id: 'e2',
    name: 'Pharmacie du Port',
    fiscalYearLabel: '2026',
    fiscalYearStatus: 'open',
    managerNames: 'M. Adjovi',
    lastEntryDate: DateTime(2026, 10, 20),
    draftCount: 0,
    unreviewedCount: 8,
    toCorrectCount: 0,
    inboxCount: 1,
  ),
  EntitySummary(
    id: 'e3',
    name: 'Société Béninoise de Transit',
    fiscalYearLabel: '2026',
    fiscalYearStatus: 'closing',
    managerNames: 'C. Dossou',
    lastEntryDate: DateTime(2026, 9, 30),
    draftCount: 11,
    unreviewedCount: 0,
    toCorrectCount: 4,
    inboxCount: 0,
  ),
  EntitySummary(
    id: 'e4',
    name: 'Association Entraide Dantokpa',
    fiscalYearLabel: '2026',
    fiscalYearStatus: 'open',
    managerNames: 'A. Hounkpatin',
    lastEntryDate: DateTime(2026, 10, 25),
    draftCount: 1,
    unreviewedCount: 3,
    toCorrectCount: 0,
    inboxCount: 0,
  ),
];

LedgerLine _line(String code, String label, String journal, int number, String text, DateTime date, {int debit = 0, int credit = 0, required int balance}) =>
    LedgerLine(
      accountCode: code,
      accountLabel: label,
      entryId: 'en$number',
      entryDate: date,
      journalCode: journal,
      number: 1000000 + number,
      reference: 'PC-${200 + number}',
      label: text,
      debit: debit,
      credit: credit,
      runningBalance: balance,
    );

final _ledger = [
  _line('5210000', 'Banques locales', 'BQ', 1, 'Virement client CHU', DateTime(2026, 10, 3), debit: 1800000, balance: 1800000),
  _line('5210000', 'Banques locales', 'BQ', 2, 'Paiement loyer octobre', DateTime(2026, 10, 5), credit: 250000, balance: 1550000),
  _line('5210000', 'Banques locales', 'BQ', 3, 'Règlement fournisseur SOBEBRA', DateTime(2026, 10, 12), credit: 640000, balance: 910000),
  _line('6221000', 'Locations de bâtiments', 'OD', 4, 'Loyer octobre 2026', DateTime(2026, 10, 5), debit: 250000, balance: 250000),
  _line('6221000', 'Locations de bâtiments', 'OD', 5, 'Loyer novembre 2026 (avance)', DateTime(2026, 10, 28), debit: 250000, balance: 500000),
];

const _balance = [
  BalanceRow(
    accountCode: '1010000',
    accountLabel: 'Capital social',
    openingDebit: 0,
    openingCredit: 5000000,
    periodDebit: 0,
    periodCredit: 0,
    closingDebit: 0,
    closingCredit: 5000000,
  ),
  BalanceRow(
    accountCode: '4110000',
    accountLabel: 'Clients',
    openingDebit: 1200000,
    openingCredit: 0,
    periodDebit: 3600000,
    periodCredit: 2400000,
    closingDebit: 2400000,
    closingCredit: 0,
  ),
  BalanceRow(
    accountCode: '5210000',
    accountLabel: 'Banques locales',
    openingDebit: 3800000,
    openingCredit: 0,
    periodDebit: 2400000,
    periodCredit: 890000,
    closingDebit: 5310000,
    closingCredit: 0,
  ),
  BalanceRow(
    accountCode: '6221000',
    accountLabel: 'Locations de bâtiments',
    openingDebit: 0,
    openingCredit: 0,
    periodDebit: 500000,
    periodCredit: 0,
    closingDebit: 500000,
    closingCredit: 0,
  ),
  BalanceRow(
    accountCode: '7011000',
    accountLabel: 'Ventes de marchandises',
    openingDebit: 0,
    openingCredit: 0,
    periodDebit: 0,
    periodCredit: 3050000,
    closingDebit: 0,
    closingCredit: 3050000,
  ),
];

/// Saisit des dates fixes pour que les captures ne dépendent pas de la date du jour.
Future<void> _setPeriod(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), '01/01/2026');
  await tester.enterText(fields.at(1), '31/12/2026');
  await tester.tap(find.text('Actualiser'));
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setUpGolden);

  testWidgets('01 connexion', (tester) async {
    useSurface(tester, desktopSize);
    await pumpScreen(tester, goldenApp(home: const LoginScreen(), scaffold: false));
    await tester.enterText(find.byKey(const Key('login-email')), 'assistant@abc-expertise.bj');
    await tester.enterText(find.byKey(const Key('login-password')), 'Motdepasse-Robuste-2026');
    await tester.pumpAndSettle();
    await expectGolden(tester, '01-connexion');
  });

  testWidgets('02 tableau de bord', (tester) async {
    useSurface(tester, desktopSize);
    await pumpScreen(
      tester,
      goldenApp(
        home: const DashboardScreen(),
        overrides: [currentUserIdProvider.overrideWithValue(null), entityDashboardProvider.overrideWith((ref) async => _dashboard)],
      ),
    );
    await expectGolden(tester, '02-tableau-de-bord');
  });

  testWidgets('08 mobile : tableau de bord', (tester) async {
    useSurface(tester, mobileSize);
    await pumpScreen(
      tester,
      goldenApp(
        home: const DashboardScreen(),
        overrides: [currentUserIdProvider.overrideWithValue(null), entityDashboardProvider.overrideWith((ref) async => _dashboard)],
      ),
    );
    await expectGolden(tester, '08-mobile-tableau-de-bord');
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    await pumpScreen(
      tester,
      goldenApp(
        home: const EntryEditorScreen(),
        overrides: [
          ..._common(),
          journalsProvider.overrideWith((ref, id) async => const [Journal(id: 'j1', code: 'OD', label: 'Opérations diverses', type: 'misc', isActive: true)]),
        ],
      ),
    );
    await tester.tap(find.byKey(const Key('entry-journal')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Opérations diverses').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byKey(const Key('entry-date')), matching: find.byType(TextField)), '05/10/2026');
    await tester.enterText(find.descendant(of: find.byKey(const Key('entry-label')), matching: find.byType(TextField)), 'Loyer octobre 2026');
    for (final (i, code) in ['6221000', '5210000'].indexed) {
      await tester.enterText(find.descendant(of: find.byKey(Key('line-account-$i')), matching: find.byType(TextField)), code);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(code).last);
      await tester.pumpAndSettle();
    }
    final amounts = find.byType(AkAmountField);
    await tester.enterText(amounts.at(0), '250000');
    await tester.enterText(amounts.at(3), '250000');
    await tester.pumpAndSettle();
  }

  testWidgets('03 saisie', (tester) async {
    useSurface(tester, desktopSize);
    await pumpEditor(tester);
    await expectGolden(tester, '03-saisie');
  });

  testWidgets('08 mobile : saisie', (tester) async {
    useSurface(tester, mobileSize);
    await pumpEditor(tester);
    // La saisie fait défiler la page jusqu'au dernier champ : on revient en haut et à gauche pour la capture.
    for (final e in find.byType(Scrollable).evaluate()) {
      (tester.state<ScrollableState>(find.byWidget(e.widget))).position.jumpTo(0);
    }
    await tester.pumpAndSettle();
    await expectGolden(tester, '08-mobile-saisie');
  });

  Future<void> pumpConsultation(WidgetTester tester) async {
    await pumpScreen(
      tester,
      goldenApp(
        home: const ConsultationScreen(),
        overrides: [..._common(), generalLedgerProvider.overrideWith((ref, p) async => _ledger), trialBalanceProvider.overrideWith((ref, p) async => _balance)],
      ),
    );
    await _setPeriod(tester);
  }

  testWidgets('04 grand livre', (tester) async {
    useSurface(tester, desktopSize);
    await pumpConsultation(tester);
    await expectGolden(tester, '04-grand-livre');
  });

  testWidgets('05 balance', (tester) async {
    useSurface(tester, desktopSize);
    await pumpConsultation(tester);
    await tester.tap(find.text('Balance générale'));
    await tester.pumpAndSettle();
    await expectGolden(tester, '05-balance');
  });

  testWidgets('06 lettrage', (tester) async {
    useSurface(tester, desktopSize);
    await pumpScreen(
      tester,
      goldenApp(home: const LetteringScreen(), overrides: [..._common(), letteringRepositoryProvider.overrideWithValue(FakeLetteringRepository())]),
    );
    await tester.tap(find.byKey(const Key('lettering-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('4110000 Clients').last);
    await tester.pumpAndSettle();
    // Sélection d'une facture et de son règlement
    await tester.tap(find.text('Facture F-2026-041 CHU'));
    await tester.tap(find.text('Règlement virement CHU'));
    await tester.pumpAndSettle();
    await expectGolden(tester, '06-lettrage');
  });

  testWidgets('07 clôture', (tester) async {
    useSurface(tester, desktopSize);
    await pumpScreen(
      tester,
      goldenApp(home: const ClosingScreen(), overrides: [..._common(), closingRepositoryProvider.overrideWithValue(FakeClosingRepository())]),
    );
    await expectGolden(tester, '07-cloture');
  });
}
