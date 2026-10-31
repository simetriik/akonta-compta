import 'dart:async';
import 'dart:typed_data';

import 'package:akonta/design/design.dart';
import 'package:akonta/src/application/connectivity/connectivity.dart';
import 'package:akonta/src/application/offline/in_memory_outbox.dart';
import 'package:akonta/src/application/providers/repositories.dart';
import 'package:akonta/src/application/providers/services.dart';
import 'package:akonta/src/domain/outbox_models.dart';
import 'package:akonta/src/presentation/shell/offline_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:akonta/src/domain/repositories/documents_repository.dart';
import 'package:akonta/src/domain/repositories/entries_repository.dart';
import 'package:akonta/src/application/offline/outbox_codec.dart';
import 'package:akonta/src/domain/entry_models.dart';

class _Net implements ConnectivityPort {
  _Net(bool online) : _online = online;

  bool _online;
  final _changes = StreamController<bool>.broadcast();

  void set(bool online) {
    _online = online;
    _changes.add(online);
  }

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<bool> check() async => _online;
}

/// Dépôts injoignables : la synchronisation automatique échoue sur un défaut de connexion et laisse la file intacte.
class _UnreachableEntries implements EntriesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw Exception('Connection refused');
}

class _UnreachableDocuments implements DocumentsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw Exception('Connection refused');
}

Map<String, dynamic> _draftPayload() => encodeEntryDraft(cabinetId: 'c1', entityId: 'e1', draft: EntryDraft(journalId: 'j1', label: 'Loyer', lines: [DraftLine(accountId: 'a1', debit: 10), DraftLine(accountId: 'a2', credit: 10)]));

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<void> pump(WidgetTester tester, {required _Net net, InMemoryOutboxRepository? outbox, String location = '/saisie'}) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overrides = <Override>[
      connectivityProvider.overrideWithValue(net),
      outboxRepositoryProvider.overrideWithValue(outbox ?? InMemoryOutboxRepository()),
      entriesRepositoryProvider.overrideWithValue(_UnreachableEntries()),
      documentsRepositoryProvider.overrideWithValue(_UnreachableDocuments()),
    ];
    await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: buildAkontaTheme(), home: Scaffold(body: OfflineGate(location: location, child: const Text('contenu'))))));
    await tester.pump();
  }

  testWidgets('en ligne et sans rien en attente : le contenu seul', (tester) async {
    await pump(tester, net: _Net(true));
    expect(find.text('contenu'), findsOneWidget);
    expect(find.byKey(const Key('offline-banner')), findsNothing);
  });

  testWidgets('hors connexion : bandeau explicatif, les brouillons restent accessibles', (tester) async {
    await pump(tester, net: _Net(false));
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.textContaining('Mode hors connexion'), findsOneWidget);
    expect(find.text('contenu'), findsOneWidget);
  });

  testWidgets('hors connexion : grand livre, balance et clôture sont remplacés par un message', (tester) async {
    for (final route in ['/consultation', '/consultation/grand-livre', '/cloture', '/inventaire', '/lettrage', '/utilisateurs', '/dossiers/nouveau']) {
      await pump(tester, net: _Net(false), location: route);
      expect(find.text('contenu'), findsNothing, reason: route);
      expect(find.textContaining('nécessite une connexion internet'), findsOneWidget, reason: route);
    }
    for (final route in ['/', '/saisie', '/saisie/nouvelle', '/pieces', '/referentiels', '/dossiers']) {
      await pump(tester, net: _Net(false), location: route);
      expect(find.text('contenu'), findsOneWidget, reason: route);
    }
  });

  testWidgets('le retour de la connexion rend l\'écran', (tester) async {
    final net = _Net(false);
    await pump(tester, net: net, location: '/consultation');
    expect(find.text('contenu'), findsNothing);
    net.set(true);
    await tester.pump();
    await tester.pump();
    expect(find.text('contenu'), findsOneWidget);
    expect(find.byKey(const Key('offline-banner')), findsNothing);
  });

  testWidgets('éléments en attente en ligne : proposition de synchroniser', (tester) async {
    final outbox = InMemoryOutboxRepository();
    await outbox.enqueue(OutboxKind.entryDraft, _draftPayload());
    await outbox.enqueue(OutboxKind.documentUpload, encodeDocumentUpload(cabinetId: 'c1', entityId: 'e1', fileName: 'a.pdf', bytes: Uint8List.fromList([1]), capturedVia: 'upload'));
    await pump(tester, net: _Net(true), outbox: outbox);
    await tester.pump();
    expect(find.byKey(const Key('sync-pending-banner')), findsOneWidget);
    expect(find.text('2 éléments saisis hors connexion à envoyer.'), findsOneWidget);
    expect(find.text('Synchroniser maintenant'), findsOneWidget);
  });

  testWidgets('un élément refusé par le serveur est signalé avec son motif', (tester) async {
    final outbox = InMemoryOutboxRepository();
    final id = await outbox.enqueue(OutboxKind.entryDraft, _draftPayload());
    await outbox.recordFailure(id, 'Période verrouillée.');
    await pump(tester, net: _Net(true), outbox: outbox);
    await tester.pump();
    expect(find.byKey(const Key('sync-failed-banner')), findsOneWidget);
    expect(find.textContaining('Période verrouillée.'), findsOneWidget);
  });
}
