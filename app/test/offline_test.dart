import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:akonta/src/application/connectivity/connectivity.dart';
import 'package:akonta/src/application/offline/in_memory_outbox.dart';
import 'package:akonta/src/application/offline/outbox_codec.dart';
import 'package:akonta/src/application/offline/sync_service.dart';
import 'package:akonta/src/application/services/closing_service.dart';
import 'package:akonta/src/application/services/documents_service.dart';
import 'package:akonta/src/application/services/entries_service.dart';
import 'package:akonta/src/core/errors/errors.dart';
import 'package:akonta/src/domain/documents_models.dart';
import 'package:akonta/src/domain/entry_models.dart';
import 'package:akonta/src/domain/outbox_models.dart';
import 'package:akonta/src/domain/repositories/closing_repository.dart';
import 'package:akonta/src/domain/repositories/documents_repository.dart';
import 'package:akonta/src/domain/repositories/entries_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeConnectivity implements ConnectivityPort {
  FakeConnectivity([this.online = true]);

  bool online;

  @override
  bool get isOnline => online;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();

  @override
  Future<bool> check() async => online;
}

class FakeEntries implements EntriesRepository {
  final saved = <EntryDraft>[];
  Object? failWith;
  var counter = 0;

  @override
  Future<String> saveDraft(String cabinetId, String entityId, EntryDraft d) async {
    if (failWith != null) throw failWith!;
    saved.add(d);
    return 'remote-${++counter}';
  }

  @override
  Future<List<EntryModel>> list(String entityId, EntryFilter f, {String? fiscalYearId, int limit = 300}) async {
    if (failWith != null) throw failWith!;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

class FakeDocuments implements DocumentsRepository {
  final uploads = <String>[];

  @override
  Future<DocumentModel> upload({required String cabinetId, required String entityId, required String fileName, required Uint8List bytes, required String capturedVia, String? note}) async {
    uploads.add('$fileName:${bytes.length}');
    throw UnimplementedError('le résultat n\'est pas utilisé');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

EntryDraft draft({String label = 'Loyer janvier', String? id}) => EntryDraft(
      id: id,
      journalId: 'j1',
      date: DateTime(2026, 1, 31),
      label: label,
      reference: 'F-1',
      lines: [
        DraftLine(accountId: 'a1', accountCode: '6222000', accountLabel: 'Locations', debit: 300000),
        DraftLine(accountId: 'a2', accountCode: '4011000', accountLabel: 'Fournisseurs', isCollective: true, thirdPartyId: 't1', thirdPartyCode: 'SOB', credit: 300000),
      ],
    );

void main() {
  late FakeConnectivity net;
  late InMemoryOutboxRepository outbox;
  late FakeEntries entriesRepo;
  late EntriesService entries;

  setUp(() {
    net = FakeConnectivity();
    outbox = InMemoryOutboxRepository();
    entriesRepo = FakeEntries();
    entries = EntriesService(entriesRepo, OnlinePolicy(net), outbox);
  });

  group('brouillons hors connexion', () {
    test('en ligne : le brouillon est enregistré sur le serveur', () async {
      expect(await entries.saveDraft('c1', 'e1', draft()), 'remote-1');
      expect(await outbox.all(), isEmpty);
    });

    test('hors ligne : le brouillon est conservé sur l\'appareil avec un identifiant local', () async {
      net.online = false;
      final id = await entries.saveDraft('c1', 'e1', draft());
      expect(isLocalDraftId(id), isTrue);
      expect(entriesRepo.saved, isEmpty);
      final item = (await outbox.all()).single;
      expect(item.kind, OutboxKind.entryDraft);
      expect(item.payload['entity_id'], 'e1');
    });

    test('en ligne mais serveur injoignable : le brouillon est mis en file, une autre erreur est relancée', () async {
      entriesRepo.failWith = Exception('ClientException: Failed to fetch');
      expect(isLocalDraftId(await entries.saveDraft('c1', 'e1', draft())), isTrue);
      entriesRepo.failWith = const AppError.business('Période verrouillée.');
      await expectLater(entries.saveDraft('c1', 'e1', draft(label: 'autre')), throwsA(isA<AppError>()));
      expect((await outbox.all()).length, 1);
    });

    test('un brouillon local se relit, se modifie et se supprime', () async {
      net.online = false;
      final id = await entries.saveDraft('c1', 'e1', draft());
      final read = await entries.get(id);
      expect(read.label, 'Loyer janvier');
      expect(read.isDraft, isTrue);
      expect(read.lines.map((l) => l.accountCode), ['6222000', '4011000']);
      expect(read.lines.last.thirdPartyCode, 'SOB');
      final edited = EntryDraft.fromEntry(read)..label = 'Loyer janvier 2026';
      expect(await entries.saveDraft('c1', 'e1', edited), id);
      expect((await entries.get(id)).label, 'Loyer janvier 2026');
      await entries.deleteDraft(id);
      expect(await outbox.all(), isEmpty);
      await expectLater(entries.get(id), throwsA(isA<AppError>()));
    });

    test('la liste de saisie montre les brouillons en attente de l\'entité demandée, filtrés', () async {
      net.online = false;
      await entries.saveDraft('c1', 'e1', draft(label: 'Loyer'));
      await entries.saveDraft('c1', 'e1', draft(label: 'Électricité'));
      await entries.saveDraft('c1', 'e2', draft(label: 'Autre dossier'));
      final all = await entries.list('e1', const EntryFilter());
      expect(all.map((e) => e.label), ['Électricité', 'Loyer']);
      expect((await entries.list('e1', const EntryFilter(search: 'loy'))).map((e) => e.label), ['Loyer']);
      expect(await entries.list('e1', const EntryFilter(status: 'validated')), isEmpty);
    });

    test('la liste reste disponible hors ligne quand des brouillons attendent, et signale l\'erreur sinon', () async {
      net.online = false;
      entriesRepo.failWith = Exception('Failed host lookup');
      await entries.saveDraft('c1', 'e1', draft());
      expect((await entries.list('e1', const EntryFilter())).length, 1);
      expect(() => entries.list('e2', const EntryFilter()), throwsA(isA<Exception>()));
    });

    test('valider hors connexion est refusé avec un message clair', () async {
      net.online = false;
      await expectLater(
        entries.validate('x'),
        throwsA(isA<AppError>().having((e) => e.kind, 'kind', AppErrorKind.offline).having((e) => e.message, 'message', contains('connexion internet'))),
      );
    });
  });

  group('règle hors connexion des fonctions de calcul', () {
    test('clôture, grand livre et autres calculs exigent la connexion', () async {
      net.online = false;
      final closing = ClosingService(_NoClosing(), OnlinePolicy(net));
      await expectLater(closing.generateStatements('e', 'fy'), throwsA(isA<AppError>().having((e) => e.message, 'message', startsWith('Les états financiers'))));
      await expectLater(closing.runChecks('e', 'fy'), throwsA(isA<AppError>().having((e) => e.kind, 'kind', AppErrorKind.offline)));
    });

    test('en ligne, l\'appel passe au dépôt', () async {
      final closing = ClosingService(_NoClosing(), OnlinePolicy(net));
      await expectLater(closing.runChecks('e', 'fy'), throwsA(isA<UnsupportedError>()));
    });
  });

  group('pièces hors connexion', () {
    test('hors ligne : la pièce est mise en file, le résultat est null', () async {
      net.online = false;
      final docs = DocumentsService(FakeDocuments(), OnlinePolicy(net), outbox);
      final result = await docs.upload(cabinetId: 'c1', entityId: 'e1', fileName: 'facture.pdf', bytes: Uint8List.fromList([1, 2, 3]), capturedVia: 'upload');
      expect(result, isNull);
      final item = (await outbox.all()).single;
      expect(item.kind, OutboxKind.documentUpload);
      expect(base64Decode(item.payload['bytes'] as String), [1, 2, 3]);
    });
  });

  group('synchronisation', () {
    late FakeDocuments docsRepo;
    late SyncService sync;

    setUp(() {
      docsRepo = FakeDocuments();
      sync = SyncService(outbox: outbox, entries: entriesRepo, documents: docsRepo, connectivity: net);
    });

    test('rejoue la file dans l\'ordre et la vide', () async {
      net.online = false;
      await entries.saveDraft('c1', 'e1', draft(label: 'Premier'));
      await entries.saveDraft('c1', 'e1', draft(label: 'Second'));
      net.online = true;
      final report = await sync.flush();
      expect(report.sent, 2);
      expect(report.remaining, 0);
      expect(entriesRepo.saved.map((d) => d.label), ['Premier', 'Second']);
      expect(entriesRepo.saved.first.id, isNull);
      expect(await outbox.all(), isEmpty);
    });

    test('hors ligne, rien n\'est envoyé', () async {
      await outbox.enqueue(OutboxKind.entryDraft, encodeEntryDraft(cabinetId: 'c1', entityId: 'e1', draft: draft()));
      net.online = false;
      expect((await sync.flush()).sent, 0);
      expect(entriesRepo.saved, isEmpty);
    });

    test('un défaut de connexion arrête le passage et garde les éléments', () async {
      await outbox.enqueue(OutboxKind.entryDraft, encodeEntryDraft(cabinetId: 'c1', entityId: 'e1', draft: draft(label: 'A')));
      await outbox.enqueue(OutboxKind.entryDraft, encodeEntryDraft(cabinetId: 'c1', entityId: 'e1', draft: draft(label: 'B')));
      entriesRepo.failWith = Exception('Connection refused');
      final report = await sync.flush();
      expect(report.sent, 0);
      expect(report.remaining, 2);
      expect((await outbox.all()).every((i) => !i.hasFailed), isTrue);
    });

    test('un refus métier est consigné sur l\'élément, qui n\'est plus rejoué seul après trois échecs', () async {
      final id = await outbox.enqueue(OutboxKind.entryDraft, encodeEntryDraft(cabinetId: 'c1', entityId: 'e1', draft: draft()));
      entriesRepo.failWith = const AppError.business('Période verrouillée.');
      expect((await sync.flush()).failed, 1);
      await sync.flush();
      await sync.flush();
      final item = (await outbox.get(id))!;
      expect(item.attempts, SyncService.maxAutomaticAttempts);
      expect(item.lastError, 'Période verrouillée.');
      expect((await sync.flush()).failed, 0);
      entriesRepo.failWith = null;
      expect((await sync.flush(retryFailed: true)).sent, 1);
      expect(await outbox.all(), isEmpty);
    });
  });

  test('le codec conserve les lignes, les tiers et les montants d\'un brouillon', () {
    final payload = encodeEntryDraft(cabinetId: 'c1', entityId: 'e1', draft: draft(id: 'remote-9'));
    final back = decodeEntryDraft(jsonDecode(jsonEncode(payload)) as Map<String, dynamic>);
    expect(back.id, 'remote-9');
    expect(back.lines.last.thirdPartyCode, 'SOB');
    expect(back.lines.last.isCollective, isTrue);
    expect(back.totalDebit, 300000);
    expect(back.totalCredit, 300000);
  });
}

class _NoClosing implements ClosingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}
