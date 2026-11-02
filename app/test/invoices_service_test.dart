import 'dart:typed_data';

import 'package:akonta/src/application/connectivity/connectivity.dart';
import 'package:akonta/src/application/services/invoices_service.dart';
import 'package:akonta/src/core/errors/errors.dart';
import 'package:akonta/src/domain/invoice_models.dart';
import 'package:akonta/src/domain/repositories/invoices_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Net implements ConnectivityPort {
  _Net(this.online);
  bool online;
  @override
  bool get isOnline => online;
  @override
  Stream<bool> get changes => const Stream.empty();
  @override
  Future<bool> check() async => online;
}

class _Repo implements InvoicesRepository {
  final calls = <String>[];

  @override
  Future<List<EmcfDevice>> devices(String entityId) async => [];
  @override
  Future<EmcfDevice> createDevice({required String cabinetId, required String entityId, required String nim, required String label, required String mode}) async {
    calls.add('createDevice:$nim');
    return EmcfDevice(id: 'd1', entityId: entityId, nim: nim, label: label, mode: mode, isActive: true);
  }

  @override
  Future<void> setDeviceActive(String deviceId, bool active) async => calls.add('active');
  @override
  Future<void> setToken(String deviceId, String token) async => calls.add('token:$token');
  @override
  Future<List<Invoice>> invoices(String entityId) async => [];
  @override
  Future<Invoice> invoice(String id) => throw UnimplementedError();
  @override
  Future<String> saveDraft(String cabinetId, InvoiceDraft draft) async => 'i1';
  @override
  Future<void> deleteDraft(String id) async => calls.add('delete');
  @override
  Future<IssueResult> issue(String id) async {
    calls.add('issue');
    return const IssueResult(state: IssueState.confirmed);
  }

  @override
  Future<IssueResult> resume(String id) async => const IssueResult(state: IssueState.confirmed);
  @override
  Future<IssueResult> cancelPending(String id) async => const IssueResult(state: IssueState.draft);
  @override
  Future<String> createCreditNote(String originalId) async => 'avoir1';
  @override
  Future<(String, Uint8List)> pdf(String id) async => ('f.pdf', Uint8List(0));
  @override
  Future<InvoiceAccountSettings?> accountSettings(String entityId) async => null;
  @override
  Future<void> saveAccountSettings(String cabinetId, InvoiceAccountSettings settings) async => calls.add('settings');
  @override
  Future<InvoiceEntryLink?> invoiceEntry(String invoiceId) async => null;
  @override
  Future<EntryOutcome> generateEntry(String invoiceId) async {
    calls.add('entry');
    return const EntryOutcome(state: EntryState.generated, entryId: 'e1');
  }
}

void main() {
  test('en ligne : le NIM est mis en majuscules, le jeton et le libellé sont nettoyés', () async {
    final repo = _Repo();
    final service = InvoicesService(repo, OnlinePolicy(_Net(true)));
    final d = await service.createDevice(cabinetId: 'c', entityId: 'e', nim: ' xx01000001 ', label: ' Boutique ', mode: 'test');
    expect(d.nim, 'XX01000001');
    expect(d.label, 'Boutique');
    await service.setToken('d1', '  jeton  ');
    expect(repo.calls, containsAll(['createDevice:XX01000001', 'token:jeton']));
  });

  test('hors connexion : émission, avoir, PDF, jeton et enregistrement sont refusés avec un message clair', () async {
    final repo = _Repo();
    final service = InvoicesService(repo, OnlinePolicy(_Net(false)));
    for (final action in <Future<Object?> Function()>[
      () => service.issue('i1'),
      () => service.resume('i1'),
      () => service.cancelPending('i1'),
      () => service.createCreditNote('i1'),
      () => service.pdf('i1'),
      () => service.setToken('d1', 't'),
      () => service.saveDraft('c', const InvoiceDraft(entityId: 'e', deviceId: 'd', type: 'FV', operatorName: 'x', lines: [])),
      () => service.deleteDraft('i1'),
      () => service.generateEntry('i1'),
      () => service.saveAccountSettings('c', InvoiceAccountSettings(entityId: 'e', validFrom: DateTime(2026), clientAccountId: 'a', salesExemptAccountId: 'b', salesTaxableAccountId: 'b', vatAccountId: 'v')),
      () => service.createDevice(cabinetId: 'c', entityId: 'e', nim: 'XX01000001', label: 'x', mode: 'test'),
    ]) {
      await expectLater(action(), throwsA(isA<AppError>().having((e) => e.kind, 'kind', AppErrorKind.offline)));
    }
    expect(repo.calls, isEmpty, reason: 'aucun appel ne doit atteindre le dépôt hors connexion');
  });

  test('hors connexion : la lecture reste permise (cache)', () async {
    final service = InvoicesService(_Repo(), OnlinePolicy(_Net(false)));
    expect(await service.invoices('e'), isEmpty);
    expect(await service.devices('e'), isEmpty);
    expect(await service.accountSettings('e'), isNull);
    expect(await service.invoiceEntry('i1'), isNull);
  });
}
