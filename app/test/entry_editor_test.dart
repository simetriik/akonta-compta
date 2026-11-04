import 'dart:typed_data';

import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/connectivity/connectivity.dart';
import 'package:akonta/src/application/providers/services.dart';
import 'package:akonta/src/application/services/documents_service.dart';
import 'package:akonta/src/domain/documents_models.dart';
import 'package:akonta/src/domain/repositories/documents_repository.dart';
import 'package:akonta/src/domain/repositories/outbox_repository.dart';
import 'package:akonta/src/domain/models.dart';
import 'package:akonta/src/domain/reference_models.dart';
import 'package:akonta/src/presentation/entries/entry_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:akonta/src/application/providers/references_providers.dart';
import 'package:akonta/src/application/providers/session_providers.dart';

/// Faux dépôt de pièces : une seule pièce PDF dans la boîte de réception du dossier.
class _FakeDocuments implements DocumentsRepository {
  static final doc = DocumentModel(
    id: 'd1',
    entityId: 'e1',
    storagePath: 'c/e1/d1.pdf',
    fileName: 'facture.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 2048,
    sha256: 'a' * 64,
    capturedVia: 'desktop',
    capturedAt: DateTime(2026, 11, 2),
  );

  @override
  Future<List<DocumentModel>> list(String entityId, {bool inboxOnly = false}) async => [doc];

  @override
  Future<String> signedUrl(DocumentModel d) async => 'https://exemple.test/facture.pdf';

  @override
  Future<Uint8List> download(DocumentModel d) async => Uint8List(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOutbox implements OutboxRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Dossier courant pré-sélectionné pour les tests.
class _FixedEntity extends CurrentEntityNotifier {
  @override
  EntitySummary? build() => const EntitySummary(id: 'e1', name: 'SARL Démo', fiscalYearLabel: '2026');
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  const accounts = [
    Account(
      id: 'a1',
      code: '6221000',
      label: 'Locations',
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
  ];
  const journals = [Journal(id: 'j1', code: 'OD', label: 'Opérations diverses', type: 'misc', isActive: true)];

  Widget app({String? documentId}) => ProviderScope(
    overrides: [
      currentEntityProvider.overrideWith(_FixedEntity.new),
      accountsProvider.overrideWith((ref, id) async => accounts),
      thirdPartiesProvider.overrideWith((ref, id) async => const <ThirdParty>[]),
      journalsProvider.overrideWith((ref, id) async => journals),
      permissionsProvider.overrideWith(
        (ref) async => const PermissionSet(
          byEntity: {
            'e1': {'entries.draft', 'entries.validate', 'documents.attach'},
          },
          cabinetWide: {},
          roles: [],
        ),
      ),
      documentsServiceProvider.overrideWithValue(DocumentsService(_FakeDocuments(), const OnlinePolicy(AlwaysOnline()), _FakeOutbox())),
    ],
    child: MaterialApp(
      home: Scaffold(body: EntryEditorScreen(documentId: documentId)),
    ),
  );

  testWidgets('la grille affiche l\'écart puis l\'équilibre après contrepartie automatique', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Équilibrée'), findsOneWidget);

    // Saisie d'un débit de 100 000 sur la première ligne
    final debitFields = find.byType(AkAmountField);
    await tester.enterText(debitFields.at(0), '100000');
    await tester.pumpAndSettle();
    expect(find.textContaining('Écart'), findsOneWidget);

    // Contrepartie automatique (bouton) → crédit 100 000 sur la ligne vide
    await tester.tap(find.text('Contrepartie (Ctrl+B)'));
    await tester.pumpAndSettle();
    expect(find.text('Équilibrée'), findsOneWidget);
  });

  testWidgets('valider sans compte ni libellé liste les erreurs sans appel réseau', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('validate-entry')));
    await tester.pumpAndSettle();
    // Le journal est proposé d'office : l'utilisateur n'a pas à le choisir pour obtenir les autres erreurs.
    expect(find.textContaining('Journal requis'), findsNothing);
    expect(find.textContaining('Libellé requis'), findsOneWidget);
    expect(find.textContaining('Au moins deux lignes'), findsOneWidget);
  });

  testWidgets('créer une écriture depuis une pièce : la pièce est jointe et s\'affiche à côté de la grille sur grand écran', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(documentId: 'd1'));
    await tester.pumpAndSettle();
    expect(find.text('Pièces justificatives (1)'), findsOneWidget);
    expect(find.text('facture.pdf'), findsWidgets);
    expect(find.byKey(const Key('document-pane')), findsOneWidget);
    // Fermer l'aperçu ne détache pas la pièce.
    await tester.tap(find.byKey(const Key('document-pane-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-pane')), findsNothing);
    expect(find.text('Pièces justificatives (1)'), findsOneWidget);
  });

  testWidgets('sur écran étroit, la pièce jointe s\'ouvre dans une fenêtre et non à côté de la grille', (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(documentId: 'd1'));
    await tester.pumpAndSettle();
    expect(find.text('Pièces justificatives (1)'), findsOneWidget);
    expect(find.byKey(const Key('document-pane')), findsNothing);
  });

  testWidgets('sur mobile, les pièces sont repliées et la barre du bas tient en deux lignes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(documentId: 'd1'));
    await tester.pumpAndSettle();
    // Le bloc des pièces est replié, son nombre reste visible sur la ligne qui le déplie.
    expect(find.byKey(const Key('entry-documents')), findsNothing);
    expect(find.text('Pièces justificatives (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('entry-documents-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('entry-documents')), findsOneWidget);
    // Pas de raccourci clavier sur mobile ; les actions d'en-tête sont courtes.
    expect(find.text('Raccourcis (F1)'), findsNothing);
    expect(find.text('Contrepartie'), findsOneWidget);
    // Enregistrer et Valider sont côte à côte, sous l'indicateur d'équilibre.
    final chip = tester.getRect(find.byKey(const Key('balance-chip')));
    final save = tester.getRect(find.byKey(const Key('save-draft')));
    final validate = tester.getRect(find.byKey(const Key('validate-entry')));
    expect(save.top, greaterThan(chip.bottom));
    expect(validate.top, save.top);
  });

  testWidgets('sur mobile, la grille annonce qu\'elle défile pour atteindre le débit et le crédit', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('Faites glisser la grille'), findsOneWidget);
  });

  testWidgets('sur grand écran, la grille n\'affiche pas d\'indice de défilement', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('Faites glisser la grille'), findsNothing);
    expect(find.text('Raccourcis (F1)'), findsOneWidget);
  });
}
