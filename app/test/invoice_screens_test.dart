import 'dart:typed_data';

import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/connectivity/connectivity.dart';
import 'package:akonta/src/application/providers/invoices_providers.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/application/providers/services.dart';
import 'package:akonta/src/application/providers/session_providers.dart';
import 'package:akonta/src/domain/invoice_models.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/repositories/invoices_repository.dart';
import 'package:akonta/src/presentation/invoices/invoice_editor.dart';
import 'package:akonta/src/presentation/invoices/invoice_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _Repo implements InvoicesRepository {
  InvoiceDraft? saved;
  String? issued;
  IssueResult result = const IssueResult(state: IssueState.confirmed);

  @override
  Future<List<EmcfDevice>> devices(String entityId) async => [const EmcfDevice(id: 'd1', entityId: 'e1', nim: 'XX01000001', label: 'Boutique', mode: 'test', isActive: true)];
  @override
  Future<EmcfDevice> createDevice({required String cabinetId, required String entityId, required String nim, required String label, required String mode}) => throw UnimplementedError();
  @override
  Future<void> setDeviceActive(String deviceId, bool active) async {}
  @override
  Future<void> setToken(String deviceId, String token) async {}
  @override
  Future<List<Invoice>> invoices(String entityId) async => [];
  @override
  Future<Invoice> invoice(String id) => throw UnimplementedError();
  @override
  Future<String> saveDraft(String cabinetId, InvoiceDraft draft) async {
    saved = draft;
    return 'i1';
  }

  @override
  Future<void> deleteDraft(String id) async {}
  @override
  Future<IssueResult> issue(String id) async {
    issued = id;
    return result;
  }

  @override
  Future<IssueResult> resume(String id) async => result;
  @override
  Future<IssueResult> cancelPending(String id) async => result;
  @override
  Future<String> createCreditNote(String originalId) async => 'avoir1';
  @override
  Future<(String, Uint8List)> pdf(String id) async => ('f.pdf', Uint8List(0));
}

Invoice _confirmed({String type = 'FV'}) => Invoice(
      id: 'i1',
      entityId: 'e1',
      deviceId: 'd1',
      type: type,
      status: InvoiceStatus.confirmed,
      isTest: true,
      operatorName: 'Jacques',
      createdAt: DateTime(2026, 11, 4),
      clientName: 'Supermarché SARL',
      total: 4950,
      codeMecef: 'X537-E4DB-AJUU-HHXN-FWIS-FEKJ',
      qrCode: 'F;XX01000001;X537E4DBAJUUHHXNFWISFEKJ;3201900000001;20261104131708',
      counters: '64/64 FV',
      dgiNim: 'XX01000001',
      dgiDatetime: '04/11/2026 13:17:08',
      issuedAt: DateTime(2026, 11, 4, 13, 17),
      lines: const [InvoiceLine(name: 'Jus d\'orange', price: 1800, quantity: 2, taxGroup: 'B'), InvoiceLine(name: 'Lait 1/1 EX', price: 450, quantity: 3, taxGroup: 'A')],
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<_Repo> pump(WidgetTester tester, Widget home, {Set<String> perms = const {'invoices.issue'}}) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        invoicesRepositoryProvider.overrideWithValue(repo),
        onlinePolicyProvider.overrideWithValue(const OnlinePolicy(AlwaysOnline())),
        permissionsProvider.overrideWith((ref) async => PermissionSet(byEntity: {'e1': perms}, cabinetWide: const {}, roles: const [])),
        currentProfileProvider.overrideWith((ref) async => const Profile(id: 'u1', cabinetId: 'c1', email: 'a@b.test', fullName: 'Awa Chef', isActive: true)),
        emcfDevicesProvider('e1').overrideWith((ref) async => await repo.devices('e1')),
      ],
      child: MaterialApp(theme: buildAkontaTheme(), home: Scaffold(body: home)),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('l\'éditeur reprend l\'opérateur du profil et calcule les totaux en direct (exemple de la DGI)', (tester) async {
    await pump(tester, const InvoiceEditor(entityId: 'e1'));
    expect(tester.widget<TextField>(find.descendant(of: find.byKey(const Key('invoice-operator')), matching: find.byType(TextField))).controller!.text, 'Awa Chef');

    await tester.enterText(find.byKey(const Key('line-name-0')), 'Jus d\'orange');
    await tester.enterText(find.byKey(const Key('line-qty-0')), '2');
    await tester.enterText(find.byKey(const Key('line-price-0')), '1800');
    await tester.tap(find.byKey(const Key('add-line')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('line-name-1')), 'Lait 1/1 EX');
    await tester.enterText(find.byKey(const Key('line-qty-1')), '3');
    await tester.enterText(find.byKey(const Key('line-price-1')), '450');
    await tester.tap(find.byKey(const Key('line-group-1')));      // la ligne du lait est exonérée (groupe A)
    await tester.pumpAndSettle();
    await tester.tap(find.text('A · Exonéré').last);
    await tester.pumpAndSettle();

    final totals = find.byKey(const Key('invoice-totals'));
    // Le séparateur de milliers (espace fine insécable U+202F en français) dépend de la bibliothèque : on l'accepte tel quel.
    expect(find.descendant(of: totals, matching: find.textContaining(RegExp(r'^4\D950$'))), findsOneWidget); // total TTC
    expect(find.descendant(of: totals, matching: find.textContaining(RegExp(r'^3\D051$'))), findsOneWidget); // HT du groupe B
    expect(find.descendant(of: totals, matching: find.textContaining(RegExp(r'^549$'))), findsOneWidget); // TVA
  });

  testWidgets('une facture invalide n\'est pas envoyée : messages clairs, rien n\'est enregistré', (tester) async {
    final repo = await pump(tester, const InvoiceEditor(entityId: 'e1'));
    await tester.tap(find.byKey(const Key('issue-invoice')));
    await tester.pumpAndSettle();
    // L'éditeur démarre avec une ligne vide : c'est elle qui est signalée.
    expect(find.text('Article 1 : le nom est obligatoire.'), findsOneWidget);
    expect(find.text('Article 1 : le prix unitaire doit être supérieur à 0.'), findsOneWidget);
    expect(repo.saved, isNull);
    expect(repo.issued, isNull);
  });

  testWidgets('émission : le brouillon envoyé contient les articles, puis la DGI est appelée après confirmation', (tester) async {
    final repo = await pump(tester, const InvoiceEditor(entityId: 'e1'));
    await tester.enterText(find.byKey(const Key('line-name-0')), 'Jus d\'orange');
    await tester.enterText(find.byKey(const Key('line-price-0')), '1800');
    await tester.enterText(find.byKey(const Key('line-qty-0')), '2');
    await tester.enterText(find.byKey(const Key('client-ifu')), '3201900000002');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('issue-invoice')));
    await tester.pumpAndSettle();
    expect(find.text('Émettre la facture ?'), findsOneWidget);
    expect(repo.issued, isNull, reason: 'rien n\'est envoyé tant que l\'utilisateur n\'a pas confirmé');
    await tester.tap(find.text('Émettre'));
    await tester.pumpAndSettle();
    expect(repo.saved!.deviceId, 'd1');
    expect(repo.saved!.clientIfu, '3201900000002');
    expect(repo.saved!.lines.single.amount, 3600);
    expect(repo.saved!.payments.single.amount, 3600);
    expect(repo.issued, 'i1');
  });

  testWidgets('refus de la DGI : le motif et les écarts s\'affichent, la facture reste modifiable', (tester) async {
    final repo = await pump(tester, const InvoiceEditor(entityId: 'e1'));
    repo.result = const IssueResult(state: IssueState.draft, message: 'Les totaux de la DGI diffèrent du calcul d\'Akonta.', gaps: ['Total : calculé 3600, DGI 3601']);
    await tester.enterText(find.byKey(const Key('line-name-0')), 'Jus');
    await tester.enterText(find.byKey(const Key('line-price-0')), '1800');
    await tester.enterText(find.byKey(const Key('line-qty-0')), '2');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('issue-invoice')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Émettre'));
    await tester.pumpAndSettle();
    final banner = find.byKey(const Key('issue-error'));
    expect(banner, findsOneWidget);
    expect(find.descendant(of: banner, matching: find.textContaining('Total : calculé 3600, DGI 3601')), findsNothing); // le texte est dans le Text lui-même
    expect(tester.widget<Text>(banner).data, contains('Total : calculé 3600, DGI 3601'));
  });

  testWidgets('facture émise : QR code, éléments de sécurité et actions (PDF, avoir)', (tester) async {
    await pump(tester, InvoiceView(invoice: _confirmed()));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('X537-E4DB-AJUU-HHXN-FWIS-FEKJ'), findsOneWidget);
    expect(find.text('64/64 FV'), findsOneWidget);
    expect(find.byKey(const Key('invoice-pdf')), findsOneWidget);
    expect(find.byKey(const Key('credit-note')), findsOneWidget);
    expect(find.textContaining('environnement de test'), findsOneWidget);
  });

  testWidgets('un avoir ne propose pas de nouvel avoir', (tester) async {
    await pump(tester, InvoiceView(invoice: _confirmed(type: 'FA')));
    expect(find.byKey(const Key('credit-note')), findsNothing);
    expect(find.byKey(const Key('invoice-pdf')), findsOneWidget);
  });

  testWidgets('sans droit d\'émission : pas de bouton d\'avoir, mais le PDF reste disponible', (tester) async {
    await pump(tester, InvoiceView(invoice: _confirmed()), perms: const {});
    expect(find.byKey(const Key('credit-note')), findsNothing);
    expect(find.byKey(const Key('invoice-pdf')), findsOneWidget, reason: 'consulter et télécharger ne demande que l\'accès au dossier');
  });
}
