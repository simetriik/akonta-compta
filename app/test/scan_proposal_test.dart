import 'package:akonta/src/domain/repositories/outbox_repository.dart';
import 'package:akonta/src/application/connectivity/connectivity.dart';
import 'package:akonta/src/application/services/documents_service.dart';
import 'package:akonta/src/core/errors/errors.dart';
import 'package:akonta/src/domain/documents_models.dart';
import 'package:akonta/src/domain/repositories/documents_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Scanner implements DocumentsRepository {
  final asked = <String>[];

  @override
  Future<ScanProposal> proposeEntry(String documentId) async {
    asked.add(documentId);
    return const ScanProposal(entryId: 'en1', existing: false, warnings: ['Fournisseur non retrouvé.']);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

class _Offline implements ConnectivityPort {
  @override
  bool get isOnline => false;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();

  @override
  Future<bool> check() async => false;
}

void main() {
  test('en ligne, la lecture de la pièce est confiée au dépôt et rend le brouillard proposé', () async {
    final repo = _Scanner();
    final service = DocumentsService(repo, const OnlinePolicy(AlwaysOnline()), _NoOutbox());
    final result = await service.proposeEntry('d1');
    expect(repo.asked, ['d1']);
    expect(result.entryId, 'en1');
    expect(result.warnings, ['Fournisseur non retrouvé.']);
  });

  test('hors connexion, la lecture est refusée avec un message clair et rien n\'est appelé', () async {
    final repo = _Scanner();
    final service = DocumentsService(repo, OnlinePolicy(_Offline()), _NoOutbox());
    await expectLater(service.proposeEntry('d1'), throwsA(isA<AppError>().having((e) => e.kind, 'kind', AppErrorKind.offline)));
    expect(repo.asked, isEmpty);
  });
}

class _NoOutbox implements OutboxRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}
