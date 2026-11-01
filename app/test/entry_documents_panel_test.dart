import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/providers/documents_providers.dart';
import 'package:akonta/src/domain/documents_models.dart';
import 'package:akonta/src/presentation/entries/entry_documents_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DocumentModel _doc(String id, String name, {List<String> entryIds = const []}) => DocumentModel(
  id: id,
  entityId: 'e1',
  storagePath: 'c/e1/$id.pdf',
  fileName: name,
  mimeType: 'application/pdf',
  sizeBytes: 2048,
  sha256: 'a' * 64,
  capturedVia: 'desktop',
  capturedAt: DateTime(2026, 11, 2),
  entryIds: entryIds,
);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<void> pump(
    WidgetTester tester, {
    String? entryId,
    List<DocumentModel> pending = const [],
    bool canAttach = true,
    bool canDetach = true,
    List<DocumentModel> attached = const [],
    List<DocumentModel> inbox = const [],
    void Function(List<DocumentModel>)? onPending,
    void Function(DocumentModel)? onView,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsProvider('e1').overrideWith((ref) async => inbox),
          entryDocumentsProvider('s1').overrideWith((ref) async => attached),
        ],
        child: MaterialApp(
          theme: buildAkontaTheme(),
          home: Scaffold(
            body: EntryDocumentsPanel(
              entityId: 'e1',
              entryId: entryId,
              pending: pending,
              onPendingChanged: onPending ?? (_) {},
              onView: onView ?? (_) {},
              canAttach: canAttach,
              canDetach: canDetach,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sans pièce, le panneau explique quoi joindre et propose les sources', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux; // ordinateur : pas de bouton photo
    await pump(tester);
    expect(find.byKey(const Key('doc-empty')), findsOneWidget);
    expect(find.textContaining('facture, le reçu ou le relevé'), findsOneWidget);
    expect(find.byKey(const Key('doc-from-inbox')), findsOneWidget);
    expect(find.byKey(const Key('doc-upload')), findsOneWidget);
    expect(find.byKey(const Key('doc-photo')), findsNothing); // la photo n'est proposée que sur mobile
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('une nouvelle écriture garde les pièces choisies en attente et permet de les retirer', (tester) async {
    List<DocumentModel>? after;
    await pump(tester, pending: [_doc('d1', 'facture.pdf'), _doc('d2', 'recu.pdf')], onPending: (l) => after = l);
    expect(find.text('facture.pdf'), findsOneWidget);
    expect(find.text('Pièces justificatives (2)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('doc-detach-d1')));
    await tester.pumpAndSettle();
    expect(after!.map((d) => d.id), ['d2']);
  });

  testWidgets('la boîte de réception propose les pièces non rattachées et en choisit une', (tester) async {
    List<DocumentModel>? after;
    await pump(
      tester,
      inbox: [_doc('d1', 'a-rattacher.pdf'), _doc('d2', 'deja-liee.pdf', entryIds: ['x'])],
      onPending: (l) => after = l,
    );
    await tester.tap(find.byKey(const Key('doc-from-inbox')));
    await tester.pumpAndSettle();
    expect(find.text('a-rattacher.pdf'), findsOneWidget);
    expect(find.text('deja-liee.pdf'), findsNothing);
    await tester.tap(find.byKey(const Key('inbox-d1')));
    await tester.pumpAndSettle();
    expect(after!.map((d) => d.id), ['d1']);
  });

  testWidgets('une écriture validée montre ses pièces sans pouvoir les détacher', (tester) async {
    await pump(tester, entryId: 's1', attached: [_doc('d1', 'facture.pdf', entryIds: ['s1'])], canDetach: false);
    expect(find.text('facture.pdf'), findsOneWidget);
    expect(find.byKey(const Key('doc-detach-d1')), findsNothing);
  });

  testWidgets('sans le droit de joindre, aucun bouton d\'ajout', (tester) async {
    await pump(tester, canAttach: false);
    expect(find.byKey(const Key('doc-from-inbox')), findsNothing);
    expect(find.byKey(const Key('doc-upload')), findsNothing);
    expect(find.text('Aucune pièce jointe.'), findsOneWidget);
  });

  testWidgets('toucher une pièce l\'affiche', (tester) async {
    DocumentModel? viewed;
    await pump(tester, pending: [_doc('d1', 'facture.pdf')], onView: (d) => viewed = d);
    await tester.tap(find.byKey(const Key('doc-d1')));
    expect(viewed?.id, 'd1');
  });
}
