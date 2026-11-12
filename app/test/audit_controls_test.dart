import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/providers/consultation_providers.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/domain/consultation_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/presentation/consultation/audit_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';


void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('textes des contrôles', () {
    test('solde anormal : le sens et le montant sont dits en français', () {
      const credit = AccountingControl(controlCode: 'abnormal_balance', severity: 'warning', accountCode: '4111000', accountLabel: 'Clients', amount: 500, detail: 'credit');
      const debit = AccountingControl(controlCode: 'abnormal_balance', severity: 'warning', accountCode: '4011000', accountLabel: 'Fournisseurs', amount: 1200000, detail: 'debit');
      expect(credit.text, contains('4111000'));
      expect(credit.text, contains('créditeur'));
      expect(debit.text, contains('débiteur'));
      expect(debit.text, contains('1 200 000'));
    });

    test('écriture hors période : la raison est dite', () {
      AccountingControl c(String why) => AccountingControl(controlCode: 'entry_outside_period', severity: 'warning', entryId: 'x', entryDate: DateTime(2027, 5, 2), detail: why);
      expect(c('period').text, contains('hors de sa période'));
      expect(c('fiscal_year').text, contains('hors de son exercice'));
      expect(c('future').text, contains('postérieure'));
    });
  });

  test('événements de la piste d\'audit : libellés lisibles', () {
    AuditTrailEvent e(String kind) => AuditTrailEvent(auditId: 1, occurredAt: DateTime(2026, 3, 10, 14, 5), actorLabel: 'Awa', event: kind, entryNumber: 7, journalCode: 'VT', label: 'Facture 1');
    expect(e('created').eventLabel, 'Saisie');
    expect(e('modified').eventLabel, 'Modification');
    expect(e('validated').eventLabel, 'Validation');
    expect(e('deleted').eventLabel, 'Suppression du brouillard');
  });

  group('onglets', () {
    Widget app(Widget child, {Set<String> perms = const {'audit.read'}}) => ProviderScope(
      overrides: [
        permissionsProvider.overrideWith((ref) async => PermissionSet(byEntity: {'e1': perms}, cabinetWide: const {}, roles: const [])),
        accountingControlsProvider.overrideWith(
          (ref, p) async => const [AccountingControl(controlCode: 'abnormal_balance', severity: 'warning', accountCode: '4111000', accountLabel: 'Clients', amount: 500, detail: 'credit')],
        ),
        entryAuditTrailProvider.overrideWith(
          (ref, p) async => [AuditTrailEvent(auditId: 2, occurredAt: DateTime(2026, 3, 10, 14, 5), actorLabel: 'Awa Assistante', event: 'validated', entryNumber: 12, journalCode: 'VT', label: 'Facture 1')],
        ),
      ],
      child: MaterialApp(
        theme: buildAkontaTheme(),
        home: Scaffold(body: SizedBox(height: 600, child: child)),
      ),
    );
    final params = ConsultationParams(entityId: 'e1', from: DateTime(2026), to: DateTime(2026, 12, 31), fiscalYearId: 'fy1');

    testWidgets('contrôles : la liste des anomalies s\'affiche', (tester) async {
      await tester.pumpWidget(app(ControlsTab(params: params)));
      await tester.pumpAndSettle();
      expect(find.textContaining('4111000'), findsOneWidget);
      expect(find.textContaining('créditeur'), findsOneWidget);
    });

    testWidgets('contrôles : aucune anomalie = message rassurant', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [accountingControlsProvider.overrideWith((ref, p) async => const <AccountingControl>[])],
          child: MaterialApp(theme: buildAkontaTheme(), home: Scaffold(body: ControlsTab(params: params))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Aucune anomalie'), findsOneWidget);
    });

    testWidgets('piste d\'audit : qui, quoi, quand', (tester) async {
      await tester.pumpWidget(app(AuditTrailTab(params: params)));
      await tester.pumpAndSettle();
      expect(find.text('Awa Assistante'), findsOneWidget);
      expect(find.text('Validation'), findsOneWidget);
      expect(find.textContaining('Facture 1'), findsOneWidget);
    });

    testWidgets('piste d\'audit : sans le droit, un message explique pourquoi', (tester) async {
      await tester.pumpWidget(app(AuditTrailTab(params: params), perms: const {'ledger.read'}));
      await tester.pumpAndSettle();
      expect(find.textContaining('réservée'), findsOneWidget);
    });
  });
}
